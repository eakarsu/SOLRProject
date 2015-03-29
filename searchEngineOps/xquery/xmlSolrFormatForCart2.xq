(: This script products data to load into SOLR. The result file will be imported into XML DB called "CSstreamCartInfoMap" :)

let $outfile := "/tmp/addcart.xml"
let $res := file:write-text($outfile,"<add>")

let $list :=
    for $record at $k in fn:doc("CSstreamCartInfo")//AddedToCart
                 let $pids := $record/ProductID/text()
                 let $sids := $record/StoreID/text()
                 let $amounts := $record/Amount/text()
                 where fn:exists($pids)
                  return
                    let $list :=
                      for $pid at $j in $pids
                          let $amount := xs:string($amounts[$j])
                          let $sid := $sids[$j]
                          let $amount := if (fn:empty($amount)) then "0" else  $amount
                          let $amount := if (fn:matches($amount,"[A-Za-z]|'| |,")) then "0" else $amount
                          return
                             <doc>
			         <CStreamID>{$j + ($k * 300000)}</CStreamID>
				 <Keyword>{fn:normalize-space($record/Keyword/text())}</Keyword>
		                  <ProductID>{$pid}</ProductID>
               		          <Amount>{$amount}</Amount>
                		  <StoreID>{$sid}</StoreID>
              		         <CustomerID>{$record/CustomerID/text()}</CustomerID>
                             </doc>
                     return
                       file:append($outfile,$list)  

let $res2 := file:append-text($outfile,"</add>")

 return ($list,$res,$res2)


