 ../bin/basex -bsqlfile=Products.sql -boutputfile=Products.sql.xml runSqlCommand.xq

ls *sql | grep -v Click| xargs -i -t ../bin/basex -bsqlfile={} -boutputfile={}.xml runSqlCommand.xq
