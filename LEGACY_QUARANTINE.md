# Legacy execution quarantine

Everything outside `discovery/`, `tests/`, `benchmarks/`, `bin/`, and root
operational metadata is an untrusted historical artifact. It depends on obsolete
Solr/Lucene, BaseX, Oracle, Tomcat, local absolute paths, missing sibling projects,
unchecked binaries, and unauthenticated endpoints. Do not source or execute its
shell scripts, run its Java/Node code, load its Solr cores, or connect it to a
network. The supported build and container deliberately exclude it.

`searchEngineOps/delAllData.sh`, `performSolrIndexing.sh`, and
`performNewSolrIndexing.sh` are refusal shims because their prior forms could
delete all documents or chain unsafe extraction and replacement. The historical
SQL extractor is also a refusal shim after credential removal. The two copied
evaluation scripts now require a brand-new output directory and never recursively
delete prior output.

Recovery of any archive feature requires a separate provenance review, dependency
inventory, secret scan, migration design, and isolated test environment. Do not
weaken the supported control plane to accommodate it.

