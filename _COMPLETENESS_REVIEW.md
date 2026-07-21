# Completeness Review: SOLRProject

**Review date:** 2026-07-18

## Assessment basis

Static inspection of project-owned source and configuration only; no dependency installation, build, database migration, external-service call, or runtime launch was performed. The scan considered 308 project files (58 source files), 2 manifest(s), 1 test-like file(s), and 0 CI workflow(s), excluding dependency/generated directories.

## Classification

**Broken-inert-unsafe**

This repository should not be treated as a launchable search/discovery app. Its checked-in state is inert, internally inconsistent, credential/provenance-sensitive, or unsafe to operate; feature work must wait until the blockers below are repaired and verified.

## Why it is not complete

- Startup/automation includes process-killing, recursive deletion, or database-reset behavior that is unsafe without isolation.
- The supported build/runtime path and a trustworthy end-to-end workflow have not been demonstrated from the checked-in state.
- The documented purpose and executable source layout are mismatched or rely on missing/obsolete components.

## Needed features

1. Replace destructive startup behavior with explicit, opt-in maintenance commands and nondestructive health checks.
2. Establish provenance/licensing and reproduce a clean build in an isolated environment before adding product surface.
3. Implement durable source ingestion with incremental indexing, deletion propagation, deduplication, and replayable jobs.
4. Add permission-aware query filtering, provenance, freshness, explainable ranking, and relevance feedback.
5. Define benchmark datasets for recall, precision, latency, multilingual behavior, and adversarial or empty queries.
6. Add index versioning, zero-downtime rebuild, monitoring, capacity limits, and disaster recovery.

## Risks or launch blockers

- Automation contains destructive process, filesystem, or database operations; do not run it on a shared machine without review.
- No CI evidence prevents broken or insecure changes from reaching a release.

## Evidence inspected

- `TRMorph/README.md`
- `html/aramasonuclari.html:342`
- `ReadProductModelDetails/src/migrosdbread/TmorphClient.java:17`
- `javascript/app.js`
- `lucene-solr-analysis-turkish-master/src/test/java/org/apache/lucene/tr/TestTurkishDeasciifyFilter.java`
- `lucene-solr-analysis-turkish-master-sol510/pom.xml`

## Recommended next action

Quarantine execution, repair provenance/secret/startup/build blockers in an isolated branch, and reassess only after a clean reproducible build and smoke test.

## Implementation progress (2026-07-19)

- Requirement 1: added a supported `bin/start` and HTTP liveness/readiness path that performs no migration or maintenance, split schema initialization and every generation operation into explicit CLI commands, converted the broad-delete/rebuild/extractor launchers to fail-closed refusal shims, removed recursive-force cleanup from the copied evaluation helpers, and removed working-tree copies of exposed Oracle credentials. Historical credentials must still be rotated because Git history retains them.
- Requirement 2: documented repository and nested-license provenance in `PROVENANCE.md`, quarantined all obsolete Java/Node/XQuery/Tomcat/JAR material from the supported build and Docker context, added a dependency-free PEP 517 backend and non-root container, and produced byte-identical wheels in two clean builds. Root licensing and archive redistribution remain owner decisions; one already-modified archived BaseX script still contains its historical `admin/admin` default and is excluded from execution and artifacts.
- Requirement 3: implemented durable SQLite sources, versioned documents, ACLs, tombstones, content hashes, deduplicated jobs, leases, bounded retry/dead-letter handling, stale-job suppression, incremental Solr upsert/delete, and explicit failed-job replay, with source and batch/document capacity validation.
- Requirement 4: implemented bearer principals with digest-only token storage and roles/groups, mandatory public/group ACL filters, authoritative source/version/hash/update provenance fields, a freshness boost, complexity and result limits, debug-role-only ranking explanations, and feedback that stores query hashes rather than raw query text.
- Requirement 5: added a JSONL benchmark contract and Turkish, de-ASCII Turkish, English, empty, and adversarial cases; the runner measures recall@k, precision@k, p95 latency, per-language recall, and behavioral failures and exits nonzero when configured gates fail.
- Requirement 6: added isolated collection generations, snapshot jobs, live Solr count/content-fingerprint verification, health-gated atomic alias activation, retained rollback generations, exact-name and age-gated purge, admin metrics/alert guidance, capacity ceilings, consistent backup validation, and a disaster-recovery procedure.
- Verification: `make clean build test audit` passes (10 tests); the installed wheel completed explicit migration, online backup, and read-only restore verification; wheel rebuilds had identical SHA-256 `6ec0e29cac0ffb9e85872127e5e821acea92fede3a89d87cddfffa44f0eb71c8`; refusal shims exit 64; uninitialized startup exits without creating a database. CI repeats build, tests, audit, migration, backup, and restore verification. A live Solr/container smoke test was not possible because the local Docker daemon is unavailable, so deployment remains blocked until an operator exercises the runbook against an isolated Solr service. The historical Oracle accounts also require external rotation, and public redistribution remains blocked pending a root license decision.

## Runtime and login acceptance (2026-07-20)

- `start.sh` safely maps the shared runtime variables to the supported Python control plane and preserves the normal readiness-only startup contract. Only the harness's explicit test-scoped disposable SQLite path receives schema initialization.
- The API has no interactive credential exchange or browser session surface. It uses provisioned bearer principals with digest-only token storage for protected operations, so browser authentication acceptance is not applicable; startup and unauthenticated liveness are the supported generic acceptance path.
- Live readiness still depends on an operator-provisioned Solr alias. The absence of local Solr does not prevent liveness startup, but it remains an explicit deployment gate.
