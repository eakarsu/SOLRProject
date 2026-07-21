from __future__ import annotations

import hashlib
import re

from .ingestion import IngestionService
from .solr import SolrClient
from .store import Store, now


SAFE_NAME = re.compile(r"^[a-z][a-z0-9-]{2,62}$")


class GenerationService:
    def __init__(self, store: Store, solr: SolrClient, alias: str,
                 minimum_retention_seconds: int = 86_400):
        self.store = store
        self.solr = solr
        self.alias = alias
        self.minimum_retention_seconds = minimum_retention_seconds

    def create(self, name: str) -> str:
        if not SAFE_NAME.fullmatch(name):
            raise ValueError("generation must match [a-z][a-z0-9-]{2,62}")
        collection = f"{self.alias}-{name}"
        self.solr.create_collection(collection)
        stamp = now()
        with self.store.connect() as db:
            count = db.execute("SELECT count(*) FROM documents WHERE deleted=0").fetchone()[0]
            db.execute("INSERT INTO generations VALUES (?, ?, 'building', ?, 0, NULL, ?, NULL)",
                       (name, collection, count, stamp))
            documents = db.execute(
                "SELECT source_id, external_id, source_version, content_hash FROM documents WHERE deleted=0"
            ).fetchall()
            for document in documents:
                IngestionService._job(db, "upsert", document["source_id"],
                                      document["external_id"], document["source_version"],
                                      document["content_hash"], name)
        return collection

    def verify(self, name: str) -> dict[str, int | str]:
        with self.store.connect() as db:
            generation = db.execute("SELECT * FROM generations WHERE name=?", (name,)).fetchone()
            if generation is None:
                raise ValueError("unknown generation")
            pending = db.execute(
                "SELECT count(*) FROM jobs WHERE generation=? AND state IN ('pending','running')", (name,)
            ).fetchone()[0]
            failed = db.execute(
                "SELECT count(*) FROM jobs WHERE generation=? AND state='failed'", (name,)
            ).fetchone()[0]
            hashes = [row[0] for row in db.execute(
                "SELECT content_hash FROM documents WHERE deleted=0"
            )]
            checksum = hashlib.sha256("\0".join(sorted(hashes)).encode()).hexdigest()
        solr_count, solr_checksum = self.solr.fingerprint(generation["collection_name"])
        ready = (pending == 0 and failed == 0
                 and generation["indexed_documents"] == generation["expected_documents"]
                 and solr_count == generation["expected_documents"]
                 and solr_checksum == checksum)
        with self.store.connect() as db:
            if ready:
                db.execute("UPDATE generations SET state='ready', checksum=? WHERE name=?",
                           (checksum, name))
        return {"state": "ready" if ready else "building", "pending": pending,
                "failed": failed, "expected": generation["expected_documents"],
                "indexed": generation["indexed_documents"], "solr_count": solr_count,
                "checksum": checksum, "checksum_match": str(solr_checksum == checksum).lower()}

    def activate(self, name: str, actor: str) -> None:
        with self.store.connect() as db:
            generation = db.execute(
                "SELECT * FROM generations WHERE name=? AND state='ready'", (name,)
            ).fetchone()
            if generation is None:
                raise ValueError("generation must pass verification before activation")
        if not self.solr.ping(generation["collection_name"]):
            raise RuntimeError("generation collection is not healthy")
        self.solr.activate_alias(self.alias, generation["collection_name"])
        with self.store.connect() as db:
            db.execute("UPDATE generations SET state='retired' WHERE state='active'")
            db.execute("UPDATE generations SET state='active', activated_at=? WHERE name=?",
                       (now(), name))
        self.store.audit(actor, "generation.activate", name,
                         {"collection": generation["collection_name"], "alias": self.alias})

    def purge(self, name: str, confirmation: str, actor: str) -> None:
        with self.store.connect() as db:
            generation = db.execute("SELECT * FROM generations WHERE name=?", (name,)).fetchone()
            if generation is None:
                raise ValueError("unknown generation")
            if generation["state"] == "active":
                raise ValueError("the active generation cannot be purged")
            if now() - generation["created_at"] < self.minimum_retention_seconds:
                raise ValueError("generation has not met minimum retention")
            if confirmation != generation["collection_name"]:
                raise ValueError("confirmation must exactly equal the collection name")
        self.solr.delete_collection(generation["collection_name"])
        with self.store.connect() as db:
            db.execute("UPDATE generations SET state='purged' WHERE name=?", (name,))
        self.store.audit(actor, "generation.purge", name,
                         {"collection": generation["collection_name"]})
