from __future__ import annotations

import contextlib
import hashlib
import json
import secrets
import sqlite3
import time
from pathlib import Path
from typing import Any, Iterator


SCHEMA_VERSION = 1
DDL = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS schema_meta(version INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS sources(
  id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS documents(
  source_id TEXT NOT NULL REFERENCES sources(id), external_id TEXT NOT NULL,
  source_version INTEGER NOT NULL, content_hash TEXT NOT NULL, payload TEXT,
  acl TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0,
  indexed_generation TEXT, updated_at INTEGER NOT NULL,
  PRIMARY KEY(source_id, external_id)
);
CREATE TABLE IF NOT EXISTS jobs(
  id TEXT PRIMARY KEY, dedupe_key TEXT NOT NULL UNIQUE, kind TEXT NOT NULL,
  source_id TEXT NOT NULL REFERENCES sources(id), external_id TEXT NOT NULL,
  source_version INTEGER NOT NULL, generation TEXT, state TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  available_at INTEGER NOT NULL, lease_until INTEGER, replay_of TEXT,
  last_error TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS jobs_claim ON jobs(state, available_at, lease_until);
CREATE TABLE IF NOT EXISTS principals(
  id TEXT PRIMARY KEY, token_digest TEXT NOT NULL UNIQUE, roles TEXT NOT NULL,
  groups_json TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1, created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS feedback(
  id TEXT PRIMARY KEY, principal_id TEXT NOT NULL REFERENCES principals(id),
  query_hash TEXT NOT NULL, document_id TEXT NOT NULL, signal TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS generations(
  name TEXT PRIMARY KEY, collection_name TEXT NOT NULL UNIQUE,
  state TEXT NOT NULL, expected_documents INTEGER NOT NULL DEFAULT 0,
  indexed_documents INTEGER NOT NULL DEFAULT 0, checksum TEXT,
  created_at INTEGER NOT NULL, activated_at INTEGER
);
CREATE TABLE IF NOT EXISTS audit_events(
  id TEXT PRIMARY KEY, actor TEXT NOT NULL, action TEXT NOT NULL,
  target TEXT NOT NULL, detail TEXT NOT NULL, created_at INTEGER NOT NULL
);
"""


def now() -> int:
    return int(time.time())


def uid(prefix: str) -> str:
    return f"{prefix}_{secrets.token_hex(12)}"


def digest(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


class Store:
    def __init__(self, path: str | Path):
        self.path = Path(path)

    @contextlib.contextmanager
    def connect(self) -> Iterator[sqlite3.Connection]:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.path, timeout=10)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys=ON")
        conn.execute("PRAGMA busy_timeout=10000")
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def migrate(self) -> None:
        with self.connect() as db:
            db.executescript(DDL)
            row = db.execute("SELECT version FROM schema_meta").fetchone()
            if row is None:
                db.execute("INSERT INTO schema_meta(version) VALUES (?)", (SCHEMA_VERSION,))
            elif row["version"] != SCHEMA_VERSION:
                raise RuntimeError(f"unsupported schema version {row['version']}")

    def ready(self) -> bool:
        if not self.path.is_file():
            return False
        try:
            uri = f"file:{self.path.resolve()}?mode=ro"
            with sqlite3.connect(uri, uri=True) as db:
                row = db.execute("SELECT version FROM schema_meta").fetchone()
                return row is not None and row[0] == SCHEMA_VERSION
        except (sqlite3.Error, TypeError):
            return False

    def create_source(self, name: str) -> str:
        if not name or len(name) > 100:
            raise ValueError("source name must contain 1-100 characters")
        source_id = uid("src")
        with self.connect() as db:
            db.execute("INSERT INTO sources VALUES (?, ?, ?)", (source_id, name, now()))
        return source_id

    def create_principal(self, principal_id: str, roles: list[str], groups: list[str]) -> str:
        allowed = {"query", "feedback", "ingest", "admin", "debug"}
        if not principal_id or not roles or not set(roles) <= allowed:
            raise ValueError("invalid principal or role")
        if any(not g or len(g) > 100 for g in groups):
            raise ValueError("invalid group")
        token = secrets.token_urlsafe(32)
        with self.connect() as db:
            db.execute(
                "INSERT INTO principals VALUES (?, ?, ?, ?, 1, ?)",
                (principal_id, digest(token), json.dumps(sorted(set(roles))),
                 json.dumps(sorted(set(groups))), now()),
            )
        return token

    def authenticate(self, token: str) -> dict[str, Any] | None:
        with self.connect() as db:
            row = db.execute(
                "SELECT id, roles, groups_json FROM principals WHERE token_digest=? AND enabled=1",
                (digest(token),),
            ).fetchone()
        if row is None:
            return None
        return {"id": row["id"], "roles": json.loads(row["roles"]),
                "groups": json.loads(row["groups_json"])}

    def audit(self, actor: str, action: str, target: str, detail: dict[str, Any]) -> None:
        with self.connect() as db:
            db.execute("INSERT INTO audit_events VALUES (?, ?, ?, ?, ?, ?)",
                       (uid("aud"), actor, action, target,
                        json.dumps(detail, sort_keys=True), now()))
