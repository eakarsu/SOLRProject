#!/bin/bash
set -x #echo on
source ~/.bashrc

host=$1
port=$2
webpath=$3
CONTEXT=$4

ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date):SOLR post index process context=$CONTEXT"

#We need to check whether or not import process is still running
#Check first active core name for input context
read activeCoreName < ../webuiprod/src/${CONTEXT}_ACTIVE_CORE_NAME
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

echo "Starting import SOLR data for core ${corename}"
curl "http://$host:$port/$webpath/$corename/dataimport0?command=full-import&entity=Products0&commit=true&optimize=true"

status="busy"
echo "Waiting for the import to complete.Status of ${corename} importing : ${status}"
while [ "$status" == "busy" ]
do
  status=$($BASEX_HOME/bin/basex -bhost=$host -bport=$port -bwebpath=$webpath -bcorename=$corename $ROOT/xquery/checkImportStatus.xq 2>&1)
  echo "Waiting for completion for $corename importing: status=$status"
  #waiting one minute: sleep 1m
  sleep 20s
done
$ROOT/populateCampaigns.sh localhost 8080 migrossolr ${CONTEXT}

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

echo "$(date):SOLR post index process ENDED context=  ${CONTEXT}"
