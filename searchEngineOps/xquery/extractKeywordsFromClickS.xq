let $prodMap :=
map:merge(
  for $rec in fn:doc("CoreProductInfo")//record
      let $pid := $rec/PRODUCT_ID/text()
      let $pmn := $rec/PRODUCT_MODEL_NAME/text()
      return
          map:entry($pid,$pmn))
          
let $list :=
  for $record in fn:doc("purchaseStats")//AddedToCart
                     let $pid := $record/ProductID/text()
                     where $pid ne "" and fn:not(fn:empty($pid))
                     group by $pid
                     return
                       let $allList := 
                         for $k in $record/Keyword
                             return fn:lower-case($k/text())                           
                       let $uniqList := fn:distinct-values($allList)
                             
                       let $keywords :=
                         for $k in $uniqList
                           let $cnt := fn:count(fn:index-of($allList,$k))
                           order by $cnt descending
                           (:where $cnt > 3 :)
                           return
                             <Keyword value="{$k}">{$cnt}</Keyword>
                       return 
                         if (fn:exists ($keywords)) then
                         <record>
                            <ProductID>{$pid}</ProductID>
                            <ProductModelName>{map:get($prodMap,$pid)}</ProductModelName>
                            {$keywords}
                         </record>
			else ()
 
                            (: {$keywords[fn:position() < 10]} :)
 return <add>{$list}</add>

