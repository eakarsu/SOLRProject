
let $priceMap := 
          map:new(
          for tumbling window $psiRecordGroup in fn:doc("PSI")//record 
                  start $first next $second when $first/PRODUCT_ID eq $second/PRODUCT_ID
                  end $last next $beyond when $last/PRODUCT_ID ne $beyond/PRODUCT_ID
                    let $pid := $psiRecordGroup[1]/PRODUCT_ID/text()
                    return
                      map:entry($pid,$psiRecordGroup))
 
 let $list :=
   for $record in fn:doc("CSstreamClickInfo")//Clicked
                 let $psi := $record/clickedPsi/text()
                 let $psiRec := map:get($priceMap,$psi)
                 let $pid := if (fn:exists($psiRec)) then $psiRec[1]/PRODUCT_ID/text() else ""
                 (:where $pid ne "" and fn:not(fn:contains($psi,",")) :)
                 return
                   <doc>
                       <field name="Keyword">{$record/Keyword/text()}</field>
                       <field name="IsClicked">{$record/IsClicked/text()}</field>
                       <field name="CustomerID">{$record/CustomerID/text()}</field>
                       <field name="PSIID">{$psi}</field>
                       <field name="ProductID">{$pid}</field>
                   </doc>
 
 return <add>{$list}</add>
                          
 
  
