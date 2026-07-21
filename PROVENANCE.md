# Provenance and licensing record

The Git remote is `https://github.com/eakarsu/SOLRProject`. The inspected history
spans the original 2014-2015 search experiment and is predominantly authored by
Erol Akarsu/eakarsu; one commit is attributed to Sukru Kilic. This records Git
metadata, not a copyright or relicensing determination.

No root `LICENSE`, contribution agreement, dependency lock, or reliable bill of
materials was present. The two copied Turkish-analysis source trees each contain
their own `LICENSE`; those notices apply only to those directories. Checked-in
JARs, Oracle drivers, generated classes, Solr/Tomcat state, HTML/JavaScript,
XQuery, SQL, and other archive material have no established repository-level
redistribution grant. They are excluded from the supported build and Docker
context. Their filenames are not proof that redistribution is permitted.

The new `discovery/` control plane and its tests were added on 2026-07-19, but no
license is inferred for them. Publication, package upload, binary distribution,
or incorporation of archive files remains blocked until the owner chooses a root
license and reviews third-party notices. The operational build is stdlib-only and
does not link or package the copied archive.

Historical source contained live-looking Oracle usernames, passwords, and network
addresses. Working-tree copies were removed on 2026-07-19, but Git history still
contains them. Treat them as compromised, rotate/disable them, and use history
rewriting only with owner coordination. `admin/admin` remains in an already
user-modified archived BaseX script; the archive is execution-quarantined and the
supported control plane never loads it.

