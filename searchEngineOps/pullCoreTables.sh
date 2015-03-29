#!/bin/bash
set -x #echo on

ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date): Starting Pull Core Tables"

## declare an array variable
declare -a array=("Brands" "Customers" "Favorites" "Features" "Path" "Products" "Properties" "PSI_stock_info")

# get length of an array
arraylength=${#array[@]}

# use for loop read all values and indexes
for (( i=1; i<${arraylength}+1; i++ ));
do
  echo "$(date):Executing " $BASEX_HOME80/bin/basex -bsqlfile=$ROOT/sqlStmts/${array[$i-1]}.sql -boutputfile=$ROOT/SQLExtracts/${array[$i-1]}.sql.xml -bmonth=0 $ROOT/xquery/runSqlCommand.xq
  $BASEX_HOME80/bin/basex -bsqlfile=$ROOT/sqlStmts/${array[$i-1]}.sql -boutputfile=$ROOT/SQLExtracts/${array[$i-1]}.sql.xml -bmonth=0 $ROOT/xquery/runSqlCommand.xq
done

echo "pull Product model details"
#java -cp java:java/ojdbc7.jar:java/opencsv-2.3.jar migrosdbread.readBlob SQLExtracts/ProductMoodelDetails.csv 500000 Prop

echo "$(date): Finished Pull Core Tables"
