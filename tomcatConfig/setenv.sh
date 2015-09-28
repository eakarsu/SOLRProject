#!/bin/sh
 
SOLRPATH=/oraexport/MigrosSearchEngine

JAVA_HOME=$SOLRPATH/jdk1.8.0_25
 
# run JVM in server mode
JAVA_OPTS="$JAVA_OPTS -server"
 
# memory
JAVA_OPTS="$JAVA_OPTS -Xms1228m -Xmx32226m"
#JAVA_OPTS="$JAVA_OPTS -Xms1228m -Xmx12226m -Djava.library.path=/usr/local/lib"

# Timezone and JVM file encoding
JAVA_OPTS="$JAVA_OPTS -Duser.timezone=UTC -Dfile.encoding=UTF8"
JAVA_OPTS="$JAVA_OPTS -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp"
 
# solr.solr.home => solr home for this app instance
# port => app server port no.
# hostContext => wepapp context name
SOLR_OPTS="-Dsolr.solr.home=$SOLRPATH/solr -Dport=8080 -Dsolr.data.dir=$SOLRPATH/data -Dsolr.maxIndexing.Threads=200 -Dsolr.ramBuffer.SizeMB=8048 -Dsolr.maxBuffered.Docs=50000 -Dsolr.merge.Factor=40 -Dsolr.allow.unsafe.resourceloading=true" 
JAVA_OPTS="$JAVA_OPTS $SOLR_OPTS"
 
