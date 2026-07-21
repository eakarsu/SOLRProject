#!/bin/sh
set -eu
echo "REFUSED: the archived rebuild deleted a whole core before an unverified swap." >&2
echo "Use generation-create, work-once, generation-verify, then generation-activate." >&2
exit 64
