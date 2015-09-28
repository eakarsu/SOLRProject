#!/bin/bash
set -x #echo on

#./incrementalProcessKeywords.sh localhost 8080 migrossolr KANGURUM
ROOT=$(cd $(dirname "$0"); pwd)

host=$1
port=$2
webpath=$3
CONTEXT=$4

echo "$(date):creating click stream click info XML database named as CSstreamClickInfo"

read activeCoreName < ../webuiprod/src/${CONTEXT}_ACTIVE_CORE_NAME

echo "Current activeCoreName = ${activeCoreName}"
if [ $activeCoreName == "${CONTEXT}ProductsCoreFirst" ]
then
   corename=${CONTEXT}ProductsCoreSecond
else
   corename=${CONTEXT}ProductsCoreFirst
fi


echo "generating raw keyword file"
$BASEX_HOME/bin/basex -ballAddCartsDoc=${CONTEXT}CSstreamCartInfoMap -bcoreProductInfo=${CONTEXT}CoreProductInfo -brawKeywordsFile=${ROOT}/solrinputfiles/${CONTEXT}/rawKeywords.xml $ROOT/xquery/extractKeywordsFromClickS.xq

#echo "Running Levenshtein algorithm on .."
#echo "generating solr input files for clicks and addcarts"
#$BASEX_HOME/bin/basex -blevendist=2 -brawKeywordsFile=${ROOT}/solrinputfiles/${CONTEXT}/rawKeywords.xml -boutputKeywordsFile=${ROOT}/solrinputfiles/${CONTEXT}/NewKeywords.xml ${ROOT}/xquery/Levenshtein.xq

echo "Indexing Levenshtein keywords"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 CREATE DB ${CONTEXT}NewKeywords ${ROOT}/solrinputfiles/${CONTEXT}/rawKeywords.xml
EOF

echo "exporing existing searchkeywords form solr"

curl -o ${ROOT}/solrinputfiles/${CONTEXT}/PreviousKeywords.xml "http://${host}:${port}/${webpath}/${corename}/query?q=*%3A*&fl=ProductID%2CSearchKeyword&wt=xml&indent=true&rows=70000"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 CREATE DB ${CONTEXT}PreviousKeywords ${ROOT}/solrinputfiles/${CONTEXT}/PreviousKeywords.xml
EOF

$BASEX_HOME/bin/basex -bcoreProductInfo=${CONTEXT}CoreProductInfo  -bpreviousKeywordsDoc=${CONTEXT}PreviousKeywords -bnewKeywordsDoc=${CONTEXT}NewKeywords -bmergedKeywordDoc=${ROOT}/solrinputfiles/${CONTEXT}/SearchKeywords.xml ${ROOT}/xquery/produceNewSearchKeywords.xq

echo "index new search keywords"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
 CREATE DB ${CONTEXT}SearchKeywords ${ROOT}/solrinputfiles/${CONTEXT}/SearchKeywords.xml
EOF

echo "$(date):Click stream processing done "

