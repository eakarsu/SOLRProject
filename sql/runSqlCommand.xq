      declare variable $sqlfile as xs:string external;
      declare variable $outputfile as xs:string external;
      
      let $lines := file:read-text-lines ($sqlfile)
      let $lines := 
        for $line in $lines
          return
            fn:normalize-space($line)
      let $sqlStmt := fn:string-join($lines," ") 

       let $addBegin := file:append-text($outputfile,"<RECORDS>","UTF-8")
       let $url := "jdbc:oracle:thin:"
(:
       let $url := "jdbc:oracle:thin:"
:)
       let $conn  := sql:connect($url)
       let $list :=
          for $rec in sql:execute ($conn,$sqlStmt)
           let $is :=
             for $line in $rec/*
               return
                 element {fn:data($line/@name)} {$line/text()}
            return file:append( $outputfile, <record>{$is}</record>)

       return
         ($list,file:append-text($outputfile,"</RECORDS>","UTF-8"))
