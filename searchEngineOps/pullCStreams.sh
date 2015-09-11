#!/bin/bash
set -x #echo on

CONTEXT=$1
ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date): Pulling click stream data context=${CONTEXT}"

for ((nk=1;nk<=12;nk++))
do
   $BASEX_HOME/bin/basex -bsqlfile=sqlStmts/${CONTEXT}/CSstream_prod.sql -boutputfile=SQLExtracts/${CONTEXT}/CSstreams/CSstream.sql.xml -bmonth=$nk -bcontext=${CONTEXT} $ROOT/xquery/runSqlCommand.xq &
  #we have to sleep some . Otherwise, Oracle this we are spamming and reset all connections
  sleep 1m
done
echo "$(date): Pulling click stream data done."
