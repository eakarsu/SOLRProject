
let $priceMap :=
          map:merge(
          for tumbling window $psiRecordGroup in fn:doc("PSI_stock_info")//record
                  start $first next $second when $first/PRODUCT_ID eq $second/PRODUCT_ID
                  end $last next $beyond when $last/PRODUCT_ID ne $beyond/PRODUCT_ID
                    let $pid := $psiRecordGroup[1]/PRODUCT_ID/text()
                    return
                      map:entry($pid,$psiRecordGroup))

 let $list :=
   for $record at $i in fn:doc("KANGURUMCSstreamClickInfo")//Clicked
                 let $psiAll := $record/clickedPsi/text()
                 return
                   if (fn:empty($psiAll)) then ()
                   else
                       for $psi at $j in $psiAll
                         let $psiRec := map:get($priceMap,$psi) 
                         let $pid := if (fn:exists($psiRec)) then $psiRec[1]/PRODUCT_ID/text() else ""
                         (:where $pid ne "" and fn:not(fn:contains($psi,",")) :)
			 where fn:exists($record/Keyword/text())
                         return
                           <doc>
			       <field name="CStreamID">{$i * 100 + $j}</field>
                               <field name="Keyword">{$record/Keyword/text()}</field>
                               <field name="IsClicked">{$record/IsClicked/text()}</field>
                               <field name="CustomerID">{$record/CustomerID/text()}</field>
                               <field name="PSIID">{$psi}</field>
                               <field name="ProductID">{$pid}</field>
                           </doc>

 return <add>{$list}</add>

