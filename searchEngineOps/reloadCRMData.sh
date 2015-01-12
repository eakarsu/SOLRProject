#!/bin/bash
ROOT=$(cd $(dirname "$0"); pwd)/SQLExtracts
echo "Current folder = ${ROOT}"

echo "Pulling CRM data from Oracle Database "
$BASEX_HOME80/bin/basex -bsqlfile=sqlStmts/CRM.sql -boutputfile=SQLExtracts/CRM.sql.xml -bmonth=0 xquery/runSqlCommand.xq

echo "Indexing CRM data in Basex XML database"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
	CREATE DB CRM $ROOT/CRM0.sql.xml
	EXIT
EOF
