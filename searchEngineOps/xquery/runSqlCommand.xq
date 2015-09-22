      declare variable $sqlfile as xs:string external;
      declare variable $outputfile as xs:string external;
      declare variable $month as xs:integer external;
      declare variable $context as xs:string external;
      
      let $lines := file:read-text-lines ($sqlfile)
      let $lines :=
        for $line in $lines
          return
            fn:normalize-space($line)
      let $sqlStmt := fn:string-join($lines," ")
      let $contextFile := "../webuiprod/src/"||$context||"_ACTIVE_CORE_NAME"
      
      let $sqlStmt :=
          if ($month le 0) then
              let $now := fn:current-dateTime()
              let $localTimeZone := fn:timezone-from-dateTime($now)
              let $fileUpdateDate := file:last-modified($contextFile)
              let $realFileUpdateDate := fn:adjust-dateTime-to-timezone($fileUpdateDate,$localTimeZone)
              let $sDate := fn:replace(fn:replace(xs:string($realFileUpdateDate),"T"," "),"(\.|\+).*$","")
              let $eDate := fn:replace(fn:replace(xs:string($now),"T"," "),"(\.|\+).*$","")
              let $sqlStmt := fn:replace($sqlStmt,"SDATE",$sDate)
              let $sqlStmt := fn:replace($sqlStmt,"EDATE",$eDate)
              (: temporary code here. Pelase delete this one late:)
              return $sqlStmt
          else if ($month eq 0) then $sqlStmt
          else
              let  $startMonth := xs:dateTime("2013-12-31T00:00:00") + ($month -1) *  xs:yearMonthDuration("P0Y1M")
              let  $endMonth := xs:dateTime("2013-12-31T00:00:00") + $month  * xs:yearMonthDuration("P0Y1M")
              (: let $sdate := fn:substring-before(xs:string($startMonth),"T")
              let $edate := fn:substring-before(xs:string($endMonth),"T") :)
              let $sdate := fn:replace(xs:string($startMonth),"T"," ")
              let $edate := fn:replace(xs:string($endMonth),"T"," " ) 
              let $sqlStmt := fn:replace($sqlStmt,"SDATE",$sdate)
              let $sqlStmt := fn:replace($sqlStmt,"EDATE",$edate)
              return
                $sqlStmt

       let $outputfile := fn:replace($outputfile,".sql",fn:concat($month,".sql"))
       let $addBegin := file:write-text($outputfile,"<RECORDS>","UTF-8")
       let $url := "jdbc:oracle:thin:kangurum/planetuc9@212.12.132.211:1521/kangpdb.sanalmarket.com.tr"
       (: let $url := "jdbc:oracle:thin:kangurum/ferhatpasa@212.12.132.196:1521/kngdb"    :)
       (: let $url := "jdbc:oracle:thin:kangurum/planetuc9@195.87.90.150:1522/KANGTEST"   :)

       let $conn  := sql:connect($url)
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
         ($list,file:append-text($outputfile,"</RECORDS>","UTF-8"),$sqlStmt)

