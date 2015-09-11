#!/bin/bash
set -x #echo on

CONTEXT=$1
echo "$(date): Starting Index Products Raw Data in Basex for CONTEXT=$1"

ROOT=$(cd $(dirname "$0"); pwd)
echo "Current folder = ${ROOT}"
echo "indexing all tables in SOLR"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
    SET INTPARSE true;
    CREATE DB ${CONTEXT}Brands $ROOT/SQLExtracts/$CONTEXT/Brands0.sql.xml
    CREATE DB ${CONTEXT}Customers $ROOT/SQLExtracts/$CONTEXT/Customers0.sql.xml
    CREATE DB ${CONTEXT}Favorites $ROOT/SQLExtracts/$CONTEXT/Favorites0.sql.xml
    CREATE DB ${CONTEXT}Features $ROOT/SQLExtracts/$CONTEXT/Features0.sql.xml
    CREATE DB ${CONTEXT}Paths $ROOT/SQLExtracts/$CONTEXT/Path0.sql.xml
    CREATE DB ${CONTEXT}CoreProductInfo $ROOT/SQLExtracts/$CONTEXT/Products0.sql.xml
    CREATE DB ${CONTEXT}Properties $ROOT/SQLExtracts/$CONTEXT/Properties0.sql.xml
    CREATE DB ${CONTEXT}PSI_stock_info  $ROOT/SQLExtracts/$CONTEXT/PSI_stock_info0.sql.xml
    CREATE DB ${CONTEXT}Discounts $ROOT/SQLExtracts/$CONTEXT/Discounts0.sql.xml

    #SET PARSER csv
    #SET CSVPARSER encoding=utf-8, header=false, separator=comma
    #SET CREATEFILTER *.csv
    #CREATE DB ProductModelDetails $ROOT/ProductMoodelDetails.csv

    EXIT
EOF

echo "$(date): Finished Indexing Products Raw Data in Basex for CONTEXT=$1"

