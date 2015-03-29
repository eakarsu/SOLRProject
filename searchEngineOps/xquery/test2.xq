(:
Clickstream datasından linkleri aşağıdaki şekilde alabilirsiniz. Sabah test dataları güncellenmiş olucak.

- Ürün Gözat Sayfaları için :
getLazyProductDetail.do

- Ürün Detay Sayfaları için :
http://www.sanalmarket.com.tr/kweb/showProductDetail.do
ve
prview ve prcview ile başlayan tüm linkler :
http://www.sanalmarket.com.tr/kweb/prview/
http://www.sanalmarket.com.tr/kweb/prcview/


- Sepete Ekelemek için :
Ürün Detay Sayfasında : addMultipleProductsToCart.do
Diğer Tüm Sayfalarda : addToCart.do
:)

declare function local:getParam ($searchReq as xs:string,$paramName as xs:string) as xs:string*
{
     let $tokens := fn:tokenize ($searchReq,"&amp;|/")
     let $keywords := $tokens[fn:starts-with(.,$paramName)]
     let $resultKeywords := if (fn:empty($keywords)) then ""
                     else
                       let $list :=
                         for $k in $keywords
                           return
                             fn:tokenize($k,"=")[2]
                       return $list
     return $resultKeywords
};

let $inputDoc := "ClickStreamInfos"

let $stopUri :=
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/searchInShop|"||

  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getProductList|" ||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getCategoryList|" ||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?browseShopCatalog|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getMigroskopDiscountProductList|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getMccDiscountProductList|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?sclist|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?scview|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?view|"||

  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?shopProductListing|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?productListing.do|" ||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getFastPurchaseProductList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?lastBoughtProducts.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?migroskopDiscountList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?mccDiscountList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getLastVisitedSanalMarketProductList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getMigroskopHeadLightProductsList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getGiftDiscountProductList.do|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getGiftDiscountList.do|" ||

  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showAllFavorite|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showCategor|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showFavorites|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showKangurum|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showOrder|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showPeriodicOrder|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showProductsList|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showShopping|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?favoriteProducts|"||
  "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showOrderHistory"

let $fileclick := "/tmp/clicks.xml"
let $filecart := "/tmp/carts.xml"


let $searchReq := "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?searchInShop"

let $clickReq :=
    "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getLazyProductDetail.do|"||
    "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showProductDetail.do|"||
    "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?prview|/kweb/(/)?prcview"

let $addCartReq :=
   "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?addMultipleProductsToCart.do|"||
   "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?addToCart.do"

let $fakeReq := "^/mobile/iphone/(/)?searchInShop/getSearchPageForIPWeb"

return
  for $ses in fn:doc($inputDoc)//session
    let $cid := fn:data($ses/@CustomerID)
    let $selects := $ses/* (: [fn:matches(.,$searchReq) or fn:matches(.,$clickReq) or fn:matches(.,$addCartReq)] :)
    let $searchGroups :=
        for tumbling window $w in $selects
          start at $s when fn:true()
          end $last next $beyond when fn:matches($beyond,$stopUri)
      return if ( fn:matches($w[1]/text(),$searchReq) and
                 fn:not(fn:matches($w[1]/text(),$fakeReq)) and
                 fn:count($w) gt 1) then <window cid="{$cid}">{ $w }</window> else ()
return $searchGroups
