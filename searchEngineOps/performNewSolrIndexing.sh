#!/bin/bash
set -x #echo on

source ~/.bashrc

CONTEXT=$1

ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date):SOLR indexing started context=$CONTEXT"

#setup folders
if [ ! -d "$ROOT/SQLExtracts/$CONTEXT" ]; then
	mkdir -p $ROOT/SQLExtracts/$CONTEXT
fi

if [ ! -d "$ROOT/solrinputfiles/$CONTEXT/batches" ]; then
	mkdir -p $ROOT/solrinputfiles/$CONTEXT/batches
fi


echo "$(date):Pulling Core tables from Oraqcle Database"
$ROOT/pullCoreTables.sh ${CONTEXT}

echo "Indexing all Products related data into XML database called Basex"
$ROOT/indexProductsRawDataInBasex.sh ${CONTEXT}

echo "Pulling CRM data. This is common for MACRO and KANG so that we pull once"
#We need to take out this and start in parallel thread
#$ROOT/reloadCRMData.sh  ${CONTEXT}

echo "Prepare Solr index data in xml"
$ROOT/prepareSolrIndexData.sh  ${CONTEXT}

exit

echo "Splitting files into multiple ones to expedidate indexing process"
#$ROOT/prepareSolrInputFiles.sh  ${CONTEXT}

echo "Now index All Migros data in SOLR"

#$ROOT/performSolrIndexing.sh localhost 8080 migrossolr  ${CONTEXT}

$ROOT/populateCampaigns.sh localhost 8080 migrossolr  ${CONTEXT}

echo "$(date):SOLR indexing done context=  ${CONTEXT}"


