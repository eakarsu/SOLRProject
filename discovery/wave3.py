"""Wave 3: tasks, document export/search helpers, and AI summaries.

Tasks live in a separate SQLite file next to the control-plane database so
the main schema is never migrated. AI provider calls happen only when
OPENROUTER_API_KEY or OPENAI_API_KEY is configured; otherwise a clearly
labelled deterministic fallback (aiGenerated: false) is returned.
"""
from __future__ import annotations

import csv
import io
import json
import os
import sqlite3
import time
import urllib.request
from pathlib import Path
from typing import Any


def has_provider(env: dict | None = None) -> bool:
    env = os.environ if env is None else env
    return bool(str(env.get("OPENROUTER_API_KEY") or env.get("OPENAI_API_KEY") or "").strip())


def format_value(value: Any) -> str:
    if value is False:
        return "false"
    if value == 0 and not isinstance(value, bool):
        return "0"
    if value in ("", None):
        return "(empty)"
    if isinstance(value, list):
        return ", ".join(str(v) for v in value) if value else "(empty)"
    return str(value)


def render_sections(sections: list[dict[str, Any]]) -> str:
    """Render AI JSON as readable labelled lines, preserving false/0/empty."""
    return "\n".join(f"{s['label']}: {format_value(s.get('value'))}" for s in sections or [])


def filter_documents(rows: list[dict[str, Any]], q: str = "", source_id: str = "") -> list[dict[str, Any]]:
    needle = str(q or "").strip().lower()
    out = []
    for row in rows or []:
        if source_id and row.get("source_id") != source_id:
            continue
        if needle and needle not in json.dumps(row, ensure_ascii=False).lower():
            continue
        out.append(row)
    return out


def to_csv(rows: list[dict[str, Any]], columns: list[str]) -> str:
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=columns, extrasaction="ignore")
    writer.writeheader()
    for row in rows or []:
        writer.writerow({c: ("|".join(map(str, row[c])) if isinstance(row.get(c), list) else row.get(c, "")) for c in columns})
    return buf.getvalue()


def fallback(feature: str, records: list[dict[str, Any]]) -> dict[str, Any]:
    rows = records or []
    deleted = sum(1 for r in rows if r.get("deleted"))
    by_feature = {
        "query-suggestions": [
            {"label": "Documents reviewed", "value": len(rows)},
            {"label": "Sources covered", "value": len({r.get("source_id") for r in rows})},
            {"label": "Deleted documents", "value": deleted},
            {"label": "Has deleted documents", "value": bool(deleted)},
        ],
        "index-health": [
            {"label": "Documents reviewed", "value": len(rows)},
            {"label": "Indexed documents", "value": sum(1 for r in rows if r.get("indexed_generation"))},
            {"label": "Unindexed documents", "value": sum(1 for r in rows if not r.get("indexed_generation"))},
            {"label": "First document id", "value": rows[0].get("external_id", "") if rows else ""},
        ],
        "relevance-gaps": [
            {"label": "Documents reviewed", "value": len(rows)},
            {"label": "Deleted documents", "value": deleted},
            {"label": "Live documents", "value": len(rows) - deleted},
            {"label": "Coverage complete", "value": bool(rows) and deleted == 0},
        ],
    }
    return {
        "aiGenerated": False,
        "source": "deterministic-fallback",
        "notice": "No AI provider key configured (OPENROUTER_API_KEY/OPENAI_API_KEY); showing a deterministic summary of your own records.",
        "feature": feature,
        "sections": by_feature.get(feature, [{"label": "Documents reviewed", "value": len(rows)}]),
    }


