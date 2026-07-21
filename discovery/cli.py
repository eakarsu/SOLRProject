from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path

from .api import serve
from .benchmark import run_benchmark
from .config import Settings
from .generations import GenerationService
from .ingestion import IngestionService
from .query import QueryService
from .solr import SolrClient
from .store import SCHEMA_VERSION, Store
from .worker import IndexWorker


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description="Safe SOLRProject control plane")
    commands = root.add_subparsers(dest="command", required=True)
    commands.add_parser("init-db", help="explicitly apply local control-plane schema")
    commands.add_parser("serve", help="start API without migrations or maintenance")
    commands.add_parser("health", help="perform read-only dependency health checks")
    source = commands.add_parser("create-source")
    source.add_argument("name")
    principal = commands.add_parser("create-principal")
    principal.add_argument("id")
    principal.add_argument("--role", action="append", required=True)
    principal.add_argument("--group", action="append", default=[])
    ingest = commands.add_parser("ingest-jsonl")
    ingest.add_argument("source_id")
    ingest.add_argument("file", type=Path)
    delete = commands.add_parser("delete")
    delete.add_argument("source_id")
    delete.add_argument("external_id")
    delete.add_argument("version", type=int)
    commands.add_parser("work-once")
    replay = commands.add_parser("replay-job")
    replay.add_argument("job_id")
    create = commands.add_parser("generation-create")
    create.add_argument("name")
    verify = commands.add_parser("generation-verify")
    verify.add_argument("name")
    activate = commands.add_parser("generation-activate")
    activate.add_argument("name")
    activate.add_argument("--actor", required=True)
    purge = commands.add_parser("generation-purge")
    purge.add_argument("name")
    purge.add_argument("--confirm-collection", required=True)
    purge.add_argument("--actor", required=True)
    benchmark = commands.add_parser("benchmark")
    benchmark.add_argument("dataset", type=Path)
    benchmark.add_argument("--token", required=True)
    benchmark.add_argument("--min-recall", type=float, default=.8)
    benchmark.add_argument("--min-precision", type=float, default=.5)
    benchmark.add_argument("--max-p95-ms", type=float, default=500)
    backup = commands.add_parser("backup")
    backup.add_argument("output", type=Path)
    restore = commands.add_parser("restore-verify")
    restore.add_argument("backup", type=Path)
    return root


def _components(settings: Settings):
    store = Store(settings.database)
    solr = SolrClient(settings.solr_url, settings.request_timeout_seconds)
    return store, solr


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    settings = Settings.from_env()
    store, solr = _components(settings)
    try:
        if args.command == "init-db":
            store.migrate()
            print(json.dumps({"schema_version": SCHEMA_VERSION, "database": str(store.path)}))
        elif args.command == "serve":
            serve(settings)
        elif args.command == "health":
            ready = store.ready() and solr.ping(settings.solr_alias)
            print(json.dumps({"ready": ready, "database": store.ready()}))
            return 0 if ready else 1
        elif args.command == "create-source":
            print(store.create_source(args.name))
        elif args.command == "create-principal":
            token = store.create_principal(args.id, args.role, args.group)
            print(json.dumps({"id": args.id, "token": token,
                              "warning": "token is shown once; store it in a secret manager"}))
        elif args.command == "ingest-jsonl":
            records = [json.loads(line) for line in args.file.read_text(encoding="utf-8").splitlines() if line.strip()]
            print(json.dumps(IngestionService(store, settings.max_document_bytes,
                                              settings.max_batch_documents).ingest(
                                                  args.source_id, records).__dict__))
        elif args.command == "delete":
            print(IngestionService(store).delete(args.source_id, args.external_id, args.version))
        elif args.command == "work-once":
            print(IndexWorker(store, solr, settings.solr_alias).run_once() or "idle")
        elif args.command == "replay-job":
            print(IngestionService(store).replay(args.job_id))
        elif args.command.startswith("generation-"):
            generations = GenerationService(store, solr, settings.solr_alias)
            if args.command == "generation-create":
                print(generations.create(args.name))
            elif args.command == "generation-verify":
                print(json.dumps(generations.verify(args.name), sort_keys=True))
            elif args.command == "generation-activate":
                generations.activate(args.name, args.actor)
            else:
                generations.purge(args.name, args.confirm_collection, args.actor)
        elif args.command == "benchmark":
            principal = store.authenticate(args.token)
            if principal is None:
                raise PermissionError("invalid benchmark token")
            query = QueryService(store, solr, settings.solr_alias,
                                 settings.max_query_chars, settings.max_query_results)
            def search(text: str, limit: int) -> list[str]:
                return [doc.get("external_id_s", doc["id"]) for doc in
                        query.search(principal, text, limit)["documents"]]
            result = run_benchmark(args.dataset, search, min_recall=args.min_recall,
                                   min_precision=args.min_precision,
                                   max_p95_ms=args.max_p95_ms)
            print(json.dumps(result, ensure_ascii=False, sort_keys=True))
            return 0 if result["passed"] else 1
        elif args.command == "backup":
            if args.output.exists():
                raise ValueError("backup output already exists")
            args.output.parent.mkdir(parents=True, exist_ok=True)
            with store.connect() as source, sqlite3.connect(args.output) as target:
                source.backup(target)
            print(args.output)
        elif args.command == "restore-verify":
            uri = f"file:{args.backup.resolve()}?mode=ro"
            with sqlite3.connect(uri, uri=True) as db:
                integrity = db.execute("PRAGMA integrity_check").fetchone()[0]
                version = db.execute("SELECT version FROM schema_meta").fetchone()[0]
            valid = integrity == "ok" and version == SCHEMA_VERSION
            print(json.dumps({"valid": valid, "integrity": integrity, "schema_version": version}))
            return 0 if valid else 1
        return 0
    except (ValueError, PermissionError, RuntimeError, sqlite3.Error) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

