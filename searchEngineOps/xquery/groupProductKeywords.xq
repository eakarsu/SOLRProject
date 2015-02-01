let $prodMap :=
map:new(
  for $rec in fn:doc("CoreProductInfo")//record
      let $pid := $rec/PRODUCT_ID/text()
      let $pmn := $rec/PRODUCT_MODEL_NAME/text()
      return
          map:entry($pid,$pmn))

let $list :=
   for $recordGrp at $k in fn:doc("CSstreamClickInfoMap")//doc
     let $pid := $recordGrp/ProductID/text()
     group by $pid
     return
           let $keyList := fn:distinct-values($recordGrp/Keyword/text())
           let $keyList :=
                  for $k in $keyList
                      let $count := fn:count(($recordGrp/Keyword)[. eq $k])
                      order by $count descending
                      return <Keyword><key>{$k}</key><count>{$count}</count></Keyword>
           let $s := 
               <doc>
                        <ProductID>{$pid}</ProductID>
                        <ProductModelName>{map:get($prodMap,$pid)}</ProductModelName>
                        
                            
                        {for $k in 1 to 10
		           return $keyList[$k]
                        }
			 <IsClickedTrue> {fn:count(($recordGrp/IsClicked)[. eq "true"])}</IsClickedTrue>
                        <IsClickedFalse> {fn:count(($recordGrp/IsClicked)[. eq "false"])}</IsClickedFalse>
                 </doc>
              return $s

return $list

