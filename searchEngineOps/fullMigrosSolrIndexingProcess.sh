#!/bin/bash
set -x #echo on

source ~/.bashrc

host=$1
port=$2
webpath=$3

ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date): Full Indexing process started "

#setup folders
if [ ! -d "$ROOT/SQLExtracts/$CONTEXT" ]; then
        mkdir -p $ROOT/SQLExtracts/$CONTEXT
fi
if [ ! -d "$ROOT/SQLExtracts/KANGURUM" ]; then
        mkdir -p $ROOT/SQLExtracts/MACROCENTER
fi
 

#$ROOT/reloadCRMData.sh KANGURUM &

$ROOT/prepareSolrInputForContext1.sh $host $port $webpath KANGURUM &

$ROOT/prepareSolrInputForContext1.sh $host $port $webpath MACROCENTER &

echo "waiting all 3 processes (reload CRM data,prepare KANGURUM data and MACROCENTER data)"

wait

echo "Adding crm data for KANGURUM"
$ROOT/prepareSolrInputForContext2.sh KANGURUM &

echo "Adding crm data for MACROCENTER "
$ROOT/prepareSolrInputForContext2.sh MACROCENTER &

wait

#start importing data
$ROOT/postIndexProcess.sh $host $port  $webpath MACROCENTER

$ROOT/postIndexProcess.sh $host $port  $webpath KANGURUM

echo "$(date): Full Indexing process finished "
