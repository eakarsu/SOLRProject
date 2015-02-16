#!/bin/bash
set -x #echo on

ROOT=$(cd $(dirname "$0"); pwd)

echo "$(date): Pulling click stream data"

for ((nk=1;nk<=12;nk++))
do
   $BASEX_HOME80/bin/basex -bsqlfile=sqlStmts/CSstream.sql -boutputfile=SQLExtracts/CSstreams/CSstream.sql.xml -bmonth=$nk $ROOT/xquery/runSqlCommand.xq &
  #we have to sleep some . Otherwise, Oracle this we are spamming and reset all connections
  sleep 1m
done
echo "$(date): Pulling click stream data done."
