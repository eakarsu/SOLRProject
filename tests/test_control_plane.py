from __future__ import annotations

import json
import hashlib
import tempfile
import unittest
from pathlib import Path

from discovery.benchmark import run_benchmark
from discovery.generations import GenerationService
from discovery.ingestion import IngestionService
from discovery.query import QueryService
from discovery.store import Store
from discovery.worker import IndexWorker


class FakeSolr:
    def __init__(self):
        self.updates = []
        self.queries = []
        self.collections = set()
        self.aliases = {}
        self.fail = False
        self.documents = {}

    def update(self, collection, commands):
        if self.fail:
            raise RuntimeError("simulated outage")
        self.updates.append((collection, commands))
        target = self.aliases.get(collection, collection)
        bucket = self.documents.setdefault(target, {})
        for command in commands:
            if "add" in command:
                doc = command["add"]["doc"]
                bucket[doc["id"]] = doc
            elif "delete" in command:
                bucket.pop(command["delete"]["id"], None)

    def query(self, collection, params):
        self.queries.append((collection, params))
        return {"response": {"numFound": 1, "docs": [{"id": "src:42"}]},
                "debug": {"explain": {"src:42": "fresh title match"}}}

    def create_collection(self, collection):
        self.collections.add(collection)

    def ping(self, collection):
        return collection in self.collections or collection in self.aliases

    def activate_alias(self, alias, collection):
        self.aliases[alias] = collection

    def delete_collection(self, collection):
        self.collections.remove(collection)

    def fingerprint(self, collection):
        docs = self.documents.get(collection, {})
        hashes = sorted(doc["content_hash_s"] for doc in docs.values())
        return len(docs), hashlib.sha256("\0".join(hashes).encode()).hexdigest()


class ControlPlaneTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.store = Store(Path(self.temp.name) / "discovery.db")
        self.store.migrate()
        self.source = self.store.create_source("catalog")
        self.solr = FakeSolr()

    def tearDown(self):
        self.temp.cleanup()

    def record(self, version=1, title="Elma", acl=None):
        return {"id": "42", "version": version,
                "document": {"title": title, "language": "tr"},
                "acl": acl or ["public"]}

    def test_schema_is_idempotent_and_ready(self):
        self.store.migrate()
        self.assertTrue(self.store.ready())

    def test_incremental_ingestion_deduplicates_and_rejects_stale(self):
        service = IngestionService(self.store)
        self.assertEqual(service.ingest(self.source, [self.record()]).accepted, 1)
        self.assertEqual(service.ingest(self.source, [self.record()]).duplicate, 1)
        self.assertEqual(service.ingest(self.source, [self.record(1, "changed")]).stale, 1)
        self.assertEqual(service.ingest(self.source, [self.record(2, "Armut")]).accepted, 1)
        with self.store.connect() as db:
            self.assertEqual(db.execute("SELECT count(*) FROM jobs").fetchone()[0], 2)
            row = db.execute("SELECT source_version, payload FROM documents").fetchone()
        self.assertEqual(row["source_version"], 2)
        self.assertIn("Armut", row["payload"])

    def test_deletion_propagates_and_old_jobs_are_superseded(self):
        service = IngestionService(self.store)
        service.ingest(self.source, [self.record()])
        self.assertEqual(service.delete(self.source, "42", 2), "accepted")
        worker = IndexWorker(self.store, self.solr, "live")
        worker.run_once()
        worker.run_once()
        self.assertEqual(len(self.solr.updates), 1)
        self.assertEqual(self.solr.updates[0][1][0]["delete"]["id"], f"{self.source}:42")
        with self.store.connect() as db:
            states = [row[0] for row in db.execute("SELECT state FROM jobs ORDER BY created_at, id")]
        self.assertEqual(sorted(states), ["completed", "superseded"])

    def test_failed_job_can_be_replayed(self):
        service = IngestionService(self.store)
        service.ingest(self.source, [self.record()])
        self.solr.fail = True
        with self.assertRaises(RuntimeError):
            IndexWorker(self.store, self.solr, "live", max_attempts=1).run_once()
        with self.store.connect() as db:
            failed = db.execute("SELECT id FROM jobs WHERE state='failed'").fetchone()[0]
        replay = service.replay(failed)
        self.assertTrue(replay.startswith("job_"))

    def test_permissions_filter_query_and_gate_explanation(self):
        service = QueryService(self.store, self.solr, "live")
        principal = {"id": "reader", "roles": ["query"], "groups": ["team-a"]}
        result = service.search(principal, "kırmızı elma", explain=True)
        self.assertNotIn("explanation", result)
        params = self.solr.queries[-1][1]
        self.assertEqual(params["fq"], "{!terms f=acl_ss}public,team-a")
        principal["roles"].append("debug")
        self.assertIn("explanation", service.search(principal, "elma", explain=True))
        self.assertEqual(service.search(principal, "*:*"), {"documents": [], "total": 0,
                         "elapsed_ms": 0, "query_hash": service.query_hash("*:*")})
        with self.assertRaises(ValueError):
            service.search(principal, "(" * 30)

    def test_feedback_stores_hash_not_raw_query(self):
        token = self.store.create_principal("user", ["feedback"], [])
        principal = self.store.authenticate(token)
        service = QueryService(self.store, self.solr, "live")
        query_hash = service.query_hash("private raw query")
        service.feedback(principal, query_hash, "doc-1", "click")
        with self.store.connect() as db:
            row = db.execute("SELECT query_hash, document_id FROM feedback").fetchone()
        self.assertEqual(row["query_hash"], query_hash)
        self.assertEqual(row["document_id"], "doc-1")

    def test_generation_rebuild_verify_atomic_activation_and_guarded_purge(self):
        IngestionService(self.store).ingest(self.source, [self.record()])
        # Drain the live job first; generation counts only its own snapshot jobs.
        IndexWorker(self.store, self.solr, "live").run_once()
        generations = GenerationService(self.store, self.solr, "live", 0)
        collection = generations.create("g001")
        IndexWorker(self.store, self.solr, "live").run_once()
        self.assertEqual(generations.verify("g001")["state"], "ready")
        generations.activate("g001", "operator")
        self.assertEqual(self.solr.aliases["live"], collection)
        with self.assertRaises(ValueError):
            generations.purge("g001", collection, "operator")
        generations.create("g002")
        IndexWorker(self.store, self.solr, "live").run_once()
        generations.verify("g002")
        generations.activate("g002", "operator")
        with self.assertRaises(ValueError):
            generations.purge("g001", "wrong", "operator")
        generations.purge("g001", collection, "operator")
        self.assertNotIn(collection, self.solr.collections)

    def test_benchmark_covers_multilingual_adversarial_and_latency(self):
        dataset = Path(self.temp.name) / "benchmark.jsonl"
        cases = [
            {"id": "tr", "query": "elma", "language": "tr", "expected_ids": ["42"]},
            {"id": "en", "query": "apple", "language": "en", "expected_ids": ["42"]},
            {"id": "empty", "query": "", "kind": "empty", "expect_empty": True},
            {"id": "attack", "query": "*:*", "kind": "adversarial", "expect_empty": True},
        ]
        dataset.write_text("\n".join(json.dumps(c) for c in cases), encoding="utf-8")
        result = run_benchmark(dataset, lambda q, k: [] if q in {"", "*:*"} else ["42"])
        self.assertTrue(result["passed"])
        self.assertEqual(set(result["recall_by_language"]), {"en", "tr"})


if __name__ == "__main__":
    unittest.main()
