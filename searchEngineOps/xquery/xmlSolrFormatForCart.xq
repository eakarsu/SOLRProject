let $outfile := "/tmp/addcart.xml"
let $res := file:write-text($outfile,"<add>")

let $list :=
    for $record in fn:doc("CSstreamCartInfo")//AddedToCart
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
                                 <field name="Keyword">{fn:normalize-space($record/Keyword/text())}</field>
                                 <field name="CustomerID">{$record/CustomerID/text()}</field>
                                 <field name="ProductID">{$pid}</field>
                                 <field name="StoreID">{$sid}</field>
                                 <field name="Amount">{$amount}</field>
                             </doc>
                     return
                       file:append($outfile,$list)  

let $res2 := file:append-text($outfile,"</add>")

 return ($list,$res,$res2)


