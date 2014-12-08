
let $stats := map:new(
  for $record in fn:doc("Customers")//record
                let $amounts := $record/AMOUNT/text()
                let $orderCounts := $record/ORDER_COUNT/text()
                let $seg := $record/SEGMENT_ID/text()
                group by $seg
                  return
                    let $pairs:=
                      for $pRec in $record
                        let $pid := $pRec/PRODUCT_ID/text()
                        group by $pid
                        return
                          let $segAmount := sum($pRec/AMOUNT/text())
                          let $segOrderCount := sum($pRec/ORDER_COUNT/text())
                          return
                            <pair><a>{$segAmount}</a><oc>{$segOrderCount}</oc></pair>
  
                    let $amountMax := fn:max($pairs//a/text())
                    let $amountMin := fn:min($pairs//a/text())
                    let $orderCountMax := fn:max($pairs//oc/text())
                    let $orderCountMin := fn:min($pairs//oc/text())
                    return
                      map:entry($seg,
                      <segment seg="{$seg}">
                        <AmountMax>{$amountMax}</AmountMax>
                        <AmountMin>{$amountMin}</AmountMin>
                        <OrderCountMax>{$orderCountMax}</OrderCountMax>
                        <OrderCountMin>{$orderCountMin}</OrderCountMin>
                      </segment>))

let $l :=
  for $key in map:keys($stats) 
    return file:append("c:/tmp/seg.xml",  map:get($stats,$key)) 
                
let $segMap :=
 map:new( 
  for $record in fn:doc("Customers")//record
                let $pid := $record/PRODUCT_ID/text()
                group by $pid
                  return
                    let $segInfo :=
                      for $segrec in $record
                         let $sid := $segrec/SEGMENT_ID/text()
                         group by $sid
                         return
                           let $st := map:get($stats,$sid)
                           let $disA := ($st/AmountMax/text() - $st/AmountMin/text()) div 10.0
                           let $disOC := ($st/OrderCountMax/text()  - $st/OrderCountMin/text()) div 10.0
                           let $segAmount := sum($segrec/AMOUNT/text())
                           let $segOrderCount := sum($segrec/ORDER_COUNT/text())
                           let $segAmountGrade := fn:floor($segAmount div $disA)
                           let $segOrderCountGrade := fn:floor($segOrderCount div $disOC)
                           return
                               <segment seg="{$sid}">
                                 <field name="SegAmount_{$sid}">{$segAmount}</field>
                                 <field name="SegOrderCount_{$sid}">{$segOrderCount}</field>
                                 <field name="SegAmountGrade_{$sid}">{$segAmountGrade}</field>
                                 <field name="SegOrderCountGrade_{$sid}">{$segOrderCountGrade}</field>
                              </segment>
                    return
                    map:entry($pid,$segInfo/*))
                      


return ($l,map:get($segMap,"178577"))