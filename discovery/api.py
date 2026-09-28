from __future__ import annotations

import json
import os
import sqlite3
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from .config import Settings
from .ingestion import IngestionService
from .query import QueryService
from .solr import SolrClient, SolrError
from .store import Store


class DiscoveryServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address: tuple[str, int], settings: Settings):
        super().__init__(address, Handler)
        self.settings = settings
        self.store = Store(settings.database)
        self.solr = SolrClient(settings.solr_url, settings.request_timeout_seconds)
        self.ingestion = IngestionService(self.store, settings.max_document_bytes,
                                          settings.max_batch_documents)
        self.query = QueryService(self.store, self.solr, settings.solr_alias,
                                  settings.max_query_chars, settings.max_query_results)


class Handler(BaseHTTPRequestHandler):
    server: DiscoveryServer

    def log_message(self, format: str, *args: Any) -> None:
        return

    def _send(self, status: int, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def _html(self, body: str) -> None:
        payload = body.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Security-Policy", "default-src 'none'; connect-src http://127.0.0.1:*; script-src 'unsafe-inline'; style-src 'unsafe-inline'; frame-ancestors 'none'")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(payload)

    def _workspace(self) -> str:
        api_origin = json.dumps(f"http://127.0.0.1:{int(os.getenv('BACKEND_PORT', '4000'))}")
        return f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Search Discovery Operations</title><style>body{{font:16px system-ui;max-width:48rem;margin:4rem auto;padding:0 1rem;color:#172033}}section{{border:1px solid #d9dfeb;border-radius:14px;padding:1.4rem;box-shadow:0 12px 36px #17203314}}label,input,button{{display:block;width:100%;margin:.65rem 0}}input,button{{padding:.75rem;box-sizing:border-box;border:1px solid #aeb8ca;border-radius:8px}}button{{cursor:pointer;font-weight:700;background:#fff}}button[type=submit]{{background:#155eef;border-color:#155eef;color:#fff}}.status{{min-height:1.5rem;color:#a32121}}.dashboard{{display:none}}.dashboard[aria-hidden=false]{{display:block}}.identity{{padding:1rem;background:#f4f7fb;border-radius:10px}}</style></head><body><h1>Search Discovery Operations</h1><p>Operate governed ingestion, relevance, index generation, feedback, and search-quality controls.</p><section id="login-panel"><form id="login"><label>Email<input id="email" type="email" autocomplete="username" required></label><label>Password<input id="password" type="password" autocomplete="current-password" required></label><button id="fill-demo" type="button">Auto Fill Demo Credentials</button><button type="submit">Sign In</button><p id="status" class="status" aria-live="polite"></p></form></section><section id="dashboard" class="dashboard" aria-hidden="true"><h2>Authenticated Search Operations Dashboard</h2><p id="identity" class="identity"></p><p>Your runtime session is active. Search ingestion, relevance, and generation controls remain governed by the application APIs.</p></section><script>const apiOrigin={api_origin};let token='';const email=document.getElementById('email');const password=document.getElementById('password');const status=document.getElementById('status');document.getElementById('fill-demo').addEventListener('click',async()=>{{status.textContent='';const response=await fetch(apiOrigin+'/api/auth/demo-credentials');if(!response.ok){{status.textContent='Demo credentials are unavailable.';return}}const credentials=await response.json();email.value=credentials.email;password.value=credentials.password;email.focus();status.textContent='Demo credentials filled. Select Sign In to continue.';}});document.getElementById('login').addEventListener('submit',async(event)=>{{event.preventDefault();status.textContent='Signing in…';const response=await fetch(apiOrigin+'/api/auth/login',{{method:'POST',headers:{{'Content-Type':'application/json'}},body:JSON.stringify({{email:email.value,password:password.value}})}});const body=await response.json();if(!response.ok){{status.textContent='Sign in failed.';return}}token=body.token;const me=await fetch(apiOrigin+'/api/auth/me',{{headers:{{Authorization:'Bearer '+token}}}});if(!me.ok){{status.textContent='Session verification failed.';return}}const identity=await me.json();password.value='';document.getElementById('identity').textContent='Signed in as '+identity.user.email+' ('+identity.user.role+').';document.getElementById('login-panel').hidden=true;document.getElementById('dashboard').setAttribute('aria-hidden','false');history.replaceState(null,'','/dashboard');}});</script></body></html>'''

    def _json(self) -> dict[str, Any]:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as exc:
            raise ValueError("invalid Content-Length") from exc
        if length < 1 or length > 2_000_000:
            raise ValueError("request body must be 1-2000000 bytes")
        try:
            value = json.loads(self.rfile.read(length))
        except json.JSONDecodeError as exc:
            raise ValueError("invalid JSON") from exc
        if not isinstance(value, dict):
            raise ValueError("JSON body must be an object")
        return value

    def _principal(self, role: str) -> dict[str, Any]:
        authorization = self.headers.get("Authorization", "")
        if not authorization.startswith("Bearer "):
            raise PermissionError("Bearer token required")
        principal = self.server.store.authenticate(authorization[7:])
        if principal is None or role not in principal["roles"]:
            raise PermissionError(f"{role} role required")
        return principal

    def do_GET(self) -> None:  # noqa: N802
        if self.path in ("/", "/dashboard"):
            self._html(self._workspace())
            return
        if self.path == "/health/live":
            self._send(HTTPStatus.OK, {"status": "live"})
            return
        if self.path == "/health/ready":
            db_ready = self.server.store.ready()
            solr_ready = db_ready and self.server.solr.ping(self.server.settings.solr_alias)
            status = HTTPStatus.OK if db_ready and solr_ready else HTTPStatus.SERVICE_UNAVAILABLE
            self._send(status, {"status": "ready" if status == 200 else "not_ready",
                                "database": db_ready, "solr": solr_ready})
            return
        if self.path == "/metrics":
            try:
                self._principal("admin")
                with self.server.store.connect() as db:
                    jobs = {row[0]: row[1] for row in db.execute(
                        "SELECT state, count(*) FROM jobs GROUP BY state"
                    )}
                    active = db.execute(
                        "SELECT name FROM generations WHERE state='active'"
                    ).fetchone()
                self._send(HTTPStatus.OK, {"jobs": jobs,
                    "active_generation": None if active is None else active[0]})
            except PermissionError as exc:
                self._send(HTTPStatus.UNAUTHORIZED, {"error": str(exc)})
            return
        self._send(HTTPStatus.NOT_FOUND, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802
        try:
            body = self._json()
            if self.path == "/v1/query":
                principal = self._principal("query")
                result = self.server.query.search(principal, body.get("query", ""),
                                                  body.get("limit", 20),
                                                  bool(body.get("explain", False)))
                self._send(HTTPStatus.OK, result)
            elif self.path == "/v1/feedback":
                principal = self._principal("feedback")
                feedback_id = self.server.query.feedback(
                    principal, body.get("query_hash", ""), body.get("document_id", ""),
                    body.get("signal", ""),
                )
                self._send(HTTPStatus.CREATED, {"id": feedback_id})
            elif self.path == "/v1/ingest":
                principal = self._principal("ingest")
                result = self.server.ingestion.ingest(body.get("source_id", ""),
                                                      body.get("records", []))
                self.server.store.audit(principal["id"], "documents.ingest",
                                        body.get("source_id", ""), result.__dict__)
                self._send(HTTPStatus.ACCEPTED, result.__dict__)
            elif self.path == "/v1/delete":
                principal = self._principal("ingest")
                result = self.server.ingestion.delete(
                    body.get("source_id", ""), body.get("id", ""), body.get("version", 0)
                )
                self.server.store.audit(principal["id"], "document.delete",
                                        body.get("id", ""), {"result": result})
                self._send(HTTPStatus.ACCEPTED, {"result": result})
            else:
                self._send(HTTPStatus.NOT_FOUND, {"error": "not found"})
        except PermissionError as exc:
            self._send(HTTPStatus.UNAUTHORIZED, {"error": str(exc)})
        except (ValueError, TypeError) as exc:
            self._send(HTTPStatus.BAD_REQUEST, {"error": str(exc)})
        except sqlite3.Error:
            self._send(HTTPStatus.SERVICE_UNAVAILABLE, {"error": "storage unavailable"})
        except SolrError:
            self._send(HTTPStatus.SERVICE_UNAVAILABLE, {"error": "search unavailable"})


def serve(settings: Settings) -> None:
    if not Store(settings.database).ready():
        raise RuntimeError("database is not initialized; run `solrproject init-db` explicitly")
    server = DiscoveryServer((settings.api_host, settings.api_port), settings)
    server.serve_forever()
