
#!/bin/bash
set -x #echo on

source ~/.bashrc

host=$1
port=$2
webpath=$3
CONTEXT=$4

CONTEXT=$1

ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date):SOLR post index process context=$CONTEXT"

$ROOT/populateCampaigns.sh localhost 8080 migrossolr  ${CONTEXT}

echo "$(date):SOLR post index process context=  ${CONTEXT}"