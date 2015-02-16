#!/bin/bash
set -x #echo on

echo "$(date): Starting Index Products Raw Data in Basex"

ROOT=$(cd $(dirname "$0"); pwd)
echo "Current folder = ${ROOT}"
echo "indexing all tables in SOLR"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
    SET INTPARSE true;
    CREATE DB Brands $ROOT/SQLExtracts/Brands0.sql.xml
    CREATE DB Favorites $ROOT/SQLExtracts/Favorites0.sql.xml
    CREATE DB Features $ROOT/SQLExtracts/Features0.sql.xml
    CREATE DB Paths $ROOT/SQLExtracts/Path0.sql.xml
    CREATE DB CoreProductInfo $ROOT/SQLExtracts/Products0.sql.xml
    CREATE DB Properties $ROOT/SQLExtracts/Properties0.sql.xml
    CREATE DB PSI_stock_info  $ROOT/SQLExtracts/PSI_stock_info0.sql.xml

    #SET PARSER csv
    #SET CSVPARSER encoding=utf-8, header=false, separator=comma
    #SET CREATEFILTER *.csv
    #CREATE DB ProductModelDetails $ROOT/ProductMoodelDetails.csv

    EXIT
EOF

echo "$(date): Finished Indexing Products Raw Data in Basex"

