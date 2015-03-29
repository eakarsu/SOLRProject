#!/bin/bash
set -x #echo on

echo "$(date):creating click stream click info XML database named as CSstreamClickInfo"

ROOT=$(cd $(dirname "$0"); pwd)

for ((nk=1;nk<=12;nk++))
do
   echo "Reformatting Click stream data at database=CSstream${nk}"
   echo $BASEX_HOME/bin/basex -binputDoc=CSstream${nk} -boutputDoc=ClickStreamInfos $ROOT/xquery/reformatAndGroupClickstreams.xq
done

