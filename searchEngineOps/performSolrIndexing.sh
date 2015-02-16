#!/bin/bash
set -x #echo on


host=$1
port=$2
webpath=$3
ROOT=$(cd $(dirname "$0"); pwd)

read activeCoreName < /opt/migros/webuiprod/src/ACTIVE_CORE_NAME

echo "activeCoreName = ${activeCoreName}"

if [ $activeCoreName == 'ProductsCoreFirst' ]
then
   corename=ProductsCoreSecond
else
   corename=ProductsCoreFirst
fi
	

echo "We picked core $corename and deleting al indexes and re-indexing onto it "

echo "we are deleting all indexes in this core ${corename}"
curl http://$host:$port/$webpath/$corename/update --data '<delete><query>*:*</query></delete>' -H 'Content-type:text/xml; charset=utf-8'
curl http://$host:$port/$webpath/$corename/update --data '<commit/>' -H 'Content-type:text/xml; charset=utf-8'

echo "We are indexing into this core ${corename}" 


for i in {0..23}
do
   $ROOT/post.sh $host $webpath $corename $ROOT/solrinputfiles/batches/solrinput${i}.xml &
done

wait

echo "We will RELAOD this code ${corename} now"

result=$($BASEX_HOME/bin/basex -bhost=$host -bport=$port -bwebpath=$webpath -bcoreName=$corename $ROOT/xquery/executeReloadCommand.xq 2>&1)

if [ $result -eq "0" ]
then
  echo "RELOADed core=${corename} executed successfully"
  echo "writing new core name into /opt/migros/webuiprod/src/ACTIVE_CORE_NAME "
  echo ${corename} > /opt/migros/webuiprod/src/ACTIVE_CORE_NAME
else
  echo "Faced problem in RELOADING core = ${corename}"
fi

echo "$(date):Real SOLR indexing done"



