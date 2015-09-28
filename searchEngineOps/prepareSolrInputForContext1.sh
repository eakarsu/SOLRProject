#!/bin/bash
set -x #echo on

source ~/.bashrc

host=$1
port=$2
webpath=$3
CONTEXT=$4

ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date):SOLR indexing started context=$CONTEXT"

echo "$(date):Pulling Core tables from Oraqcle Database"
$ROOT/pullCoreTables.sh ${CONTEXT}

echo "Indexing all Products related data into XML database called Basex"
$ROOT/indexProductsRawDataInBasex.sh ${CONTEXT}

#pull incremental click stream data
echo "incremental click stream data"
$ROOT/incrementalProcessCSStreams.sh $host $port $webpath ${CONTEXT}

#pull keywords
echo "pull Keywords forem click stream data"
$ROOT/incrementalProcessKeywords.sh $host $port $webpath ${CONTEXT}

echo "$(date): Adding empty database 'AccumulatedProducts' with content <add/> context=${CONTEXT} "
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 CREATE DB ${CONTEXT}AccumulatedProducts "<add/>"
 EXIT
EOF

echo "$(date): Adding Core Product data into solr input files .."
$BASEX_HOME/bin/basex -baction=coresetup  -bcontext=${CONTEXT} $ROOT/xquery/PrepareMigrosData.xq

echo "$(date): Adding Product Sales Infos data into solr input files .."
$BASEX_HOME/bin/basex -baction=addpsi  -bcontext=${CONTEXT} $ROOT/xquery/PrepareMigrosData.xq


