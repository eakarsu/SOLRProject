declare namespace matchRes = "java.util.regex.MatchResult";
declare namespace matcher = "java.util.regex.Matcher";
declare namespace pattern = "java.util.regex.Pattern";
declare namespace string = "java.lang.String";
declare namespace random = "java.util.Random";

declare function local:convertUnit ($uval as xs:string, $usymbol as xs:string) as xs:string
{
   let $mult := if ($usymbol eq "L" or $usymbol eq "LT") then 1000 
                else if (fn:matches($usymbol,"KG")) then 1000
                else if ($usymbol eq "M") then 100
                else if ($usymbol eq "MM") then 0.1
                else 1
   let $val := xs:string(xs:float($uval) * xs:float($mult))
   return $val
   
};

declare function local:splitUnits ($uval as xs:string) as item()*
{
  let $rexpr1 := "[0-9]+[\\.\\,]?[0-9]*[ ]?"
  let $rexpr2 := "(KG|GR|ML|CM|ADET|adet|kg|dk|DK|LT|CC|Watt|WATT|LU|L|cm|gr|G|V|VOLT|Volt|Mps|MM|mm|MP|m|M)"
  let $fullrexpr := fn:concat($rexpr1,$rexpr2)
   
  
  let $p1 := pattern:compile($rexpr1)
  let $p2 := pattern:compile($rexpr2)
  let $p3 := pattern:compile($fullrexpr)
  
  let $matcher1 := pattern:matcher($p3,$uval)
  let $b := matcher:find($matcher1)
  return
    if (fn:not($b)) then ()
    else
      let $unitexpr := matcher:group($matcher1)
      
      let $matcher2 := pattern:matcher($p1,$unitexpr)
      let $b := matcher:find($matcher2)
      let $unitval := matcher:group($matcher2)
      let $unitval := fn:normalize-space($unitval)
      let $unitval := fn:replace($unitval,",",".")
      
      let $matcher3 := pattern:matcher($p2,$unitexpr)
      let $b := matcher:find($matcher3)
      let $unitSymbol := matcher:group($matcher3)
      let $unitSymbol := fn:upper-case(fn:normalize-space($unitSymbol))
      let $unitSymbol := if ($unitSymbol eq "LU") then "ADET" else $unitSymbol
      
      let $unitval := local:convertUnit($unitval,$unitSymbol)
      
      return ($unitexpr,$unitval,$unitSymbol)
};
 
declare function local:transTurkishChars ($fieldName,$sentence as xs:string*) as element()*
{
    let $turkishChars2 := "ç|Ç|ğ|Ğ|ı|İ|ö|Ö|ş|Ş|ü|Ü"
    let $turkishChars := "çÇğĞıİöÖşŞüÜ"
    let $englishChars := "cCgGiIoOsSuU"
    let $sepChars := "\s+|;|:|,|\t|\(|\)|\[|\]|\{|\}"
    let $tokens := fn:tokenize($sentence,$sepChars)
    let $newTokens :=
      for $token in $tokens   
        let $isTurkishCharIncluded := fn:matches($token,$turkishChars2)
        let $res  := if ($isTurkishCharIncluded) then fn:translate ($token,$turkishChars,$englishChars) else ()
        where ($isTurkishCharIncluded)
        return $res 
    let $newTokensMerged := fn:string-join($newTokens," ")
    let $newFieldName := fn:concat($fieldName,"_TR")
    return 
      if (fn:not(fn:empty($newTokens)) ) 
      then 
        element field {
            attribute name {$newFieldName},
            text {$newTokensMerged}
          } 
      else ()
           
};

