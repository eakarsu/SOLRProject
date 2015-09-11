#!/bin/bash
set -x #echo on

CONTEXT=$1
ROOT=$(cd $(dirname "$0"); pwd)
echo "$(date): Preparing solr input files context=${CONTEXT}"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 OPEN ${CONTEXT}AccumulatedProducts
 EXPORT $ROOT/solrinputfiles/${CONTEXT}
 EXIT
EOF

echo "$(date): Splitting files into 24 different xml files to speed up SOLR indexing process "
$BASEX_HOME/bin/basex -bnparts=24  -boutfolder=$ROOT/solrinputfiles/${CONTEXT}/batches -bsolrdbname=${CONTEXT}AccumulatedProducts $ROOT/xquery/split.xq

echo "$(date): Finished Preparing Solr Input files"
