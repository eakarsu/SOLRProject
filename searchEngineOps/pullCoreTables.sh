#!/bin/bash
## declare an array variable
declare -a array=("Brands" "Customers" "Favorites" "Features" "Path" "Products" "Properties" "PSI")

# get length of an array
arraylength=${#array[@]}

# use for loop read all values and indexes
for (( i=1; i<${arraylength}+1; i++ ));
do
  echo "executing " $BASEX_HOME80/bin/basex -bsqlfile=sqlStmts/${array[$i-1]}.sql -boutputfile=SQLExtracts/${array[$i-1]}.sql.xml -bmonth=0 xquery/runSqlCommand.xq
  $BASEX_HOME80/bin/basex -bsqlfile=sqlStmts/${array[$i-1]}.sql -boutputfile=SQLExtracts/${array[$i-1]}.sql.xml -bmonth=0 xquery/runSqlCommand.xq
done

echo "pull Product model details"
java -cp java:java/ojdbc7.jar:java/opencsv-2.3.jar migrosdbread.readBlob SQLExtracts/ProductMoodelDetails.csv 500000 Prop
