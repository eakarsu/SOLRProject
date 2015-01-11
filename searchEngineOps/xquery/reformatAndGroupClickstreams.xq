declare namespace urlDecoder = "java.net.URLDecoder";
declare variable $inputDoc as xs:string external;
declare variable $outputDoc as xs:string external;
         
let $outDoc := fn:doc($outputDoc)//RECORDS
let $inDoc := fn:doc($inputDoc)

return
  for $rec in ($inDoc//record)
    let $cid := $rec/CUSTOMER_ID/text()
    let $ts := $rec/TIME_STAMP/text()
    let $ts := fn:replace($ts," ","T")

    let $timeStamp := xs:dateTime($ts)
    let $us := $rec/QUERY_STRING/text()
    let $us := fn:replace($us,"%100","%25100")
    let $us := fn:replace($us,"%10","%0A")
    let $us := fn:replace($us,"%%20","%20")
    let $urlStr := if (fn:empty($us)) then $us else 
    try{
      urlDecoder:decode(xs:string($us),"UTF-8")        
    }catch *{
      'Error [' || $err:code || ']: ' || $err:description || ':'||$us||':'||$ts
    }
    
    let $ru := $rec/REQUEST_URI
    let $qs := $urlStr
    let $path := fn:concat($ru,"/",$qs)
    
    order by $timeStamp
    group by $cid
    return
       insert node  
                  <session CustomerID="{$cid}">
                    {for $j in 1 to fn:count($path)
                      return
                      <httpRequest>{$path[$j]}</httpRequest>
                    } 
                  </session> into $outDoc
      
