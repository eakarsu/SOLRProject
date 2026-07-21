from __future__ import annotations

import hashlib
import re
import time
from typing import Any

from .solr import SolrClient
from .store import Store, now, uid


SAFE_GROUP = re.compile(r"^[A-Za-z0-9_.:@/-]{1,100}$")


class QueryService:
    def __init__(self, store: Store, solr: SolrClient, alias: str,
                 max_query_chars: int = 512, max_results: int = 100):
        self.store = store
        self.solr = solr
        self.alias = alias
        self.max_query_chars = max_query_chars
        self.max_results = max_results

    def search(self, principal: dict[str, Any], query: str, limit: int = 20,
               explain: bool = False) -> dict[str, Any]:
        if "query" not in principal["roles"]:
            raise PermissionError("query role required")
        query = query.strip()
        if not query:
            return {"documents": [], "total": 0, "elapsed_ms": 0,
                    "query_hash": self.query_hash("")}
        if query.casefold() in {"*", "*:*"}:
            return {"documents": [], "total": 0, "elapsed_ms": 0,
                    "query_hash": self.query_hash(query)}
        if len(query) > self.max_query_chars or any(ord(c) < 32 for c in query):
            raise ValueError("query is too long or contains control characters")
        if query.count("(") + query.count(")") > 20 or query.count("*") > 5:
            raise ValueError("query complexity limit exceeded")
        if not isinstance(limit, int) or not 1 <= limit <= self.max_results:
            raise ValueError(f"limit must be 1-{self.max_results}")
        groups = sorted({"public", *principal["groups"]})
        if any(not SAFE_GROUP.fullmatch(group) for group in groups):
            raise ValueError("principal contains an invalid group")
        can_explain = explain and "debug" in principal["roles"]
        params: dict[str, Any] = {
            "q": query,
            "defType": "edismax",
            "qf": "title^4 name^3 description body tags",
            "fq": "{!terms f=acl_ss}" + ",".join(groups),
            "rows": limit,
            "fl": "id,source_id_s,external_id_s,source_version_l,content_hash_s,source_updated_at_l,score,*",
            "boost": "recip(ms(NOW,source_updated_at_l),3.16e-11,1,1)",
            "wt": "json",
        }
        if can_explain:
            params["debugQuery"] = "true"
        started = time.perf_counter()
        result = self.solr.query(self.alias, params)
        elapsed = round((time.perf_counter() - started) * 1000, 3)
        response: dict[str, Any] = {
            "documents": result.get("response", {}).get("docs", []),
            "total": result.get("response", {}).get("numFound", 0),
            "elapsed_ms": elapsed,
            "query_hash": self.query_hash(query),
        }
        if can_explain:
            response["explanation"] = result.get("debug", {}).get("explain", {})
        return response

    @staticmethod
    def query_hash(query: str) -> str:
        return hashlib.sha256(query.strip().casefold().encode("utf-8")).hexdigest()

    def feedback(self, principal: dict[str, Any], query_hash: str,
                 document_id: str, signal: str) -> str:
        if "feedback" not in principal["roles"]:
            raise PermissionError("feedback role required")
        if not re.fullmatch(r"[a-f0-9]{64}", query_hash):
            raise ValueError("query_hash must be a SHA-256 digest")
        if signal not in {"click", "useful", "not_useful"} or not document_id:
            raise ValueError("invalid feedback")
        feedback_id = uid("fb")
        with self.store.connect() as db:
            db.execute("INSERT INTO feedback VALUES (?, ?, ?, ?, ?, ?)",
                       (feedback_id, principal["id"], query_hash,
                        document_id[:400], signal, now()))
        return feedback_id
