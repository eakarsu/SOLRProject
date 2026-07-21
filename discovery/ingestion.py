from __future__ import annotations

import hashlib
import json
import sqlite3
from dataclasses import dataclass
from typing import Any, Iterable

from .store import Store, now, uid


@dataclass(frozen=True)
class IngestResult:
    accepted: int = 0
    duplicate: int = 0
    stale: int = 0


def _canonical(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True)


class IngestionService:
    def __init__(self, store: Store, max_document_bytes: int = 262_144,
                 max_batch_documents: int = 500):
        self.store = store
        self.max_document_bytes = max_document_bytes
        self.max_batch_documents = max_batch_documents

    def ingest(self, source_id: str, records: Iterable[dict[str, Any]],
               generation: str | None = None) -> IngestResult:
        items = list(records)
        if not items or len(items) > self.max_batch_documents:
            raise ValueError(f"batch must contain 1-{self.max_batch_documents} documents")
        counts = {"accepted": 0, "duplicate": 0, "stale": 0}
        with self.store.connect() as db:
            if db.execute("SELECT 1 FROM sources WHERE id=?", (source_id,)).fetchone() is None:
                raise ValueError("unknown source")
            for record in items:
                outcome = self._ingest_one(db, source_id, record, generation)
                counts[outcome] += 1
        return IngestResult(**counts)

    def _ingest_one(self, db: sqlite3.Connection, source_id: str,
                    record: dict[str, Any], generation: str | None) -> str:
        external_id = str(record.get("id", "")).strip()
        version = record.get("version")
        document = record.get("document")
        acl = record.get("acl", ["public"])
        if not external_id or len(external_id) > 200 or not isinstance(version, int) or version < 1:
            raise ValueError("each record requires a valid id and positive integer version")
        if not isinstance(document, dict) or not isinstance(acl, list) or not acl:
            raise ValueError("document must be an object and acl a non-empty list")
        if any(not isinstance(g, str) or not g or len(g) > 100 for g in acl):
            raise ValueError("invalid ACL group")
        payload = _canonical(document)
        if len(payload.encode("utf-8")) > self.max_document_bytes:
            raise ValueError("document exceeds MAX_DOCUMENT_BYTES")
        content_hash = hashlib.sha256(payload.encode()).hexdigest()
        previous = db.execute(
            "SELECT source_version, content_hash, deleted FROM documents WHERE source_id=? AND external_id=?",
            (source_id, external_id),
        ).fetchone()
        if previous and version < previous["source_version"]:
            return "stale"
        if previous and version == previous["source_version"]:
            return "duplicate" if previous["content_hash"] == content_hash and not previous["deleted"] else "stale"
        stamp = now()
        db.execute(
            """INSERT INTO documents VALUES (?, ?, ?, ?, ?, ?, 0, NULL, ?)
               ON CONFLICT(source_id, external_id) DO UPDATE SET
               source_version=excluded.source_version, content_hash=excluded.content_hash,
               payload=excluded.payload, acl=excluded.acl, deleted=0,
               indexed_generation=NULL, updated_at=excluded.updated_at""",
            (source_id, external_id, version, content_hash, payload,
             _canonical(sorted(set(acl))), stamp),
        )
        self._job(db, "upsert", source_id, external_id, version, content_hash, generation)
        return "accepted"

    def delete(self, source_id: str, external_id: str, version: int,
               generation: str | None = None) -> str:
        if version < 1 or not external_id:
            raise ValueError("invalid delete version or id")
        with self.store.connect() as db:
            row = db.execute(
                "SELECT source_version, deleted FROM documents WHERE source_id=? AND external_id=?",
                (source_id, external_id),
            ).fetchone()
            if row and version < row["source_version"]:
                return "stale"
            if row and version == row["source_version"]:
                return "duplicate" if row["deleted"] else "stale"
            stamp = now()
            tombstone_hash = hashlib.sha256(f"deleted:{version}".encode()).hexdigest()
            db.execute(
                """INSERT INTO documents VALUES (?, ?, ?, ?, NULL, '[]', 1, NULL, ?)
                   ON CONFLICT(source_id, external_id) DO UPDATE SET
                   source_version=excluded.source_version, content_hash=excluded.content_hash,
                   payload=NULL, acl='[]', deleted=1, indexed_generation=NULL,
                   updated_at=excluded.updated_at""",
                (source_id, external_id, version, tombstone_hash, stamp),
            )
            self._job(db, "delete", source_id, external_id, version, tombstone_hash, generation)
        return "accepted"

    @staticmethod
    def _job(db: sqlite3.Connection, kind: str, source_id: str, external_id: str,
             version: int, content_hash: str, generation: str | None) -> None:
        key = hashlib.sha256(
            f"{kind}\0{source_id}\0{external_id}\0{version}\0{content_hash}\0{generation or ''}".encode()
        ).hexdigest()
        stamp = now()
        db.execute(
            """INSERT OR IGNORE INTO jobs
               (id,dedupe_key,kind,source_id,external_id,source_version,generation,state,attempts,
                available_at,lease_until,replay_of,last_error,created_at,updated_at)
               VALUES (?,?,?,?,?,?,?,'pending',0,?,NULL,NULL,NULL,?,?)""",
            (uid("job"), key, kind, source_id, external_id, version, generation,
             stamp, stamp, stamp),
        )

    def replay(self, failed_job_id: str) -> str:
        with self.store.connect() as db:
            row = db.execute("SELECT * FROM jobs WHERE id=? AND state='failed'", (failed_job_id,)).fetchone()
            if row is None:
                raise ValueError("only a failed job can be replayed")
            stamp = now()
            replay_id = uid("job")
            replay_key = hashlib.sha256(f"replay\0{failed_job_id}\0{replay_id}".encode()).hexdigest()
            db.execute(
                """INSERT INTO jobs VALUES (?,?,?,?,?,?,?, 'pending',0,?,NULL,?,NULL,?,?)""",
                (replay_id, replay_key, row["kind"], row["source_id"], row["external_id"],
                 row["source_version"], row["generation"], stamp, failed_job_id, stamp, stamp),
            )
        return replay_id
