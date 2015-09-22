#!/bin/bash
set -x #echo on

ROOT=$(cd $(dirname "$0"); pwd)

host=$1
post=$2
webpath=$3
CONTEXT=$4
csinputfile="CSstreamDelta"

echo "$(date):creating click stream click info XML database named as CSstreamClickInfo"

echo "Pulliong delta CSstrem information recenyly updated"
$BASEX_HOME/bin/basex -bsqlfile=$ROOT/sqlStmts/${CONTEXT}/CSstream_prod.sql -boutputfile=$ROOT/SQLExtracts/${CONTEXT}/CSstreams/CSstreamDelta.sql.xml -bmonth=-1 -bcontext=${CONTEXT} $ROOT/xquery/runSqlCommand.xq &

echo "Index delta CSstream data"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
    SET INTPARSE true;
    CREATE DB ${csinputfile} $ROOT/SQLExtracts/${CONTEXT}/CSstreams/CSstreamDelta.sql.xml
EOF

$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 CREATE DB ${CONTEXT}CSstreamClickInfo "<RECORDS/>"
 CREATE DB ${CONTEXT}CSstreamCartInfo "<RECORDS/>"
 CREATE DB ${CONTEXT}CSstreamInfos "<RECORDS/>"
EOF

echo "Indexing in Basex click and addcart files.."
$BASEX_HOME/bin/basex -binputDoc=${csinputfile} -bclickCountDoc=${CONTEXT}CSstreamClickInfo -baddCartDoc=${CONTEXT}CSstreamCartInfo $ROOT/xquery/ProcessAllClickStream.xq

echo "generating solr input files for clicks and addcarts"
$BASEX_HOME/bin/basex -bcartInfoDoc=${CONTEXT}CSstreamCartInfo  -boutfile=${ROOT}/solrinputfiles/${CONTEXT}/solraddcarts.xml ${ROOT}/xquery/xmlSolrFormatForCart2.xq
$BASEX_HOME/bin/basex -bclickInfoDoc=${CONTEXT}CSstreamClickInfo -boutfile=${ROOT}/solrinputfiles/${CONTEXT}/solraddclicks.xml ${ROOT}/xquery/xmlSolrFormatForClicks2.xq

echo "Indexing clicks and addcarts into SOLR now"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 CREATE DB ${CONTEXT}CSstreamClickInfoMap ${ROOT}/solrinputfiles/${CONTEXT}/solraddclicks.xml
 CREATE DB ${CONTEXT}CSstreamCartInfoMap ${ROOT}/solrinputfiles/${CONTEXT}/solraddcarts.xml
EOF

echo "exporint existing clicks and addcart data from SOLR. We will add up new numbers to this data"

curl -o ${ROOT}/solrinputfiles/${CONTEXT}/PreviousClicksAddCarts.xml "http://${host}:${port}/${webpath}/ProductsCoreFirst/query?q=*%3A*&fl=NumberOfClicks%2CNumberOfAddCarts%2CProductID&wt=xml&indent=true&rows=70000"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 CREATE DB ${CONTEXT}PreviousClicksAddCarts ${ROOT}/solrinputfiles/${CONTEXT}/PreviousClicksAddCarts.xml
EOF

echo "$(date):Click stream processing done "

