
declare variable $coreProductInfo as xs:string external;
declare variable $previousKeywordsDoc as xs:string external;
declare variable $newKeywordsDoc as xs:string external;
declare variable $mergedKeywordDoc as xs:string external;

let $prodMap :=
map:merge(
  for $rec in fn:doc($coreProductInfo)//record
      let $pid := $rec/PRODUCT_ID/text()
      let $pmn := $rec/PRODUCT_MODEL_NAME/text()
      return
          map:entry($pid,$pmn))
          
let $prevKeyMap :=
  map:merge(
    for $rec in fn:doc($previousKeywordsDoc)//doc
        let $pid := $rec/str[@name eq "ProductID"]/text()
        let $keywords := $rec/arr[@name eq "SearchKeyword"]/str/text()
        let $keywords := 
               for $k in $keywords
                   return fn:lower-case($k) 
        return
            map:entry($pid,$keywords))
          
let $curKeyMap :=
  map:merge(for $record in fn:doc($newKeywordsDoc)//record
                     let $pid := $record/ProductID/text()
                     where $pid ne "" and fn:not(fn:empty($pid))
                     group by $pid
                     return
                       let $allList := 
                         for $k in $record/Keyword
                             return fn:lower-case($k/@value)                                   
                       return
                         map:entry($pid,$allList))
                       
let $allPids :=
   fn:distinct-values(
     for $a in (map:keys($prevKeyMap),map:keys($curKeyMap))
       return
         $a
       )

  
let $list :=
  for $pid in $allPids
            let $prevKeys := map:get($prevKeyMap,$pid)
            let $curKeys := map:get($curKeyMap,$pid) 
            let $allList :=  ($prevKeys,$curKeys)                       
            let $uniqList :=  
                    fn:distinct-values(
                        for $a in $allList
                           return $a)
                           
            let $keywords :=
                 for $k in $uniqList
                     let $cnt := fn:count(fn:index-of($allList,$k))
                     order by $cnt descending
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
                     

 return file:write($mergedKeywordDoc,
		  <add>{$list}</add>)
