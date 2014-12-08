declare namespace urlDecoder = "java.net.URLDecoder";

let $fn := "c:/tmp/clickstream.xml"
let $addBegin := file:append-text($fn,"<RECORDS>","UTF-8")
         
let $doc := fn:doc("D:\Migros\istanbul\clickstreamIstanbul1.xml")
let $list :=
  for $rec in ($doc//record)
    let $ts := $rec/TIME_STAMP/text()
    let $ts := fn:replace($ts," ","T")
    let $timeStamp := xs:dateTime($ts)
    let $us := $rec/QUERY_STRING/text()
    let $us := fn:replace($us,"%100","%25100")
    let $us := fn:replace($us,"%10","%0A")
    let $us := fn:replace($us,"%%20","%20")
    let $urlStr := if (fn:empty($us)) then $us else urlDecoder:decode(xs:string($us),"UTF-8")        
      
    order by $timeStamp
    return
      file:append( $fn,
      <record>
        {$rec/*[fn:name() ne "TIME_STAMP" or fn:name() ne "QUERY_STRING"]}
        <TIME_STAMP>{$timeStamp}</TIME_STAMP>
        <QUERY_STRING>{$urlStr}</QUERY_STRING>
      </record>)
    

return ($list,file:append-text($fn,"</RECORDS>","UTF-8"))