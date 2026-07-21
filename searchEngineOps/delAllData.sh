#!/bin/sh
set -eu
echo "REFUSED: this archived script previously deleted every document in a shared core." >&2
echo "Use: python -m discovery generation-purge NAME --confirm-collection COLLECTION --actor OPERATOR" >&2
exit 64
