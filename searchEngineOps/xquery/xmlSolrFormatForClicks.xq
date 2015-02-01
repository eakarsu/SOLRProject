let $outfile := "/tmp/clicks.xml"
let $res := file:write-text($outfile,"<add>")
let $priceMap :=
          map:new(
          for $psiRecord in fn:doc("PSI_All")//record
                    let $pid := $psiRecord/PRODUCT_ID/text()
                    let $psi := $psiRecord/PRODUCT_SALES_INFO_ID/text()
                    return
                      map:entry($psi,$pid))

let $c := 4242893
 let $list :=
   for $record at $k in fn:doc("CSstreamClickInfo")//Clicked
                 let $clickedPsi := $record/clickedPsi/text()
                
                 let $pidRecs :=
                   for $psi at $j in $clickedPsi
                     let $pid :=  if ($psi ne "" ) then map:get($priceMap,$psi) else ""
                     where $pid ne "" and fn:not(fn:contains($psi,","))
                     return
                       <doc>
                         <field name="Keyword">{fn:normalize-space($record/Keyword/text())}</field>
                         <field name="IsClicked">{$record/IsClicked/text()}</field>
                         <field name="CustomerID">{$record/CustomerID/text()}</field>
                         <field name="PSIID">{$psi}</field>
                         <field name="ProductID">{$pid}</field>
                       </doc>
                      

                 return
                   file:append($outfile,$pidRecs)
                  

let $res2 := file:append-text($outfile,"</add>")

 return ($list,$res,$res2)

