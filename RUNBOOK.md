# Operations runbook

## Safety model

Startup performs no migration, source extraction, deletion, rebuild, or alias
change. Maintenance commands are individually invoked, authenticated at the
operator boundary, and written to `audit_events` when they affect a generation.
Use a dedicated service account and TLS for remote Solr. HTTP is accepted only
for loopback development. Put the API behind TLS and network policy; bearer
tokens are stored as SHA-256 digests and printed only once at creation.

Historical Oracle credentials in Git history must be considered compromised.
Rotate or disable those accounts before any network access from this repository.

## Deploy and health

Set values from `.env.example`. Create a durable volume for `var/`, run
`python -m discovery init-db` as a deliberate one-off release step, then run
`bin/start`. `/health/live` confirms only that the HTTP process responds.
`/health/ready` returns 200 only when the schema exists and the live alias pings.
It never repairs state.

Monitor the admin `/metrics` endpoint and alert when failed jobs are nonzero,
pending jobs grow for 10 minutes, readiness fails for 2 minutes, free disk falls
below twice the SQLite database size, or benchmark p95 exceeds its gate. Track
Solr heap, disk, replica recovery, query p95/p99, and alias collection size in the
platform's Solr monitoring as well.

## Ingestion and replay

JSONL records have this shape:

```json
{"id":"sku-42","version":7,"acl":["public","buyers"],"document":{"title":"Elma","description":"Taze ürün"}}
```

Run `python -m discovery ingest-jsonl SOURCE records.jsonl`, then run supervised
`python -m discovery work-once` workers until idle. A `(source, id)` only accepts
monotonically increasing versions. Identical versions are deduplicated; stale
updates cannot overwrite current state. `delete SOURCE ID VERSION` creates a
durable tombstone. Workers use leases, exponential retry, and a five-attempt
dead-letter state. After correcting a cause, use `replay-job FAILED_JOB_ID`.

Capacity defaults are 500 records per batch, 256 KiB per document, 512 query
characters, and 100 results. Lower these with environment settings if Solr or
SQLite saturation appears; do not raise them without load and abuse tests.

## Zero-downtime rebuild and rollback

1. `generation-create gYYYYMMDDNN` creates an isolated Solr collection and
   snapshots all live source documents into generation-specific jobs.
2. Drain workers and run `generation-verify NAME`. Activation is blocked until
   the expected count, completed count, failure count, and content checksum pass.
3. Run the benchmark dataset against the candidate collection in staging.
4. `generation-activate NAME --actor OPERATOR` health-checks the collection and
   atomically moves the live alias. The prior generation is retained as retired.
5. Roll back by activating the retained generation after re-verifying its health.

Purging is never part of rebuild or startup. A retired collection must satisfy
the retention window and the operator must type its exact collection name:

```sh
python -m discovery generation-purge NAME \
  --confirm-collection discovery-live-NAME --actor OPERATOR
```

## Relevance gates

`benchmarks/search.jsonl` includes Turkish and English relevance, empty input,
and adversarial syntax. Expand it with anonymized judged queries before launch.
Run `python -m discovery benchmark benchmarks/search.jsonl --token TOKEN`.
The command fails on recall@10 below 0.80, precision@10 below 0.50, p95 above
500 ms, behavioral failures, or loss of multilingual coverage. Debug explanations
are returned only to principals with the `debug` role. Feedback stores a stable
query digest, document ID, signal, principal, and timestamp—not raw query text.

## Backup and disaster recovery

Create an online consistent SQLite backup to a new path:

```sh
python -m discovery backup backups/discovery-$(date +%Y%m%d).db
python -m discovery restore-verify backups/discovery-YYYYMMDD.db
```

Encrypt backups, keep them outside the service host, and test restore quarterly.
To recover: stop writers, verify the selected backup, copy it into a new volume,
start against a retained Solr generation, run readiness and benchmark checks, and
only then restore traffic. If Solr is lost, restore SQLite and run the generation
rebuild sequence. Target RPO is the backup interval plus queued source replay;
target RTO must be measured with the production corpus.

