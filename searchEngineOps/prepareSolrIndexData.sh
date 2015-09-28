#!/bin/bash
set -x #echo on

CONTEXT=$1
echo "$(date): Adding empty database 'AccumulatedProducts' with content <add/> context=${CONTEXT} "
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 CREATE DB ${CONTEXT}AccumulatedProducts "<add/>"
 EXIT
EOF

ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date): Adding Core Product data into solr input files .." 
$BASEX_HOME/bin/basex -baction=coresetup  -bcontext=${CONTEXT} $ROOT/xquery/PrepareMigrosData.xq

echo "$(date): Adding CRM data into solr input files .." 
$BASEX_HOME/bin/basex -baction=addcrm1  -bcontext=${CONTEXT} $ROOT/xquery/PrepareMigrosData.xq
$BASEX_HOME/bin/basex -baction=addcrm2  -bcontext=${CONTEXT} $ROOT/xquery/PrepareMigrosData.xq
$BASEX_HOME/bin/basex -baction=addcrm3  -bcontext=${CONTEXT} $ROOT/xquery/PrepareMigrosData.xq
$BASEX_HOME/bin/basex -baction=addcrm4  -bcontext=${CONTEXT} $ROOT/xquery/PrepareMigrosData.xq

echo "$(date): Adding Product Sales Infos data into solr input files .."
$BASEX_HOME/bin/basex -baction=addpsi  -bcontext=${CONTEXT} $ROOT/xquery/PrepareMigrosData.xq

echo "$(date): Preparing solr input files context=${CONTEXT}"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 OPEN ${CONTEXT}AccumulatedProducts
 EXPORT $ROOT/solrinputfiles/${CONTEXT}
 EXIT
EOF


echo "$(date): Finished"
