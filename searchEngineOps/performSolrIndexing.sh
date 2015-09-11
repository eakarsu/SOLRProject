#!/bin/bash
set -x #echo on


host=$1
port=$2
webpath=$3
CONTEXT=$4
ROOT=$(cd $(dirname "$0"); pwd)

read activeCoreName < ../webuiprod/src/${CONTEXT}_ACTIVE_CORE_NAME

echo "Current activeCoreName = ${activeCoreName}"
if [ $activeCoreName == "${CONTEXT}ProductsCoreFirst" ]
then
   corename=${CONTEXT}ProductsCoreSecond
else
   corename=${CONTEXT}ProductsCoreFirst
fi
	

echo "We picked core $corename and deleting al indexes and re-indexing onto it "

echo "we are deleting all indexes in this core ${corename}"
curl http://$host:$port/$webpath/$corename/update --data '<delete><query>*:*</query></delete>' -H 'Content-type:text/xml; charset=utf-8'
curl http://$host:$port/$webpath/$corename/update --data '<commit/>' -H 'Content-type:text/xml; charset=utf-8'

echo "We are indexing into this core ${corename}" 


for i in {0..23}
do
   $ROOT/post.sh $host $port $webpath $corename $ROOT/solrinputfiles/${CONTEXT}/batches/solrinput${i}.xml &
done

wait

echo "We will RELAOD this code ${corename} now"

result=$($BASEX_HOME/bin/basex -bhost=$host -bport=$port -bwebpath=$webpath -bcoreName=$corename $ROOT/xquery/executeReloadCommand.xq 2>&1)

if [ $result -eq "0" ]
then
  echo "RELOADed core=${corename} executed successfully"
  echo "writing new core name into ../webuiprod/src/${CONTEXT}_ACTIVE_CORE_NAME "
  echo ${corename} > ..//webuiprod/src/${CONTEXT}_ACTIVE_CORE_NAME
else
  echo "Faced problem in RELOADING core = ${corename}"
fi

echo "$(date):Real SOLR indexing done"



