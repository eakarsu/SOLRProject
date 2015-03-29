#!/bin/bash
set -x #echo on

ROOT=$(cd $(dirname "$0"); pwd)
echo "Current folder = ${ROOT}"

echo "Pulling CRM data from Oracle Database "
$BASEX_HOME80/bin/basex -bsqlfile=$ROOT/sqlStmts/CRMSegments.sql -boutputfile=$ROOT/SQLExtracts/CRMSegments.sql.xml -bmonth=0 $ROOT/xquery/runSqlCommand.xq
$BASEX_HOME80/bin/basex -bsqlfile=$ROOT/sqlStmts/CRMCounts.sql -boutputfile=$ROOT/SQLExtracts/CRMCounts.sql.xml -bmonth=0 $ROOT/xquery/runSqlCommand.xq
$BASEX_HOME80/bin/basex -bsqlfile=$ROOT/sqlStmts/CRMCustomers.sql -boutputfile=$ROOT/SQLExtracts/CRMCustomers.sql.xml -bmonth=0 $ROOT/xquery/runSqlCommand.xq

echo "Indexing CRM data in Basex XML database"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
	CREATE DB CRMSegments $ROOT/SQLExtracts/CRMSegments0.sql.xml
	CREATE DB CRMCounts $ROOT/SQLExtracts/CRMCounts0.sql.xml
	CREATE DB CRMCustomers $ROOT/SQLExtracts/CRMCustomers0.sql.xml
	EXIT
EOF
