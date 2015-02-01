
let $sids := ("177","178","182","183","190","194","237","230","232","233","63","96","304","325","388","766","767","905","925","1005","1405","1467","1468","1505","1566","1567","1685","1705","1706","1707","1725","1805","1846","1865","1866","1885","1905","1965","2006","2045","2065","2085","2106","2114","2115","2116","2145","2166","1765","2287","2345","1806","2505","1645","2565","2566","2567","1325","185","2727","2728","2729","2265","193","2185","2226","2386","175","2390","2405","1006","2465","2466","2467","2525","1445","2687","2747","2245","2366","2426","2445","2446","2447","2585","2586","2625","1745","2707","2205","1746","184","2305","2365","2545","2605","645","179","1925","2627","2667","324","189"
)

let $units := ("ADET","KG","LT","M","MP","V","W")

let $normalFields := ("ProductModelID","ProductID","ProductModelName","Description","ShopCode","ShopID","StoreID","Keyword","SearchKeywordValue","CategoryID","SearchBoost","ProductMoreDetail","ProductModelNameExact","ProductMoreDetailExact","CustomersPurchased","CustomersFavourite","ProductProperty","CategoryPath","ProductFeatures","PathLevel2","BrandName","IsMigroskop","IsInCampaign","Amount","OrderCount","NumberOfClicks","NumberOfAddCarts","AmountGrade","OrderCountGrade","NumberOfClicksGrade")    

let $storeFields :=
  for $sid in $sids
    let $f1 := <field column="PSIID_{$sid}"        xpath="/add/doc/field[@name='PSIID_{$sid}']" />
    let $f2 := <field column="InStock_{$sid}"        xpath="/add/doc/field[@name='InStock_{$sid}']" />
    let $f3 := <field column="InPromotion_{$sid}"        xpath="/add/doc/field[@InPromotion='PSIID_{$sid}']" />
    let $f4 := <field column="IsMCCProduct_{$sid}"        xpath="/add/doc/field[@name='IsMCCProduct_{$sid}']" />
    let $f5 := <field column="Price_{$sid}"        xpath="/add/doc/field[@name='Price_{$sid}']" />
    return ($f1,$f2,$f3,$f4,$f5)
   
let $unitFields :=
  for $unit in $units
    let $f1 := <field column="UnitSymbol_{$unit}"        xpath="/add/doc/field[@name='UnitSymbol_{$unit}']" />
    let $f2 := <field column="UnitVal_{$unit}"        xpath="/add/doc/field[@name='UnitVal_{$unit}']" />
    let $f3 := <field column="UnitExpr_{$unit}"        xpath="/add/doc/field[@name='UnitExpr_{$unit}']" />
    return ($f1,$f2,$f3)
 
   
let $segFields :=
  for $seg in 101 to 110
    let $f1 := <field column="SegAmount_{$seg}"        xpath="/add/doc/field[@name='SegAmount_{$seg}']" />
    let $f2 := <field column="SegOrderCount_{$seg}"        xpath="/add/doc/field[@name='SegOrderCount_{$seg}']" />
    let $f3 := <field column="SegAmountGrade_{$seg}"        xpath="/add/doc/field[@name='SegAmountGrade_{$seg}']" />
    let $f4 := <field column="SegOrderCountGrade_{$seg}"        xpath="/add/doc/field[@name='SegOrderCountGrade_{$seg}']" />
     return ($f1,$f2,$f3,$f4)

let $coreFields :=
    for $fn in $normalFields
      let $f1 := <field column="{$fn}"        xpath="/add/doc/field[@name='{$fn}']" />
      return $f1
      
      
return
  ($unitFields,$segFields,$coreFields,$storeFields)