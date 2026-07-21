# SOLRProject control plane

This repository now has one supported runtime: the Python 3.12+ `discovery`
control plane. It incrementally stages source records in SQLite, applies them to
Solr through replayable jobs, filters every query by ACL, and replaces cores by
verified collection generations and an atomic alias switch.

The Java, Node, XQuery, Tomcat, copied JARs, Solr 4/5 configuration, and historic
shell workflows are an evidence archive only. They are not part of the build or
container. Several dangerous entry points are refusal-only shims. See
`LEGACY_QUARANTINE.md` and `PROVENANCE.md` before inspecting them.

## Clean local verification

```sh
make clean build test audit
```

The supported application has no third-party runtime dependencies. Initialize
state explicitly, then provision identities and sources:

```sh
cp .env.example .env
DISCOVERY_DATABASE=var/discovery.db python3 -m discovery init-db
DISCOVERY_DATABASE=var/discovery.db python3 -m discovery create-source catalog
DISCOVERY_DATABASE=var/discovery.db python3 -m discovery create-principal operator \
  --role admin --role ingest --role query --role feedback --role debug --group catalog-ops
```

`init-db`, rebuilds, activation, and purge are separate commands. `bin/start`
only starts the API and refuses to start if the schema has not been initialized.
See `RUNBOOK.md` for ingestion, workers, benchmark gates, rollback, backup, and
recovery procedures.

`./start.sh` is the supported root launcher. It maps `PORT` and the acceptance
harness's disposable `DB_PATH` onto the control-plane settings, validates Python
and the port, and then replaces itself with `bin/start`. It initializes only an
explicit `NODE_ENV=test` disposable `DB_PATH`; every normal environment retains
the fail-closed, explicit `init-db` requirement.

## API

- `GET /health/live`: process liveness; no writes or external calls.
- `GET /health/ready`: read-only schema and live Solr alias probes.
- `POST /v1/query`: bearer-authenticated, permission-filtered search.
- `POST /v1/feedback`: query-hash-only relevance feedback.
- `POST /v1/ingest` and `/v1/delete`: durable source changes.
- `GET /metrics`: admin-only job and active-generation gauges.

No repository-wide license was present in the imported history. Do not publish
or redistribute the archive or the new control plane until the owner supplies a
license; see `PROVENANCE.md`.
