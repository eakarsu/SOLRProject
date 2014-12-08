ls *sql |  xargs -i -t ../../bin/basex  -bsqlfile={}  -boutputfile={}.xml runSqlCommand.xq
