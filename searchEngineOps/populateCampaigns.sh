#!/bin/bash

set -x #echo on


host=$1
port=$2
webpath=$3

ROOT=$(cd $(dirname "$0"); pwd)

read activeCoreName < /opt/migros/webuiprod/src/ACTIVE_CORE_NAME

echo "activeCoreName = ${activeCoreName}"

#Prepare SOLR input file that will include Products IDs for selected Brand and  Category names in Campaigns core. t
#This SOLR input file will be imported in next step
$BASEX_HOME/bin/basex -bhost=$host -bport=$port -bwebpath=$webpath -bcoreName=$activeCoreName -boutFileName=$ROOT/solrinputfiles/populateKampanyaPIDs.xml $ROOT/xquery/populateKampanyaPIDs.xq

#Now Populate Campaigns with ProductIDs obtained in previous step
$ROOT/post.sh $host $webpath "Campaigns" $ROOT/solrinputfiles/populateKampanyaPIDs.xml 

#Prepare SOLR input file to flag all products obtained in previous step in Product core
$BASEX_HOME/bin/basex -bhost=$host -bport=$port -bwebpath=$webpath  -boutFileName=$ROOT/solrinputfiles/prepareKampanyaAdd.xml -bprocess=set $ROOT/xquery/prepareKampanyaAdd.xq

#Import SOLR input file in previous step
$ROOT/post.sh $host $webpath $activeCoreName $ROOT/solrinputfiles/prepareKampanyaAdd.xml 
