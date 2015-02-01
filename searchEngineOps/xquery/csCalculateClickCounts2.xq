let $outfile := "/oraexport/searchEngineOps/SQLExtracts/clicksCountForSOLRFormatted2.xml"
let $infile := "/oraexport/searchEngineOps/SQLExtracts/clicksCountForSOLRFormatted.xml"
let $res1 := file:append-text($outfile,"<RECORDS>")
let $list :=
     for $pidrec in fn:doc($infile)//PRODUCT_ID
                 let $pid := $pidrec/text()
                 group by $pid
                 return
                   let $clickCount := fn:count($pidrec)
                   return
                   file:append($outfile,
                    <ProductClick pid="{$pid}" clickCount="{$clickCount}"></ProductClick>
                   )
let $res2 := file:append-text($outfile,"</RECORDS>")
return ($list,$res1,$res2)
