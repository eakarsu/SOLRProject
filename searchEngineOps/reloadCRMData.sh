#!/bin/bash
set -x #echo on

CONTEXT=$1

ROOT=$(cd $(dirname "$0"); pwd)
echo "Current folder = ${ROOT}"

#setup folders
if [ ! -d "$ROOT/SQLExtracts/$CONTEXT" ]; then
	mkdir -p $ROOT/SQLExtracts/$CONTEXT
fi


echo "Pulling CRM data from Oracle Database "
$BASEX_HOME/bin/basex -bsqlfile=$ROOT/sqlStmts/$CONTEXT/CRMSegments.sql -boutputfile=$ROOT/SQLExtracts/$CONTEXT/CRMSegments.sql.xml -bmonth=0 -bcontext=${CONTEXT} $ROOT/xquery/runSqlCommand.xq
$BASEX_HOME/bin/basex -bsqlfile=$ROOT/sqlStmts/$CONTEXT/CRMCounts.sql -boutputfile=$ROOT/SQLExtracts/$CONTEXT/CRMCounts.sql.xml -bmonth=0 -bcontext=${CONTEXT} $ROOT/xquery/runSqlCommand.xq
$BASEX_HOME/bin/basex -bsqlfile=$ROOT/sqlStmts/$CONTEXT/CRMCustomers.sql -boutputfile=$ROOT/SQLExtracts/$CONTEXT/CRMCustomers.sql.xml -bmonth=0 -bcontext=${CONTEXT} $ROOT/xquery/runSqlCommand.xq

echo "Indexing CRM data in Basex XML database"
$BASEX_HOME/bin/basexclient -p1984 -Padmin -Uadmin << EOF
	CREATE DB CRMSegments $ROOT/SQLExtracts/$CONTEXT/CRMSegments0.sql.xml
	CREATE DB CRMCounts $ROOT/SQLExtracts/$CONTEXT/CRMCounts0.sql.xml
	CREATE DB CRMCustomers $ROOT/SQLExtracts/$CONTEXT/CRMCustomers0.sql.xml
	EXIT
EOF
