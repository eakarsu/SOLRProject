(:let $outfile := "/oraexport/searchEngineOps/SQLExtracts/clicksCountForSOLR.xml"
let $res1 := file:append-text($outfile,"<RECORDS>")
let $list :=
     for $pidrec in fn:doc("CSstreamClickInfoPidEnhanced")//PRODUCT_ID
                 let $pid := $pidrec/text()
                 let $clickFlag := $pidrec/../IsClicked/text()
                 where $clickFlag eq "true"
                 group by $pid
                 return
                   let $clickCount := fn:count($pidrec)
                   return
                   file:append($outfile,
                    <ProductClick pid="{$pid}" clickCount="{$clickCount}"></ProductClick>
                   )
let $res2 := file:append-text($outfile,"</RECORDS>")
return ($list,$res1,$res2)
:)
let $outfile := "/oraexport/searchEngineOps/SQLExtracts/clicksCountForSOLR.xml"
let $res1 := file:append-text($outfile,"<RECORDS>")
let $list :=
     for $pidrec in fn:doc("CSstreamClickInfoPidEnhanced")//record
                 let $clickFlag := $pidrec/IsClicked/text()
                 where $clickFlag eq "true"
                 return     
                   for $pid in $pidrec/PRODUCT_ID
                   return          
                     file:append($outfile,
                      $pid
                     )
let $res2 := file:append-text($outfile,"</RECORDS>")
return ($list,$res1,$res2)

