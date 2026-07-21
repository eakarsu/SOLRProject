#!/bin/sh
set -eu
echo "REFUSED: the archived pipeline contains unauthenticated database and destructive index operations." >&2
echo "Use the supported discovery control plane documented in RUNBOOK.md." >&2
exit 64