declare function local:getSegmentInfo () as map(*)
{
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
  
  (:let $l :=
    for $key in map:keys($stats) 
      return file:append("c:/tmp/seg.xml",  map:get($stats,$key)) :)
                  
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
                             let $segAmountGrade := fn:ceiling($segAmount div $disA)
                             let $segOrderCountGrade := fn:ceiling($segOrderCount div $disOC)
                             return
                                 <segment seg="{$sid}">
                                   <field name="SegAmount_{$sid}">{$segAmount}</field>
                                   <field name="SegOrderCount_{$sid}">{$segOrderCount}</field>
                                   <field name="SegAmountGrade_{$sid}">{$segAmountGrade}</field>
                                   <field name="SegOrderCountGrade_{$sid}">{$segOrderCountGrade}</field>
                                </segment>
                      return
                      map:entry($pid,$segInfo/*))
  return $segMap
  
};

declare function local:getClicksMap () as map(*)
{
    let $clickList :=   
        for $record in fn:doc("ClickStreamNewAlgorithm")//Clicked
             let $psis := fn:tokenize($record/clickedPsi/text()," ")
             let $rl :=
               for $p in $psis
                 return
                   <Clicked>
                     <clickedPsi>{$p}</clickedPsi>
                     {$record/*[fn:name() ne "clickedPsi"]}
                   </Clicked>
              return $rl
                   
      let $mapClicks :=
      map:new(for $record in $clickList
                 let $psi := $record/clickedPsi/text()
                 where $record/IsClicked eq "true"
                 group by $psi
                 return map:entry($psi,fn:count($record)))
                 
      return $mapClicks
};
                                                          
declare function local:getCRMSegmentMap () as map(*)
{
  let $segments := ("Aburcubur","Çay_Kahve","İçecek","Karma_Az","Meyve_Sebze","Saç_Bakım","Süt_Su-Maden","Taze_Tüketim","Temizlik")
  let $segMap :=
      map:new(
        for $record in fn:doc("ProdCRMExport")//record
          let $pid := $record/PRODUCT_ID 
          group by $pid
          return 
            let $totalAmount := sum($record//AMOUNT/text())
            let $totalOrderCount := sum($record//ORDER_COUNT)
            let $sumSolrFields := (<field name="Amount">{$totalAmount}</field>,
                                 <field name="OrderCount">{$totalOrderCount}</field>)
            let $solrFields :=
              for $r in $record
                let $sid := $r/SON_SEGMENT/text()
                let $sid := fn:concat("10",fn:index-of($segments,$sid))
                let $segAmount := $r/AMOUNT/text()
                let $segOrderCount := $r/ORDER_COUNT/text()
                let $solrField := (<field name="SegAmount_{$sid}">{$segAmount}</field>,
                                    <field name="SegOrderCount_{$sid}">{$segOrderCount}</field>)
                return $solrField
           return
             map:entry($pid,($solrFields,$sumSolrFields)
        )
    
        )
   
   return $segMap
};

declare function local:getCustMap () as map(*)
{
  let $rnd := random:new()
  let $productStatistics :=
      map:new(for $record in fn:doc("Customers")//record
         let $pid := $record/PRODUCT_ID
         group by $pid       
            return
             let $numberOfClicks := random:nextInt($rnd,xs:int(100))
             let $amount := fn:sum($record/AMOUNT)
             let $orderCount := fn:sum($record/ORDER_COUNT)
             return
               map:entry($pid,
                  <block>
                    <PRODUCT_ID>{$pid}</PRODUCT_ID> 
                    <Amount>{$amount}</Amount>
                    <OrderCount>{$orderCount}</OrderCount>
                    <NumberOfClicks>{$numberOfClicks}</NumberOfClicks>
                  </block>))
  return $productStatistics
};

declare function local:enhanceCustMap ($inProductStatistics as map(*)) as map(*)
{
      let $rnd := random:new()
      let $productStatistics := 
        map:new(
          for $record in fn:doc("Products")//record
              let $pid := $record/*[fn:name() eq "PRODUCT_ID"]/text()
              group by $pid
              return
                let $val := map:get($inProductStatistics,$pid)
                return
                  if (fn:empty($val)) then
                     let $amount :=  random:nextFloat($rnd) * 10000
                     let $orderCount := random:nextInt($rnd,xs:int(200)) 
                     let $numberOfClicks := random:nextInt($rnd,xs:int(100))
                     return
                       map:entry($pid,
                        <block>
                            <PRODUCT_ID>{$pid}</PRODUCT_ID> 
                            <Amount>{$amount}</Amount>
                            <OrderCount>{$orderCount}</OrderCount>
                            <NumberOfClicks>{$numberOfClicks}</NumberOfClicks>
                         </block>)
                  else map:entry($pid,$val)) 
      return $productStatistics
}; 

declare function local:getDeltaVals ($custMap as map(*)) as item()*
{
       let $allStats := for $key in map:keys($custMap) 
                            return map:get($custMap,$key)
      let $minAmount := fn:min($allStats//Amount)
      let $maxAmount := fn:max($allStats//Amount)
      let $minOrderCount := fn:min($allStats//OrderCount)
      let $maxOrderCount := fn:max($allStats//OrderCount)
      let $minNumberOfClicks := fn:min($allStats//NumberOfClicks)
      let $maxNumberOfClicks := fn:max($allStats//NumberOfClicks)
      let $disAmount := ($maxAmount - $minAmount) div 10.0
      let $disOrderCount := ($maxOrderCount  - $minOrderCount) div 10.0
      let $disNumberOfClicks := ($maxNumberOfClicks - $minNumberOfClicks) div 10.0
      
      let $disAmount := if ($disAmount = 0) then $maxAmount else $disAmount
      let $disOrderCount := if ($disOrderCount = 0) then $maxOrderCount else $disOrderCount
      let $disNumberOfClicks := if ($disNumberOfClicks = 0) then $maxNumberOfClicks else $disNumberOfClicks
      
      return ($disAmount,$disOrderCount,$disNumberOfClicks)
};
  

let $rnd := random:new()
let $root := "C:/tmp/"
let $text := file:read-text(fn:concat($root,"ProductModelDetails.csv"),"UTF-8") 
let $options := { 'lax': 'no' }
let $modelDetails := csv:parse($text, $options) 

let $mapBrands :=
  map:new(for $record in fn:doc("Brands")//record
             return map:entry($record/BRAND_ID/text(),$record/NAME/text()))
             
let $mapFeatures :=
  map:new(for $record in fn:doc("Features")//record
             return map:entry($record/PRODUCT_MODEL_ID/text(),$record/FEATURE_VALUE/text()))
             
let $mapFavorites :=
  map:new(for $record in fn:doc("Favorites")//record
             return map:entry($record/PRODUCT_MODEL_ID/text(),$record/CUSTOMER_ID/text()))
            
let $mapProperties :=
  map:new(for $record in fn:doc("Properties")//record
             return map:entry($record/PRODUCT_MODEL_ID/text(),$record/PROPERTY_NAME/text()))

let $mapCustomers :=
  map:new(for $record in fn:doc("Customers")//record
                let $pid := $record/PRODUCT_ID
                let $cid := $record/CUSTOMER_ID
                group by $pid
                return map:entry($pid,<block>{$cid}</block>))
 
                                       
(: temporary. get paths from test:)
let $pathsmap :=
  map:new(for $record in fn:doc("Paths")//record
                let $pid := $record/PRODUCT_MODEL_ID
                let $path := $record/Path/text()
                group by $pid
                return map:entry($pid,$path))
                                                       
let $mapMD :=
  map:new(for $record in $modelDetails//record
             return map:entry(($record/entry)[1]/text(), ($record/entry)[2]/text()))

let $segMap := local:getCRMSegmentMap ()
let $clickMap := local:getClicksMap ()
let $outfile := fn:concat($root,"solrinputIstanbul.xml")
let $addBegin := file:append-text($outfile,"<add>","UTF-8")
       
let $prods := 
  for $record in fn:doc("Products")//record
    let $prodModID := $record/*[fn:name() eq "PRODUCT_MODEL_ID"]/text()
    let $pid := $record/*[fn:name() eq "PRODUCT_ID"]/text()
    let $pDetail :=  <field name="ProductMoreDetail">{map:get($mapMD,$prodModID)}</field> 
    let $pmid :=  <field name="ProductModelID">{$record/*[fn:name() eq "PRODUCT_MODEL_ID"]/text()}</field>
    let $pmn :=    <field name="ProductModelName">{$record/*[fn:name() eq "PRODUCT_MODEL_NAME"]/text()}</field>
    let $desc := <field name="Description"> {$record/*[fn:name() eq "DESCRIPTION"]/text()}</field>
    let $shopCode :=    $record/*[fn:name() eq "SHOP_CODE"]/text()
    let $shopID :=   $record/*[fn:name() eq "SHOP_ID"]/text()
    let $storeID :=$record/*[fn:name() eq "STORE_ID"]/text()
    let $keyword :=    $record/*[fn:name() eq "SEARCH_KEYWORD_VALUE"]/text()
    let $categoryID :=    $record/*[fn:name() eq "CATEGORY_ID"]/text()
    let $boost :=   $record/*[fn:name() eq "SEARCH_BOOST"]/text()
    let $price :=    $record/*[fn:name() eq "PRICE"]/text()
    let $actionPrice :=    $record/*[fn:name() eq "ACTION_PRICE"]/text()
    let $mccPrice :=   $record/*[fn:name() eq "MCC_PRICE"]/text()
    let $promotionType :=    $record/*[fn:name() eq "PROMOTION_TYPE"]/text()
    let $path := $record/*[fn:name() eq "Path"]/text() 
    let $isMigroskop :=  $record/*[fn:name() eq "IS_MIGROSKOP"]/text()
    let $brandID :=  $record/*[fn:name() eq "BRAND_ID"]/text()
    let $psiId := $record/*[fn:name() eq "PRODUCT_SALES_INFO_ID"]/text()
     
    group by $pid
    let $nclicks := for $r in $psiId 
                        return map:get($clickMap,$r)
    let $nclicks := if (fn:empty($nclicks)) then () 
                    else <field name="NumberOfClicks">{sum($nclicks)}</field> 
    let $segData := map:get($segMap,$pid)    
    let $setData := if (fn:empty($segData)) then ()
                    else $segData
    
    return file:append($outfile,
      <doc>  
          {$segData }
          {$nclicks}
         <field name="IsMigroskop">{$isMigroskop[1]}</field>
         <field name="ProductID">{$pid}</field>
         {$pDetail[1]}
         {local:transTurkishChars("ProductMoreDetail",$pDetail[1]/text())}
         {$pmid[1]}
         {$pmn[1]}
         {local:transTurkishChars("ProductModelName",$pmn[1]/text())}
         {$desc[1]}
         {local:transTurkishChars("Description",$desc[1]/text())}
  
         {
          let $utriple := local:splitUnits($pmn[1])
          return
            if (fn:empty($utriple)) then ()
                    else
                      (<field name="UnitExpr">{$utriple[1]}</field>,
                      <field name="UnitVal">{$utriple[2]}</field>,
                      <field name="UnitSymbol">{$utriple[3]}</field>
                    )
          }
         
         {for $r in map:get($mapFeatures,$pmid[1])
           return
            (<field name="ProductFeatures">{$r}</field>,
              local:transTurkishChars("ProductFeatures",$r))
         }
         {for $r in fn:distinct-values($shopCode)
           return
            <field name="ShopCode">{$r}</field>
         }
          {for $r in fn:distinct-values($shopID)
           return
            <field name="ShopID">{$r}</field>
         }
         
          {for $r in fn:distinct-values($keyword)
           return
            (<field name="SearchKeywordValue">{$r}</field>,
              local:transTurkishChars("SearchKeywordValue",$r))
         }
          {for $r in fn:distinct-values($categoryID)
           return
            <field name="CategoryID">{$r}</field>
         }
          {for $r in fn:distinct-values($boost)
           return
            <field name="SearchBoost">{$r}</field>
         }
           
         {for $r at $k in fn:distinct-values($storeID)
           let $inPromotion := $isMigroskop[$k] eq "1" and 
                               (($mccPrice[$k] < $price[$k] and $mccPrice[$k]> 0.0) or
                                ($actionPrice[$k] < $price[$k] and $actionPrice[$k]> 0.0))
           return
             (<field name="StoreID">{$r}</field>,
             <field name="Price_{$r}">{$price[$k]}</field>,
             <field name="Mcc_Price_{$r}">{$mccPrice[$k]}</field>,
             <field name="Action_Price_{$r}">{$actionPrice[$k]}</field>,
             <field name="InPromotion_{$r}">{$inPromotion}</field>
             )
           }
                       
          
          {for $r in  map:get($pathsmap,$pmid[1]) (: fn:distinct-values($path) :)
            let $ar := fn:tokenize($r,"\\")[fn:position() > 1]
            let $plen := fn:count($ar)
            let $pathLevels :=
              for $p at $j in $ar
                let $name := fn:concat("PathLevel",$plen - $j +1)
                return
                  <field name="{$name}" >{$p}</field>
            return
               ($pathLevels[fn:last() - 1],<field name="CategoryPath">{$r}</field>)
         }
          {for $r in map:get($mapCustomers,$pid[1])//CUSTOMER_ID/text()
           return
            <field name="CustomersPurchased">{$r}</field>
         }
         
          {for $r in map:get($mapFavorites,$pid[1])//PRODUCT_MODEL_ID/text()
           return
            <field name="Favorite">{$r}</field>
         }
         
          {for $r in map:get($mapProperties,$pid[1])//PRODUCT_MODEL_ID/text()
           return
            <field name="ProductProperty">{$r}</field>
         }
         {
           if (fn:not(fn:empty($brandID[1]))) then
             let $brandName := map:get($mapBrands,$brandID[1])
             return
               <field name="BrandName">{$brandName}</field>
           else ()
         }
         
      </doc>)  
      
let $addEnd := file:append-text($outfile,"</add>","UTF-8")      
  
return ($addBegin,$prods,$addEnd)
