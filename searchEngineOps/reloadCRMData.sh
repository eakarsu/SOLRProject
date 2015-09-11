#!/bin/bash
set -x #echo on

CONTEXT=$1

ROOT=$(cd $(dirname "$0"); pwd)
echo "Current folder = ${ROOT}"

#setup folders
if [ ! -d "$ROOT/SQLExtracts/$CONTEXT" ]; then
	mkdir -p $ROOT/SQLExtracts/$CONTEXT
fi

if [ ! -d "$ROOT/solrinputfiles/$CONTEXT/batches" ]; then
	mkdir -p $ROOT/solrinputfiles/$CONTEXT/batches
fi

echo "Pulling CRM data from Oracle Database "
$BASEX_HOME/bin/basex -bsqlfile=$ROOT/sqlStmts/CRMSegments.sql -boutputfile=$ROOT/SQLExtracts/CRMSegments.sql.xml -bmonth=0 -bcontext=${CONTEXT} $ROOT/xquery/runSqlCommand.xq
$BASEX_HOME/bin/basex -bsqlfile=$ROOT/sqlStmts/CRMCounts.sql -boutputfile=$ROOT/SQLExtracts/CRMCounts.sql.xml -bmonth=0 -bcontext=${CONTEXT} $ROOT/xquery/runSqlCommand.xq
$BASEX_HOME/bin/basex -bsqlfile=$ROOT/sqlStmts/CRMCustomers.sql -boutputfile=$ROOT/SQLExtracts/CRMCustomers.sql.xml -bmonth=0 -bcontext=${CONTEXT} $ROOT/xquery/runSqlCommand.xq

echo "Indexing CRM data in Basex XML database"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
	CREATE DB CRMSegments $ROOT/SQLExtracts/CRMSegments0.sql.xml
	CREATE DB CRMCounts $ROOT/SQLExtracts/CRMCounts0.sql.xml
	CREATE DB CRMCustomers $ROOT/SQLExtracts/CRMCustomers0.sql.xml
	EXIT
EOF
