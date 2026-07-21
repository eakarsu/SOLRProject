      declare variable $sqlfile as xs:string external;
      declare variable $outputfile as xs:string external;
      declare variable $month as xs:integer external;
      declare variable $jdbc-url as xs:string external;
      declare variable $jdbc-user as xs:string external;
      declare variable $jdbc-password as xs:string external;

      let $lines := file:read-text-lines ($sqlfile)
      let $lines :=
        for $line in $lines
          return
            fn:normalize-space($line)
      let $sqlStmt := fn:string-join($lines," ")

      let $sqlStmt :=
          if ($month eq 0) then $sqlStmt
          else
              let  $startMonth := xs:dateTime("2013-12-31T00:00:00") + ($month -1) *  xs:yearMonthDuration("P0Y1M")
              let  $endMonth := xs:dateTime("2013-12-31T00:00:00") + $month  * xs:yearMonthDuration("P0Y1M")
              let $sdate := fn:substring-before(xs:string($startMonth),"T")
              let $edate := fn:substring-before(xs:string($endMonth),"T")
              let $sqlStmt := fn:replace($sqlStmt,"SDATE",$sdate)
              let $sqlStmt := fn:replace($sqlStmt,"EDATE",$edate)
              return
                $sqlStmt

       let $outputfile := fn:replace($outputfile,".sql",fn:concat($month,".sql"))
       let $addBegin := file:write-text($outputfile,"<RECORDS>","UTF-8")
       let $conn  := sql:connect($jdbc-url, $jdbc-user, $jdbc-password)
       let $list :=
         for tumbling window $w in sql:execute ($conn,$sqlStmt)
            start at $x when fn:true()
            end at $y when $y - $x = 10000
              let $windowData :=
                for $rec in $w
                   let $rowData :=
                     for $line in $rec/*
                       return
                         element {fn:data($line/@name)} {$line/text()}
                   return <record>{$rowData}</record>
             return 
               file:append( $outputfile, $windowData)

       return
         ($list,file:append-text($outputfile,"</RECORDS>","UTF-8"))
