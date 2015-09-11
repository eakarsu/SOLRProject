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

 let $now := fn:current-dateTime()
              let $localTimeZone := fn:timezone-from-dateTime($now)
              let $fileUpdateDate := file:last-modified($contextFile)
              let $realFileUpdateDate := fn:adjust-dateTime-to-timezone($fileUpdateDate,$localTimeZone)
              let $sDate := fn:replace(fn:replace(xs:string($realFileUpdateDate),"T"," "),"(\.|\+).*$","")
              let $eDate := fn:replace(fn:replace(xs:string($now),"T"," "),"(\.|\+).*$","")
              let $sqlStmt := fn:replace($sqlStmt,"SDATE",$sDate)
              let $sqlStmt := fn:replace($sqlStmt,"EDATE",$eDate)
              (: temporary code here. Pelase delete this one late:)
              let $sqlStmt := fn:replace($sqlStmt,"2015","2014")
              return $sqlStmt
