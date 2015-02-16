#!/bin/bash
set -x #echo on

ROOT=$(cd $(dirname "$0"); pwd)
echo "Current folder = ${ROOT}"
echo "indexing click sterams data itable in SOLR"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
     SET INTPARSE true;
     CREATE DB CSstream1 $ROOT/CSstreams/CSstream1.sql.xml
     CREATE DB CSstream2 $ROOT/CSstreams/CSstream2.sql.xml
     CREATE DB CSstream3 $ROOT/CSstreams/CSstream3.sql.xml
     CREATE DB CSstream4 $ROOT/CSstreams/CSstream4.sql.xml
     CREATE DB CSstream5 $ROOT/CSstreams/CSstream5.sql.xml
     CREATE DB CSstream6 $ROOT/CSstreams/CSstream6.sql.xml
     CREATE DB CSstream7 $ROOT/CSstreams/CSstream7.sql.xml
     CREATE DB CSstream8 $ROOT/CSstreams/CSstream8.sql.xml
     CREATE DB CSstream9 $ROOT/CSstreams/CSstream9.sql.xml
     CREATE DB CSstream10 $ROOT/CSstreams/CSstream10.sql.xml
     CREATE DB CSstream11 $ROOT/CSstreams/CSstream11.sql.xml
     CREATE DB CSstream12 $ROOT/CSstreams/CSstream12.sql.xm
     EXIT
EOF
