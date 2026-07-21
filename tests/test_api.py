from __future__ import annotations

import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

from discovery.api import DiscoveryServer, serve
from discovery.config import Settings
from discovery.store import Store


class HealthySolr:
    def ping(self, collection):
        return True

    def query(self, collection, params):
        return {"response": {"numFound": 0, "docs": []}}


class ApiTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.database = Path(self.temp.name) / "api.db"
        self.settings = Settings(self.database, "http://127.0.0.1:8983/solr", "live",
                                 "127.0.0.1", 0, 262144, 500, 512, 100, 1)

    def tearDown(self):
        self.temp.cleanup()

    def test_startup_never_implicitly_migrates(self):
        with self.assertRaises(RuntimeError):
            serve(self.settings)
        self.assertFalse(self.database.exists())

    def test_health_and_authenticated_query(self):
        store = Store(self.database)
        store.migrate()
        token = store.create_principal("reader", ["query"], ["team-a"])
        server = DiscoveryServer(("127.0.0.1", 0), self.settings)
        server.solr = HealthySolr()
        server.query.solr = server.solr
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f"http://127.0.0.1:{server.server_port}"
        try:
            with urllib.request.urlopen(base + "/health/live") as response:
                self.assertEqual(json.load(response)["status"], "live")
            with urllib.request.urlopen(base + "/health/ready") as response:
                self.assertEqual(json.load(response)["status"], "ready")
            body = json.dumps({"query": "elma"}).encode()
            unauthorized = urllib.request.Request(base + "/v1/query", data=body,
                                                   headers={"Content-Type": "application/json"})
            with self.assertRaises(urllib.error.HTTPError) as error:
                urllib.request.urlopen(unauthorized)
            self.assertEqual(error.exception.code, 401)
            error.exception.close()
            authorized = urllib.request.Request(
                base + "/v1/query", data=body,
                headers={"Content-Type": "application/json", "Authorization": f"Bearer {token}"},
            )
            with urllib.request.urlopen(authorized) as response:
                self.assertEqual(json.load(response)["documents"], [])
        finally:
            server.shutdown()
            server.server_close()
            thread.join(2)


if __name__ == "__main__":
    unittest.main()
