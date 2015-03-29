#!/bin/bash
set -x #echo on

ROOT=$(cd $(dirname "$0"); pwd)
echo "Current folder = ${ROOT}"
echo "indexing click sterams data itable in SOLR"

#
#CSStreams12.sql.xml has invalid characters in it. We have to make this sed replacements
sed -i 's/&#x1;//g;s/&#x2;//g;s/&#x6;//g;s/&#x7;s/&#x8;//g;//g;s/&#x10;//g;s/&#xD;//g;s/&#x15;//g;s/&#x1F;//g' $ROOT/SQLExtracts/CSstreams/CSstream12.sql.xml
#

$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
     SET INTPARSE true;
     CREATE DB CSstream1 $ROOT/SQLExtracts/CSstreams/CSstream1.sql.xml
     CREATE DB CSstream2 $ROOT/SQLExtracts/CSstreams/CSstream2.sql.xml
     CREATE DB CSstream3 $ROOT/SQLExtracts/CSstreams/CSstream3.sql.xml
     CREATE DB CSstream4 $ROOT/SQLExtracts/CSstreams/CSstream4.sql.xml
     CREATE DB CSstream5 $ROOT/SQLExtracts/CSstreams/CSstream5.sql.xml
     CREATE DB CSstream6 $ROOT/SQLExtracts/CSstreams/CSstream6.sql.xml
     CREATE DB CSstream7 $ROOT/SQLExtracts/CSstreams/CSstream7.sql.xml
     CREATE DB CSstream8 $ROOT/SQLExtracts/CSstreams/CSstream8.sql.xml
     CREATE DB CSstream9 $ROOT/SQLExtracts/CSstreams/CSstream9.sql.xml
     CREATE DB CSstream10 $ROOT/SQLExtracts/CSstreams/CSstream10.sql.xml
     CREATE DB CSstream11 $ROOT/SQLExtracts/CSstreams/CSstream11.sql.xml
     CREATE DB CSstream12 $ROOT/SQLExtracts/CSstreams/CSstream12.sql.xm
     EXIT
EOF
