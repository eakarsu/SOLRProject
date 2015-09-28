#!/bin/bash
set -x #echo on

CONTEXT=$1
ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date): Starting Pull Core Tables context=${CONTEXT}"

## declare an array variable
declare -a array=("Brands" "Customers" "Favorites" "Features" "Path" "Products" "Properties" "PSI_stock_info" "Discounts")

# get length of an array
arraylength=${#array[@]}

# use for loop read all values and indexes
for (( i=1; i<${arraylength}+1; i++ ));
do
  echo  "$(date):Executing " $BASEX_HOME/bin/basex -bsqlfile=$ROOT/sqlStmts/${CONTEXT}/${array[$i-1]}.sql -boutputfile=$ROOT/SQLExtracts/${CONTEXT}/${array[$i-1]}.sql.xml -bmonth=0 -bcontext=${CONTEXT} $ROOT/xquery/runSqlCommand.xq
  $BASEX_HOME/bin/basex -bsqlfile=$ROOT/sqlStmts/${CONTEXT}/${array[$i-1]}.sql -boutputfile=$ROOT/SQLExtracts/${CONTEXT}/${array[$i-1]}.sql.xml -bmonth=0 -bcontext=${CONTEXT} $ROOT/xquery/runSqlCommand.xq
done

echo "pull Product model details"
#java -cp java:java/ojdbc7.jar:java/opencsv-2.3.jar migrosdbread.readBlob SQLExtracts/ProductMoodelDetails.csv 500000 Prop

echo "$(date): Finished Pull Core Tables"
