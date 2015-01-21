declare namespace matchRes = "java.util.regex.MatchResult";
declare namespace matcher = "java.util.regex.Matcher";
declare namespace pattern = "java.util.regex.Pattern";
declare namespace string = "java.lang.String";
declare namespace random = "java.util.Random";
declare variable $action as xs:string external;

declare function local:convertUnit ($uval as xs:string, $usymbol as xs:string) as xs:string*
{
    let $mult := if (fn:matches($usymbol,"CC|ML")) then 0.001 
                else if ($usymbol eq "G" or $usymbol eq "GR") then 0.001
                else if ($usymbol eq "CM") then 0.01
                else if ($usymbol eq "MM") then 0.001
                else 1
     
    let $convSymb := if (fn:matches($usymbol,"CC|ML") or $usymbol eq "L") then "LT"
                else if ($usymbol eq "G" or $usymbol eq "GR")  then "KG"
                else if ($usymbol eq "WATT")  then "W"
                else if (fn:matches($usymbol,"CM|MM")) then "M"
                else $usymbol
                             
   let $newFal := xs:string(xs:float($uval) * xs:float($mult))
   return ($newFal,$convSymb)
   
};

declare function local:getTriple ($unitExpr as xs:string,$unitVal as xs:string,$unitSymbol as xs:string) as element()*
{
    let $one := (<field name="UnitExpr_{$unitSymbol}">{$unitExpr}</field>,
                 <field name="UnitVal_{$unitSymbol}">{$unitVal}</field>,
                 <field name="UnitSymbol_{$unitSymbol}">{$unitSymbol}</field>)
                                                    
    return $one                                              
};

