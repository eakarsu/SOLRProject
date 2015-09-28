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

       return $sqlStmt
