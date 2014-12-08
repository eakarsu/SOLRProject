#!/bin/sh
 
#JAVA_HOME=/home/eakarsu/jdk1.7.0_45
JAVA_HOME=/home/eakarsu/jdk1.8.0_25
 
# run JVM in server mode
JAVA_OPTS="$JAVA_OPTS -server"
 
# memory
JAVA_OPTS="$JAVA_OPTS -Xms128m -Xmx8096m"
JAVA_OPTS="$JAVA_OPTS -XX:PermSize=64m -XX:MaxPermSize=128m"
 
# Timezone and JVM file encoding
JAVA_OPTS="$JAVA_OPTS -Duser.timezone=UTC -Dfile.encoding=UTF8"
JAVA_OPTS="$JAVA_OPTS -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp"
 
# solr.solr.home => solr home for this app instance
# port => app server port no.
# hostContext => wepapp context name
#SOLR_OPTS="-Dsolr.solr.home=/opt/migros/solr -Dport=8080 -Dsolr.data.dir=/opt/migros/data"
SOLR_OPTS="-Dsolr.clustering.enabled=true -Dsolr.solr.home=/opt/migros/solr -Dport=8080 -Dsolr.data.dir=/opt/migros/data -Dsolr.maxIndexing.Threads=40 -Dsolr.ramBuffer.SizeMB=2048 -Dsolr.maxBuffered.Docs=50000 -Dsolr.merge.Factor=25"
JAVA_OPTS="$JAVA_OPTS $SOLR_OPTS"
 
