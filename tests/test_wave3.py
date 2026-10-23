from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from discovery.cli import main as cli_main
from discovery.config import Settings
from discovery.store import Store
from discovery.wave3 import TaskStore, fallback, filter_documents, has_provider, render_sections, to_csv


class Wave3Test(unittest.TestCase):
    def test_filter_and_csv_export(self):
        rows = [
            {"source_id": "s1", "external_id": "doc-1", "deleted": 0},
            {"source_id": "s2", "external_id": "doc-2", "deleted": 1},
        ]
        self.assertEqual(len(filter_documents(rows, q="doc-1")), 1)
        self.assertEqual(filter_documents(rows, source_id="s2")[0]["external_id"], "doc-2")
        self.assertIn("doc-1", to_csv(rows, ["source_id", "external_id", "deleted"]))

    def test_ai_fallback_labelled_and_preserves_false_zero_empty(self):
        self.assertFalse(has_provider({}))
        out = fallback("relevance-gaps", [{"external_id": "a", "deleted": 1}])
        self.assertFalse(out["aiGenerated"])
        text = render_sections(out["sections"])
        self.assertIn("Deleted documents: 1", text)
        self.assertIn("Coverage complete: false", text)
        self.assertIn("Deleted documents: 0", render_sections(fallback("relevance-gaps", [{"external_id": "a", "deleted": 0}])["sections"]))
        self.assertIn("Note: (empty)", render_sections([{"label": "Note", "value": ""}]))

    def test_tasks_crud_in_sidecar_store(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = TaskStore(Path(tmp) / "main.db")
            task = store.create("reader", "Review relevance gaps", priority="high")
            self.assertEqual(store.list("reader", q="relevance")[0]["id"], task["id"])
            self.assertEqual(store.list("other"), [])
            updated = store.update("reader", task["id"], {"status": "done"})
            self.assertEqual(updated["status"], "done")
            self.assertFalse((Path(tmp) / "main.db").exists())


class CliWave3Test(unittest.TestCase):
    def test_cli_tasks_export_and_ai_fallback(self):
        import io
        from contextlib import redirect_stdout
        with tempfile.TemporaryDirectory() as tmp:
            db = Path(tmp) / "main.db"
            store = Store(db)
            store.migrate()
            token = store.create_principal("reader", ["query"], [])
            import os
            old = os.environ.get("DISCOVERY_DATABASE")
            os.environ["DISCOVERY_DATABASE"] = str(db)
            try:
                buf = io.StringIO()
                with redirect_stdout(buf):
                    self.assertEqual(cli_main(["task-create", "--token", token, "Review CLI task"]), 0)
                self.assertIn("Review CLI task", buf.getvalue())
                buf = io.StringIO()
                with redirect_stdout(buf):
                    self.assertEqual(cli_main(["tasks", "--token", token, "--q", "CLI"]), 0)
                self.assertIn("Review CLI task", buf.getvalue())
                buf = io.StringIO()
                with redirect_stdout(buf):
                    self.assertEqual(cli_main(["export-documents", "--token", token, "--format", "json"]), 0)
                self.assertIn("documents", buf.getvalue())
                buf = io.StringIO()
                with redirect_stdout(buf):
                    self.assertEqual(cli_main(["ai-summary", "--token", token, "index-health"]), 0)
                self.assertIn('"aiGenerated": false', buf.getvalue())
                buf = io.StringIO()
                with redirect_stdout(buf):
                    self.assertEqual(cli_main(["tasks", "--token", "bad-token"]), 2)
            finally:
                if old is None:
                    os.environ.pop("DISCOVERY_DATABASE", None)
                else:
                    os.environ["DISCOVERY_DATABASE"] = old


if __name__ == "__main__":
    unittest.main()
