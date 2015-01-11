for ((nk=1;nk<=12;nk++))
do
   $BASEX_HOME80/bin/basex -bsqlfile=sqlStmts/CSstream.sql -boutputfile=SQLExtracts/CSstreams/CSstream.sql.xml -bmonth=$nk xquery/runSqlCommand.xq &
  #we have to sleep some . Otherwise, Oracle this we are spamming and reset all connections
  sleep 1m
done