declare function local:splitUnits ($uval as xs:string) as item()*
{
  let $adetExpr := "([0-9]+)[ ]*'?[ ]*(LU|LI|LÜ|Lİ)"
  let $rexpr1 := "([0-9]+X)?([0-9]+[\\.\\,]?[0-9]*[ ]?)"
  let $rexpr2 := "(KG|GR|ML|CM|ADET|adet|kg|dk|DK|LT|CC|Watt|WATT|L|cm|gr|G|V|W|VOLT|Volt|Mps|MM|mm|MP|m|M)($|[^A-ZçÇğĞıİöÖşŞüÜ])"
  let $sexpr := "(KG|GR|ML|CM|ADET|adet|kg|dk|DK|LT|CC|Watt|WATT|L|cm|gr|G|V|W|VOLT|Volt|Mps|MM|mm|MP|m|M)"
  let $fullrexpr := fn:concat($rexpr1,$rexpr2)
  
  let $unitSymbol := ""
  let $b := fn:matches($uval,$adetExpr)
  let $adetTriple := 
    if ($b) then
      let $ps := fn:analyze-string ($uval,$adetExpr)
      let $unitVal :=  fn:normalize-space($ps//fn:match[fn:last()]/fn:group[1]/text())
      let $unitVal := fn:replace($unitVal,",",".")
      return local:getTriple(fn:concat ($unitVal," ADET"),$unitVal,"ADET")
    else
      ()
   
  let $b := fn:matches($uval,$fullrexpr)
  let $otherExpr :=
    if ( $b ) then
      let $ps := fn:analyze-string ($uval,$fullrexpr)
      
      let $adetVal := $ps//fn:match[fn:last()]/fn:group[@nr eq "1"]/text()
      let $adetVal :=  fn:substring(fn:normalize-space($adetVal),1,fn:string-length($adetVal)-1)
      let $adetTuple := 
          if (fn:not(fn:empty($adetVal)) and $adetVal ne "") 
          then local:getTriple(fn:concat ($adetVal," ADET"),$adetVal,"ADET")
          else ()
          
      let $unitVal :=  fn:normalize-space($ps//fn:match[fn:last()]/fn:group[@nr eq "2"]/text())
      let $unitVal := fn:replace($unitVal,",",".")
      let $unitSymbol :=  $ps//fn:match[fn:last()]/fn:group[@nr eq "3"]/text()
      let $pair := local:convertUnit ($unitVal,$unitSymbol)
      let $unitVal := $pair[1]
      let $unitSymbol := fn:upper-case($pair[2])
      return (local:getTriple(fn:concat($unitVal," ",$unitSymbol),$unitVal,$unitSymbol),$adetTuple)
    else
      ()
  
  let $onlySymbExpr :=
    if (fn:empty($otherExpr) and fn:empty($adetTriple)) then
      let $ps := fn:analyze-string ($uval,fn:concat("[ ]+",$sexpr,"$"))
      let $unitSymbol := fn:normalize-space($ps//fn:match[fn:last()]/fn:group[@nr eq "1"]/text())
      let $unitSymbol := fn:upper-case($unitSymbol)
      let $pair := local:convertUnit ("9999",$unitSymbol)
      let $unitSymbol := $pair[2]
      return 
       if (fn:not(fn:empty($unitSymbol)) and $unitSymbol ne "") then
          local:getTriple($unitSymbol,"9999",$unitSymbol)
       else ()
    else ()
      
  return ($adetTriple, $otherExpr,$onlySymbExpr)
};

declare function local:splitUnitsOld ($uval as xs:string) as item()*
{
  let $adetExpr := "[0-9]+[ ]*'? [ ]*(LU|LI|LÜ|Lİ)"
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
      let $unitSymbol := if ($unitSymbol eq "G") then "GR" else $unitSymbol
      let $unitSymbol := if ($unitSymbol eq "L") then "LT" else $unitSymbol
      
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

declare function local:getAddCartMap () as map(*)
{
                let $mapAddCarts :=
           map:new(for $record in fn:doc("CSstreamCartInfo")//AddedToCart
                 let $pid := $record/ProductID/text()
		 where $pid ne "" and fn:not(fn:empty($pid))
                 group by $pid
                 return map:entry($pid,fn:count($record)))

      return $mapAddCarts
};

declare function local:getClicksMap () as map(*)
{
                let $mapClicks :=
           map:new(for $record in fn:doc("CSstreamClickInfo")//Clicked
                 let $psi := $record/clickedPsi/text()
                 where $record/IsClicked eq "true"
                 group by $psi
                 return map:entry($psi,fn:count($record)))

      return $mapClicks
};
                                                            
declare %updating function local:addCRMDataIntoProducts () 
{
     
     let $allProds := fn:doc("AccumulatedProducts")
     let $segments := ("Aburcubur","Çay_Kahve","İçecek","Karma_Az","Meyve_Sebze","Saç_Bakım","Süt_Su-Maden","Taze_Tüketim","Temizlik")
     let $productsMap :=
            map:new(
              for $rec in $allProds//doc
                  let $prodIDField := $rec/field[@name eq "ProductID"]
                  let $pid := $prodIDField/text()
                    return
                          map:entry($pid,$prodIDField))
                 
     for tumbling window $prodGroup in fn:doc("CRM")//record
          start $first next $second when $first/PRODUCT_ID eq $second/PRODUCT_ID
          end $last next $beyond when $last/PRODUCT_ID ne $beyond/PRODUCT_ID
   
          let $pid := $prodGroup[1]/PRODUCT_ID 
          return 
            let $prodEntry := map:get($productsMap,$pid)/..          
            return
              if (fn:empty($prodEntry))   then  ()
              else
                  let $totalAmount := sum($prodGroup//AMOUNT/text())
                  let $totalOrderCount := sum($prodGroup//ORDER_COUNT)
                  let $customers := 
                    for $cid in $prodGroup/CUSTOMER_ID/text()
                      return 
                        <field name="CustomersPurchased">{$cid}</field>
                  let $sumSolrFields := (<field name="Amount">{$totalAmount}</field>,
                                       <field name="OrderCount">{$totalOrderCount}</field>,
                                        $customers)
                  let $segData :=
                    for $segGroup in $prodGroup
                      let  $sid := $segGroup/SON_SEGMENT/text()
                      let $sid := fn:concat("10",fn:index-of($segments,$sid))
                      group by $sid
                      return
                        let $segAmount := sum($segGroup//AMOUNT/text())
                        let $segOrderCount := sum($segGroup//ORDER_COUNT)
                        let $segFields := (<field name="SegAmount_{$sid}">{$segAmount}</field>,
                                          <field name="SegOrderCount_{$sid}">{$segOrderCount}</field>)
                        return $segFields
                       
                 return
                   insert nodes ($segData,$sumSolrFields) as last into $prodEntry
                   
         (:,
         let $allAddedMap := map:new(
            for tumbling window $prodGroup in fn:doc("CRM")//record
                start $first next $second when $first/PRODUCT_ID eq $second/PRODUCT_ID
                end $last next $beyond when $last/PRODUCT_ID ne $beyond/PRODUCT_ID
                  return map:entry($prodGroup[1]/PRODUCT_ID/text(),"1"))
          
         let $allProds := fn:doc("AccumulatedProducts")
         for $pid in map:keys($productsMap)
            let $doc := map:get($allAddedMap,$pid)
            return
              if (fn:empty($doc)) 
              then 
                 insert node map:get($productsMap,$pid) into $allProds/add
              else () 
          :)
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
 
declare   %updating function local:addPriceDataIntoProducts ($shortProdMap as map(*),$clickMap as map(*)) 
{
   let $priceMap := 
          map:new(
          for tumbling window $psiRecordGroup in fn:doc("PSI_stock_info")//record
                  start $first next $second when $first/PRODUCT_ID eq $second/PRODUCT_ID
                  end $last next $beyond when $last/PRODUCT_ID ne $beyond/PRODUCT_ID
                    let $pid := $psiRecordGroup[1]/PRODUCT_ID/text()
                    return
                      map:entry($pid,$psiRecordGroup))
                      
  let $n := 500
  let $len := xs:int(fn:floor(map:size($priceMap) div $n))
    for $k in 0 to $len
      return
        local:addPriceDataIntoProductsExt ($shortProdMap,$clickMap,$priceMap,xs:int($k * $n), xs:int(($k + 1)*$n))
      
};

declare   %updating function local:addPriceDataIntoProductsExt ($shortProdMap as map(*),$clickMap as map(*),$priceMap as map(*),$start as xs:int, $end as xs:int) 
{
        let $prodStore := fn:doc("AccumulatedProducts")
        
       
        (: PSI is sorted based product_id. here we gett all psi data fro per product_id in $psiRecordGroup variable:)
  
        for $psiPid in (map:keys($priceMap))[fn:position() >= $start and fn:position() < $end]
              let $psiRecordGroup := map:get ($priceMap,$psiPid)

              let $psiIDs := $psiRecordGroup/PRODUCT_SALES_INFO_ID/text()
              (: Get core product info :)   
              let $prodRecord := map:get($shortProdMap,$psiPid)
              return
                if (fn:empty($prodRecord)) then ()
                else
                  let $stockModel := xs:int($prodRecord/STOCK_MODEL/text())
                  let $isMigroskop := $prodRecord/IS_MIGROSKOP/text()
                  let $priceTuples :=
                    for $psiID at $k in $psiIDs
                    
                      let $mccP := xs:float($psiRecordGroup[$k]/MCC_PRICE/text())
                      let $accP := xs:float($psiRecordGroup[$k]/ACTION_PRICE/text())
                      let $price :=  xs:float($psiRecordGroup[$k]/PRICE/text()) 
                      let $sAmount := $psiRecordGroup[$k]/STOCK_AMOUNT/text()
                      let $finalPrice := 
                          if ($mccP < $price and $mccP > 0) then $mccP
                          else if ($accP < $price and $accP > 0) then $accP
                          else $price
                      let $sid := $psiRecordGroup[$k]/STORE_ID/text()          
                     
                      let $inPromotion := $isMigroskop eq "1" or 
                                             (($mccP < $price and $mccP > 0.0) or
                                              ($accP < $price and $accP > 0.0))
                      let $isMCC := ($mccP < $price and $mccP> 0.0)
                     (:inStock:true| false based on for each store price ((pm.stock_model <> 1 AND psi.stock_amount > 0) OR  pm.stock_model = 1):)
                      let $inStock := if (($stockModel ne 1 and xs:float($sAmount) > 0) or $stockModel eq 1) then fn:true() else fn:false()
                      return  
                        (: 3 new fields here:)
                        (<field name="Price_{$sid}">{$finalPrice}</field>,
                         <field name="PSIID_{$sid}">{$psiID}</field>,
                         <field name="InStock_{$sid}">{$inStock}</field>,               
                         <field name="InPromotion_{$sid}">{$inPromotion}</field>,
                         <field name="IsMCCProduct_{$sid}">{$isMCC}</field>,
                         <field name="StoreID">{$sid}</field>)  
               
                      
                 let $nclicks := for $r in $psiIDs 
                                    return map:get($clickMap,$r)
                 let $nclicks := if (fn:empty($nclicks)) then () 
                                  else <field name="NumberOfClicks">{sum($nclicks)}</field> 
                                  
                 return
                 insert nodes  ($nclicks,$priceTuples) as first into $prodStore/add
                  (:  insert nodes  ($nclicks,$priceTuples) as first into $prodRecord :)
};
 
             
declare   %updating function local:addPriceDataIntoAccumulatedFile () 
{
        
        let $clickMap := local:getClicksMap ()
	let $addCartMap := local:getAddCartMap ()
        
        let $priceMap := 
          map:new(
          for tumbling window $psiRecordGroup in fn:doc("PSI_stock_info")//record (: test temporarily with "PSI_sorted. Change it to PSI_stock_info later":)
                  start $first next $second when $first/PRODUCT_ID eq $second/PRODUCT_ID
                  end $last next $beyond when $last/PRODUCT_ID ne $beyond/PRODUCT_ID
                    let $pid := $psiRecordGroup[1]/PRODUCT_ID/text()
                    return
                      map:entry($pid,$psiRecordGroup))
                      
        let $shortProdMap :=
            map:new(
              for $rec in fn:doc("CoreProductInfo")//record
                  let $pid := $rec/PRODUCT_ID/text()
                  let $exist := map:get($priceMap,$pid)    
                  where fn:exists($exist)
                    return
                          map:entry($pid,$rec))
                          
        let $accProdMap :=
            map:new(
              for $rec in fn:doc("AccumulatedProducts")//doc
                  let $pid := $rec/field[@name eq "ProductID"]/text()
                  group by $pid
                    return
                          map:entry($pid,$rec))
        
               
        for tumbling window $psiRecordGroup in fn:doc("PSI_stock_info")//record (: test temporarily with "PSI_sorted. Change it to PSI_stock_info later":)
                  start $first next $second when $first/PRODUCT_ID eq $second/PRODUCT_ID
                  end $last next $beyond when $last/PRODUCT_ID ne $beyond/PRODUCT_ID
                    let $psiPid := $psiRecordGroup[1]/PRODUCT_ID/text()
                    let $psiIDs := $psiRecordGroup/PRODUCT_SALES_INFO_ID/text()
                    (: Get core product info :)   
                    let $prodRecord := map:get($shortProdMap,$psiPid)
                    let $accRecord := map:get($accProdMap,$psiPid)
                    return
                      if (fn:empty($accRecord)) then ()
                      else                        
                        let $stockModel := xs:int($prodRecord/STOCK_MODEL/text())
                        let $isMigroskop := $prodRecord/IS_MIGROSKOP/text()
                        let $priceTuples :=
                          for $psiID at $k in $psiIDs
                          
                            let $mccP := xs:float($psiRecordGroup[$k]/MCC_PRICE/text())
                            let $accP := xs:float($psiRecordGroup[$k]/ACTION_PRICE/text())
                            let $price :=  xs:float($psiRecordGroup[$k]/PRICE/text()) 
                            let $sAmount := $psiRecordGroup[$k]/STOCK_AMOUNT/text()
                            let $finalPrice := 
                                if ($mccP < $price and $mccP > 0) then $mccP
                                else if ($accP < $price and $accP > 0) then $accP
                                else $price
                            let $sid := $psiRecordGroup[$k]/STORE_ID/text()          
                           
                            let $inPromotion := $isMigroskop eq "1" or 
                                                   (($mccP < $price and $mccP > 0.0) or
                                                    ($accP < $price and $accP > 0.0))
                            let $isMCC := ($mccP < $price and $mccP> 0.0)
                           (:inStock:true| false based on for each store price ((pm.stock_model <> 1 AND psi.stock_amount > 0) OR  pm.stock_model = 1):)
                            let $inStock := if (($stockModel ne 1 and xs:float($sAmount) > 0) or $stockModel eq 1) then fn:true() else fn:false()
                            return  
                              (: 3 new fields here:)
                              (<field name="Price_{$sid}">{$finalPrice}</field>,
                               if ($inStock) then (
                               <field name="PSIID_{$sid}">{$psiID}</field>,
                               <field name="InStock_{$sid}">{$inStock}</field>,               
                               <field name="InPromotion_{$sid}">{$inPromotion}</field>,
                               <field name="IsMCCProduct_{$sid}">{$isMCC}</field>) else (),
                               <field name="StoreID">{$sid}</field>)  
                     
                            
                       let $nclicks := for $r in $psiIDs 
                                          return map:get($clickMap,$r)
                       let $nclicks := if (fn:empty($nclicks)) then () 
                                        else <field name="NumberOfClicks">{sum($nclicks)}</field> 
                       let $pidEntry := <PRODUCT_ID>{$psiPid}</PRODUCT_ID>     
                       
                       let $nCart := map:get($addCartMap,$psiPid)
                       let $nAddCarts :=  if (fn:exists($nCart)) then <field name="NumberOfAddCarts">{$nCart}</field>
                                           else ()
   
                       
                       return 
                         insert nodes ($nclicks,$nAddCarts,$priceTuples) into $accRecord
              
}; 

   
declare   %updating function local:dumpPriceDataIntoFile ($outFileName as xs:string,$dbName as xs:string,$shortProdMap as map(*),$clickMap as map(*)) 
{
        
        let $priceMap := 
          map:new(
          for tumbling window $psiRecordGroup in fn:doc("PSI_stock_info")//record
                  start $first next $second when $first/PRODUCT_ID eq $second/PRODUCT_ID
                  end $last next $beyond when $last/PRODUCT_ID ne $beyond/PRODUCT_ID
                    let $pid := $psiRecordGroup[1]/PRODUCT_ID/text()
                    return
                      map:entry($pid,$psiRecordGroup))
        
       
        let $sf := file:write-text($outFileName,"<add>")
        (: PSI is sorted based product_id. here we gett all psi data fro per product_id in $psiRecordGroup variable:)
        let $list :=
        for $psiPid in map:keys($priceMap)
              let $psiRecordGroup := map:get ($priceMap,$psiPid)

              let $psiIDs := $psiRecordGroup/PRODUCT_SALES_INFO_ID/text()
              (: Get core product info :)   
              let $prodRecord := map:get($shortProdMap,$psiPid)
              return
                if (fn:empty($prodRecord)) then ()
                else
                  let $stockModel := xs:int($prodRecord/STOCK_MODEL/text())
                  let $isMigroskop := $prodRecord/IS_MIGROSKOP/text()
                  let $priceTuples :=
                    for $psiID at $k in $psiIDs
                    
                      let $mccP := xs:float($psiRecordGroup[$k]/MCC_PRICE/text())
                      let $accP := xs:float($psiRecordGroup[$k]/ACTION_PRICE/text())
                      let $price :=  xs:float($psiRecordGroup[$k]/PRICE/text()) 
                      let $sAmount := $psiRecordGroup[$k]/STOCK_AMOUNT/text()
                      let $finalPrice := 
                          if ($mccP < $price and $mccP > 0) then $mccP
                          else if ($accP < $price and $accP > 0) then $accP
                          else $price
                      let $sid := $psiRecordGroup[$k]/STORE_ID/text()          
                     
                      let $inPromotion := $isMigroskop eq "1" or 
                                             (($mccP < $price and $mccP > 0.0) or
                                              ($accP < $price and $accP > 0.0))
                      let $isMCC := ($mccP < $price and $mccP> 0.0)
                     (:inStock:true| false based on for each store price ((pm.stock_model <> 1 AND psi.stock_amount > 0) OR  pm.stock_model = 1):)
                      let $inStock := if (($stockModel ne 1 and xs:float($sAmount) > 0) or $stockModel eq 1) then fn:true() else fn:false()
                      return  
                        (: 3 new fields here:)
                        (<field name="Price_{$sid}">{$finalPrice}</field>,
                         <field name="PSIID_{$sid}">{$psiID}</field>,
                         <field name="InStock_{$sid}">{$inStock}</field>,               
                         <field name="InPromotion_{$sid}">{$inPromotion}</field>,
                         <field name="IsMCCProduct_{$sid}">{$isMCC}</field>,
                         <field name="StoreID">{$sid}</field>)  
               
                      
                 let $nclicks := for $r in $psiIDs 
                                    return map:get($clickMap,$r)
                 let $nclicks := if (fn:empty($nclicks)) then () 
                                  else <field name="NumberOfClicks">{sum($nclicks)}</field> 
                 let $pidEntry := <PRODUCT_ID>{$psiPid}</PRODUCT_ID>                
                 return 
                   file:append($outFileName, <doc>{($pidEntry,$nclicks,$priceTuples)}</doc>)
                  
         let $ef := file:append($outFileName,"</add>")
         
         return local:indexFile ($dbName, $outFileName, ($sf,$list,$ef))
};

declare %updating function local:indexFile ($dbName as xs:string,$outFileName as xs:string,$args as item()*) 
{
   let $temp := "" 
   return
     db:create ($dbName,$outFileName)
};
                    
declare   %updating function local:setupProducts ($mapBrands as map(*),$mapFeatures as map(*),$mapFavorites as map(*),$mapProperties as map(*),
                                                            $pathsmap as map(*),$mapMD as map(*),$shortProdMap as map(*)) 
{
 
       
       let $prodStore := fn:doc("AccumulatedProducts")    
       for $pid in map:keys($shortProdMap)
                  let $record := map:get($shortProdMap,$pid)

                  (:get core product data here:)
                  let $prodModID := $record/PRODUCT_MODEL_ID/text()
                  let $pid := $record/PRODUCT_ID/text()
                  let $pDetail :=  <field name="ProductMoreDetail">{map:get($mapMD,$prodModID)}</field>   
                 
                  let $pidField:=<field name="ProductID">{$pid}</field>
                  let $pmid :=  <field name="ProductModelID">{$prodModID}</field>
                  let $pmn :=    <field name="ProductModelName">{$record/PRODUCT_MODEL_NAME/text()}</field>
                  let $desc := <field name="Description"> {$record/DESCRIPTION/text()}</field>
                  let $shopCode :=    $record/SHOP_CODE/text()
                  let $shopID :=   $record/SHOP_ID/text()
                  let $storeID :=$record/STORE_ID/text()
                  let $isMigroskop :=  $record/IS_MIGROSKOP/text()
                  let $brandID :=  $record/BRAND_ID/text() 
               
                   
                  (: We will add ProductID fiel after adding customers CRM data. We have to locate product record with unique XML tag. Otherwise, xquery 
                  i staking a lot of time to locate product. We are adding <PRODUCT_ID></PRODUCT_ID> into record. During CRM addition, we will remove it an dadd SOLR field:) 
                  return
                  insert node    
                    <doc>   
                       {$pidField} 
                       {$pmid}
                       {$pmn}
                       {$pDetail}
                       {$desc}
                       <field name="IsMigroskop">{$isMigroskop}</field>
                      
                       {local:transTurkishChars("ProductMoreDetail",$pDetail/text())} 
                       {local:transTurkishChars("ProductModelName",$pmn/text())}
                       {local:transTurkishChars("Description",$desc/text())}
                 
                       {                        
                        let $utriple := local:splitUnits($pmn)                      
                        return ($utriple)
                       }
                                 
                       <field name="ShopCode">{$shopCode}</field>         
                       <field name="ShopID">{$shopID}</field>
                            
                       {for $r in  map:get($pathsmap,$pmid) 
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
                       
                       {for $custids in map:get($mapFavorites,$pid)
                         return
                           for $cid in $custids
                            return
                            <field name="CustomersFavourite">{$cid}</field>
                       }
                       
                       {for $props in map:get($mapProperties,$pid)
                         return
                           for $p in $props
                            return
                              <field name="ProductProperty">{$p}</field>
                       }
                       
                       {for $features in map:get($mapFeatures,$pmid)
                         return
                            for $f in $features
                            return
                              (<field name="ProductFeatures">{$f}</field>,
                                local:transTurkishChars("ProductFeatures",$f))
                       }
                       
                       {
                         if (fn:not(fn:empty($brandID[1]))) then
                           let $brandName := map:get($mapBrands,$brandID)
                           return
                             <field name="BrandName">{$brandName}</field>
                         else ()
                       }
                       
                    </doc> as first into $prodStore/add

};
 

let $modelDetails := fn:doc("ProductModelDetails")

let $mapBrands :=
  map:new(for $record in fn:doc("Brands")//record
             return map:entry($record/BRAND_ID/text(),$record/NAME/text()))
             
let $mapFeatures :=
  map:new(for $record in fn:doc("Features")//record
             let $pid := $record/PRODUCT_ID
             group by $pid
             return map:entry($pid,$record/FEATURE_VALUE/text()))
             
let $mapFavorites :=
  map:new(for $record in fn:doc("Favorites")//record
             let $pid := $record/PRODUCT_ID
             group by $pid
             return map:entry($pid,$record/CUSTOMER_ID/text()))
            
let $mapProperties :=
  map:new(for $record in fn:doc("Properties")//record
             let $pid := $record/PRODUCT_ID
             group by $pid
             return map:entry($pid,$record/PROPERTY_NAME/text()))
                                                    
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


 let $priceMap := 
          map:new(
          for tumbling window $psiRecordGroup in fn:doc("PSI_stock_info")//record (: test temporarily with "PSI_sorted. Change it to PSI_stock_info later":)
                  start $first next $second when $first/PRODUCT_ID eq $second/PRODUCT_ID
                  end $last next $beyond when $last/PRODUCT_ID ne $beyond/PRODUCT_ID
                    let $pid := $psiRecordGroup[1]/PRODUCT_ID/text()
                    return
                      map:entry($pid,$psiRecordGroup))
                      
let $shortProdMap :=
map:new(
  for $rec in fn:doc("CoreProductInfo")//record
      let $pid := $rec/PRODUCT_ID/text()
      let $exist := map:get($priceMap,$pid)    
      group by $pid
       where fn:exists($exist)
        return
              map:entry($pid,$rec))
  
  (:
let $action := "coresetup"
return
  local:setupProducts ($mapBrands,$mapFeatures,$mapFavorites ,$mapProperties ,$pathsmap ,$mapMD ,$shortProdMap )
  :)
  
return
  if ($action eq "coresetup") then
    local:setupProducts ($mapBrands,$mapFeatures,$mapFavorites ,$mapProperties ,$pathsmap ,$mapMD ,$shortProdMap )
  else if ($action eq "addcrm") then
    local:addCRMDataIntoProducts ()
  else if ($action eq "addpsi") then
    local:addPriceDataIntoAccumulatedFile ()
  else ()





  

