#!/bin/bash
set -x #echo on

echo "$(date): Adding empty database 'AccumulatedProducts' with content <add/> "
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 CREATE DB AccumulatedProducts "<add/>"
 EXIT
EOF

ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date): Adding Core Product data into solr input files .." 
$BASEX_HOME/bin/basex -baction=coresetup  $ROOT/xquery/PrepareMigrosData.xq

echo "$(date): Adding CRM data into solr input files .." 
$BASEX_HOME/bin/basex -baction=addcrm1  $ROOT/xquery/PrepareMigrosData.xq
$BASEX_HOME/bin/basex -baction=addcrm2  $ROOT/xquery/PrepareMigrosData.xq
$BASEX_HOME/bin/basex -baction=addcrm3  $ROOT/xquery/PrepareMigrosData.xq
$BASEX_HOME/bin/basex -baction=addcrm4  $ROOT/xquery/PrepareMigrosData.xq

echo "$(date): Adding Product Sales Infos data into solr input files .."
$BASEX_HOME/bin/basex -baction=addpsi  $ROOT/xquery/PrepareMigrosData.xq

echo "$(date): Finished"
