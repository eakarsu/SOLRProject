from __future__ import annotations

import json
import math
import time
from collections import defaultdict
from pathlib import Path
from typing import Any, Callable


def percentile(values: list[float], percent: float) -> float:
    if not values:
        return 0
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, math.ceil(percent * len(ordered)) - 1)]


def run_benchmark(dataset: str | Path,
                  search: Callable[[str, int], list[str]],
                  *, k: int = 10, min_recall: float = 0.8,
                  min_precision: float = 0.5, max_p95_ms: float = 500) -> dict[str, Any]:
    cases = [json.loads(line) for line in Path(dataset).read_text(encoding="utf-8").splitlines() if line.strip()]
    if not cases:
        raise ValueError("benchmark dataset is empty")
    recalls: list[float] = []
    precisions: list[float] = []
    latencies: list[float] = []
    languages: dict[str, list[float]] = defaultdict(list)
    behavioral_failures: list[str] = []
    for case in cases:
        started = time.perf_counter()
        try:
            actual = search(case["query"], k)
        except ValueError:
            actual = []
            if case.get("kind") not in {"empty", "adversarial"}:
                behavioral_failures.append(case["id"])
        latencies.append((time.perf_counter() - started) * 1000)
        expected = set(case.get("expected_ids", []))
        found = set(actual[:k])
        if case.get("kind") in {"empty", "adversarial"} and case.get("expect_empty") and actual:
            behavioral_failures.append(case["id"])
        if expected:
            recall = len(expected & found) / len(expected)
            precision = len(expected & found) / max(1, len(found))
            recalls.append(recall)
            precisions.append(precision)
            languages[case.get("language", "unknown")].append(recall)
    metrics = {
        "cases": len(cases),
        "recall_at_k": sum(recalls) / max(1, len(recalls)),
        "precision_at_k": sum(precisions) / max(1, len(precisions)),
        "p95_latency_ms": percentile(latencies, .95),
        "recall_by_language": {key: sum(vals) / len(vals) for key, vals in sorted(languages.items())},
        "behavioral_failures": behavioral_failures,
    }
    metrics["passed"] = (
        metrics["recall_at_k"] >= min_recall
        and metrics["precision_at_k"] >= min_precision
        and metrics["p95_latency_ms"] <= max_p95_ms
        and not behavioral_failures
        and len(languages) >= 2
    )
    return metrics
