from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request
from typing import Any
import hashlib


class SolrError(RuntimeError):
    pass


class SolrClient:
    def __init__(self, base_url: str, timeout: float = 5):
        self.base_url = base_url.rstrip("/")
        parsed = urllib.parse.urlparse(self.base_url)
        if parsed.scheme not in {"http", "https"} or not parsed.hostname:
            raise ValueError("SOLR_URL must be an absolute HTTP(S) URL")
        if parsed.scheme != "https" and parsed.hostname not in {"127.0.0.1", "localhost", "::1"}:
            raise ValueError("remote SOLR_URL must use HTTPS")
        self.timeout = timeout

    def _request(self, path: str, *, method: str = "GET",
                 body: Any | None = None) -> dict[str, Any]:
        data = None if body is None else json.dumps(body).encode("utf-8")
        request = urllib.request.Request(
            f"{self.base_url}/{path.lstrip('/')}", data=data, method=method,
            headers={"Accept": "application/json", "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                result = json.load(response)
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            raise SolrError(str(exc)) from exc
        if result.get("responseHeader", {}).get("status", 0) != 0:
            raise SolrError(f"Solr rejected request: {result}")
        return result

    def ping(self, collection: str) -> bool:
        try:
            self._request(f"{urllib.parse.quote(collection)}/admin/ping")
            return True
        except SolrError:
            return False

    def update(self, collection: str, commands: list[dict[str, Any]]) -> None:
        target = urllib.parse.quote(collection)
        body: Any = commands[0] if len(commands) == 1 else commands
        self._request(f"{target}/update?commitWithin=5000", method="POST", body=body)

    def query(self, collection: str, params: dict[str, Any]) -> dict[str, Any]:
        query = urllib.parse.urlencode(params, doseq=True)
        return self._request(f"{urllib.parse.quote(collection)}/select?{query}")

    def fingerprint(self, collection: str) -> tuple[int, str]:
        result = self.query(collection, {
            "q": "*:*", "rows": 0, "facet": "true", "facet.field": "content_hash_s",
            "facet.limit": -1, "facet.mincount": 1, "wt": "json",
        })
        count = int(result.get("response", {}).get("numFound", -1))
        facets = result.get("facet_counts", {}).get("facet_fields", {}).get("content_hash_s", [])
        if len(facets) % 2:
            raise SolrError("invalid content hash facet response")
        hashes: list[str] = []
        for index in range(0, len(facets), 2):
            value, occurrences = facets[index], int(facets[index + 1])
            hashes.extend([str(value)] * occurrences)
        checksum = hashlib.sha256("\0".join(sorted(hashes)).encode()).hexdigest()
        return count, checksum

    def create_collection(self, collection: str) -> None:
        params = urllib.parse.urlencode({"action": "CREATE", "name": collection,
                                        "numShards": 1, "replicationFactor": 1,
                                        "collection.configName": "_default"})
        self._request(f"admin/collections?{params}")

    def activate_alias(self, alias: str, collection: str) -> None:
        params = urllib.parse.urlencode({"action": "CREATEALIAS", "name": alias,
                                        "collections": collection})
        self._request(f"admin/collections?{params}")

    def delete_collection(self, collection: str) -> None:
        params = urllib.parse.urlencode({"action": "DELETE", "name": collection})
        self._request(f"admin/collections?{params}")
