#!/bin/bash
ROOT=$(cd $(dirname "$0"); pwd)/SQLExtracts
echo "Current folder = ${ROOT}"
echo "indexing all tables in SOLR"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
    SET INTPARSE true;
    CREATE DB Brands $ROOT/Brands0.sql.xml
    CREATE DB Customers $ROOT/Customers0.sql.xml
    CREATE DB Favorites $ROOT/Favorites0.sql.xml
    CREATE DB Features $ROOT/Features0.sql.xml
    CREATE DB Paths $ROOT/Path0.sql.xml
    CREATE DB CoreProductInfo $ROOT/Products0.sql.xml
    CREATE DB Properties $ROOT/Properties0.sql.xml
    CREATE DB PSI $ROOT/PSI0.sql.xml
    CREATE DB CRM $ROOT/CRM0.sql.xml

    SET PARSER csv
    SET CSVPARSER encoding=utf-8, header=false, separator=comma
    SET CREATEFILTER *.csv
    CREATE DB ProductModelDetails $ROOT/ProductMoodelDetails.csv

    EXIT
EOF
