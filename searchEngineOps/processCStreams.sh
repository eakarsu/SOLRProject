#!/bin/bash
set -x #echo on

CONTEXT=$1
echo "$(date):creating click stream click info XML database named as CSstreamClickInfo"
#$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
# CREATE DB CSstreamClickInfo "<RECORDS/>"
# CREATE DB CSstreamCartInfo "<RECORDS/>"
# CREATE DB ClickStreamInfos "<RECORDS/>"
#EOF


#
#CSStreams12.sql.xml has invalid characters in it. We have to make this sed replacements
#sed -i 's/&#x1;//g;s/&#x2;//g;s/&#x6;//g;s/&#x7;s/&#x8;//g;//g;s/&#x10;//g;s/&#xD;//g;s/&#x15;//g;s/&#x1F;//g' CSstream12.sql.xml
#

ROOT=$(cd $(dirname "$0"); pwd)

for ((nk=1;nk<=12;nk++))
do
   echo "Reformatting Click stream data at database=CSstream${nk}"
   $BASEX_HOME/bin/basex -binputDoc=CSstream${nk} -boutputDoc=${CONTEXT}ClickStreamInfos $ROOT/xquery/reformatAndGroupClickstreams.xq
done


echo "Forming Click and Cart Information Databases..."


$BASEX_HOME/bin/basex -binputDoc=${CONTEXT}ClickStreamInfos -bclickCountDoc=${CONTEXT}CSstreamClickInfo -baddCartDoc=${CONTEXT}CSstreamCartInfo $ROOT/xquery/ProcessClickstreamSessions2.xq

echo "$(date):Click stream processing done "

