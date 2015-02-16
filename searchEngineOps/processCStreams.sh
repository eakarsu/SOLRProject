#!/bin/bash
set -x #echo on

echo "$(date):creating click stream click info XML database named as CSstreamClickInfo"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 CREATE DB CSstreamClickInfo "<RECORDS/>"
 CREATE DB CSstreamCartInfo "<RECORDS/>"
 CREATE DB ClickStreamInfos "<RECORDS/>"
EOF

ROOT=$(cd $(dirname "$0"); pwd)

for ((nk=1;nk<=12;nk++))
do
   echo "Reformatting Click stream data at database=CSstream${nk}"
   $BASEX_HOME/bin/basex -binputDoc=CSstream${nk} -boutputDoc=ClickStreamInfos $ROOT/xquery/reformatAndGroupClickstreams.xq 
done

echo "Forming Click and Cart Information Databases..."

echo "executing " $BASEX_HOME/bin/basex -binputDoc=ClickStreamInfos -bclickCountDoc=CSstreamClickInfo -baddCartDoc=CSstreamCartInfo $ROOT/xquery/ProcessCllickstreamSessions.xq

$BASEX_HOME/bin/basex -binputDoc=ClickStreamInfos -bclickCountDoc=CSstreamClickInfo -baddCartDoc=CSstreamCartInfo $ROOT/xquery/ProcessCllickstreamSessions.xq

echo "$(date):Click stream processing done "

