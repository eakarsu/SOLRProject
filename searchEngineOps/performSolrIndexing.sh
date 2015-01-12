#!/bin/bash


host=$1
port=$2
webpath=$3

echo "We are looking for which core we will re-index now"
corename=$($BASEX_HOME/bin/basex -bhost=$host -bport=$port -bwebpath=$webpath -bcoreName=ProductsCoreFirst xquery/getSwappedCoreName.xq 2>&1)

echo "We picked core $corename and deleting al indexes and re-indexing onto it "

echo "web are deleting all indexes in this core ${corename}"
curl http://$host:$port/$webpath/$corename/update --data '<delete><query>*:*</query></delete>' -H 'Content-type:text/xml; charset=utf-8'
curl http://$host:$port/$webpath/$corename/update --data '<commit/>' -H 'Content-type:text/xml; charset=utf-8'

echo "We are indexing into this core ${corename}" 


for i in {0..23}
do
   ./post.sh $host $webpath $corename solrinputfiles/batches/solrinput${i}.xml &
done

wait

echo "We will RELAOD this code ${corename} now"

result=$($BASEX_HOME/bin/basex -bhost=$host -bport=$port -bwebpath=$webpath -bcoreName=$corename xquery/executeReloadCommand.xq 2>&1)

if [ $result -eq "0" ]
then
  echo "RELOADed core=${corename} executed successfully"
else
  echo "Faced problem in RELOADING core = ${corename}"
fi

echo "We are swapping core now"

result=$($BASEX_HOME/bin/basex -bhost=$host -bport=$port -bwebpath=$webpath xquery/executeSwapCommand.xq 2>&1)

if [ $result -eq "0" ]
then
  echo "SWAPped core=${corename} executed successfully"
else
  echo "Faced problem in SWAP operation"
fi



