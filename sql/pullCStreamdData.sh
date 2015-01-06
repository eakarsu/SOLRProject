 sqlplus64 -s kangurum/planetuc9@212.12.132.196:1521/kngdb @CSstream.sql JAN FEB |  awk '$1=$1' | sed -e 's/|\s\+/|/g' | sed -e 's/\s\+|/|/g' > CS1.csv &
 sqlplus64 -s kangurum/planetuc9@212.12.132.196:1521/kngdb @CSstream.sql FEB MAR |  awk '$1=$1' | sed -e 's/|\s\+/|/g' | sed -e 's/\s\+|/|/g' > CS2.csv &
 sqlplus64 -s kangurum/planetuc9@212.12.132.196:1521/kngdb @CSstream.sql MAR APR |  awk '$1=$1' | sed -e 's/|\s\+/|/g' | sed -e 's/\s\+|/|/g' > CS3.csv &
 sqlplus64 -s kangurum/planetuc9@212.12.132.196:1521/kngdb @CSstream.sql APR MAY |  awk '$1=$1' | sed -e 's/|\s\+/|/g' | sed -e 's/\s\+|/|/g' > CS4.csv &
 sqlplus64 -s kangurum/planetuc9@212.12.132.196:1521/kngdb @CSstream.sql MAY JUN |  awk '$1=$1' | sed -e 's/|\s\+/|/g' | sed -e 's/\s\+|/|/g' > CS5.csv &
 sqlplus64 -s kangurum/planetuc9@212.12.132.196:1521/kngdb @CSstream.sql JUN JUL |  awk '$1=$1' | sed -e 's/|\s\+/|/g' | sed -e 's/\s\+|/|/g' > CS6.csv &
 sqlplus64 -s kangurum/planetuc9@212.12.132.196:1521/kngdb @CSstream.sql JUL AUG |  awk '$1=$1' | sed -e 's/|\s\+/|/g' | sed -e 's/\s\+|/|/g' > CS7.csv &
 sqlplus64 -s kangurum/planetuc9@212.12.132.196:1521/kngdb @CSstream.sql AUG SEP |  awk '$1=$1' | sed -e 's/|\s\+/|/g' | sed -e 's/\s\+|/|/g' > CS8.csv &
 sqlplus64 -s kangurum/planetuc9@212.12.132.196:1521/kngdb @CSstream.sql SEP OCT |  awk '$1=$1' | sed -e 's/|\s\+/|/g' | sed -e 's/\s\+|/|/g' > CS9.csv &
 sqlplus64 -s kangurum/planetuc9@212.12.132.196:1521/kngdb @CSstream.sql OCT NOV |  awk '$1=$1' | sed -e 's/|\s\+/|/g' | sed -e 's/\s\+|/|/g' > CS10.csv &
 sqlplus64 -s kangurum/planetuc9@212.12.132.196:1521/kngdb @CSstream.sql NOV DEC |  awk '$1=$1' | sed -e 's/|\s\+/|/g' | sed -e 's/\s\+|/|/g' > CS11.csv &
 
