#!/bin/bash
set -x #echo on

ROOT=$(cd $(dirname "$0"); pwd)
echo "$(date): Preparing solr input files "
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 OPEN AccumulatedProducts
 EXPORT $ROOT/solrinputfiles
 EXIT
EOF

echo "$(date): Splitting files into 24 different xml files to speed up SOLR indexing process "
$BASEX_HOME/bin/basex -bnparts=24  -boutfolder=$ROOT/solrinputfiles/batches -bsolrdbname=AccumulatedProducts $ROOT/xquery/split.xq

echo "$(date): Finished Preparing Solr Input files"
