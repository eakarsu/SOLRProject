from __future__ import annotations

import json
from typing import Any

from .solr import SolrClient
from .store import Store, now


class IndexWorker:
    def __init__(self, store: Store, solr: SolrClient, live_alias: str,
                 max_attempts: int = 5, lease_seconds: int = 60):
        self.store = store
        self.solr = solr
        self.live_alias = live_alias
        self.max_attempts = max_attempts
        self.lease_seconds = lease_seconds

    def run_once(self) -> str | None:
        job = self._claim()
        if job is None:
            return None
        try:
            status = self._process(job)
            self._finish(job["id"], status)
        except Exception as exc:
            self._fail(job["id"], job["attempts"], str(exc))
            raise
        return job["id"]

    def _claim(self) -> dict[str, Any] | None:
        stamp = now()
        with self.store.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute(
                """SELECT * FROM jobs
                   WHERE (state='pending' AND available_at<=?)
                      OR (state='running' AND lease_until<?)
                   ORDER BY created_at, id LIMIT 1""", (stamp, stamp)
            ).fetchone()
            if row is None:
                return None
            db.execute(
                "UPDATE jobs SET state='running', attempts=attempts+1, lease_until=?, updated_at=? WHERE id=?",
                (stamp + self.lease_seconds, stamp, row["id"]),
            )
            result = dict(row)
            result["attempts"] += 1
            return result

    def _process(self, job: dict[str, Any]) -> str:
        with self.store.connect() as db:
            document = db.execute(
                "SELECT * FROM documents WHERE source_id=? AND external_id=?",
                (job["source_id"], job["external_id"]),
            ).fetchone()
        if document is None or document["source_version"] != job["source_version"]:
            return "superseded"
        target = self.live_alias
        if job["generation"]:
            with self.store.connect() as db:
                generation = db.execute(
                    "SELECT collection_name FROM generations WHERE name=?",
                    (job["generation"],),
                ).fetchone()
            if generation is None:
                raise RuntimeError("job references an unknown generation")
            target = generation["collection_name"]
        solr_id = f"{job['source_id']}:{job['external_id']}"
        if job["kind"] == "delete":
            if not document["deleted"]:
                return "superseded"
            self.solr.update(target, [{"delete": {"id": solr_id}}])
        else:
            if document["deleted"]:
                return "superseded"
            payload = json.loads(document["payload"])
            payload.update({
                "id": solr_id,
                "source_id_s": job["source_id"],
                "external_id_s": job["external_id"],
                "source_version_l": document["source_version"],
                "content_hash_s": document["content_hash"],
                "acl_ss": json.loads(document["acl"]),
                "source_updated_at_l": document["updated_at"],
            })
            self.solr.update(target, [{"add": {"doc": payload, "overwrite": True}}])
        with self.store.connect() as db:
            db.execute(
                "UPDATE documents SET indexed_generation=? WHERE source_id=? AND external_id=? AND source_version=?",
                (target, job["source_id"], job["external_id"], job["source_version"]),
            )
            if job["generation"]:
                db.execute(
                    "UPDATE generations SET indexed_documents=indexed_documents+1 WHERE name=?",
                    (job["generation"],),
                )
        return "completed"

    def _finish(self, job_id: str, state: str) -> None:
        with self.store.connect() as db:
            db.execute("UPDATE jobs SET state=?, lease_until=NULL, updated_at=? WHERE id=?",
                       (state, now(), job_id))

    def _fail(self, job_id: str, attempts: int, message: str) -> None:
        terminal = attempts >= self.max_attempts
        delay = min(300, 2 ** attempts)
        with self.store.connect() as db:
            db.execute(
                """UPDATE jobs SET state=?, available_at=?, lease_until=NULL,
                   last_error=?, updated_at=? WHERE id=?""",
                ("failed" if terminal else "pending", now() + delay,
                 message[:1000], now(), job_id),
            )
