swig -java -package org.apache.lucene.analysis.tr -outdir src foma.i
gcc -fPIC -c foma_wrap.c -I/home/eakarsu/jdk1.8.0_60/include -I/home/eakarsu/jdk1.8.0_60/include/linux
gcc -fPIC -c fomaread.c
ld -G foma_wrap.o fomaread.o -lfoma -o libfomahelpers.so
