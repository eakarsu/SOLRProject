let $priceMap :=
          map:new(
          for $psiRecord in fn:doc("PSI_All")//record
                    let $pid := $psiRecord/PRODUCT_ID/text()
                    let $psi := $psiRecord/PRODUCT_SALES_INFO_ID/text()
                    return
                      map:entry($psi,$pid))



 let $list :=
     for $record in fn:doc("CSstreamClickInfo")//Clicked
                 let $pids := 
                   for $psi in $record//clickedPsi/text()
                     let $pid := if ($psi ne "" ) then map:get($priceMap,$psi) else ""
                     return
                        <PRODUCT_ID psi="{$psi}">{$pid}</PRODUCT_ID>
                 return   
                   file:append("/oraexport/searchEngineOps/clicks.xml",   
                   <record>
                     {$record/*[fn:name() ne "clickedPsi"]}{$pids}
                   </record>)
  return $list

