from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {".java", ".py", ".sh", ".xq", ".xml", ".yml", ".yaml", ".md", ".sql"}
FORBIDDEN = {
    "historical Oracle credential": re.compile(rb"kangurum/(?:planetuc9|ferhatpasa1)"),
    "recursive-force deletion": re.compile(rb"\brm\s+-rf\b"),
}
REFUSAL_SHIMS = [
    "searchEngineOps/delAllData.sh",
    "searchEngineOps/performSolrIndexing.sh",
    "searchEngineOps/performNewSolrIndexing.sh",
    "sql/pullCStreamdData.sh",
]


def main() -> int:
    findings: list[str] = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts or path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        data = path.read_bytes()
        for label, pattern in FORBIDDEN.items():
            if pattern.search(data):
                findings.append(f"{path.relative_to(ROOT)}: {label}")
    for relative in REFUSAL_SHIMS:
        text = (ROOT / relative).read_text(encoding="utf-8")
        if "REFUSED:" not in text or "exit 64" not in text:
            findings.append(f"{relative}: missing fail-closed quarantine")
    dockerignore = (ROOT / ".dockerignore").read_text(encoding="utf-8")
    if not dockerignore.startswith("**\n"):
        findings.append(".dockerignore: legacy archive is not excluded by default")
    if findings:
        print("\n".join(findings), file=sys.stderr)
        return 1
    print("repository safety audit passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

