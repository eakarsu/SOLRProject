#!/bin/bash
set -x #echo on

source ~/.bashrc

CONTEXT=$1

ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date):Adding all CRM related data into final SOLR input file context=$CONTEXT"

echo "$(date): Adding CRM data into solr input files .."
$BASEX_HOME/bin/basex -baction=addcrm1  -bcontext=${CONTEXT} $ROOT/xquery/PrepareMigrosData.xq
$BASEX_HOME/bin/basex -baction=addcrm2  -bcontext=${CONTEXT} $ROOT/xquery/PrepareMigrosData.xq
$BASEX_HOME/bin/basex -baction=addcrm3  -bcontext=${CONTEXT} $ROOT/xquery/PrepareMigrosData.xq
$BASEX_HOME/bin/basex -baction=addcrm4  -bcontext=${CONTEXT} $ROOT/xquery/PrepareMigrosData.xq


echo "$(date): Exporting ${CONTEXT} data"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 OPEN ${CONTEXT}AccumulatedProducts
 EXPORT $ROOT/solrinputfiles/$CONTEXT
 EXIT
EOF




