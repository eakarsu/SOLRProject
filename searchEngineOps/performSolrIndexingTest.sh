#!/bin/bash
set -x #echo on

host=localhost
port=8080
webpath=migrossolr

ROOT=$(cd $(dirname "$0"); pwd)
corename=ProductsCoreFirst
echo "We are indexing into this core ${corename}" 


for i in {0..24}
do
   $ROOT/post.sh $host $webpath $corename solrinputfiles/batches/solrinput${i}.xml &
done

wait




