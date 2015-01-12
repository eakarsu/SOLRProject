
echo "Adding empty database 'AccumulatedProducts' with content <add/> "
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 CREATE DB AccumulatedProducts "<add/>"
 EXIT
EOF

echo "Adding Core Product data into solr input files .." 
$BASEX_HOME/bin/basex -baction=coresetup  xquery/PrepareMigrosData.xq

echo "Adding CRM data into solr input files .." 
$BASEX_HOME/bin/basex -baction=addcrm  xquery/PrepareMigrosData.xq

echo "Adding Product Sales Infos data into solr input files .."
$BASEX_HOME/bin/basex -baction=addpsi  xquery/PrepareMigrosData.xq
