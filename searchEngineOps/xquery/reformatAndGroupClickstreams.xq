declare namespace urlDecoder = "java.net.URLDecoder";
declare variable $inputDoc as xs:string external;
declare variable $outputDoc as xs:string external;

let $uris := 
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getProductList|" ||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getCategoryList|" ||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?browseShopCatalog|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getMigroskopDiscountProductList|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getMccDiscountProductList|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?sclist|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?scview|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?view|"||

  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?searchInShop.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getLazyProductDetail.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showProductDetail.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?prview|/kweb/(/)?prcview|"||
  "^/(kweb|mobile/iphone)/(/)?prview|/kweb/(/)?prcview|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?addMultipleProductsToCart.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?addToCart.do|"||

  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showAllFavorite|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showCategor|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showFavorites|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showKangurum|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showPeriodicOrder|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showProductsList|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showShopping|"|| 
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?favoriteProducts|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showOrderHistory|"||
  
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?shopProductListing|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?productListing.do|" ||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getFastPurchaseProductList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?lastBoughtProducts.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?migroskopDiscountList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?mccDiscountList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getLastVisitedSanalMarketProductList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getMigroskopHeadLightProductsList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getGiftDiscountProductList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getGiftDiscountList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?searchInShop/"
 
let $outDoc := fn:doc($outputDoc)//RECORDS
let $inDoc := fn:doc($inputDoc)

return
  for $rec in ($inDoc//record)
    let $cid := $rec/CUSTOMER_ID/text()
    let $streamId := $rec/STREAM_ID/text()
    let $ts := $rec/TIME_STAMP/text()
    let $ts := fn:replace($ts," ","T")

    let $timeStamp := xs:dateTime($ts)
    let $us := $rec/QUERY_STRING/text()
    let $us := fn:replace($us,"%100","%25100")
    let $us := fn:replace($us,"%10","%0A")
    let $us := fn:replace($us,"%%20","%20")
    let $urlStr := if (fn:empty($us)) then $us else 
    try{
      urlDecoder:decode(xs:string($us),"UTF-8")        
    }catch *{
      'Error [' || $err:code || ']: ' || $err:description || ':'||$us||':'||$ts
    }
    
    let $ru := $rec/REQUEST_URI
    let $qs := $urlStr
    let $path := fn:concat($ru,"/",$qs)
   
    where fn:matches($path,$uris) 
    order by $timeStamp
    group by $cid
    return
       insert node  
                  <session CustomerID="{$cid}">
                    {for $j in 1 to fn:count($path)
                      return
                      <httpRequest streamId="{$streamId[$j]}" date="{$ts[$j]}">{$path[$j]}</httpRequest>
                    } 
                  </session> into $outDoc
      
