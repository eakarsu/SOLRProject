#!/bin/bash

set -x #echo on


host=$1
port=$2
webpath=$3
CONTEXT=$4

ROOT=$(cd $(dirname "$0"); pwd)

read activeCoreName < ../webuiprod/src/${CONTEXT}_ACTIVE_CORE_NAME

echo "activeCoreName = ${activeCoreName}"

#Prepare SOLR input file that will include Products IDs for selected Brand and  Category names in Campaigns core. t
#This SOLR input file will be imported in next step
$BASEX_HOME/bin/basex -bhost=$host -bport=$port -bwebpath=$webpath -bcoreName=$activeCoreName -boutFileName=$ROOT/solrinputfiles/${CONTEXT}populateKampanyaPIDs.xml $ROOT/xquery/populateKampanyaPIDs.xq

#Now Populate Campaigns with ProductIDs obtained in previous step
$ROOT/post.sh $host $port $webpath "Campaigns" $ROOT/solrinputfiles/${CONTEXT}populateKampanyaPIDs.xml

#Prepare SOLR input file to flag all products obtained in previous step in Product core
$BASEX_HOME/bin/basex -bhost=$host -bport=$port -bwebpath=$webpath  -boutFileName=$ROOT/solrinputfiles/${CONTEXT}prepareKampanyaAdd.xml -bprocess=set $ROOT/xquery/prepareKampanyaAdd.xq

#Import SOLR input file in previous step
$ROOT/post.sh $host $port $webpath $activeCoreName $ROOT/solrinputfiles/${CONTEXT}prepareKampanyaAdd.xml
