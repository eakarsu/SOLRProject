(: This script products data to load into SOLR. The result file will be imported into XML DB called "CSstreamClickInfoMap" :)
let $priceMap :=
          map:merge(
          for $psiRecord in fn:doc("PSI_All")//record
                    let $pid := $psiRecord/PRODUCT_ID/text()
                    let $psi := $psiRecord/PRODUCT_SALES_INFO_ID/text()
                    return
                      map:entry($psi,$pid))
let $c := 0
let $outfile := "/tmp/clicks.xml"
let $res := file:write-text($outfile,"<add>")

let $list :=
   for $record at $k in (fn:doc("CSstreamClickInfo")//Clicked)[fn:position() ge $c]
                 let $clickedPsi := $record/clickedPsi/text()
		 let $keyword := $record/Keyword/text()               
                 let $pidRecs :=
                   for $psi at $j in $clickedPsi
                     let $pid :=  if ($psi ne "" ) then map:get($priceMap,$psi) else ""
                     where $pid ne "" and fn:not(fn:contains($psi,",")) and fn:exists($keyword) and $keyword ne ""
                     return
                       <doc>
			          <Counter>{$k + $j + $c}</Counter>
                                  <CStreamID>{$j + (300000 * $k) + $c}</CStreamID>
                                  <Keyword>{fn:normalize-space($record/Keyword/text())}</Keyword>
				  <IsClicked>{$record/IsClicked/text()}</IsClicked>
				  <CustomerID>{$record/CustomerID/text()}</CustomerID>
				  <PSIID>{$psi}</PSIID>
                  		  <ProductID>{$pid}</ProductID>
                       </doc>
                      
		return
                     file:append($outfile, $pidRecs)
                  

let $res2 := file:append-text($outfile,"</add>")

 return ($list,$res,$res2)