def provider_summary(feature: str, records: list[dict[str, Any]], env: dict | None = None) -> dict[str, Any]:
    env = os.environ if env is None else env
    if not has_provider(env):
        return fallback(feature, records)
    key = env.get("OPENROUTER_API_KEY") or env.get("OPENAI_API_KEY")
    base = "https://openrouter.ai/api/v1" if env.get("OPENROUTER_API_KEY") else "https://api.openai.com/v1"
    model = env.get("OPENROUTER_MODEL") or env.get("OPENAI_MODEL") or "openai/gpt-4o-mini"
    body = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": "Summarize the supplied search-index records as JSON sections."},
            {"role": "user", "content": f"Feature: {feature}\nRecords: {json.dumps(records)[:8000]}"},
        ],
    }).encode()
    req = urllib.request.Request(
        f"{base}/chat/completions", data=body, method="POST",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            payload = json.loads(resp.read())
    except Exception:
        return {**fallback(feature, records), "providerError": "Provider request failed"}
    content = payload.get("choices", [{}])[0].get("message", {}).get("content", "")
    return {"aiGenerated": True, "source": "provider", "model": payload.get("model", model),
            "feature": feature, "sections": [{"label": "Summary", "value": content}]}


FEATURES = ["query-suggestions", "index-health", "relevance-gaps"]


class TaskStore:
    """Authenticated tasks in a sidecar SQLite file (main DB untouched)."""

    def __init__(self, database_path: str | Path):
        base = Path(database_path)
        self.path = base.with_name(base.name + ".wave3-tasks.db")

    def _connect(self) -> sqlite3.Connection:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.path, timeout=10)
        conn.row_factory = sqlite3.Row
        conn.execute(
            "CREATE TABLE IF NOT EXISTS wave3_tasks ("
            "id INTEGER PRIMARY KEY AUTOINCREMENT, owner TEXT NOT NULL, title TEXT NOT NULL,"
            "status TEXT NOT NULL DEFAULT 'open', priority TEXT NOT NULL DEFAULT 'medium',"
            "notes TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)"
        )
        return conn

    def list(self, owner: str, q: str = "", status: str = "") -> list[dict[str, Any]]:
        with self._connect() as conn:
            rows = conn.execute(
                "SELECT * FROM wave3_tasks WHERE owner=? ORDER BY created_at DESC LIMIT 200", (owner,)
            ).fetchall()
        needle = str(q or "").strip().lower()
        return [dict(r) for r in rows
                if (not status or r["status"] == status) and (not needle or needle in r["title"].lower())]

    def create(self, owner: str, title: str, status: str = "open", priority: str = "medium", notes: str | None = None) -> dict[str, Any]:
        if not str(title or "").strip() or len(title) > 300:
            raise ValueError("title must be 1-300 characters")
        if status not in ("open", "in_progress", "done"):
            raise ValueError("status must be open, in_progress, or done")
        if priority not in ("low", "medium", "high"):
            raise ValueError("priority must be low, medium, or high")
        ts = int(time.time())
        with self._connect() as conn:
            cur = conn.execute(
                "INSERT INTO wave3_tasks (owner,title,status,priority,notes,created_at,updated_at) VALUES (?,?,?,?,?,?,?)",
                (owner, title.strip(), status, priority, notes, ts, ts),
            )
            row = conn.execute("SELECT * FROM wave3_tasks WHERE id=?", (cur.lastrowid,)).fetchone()
        return dict(row)

    def update(self, owner: str, task_id: int, fields: dict[str, Any]) -> dict[str, Any] | None:
        allowed = {k: v for k, v in fields.items() if k in ("title", "status", "priority", "notes")}
        if "status" in allowed and allowed["status"] not in ("open", "in_progress", "done"):
            raise ValueError("status must be open, in_progress, or done")
        if "priority" in allowed and allowed["priority"] not in ("low", "medium", "high"):
            raise ValueError("priority must be low, medium, or high")
        if not allowed:
            raise ValueError("at least one editable field is required")
        sets = ", ".join(f"{k}=?" for k in allowed)
        with self._connect() as conn:
            conn.execute(
                f"UPDATE wave3_tasks SET {sets}, updated_at=? WHERE id=? AND owner=?",
                (*allowed.values(), int(time.time()), task_id, owner),
            )
            row = conn.execute("SELECT * FROM wave3_tasks WHERE id=? AND owner=?", (task_id, owner)).fetchone()
        return dict(row) if row else None
