#!/bin/bash
set -x #echo on

source ~/.bashrc

ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date):SOLR indexing started"

echo "$(date):Pulling Core tables from Oraqcle Database"
$ROOT/pullCoreTables.sh

echo "Indexing all Products related data into XML database called Basex"
$ROOT/indexProductsRawDataInBasex.sh

echo "Pulling CRM data"
$ROOT/reloadCRMData.sh

echo "Prepare Solr index data in xml"
$ROOT/prepareSolrIndexData.sh

echo "Splitting files into multiple ones to expedidate indexing process"
$ROOT/prepareSolrInputFiles.sh

echo "Now index All Migros data in SOLR"

$ROOT/performSolrIndexing.sh localhost 8080 migrossolr

$ROOT/populateCampaigns.sh localhost 8080 migrossolr

echo "$(date):SOLR indexing done"


