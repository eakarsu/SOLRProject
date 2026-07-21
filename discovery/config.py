from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    database: Path
    solr_url: str
    solr_alias: str
    api_host: str
    api_port: int
    max_document_bytes: int
    max_batch_documents: int
    max_query_chars: int
    max_query_results: int
    request_timeout_seconds: float

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            database=Path(os.getenv("DISCOVERY_DATABASE", "var/discovery.db")),
            solr_url=os.getenv("SOLR_URL", "http://127.0.0.1:8983/solr"),
            solr_alias=os.getenv("SOLR_ALIAS", "discovery-live"),
            api_host=os.getenv("DISCOVERY_HOST", "127.0.0.1"),
            api_port=int(os.getenv("DISCOVERY_PORT", "8080")),
            max_document_bytes=int(os.getenv("MAX_DOCUMENT_BYTES", "262144")),
            max_batch_documents=int(os.getenv("MAX_BATCH_DOCUMENTS", "500")),
            max_query_chars=int(os.getenv("MAX_QUERY_CHARS", "512")),
            max_query_results=int(os.getenv("MAX_QUERY_RESULTS", "100")),
            request_timeout_seconds=float(os.getenv("REQUEST_TIMEOUT_SECONDS", "5")),
        )

