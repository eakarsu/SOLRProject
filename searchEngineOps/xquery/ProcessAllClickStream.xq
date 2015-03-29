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
declare namespace urlDecoder = "java.net.URLDecoder";
declare variable $inputDoc as xs:string external;
declare variable $docNum as xs:string external;
(:
declare variable $clickCountDoc as xs:string external;
declare variable $addCartDoc as xs:string external;
:)


declare function local:getParam ($rec as element()*,$paramName as xs:string) as xs:string*
{
     let $searchReq := local:getPath($rec)
            
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

declare function local:getPath ($rec as element() *) as xs:string*
{
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
    let $path := $ru || "/" || $qs
    return $path
};

 
    
declare function local:processOneSearchSession ($cid as xs:string,$filecart as xs:string,$fileclick as xs:string,$clickReq as xs:string,
                                                $addCartReq as xs:string,$searchGroups as element()*) as element()*
{
    let $tmp := ""
    for $group in $searchGroups
        let $searchReq := $group/*[fn:position() eq 1]
        let $keyword := local:getParam($searchReq,"searchKeyword")
        let $clickRequests := $group/*[fn:matches(./REQUEST_URI/text(),$clickReq)] 
        let $isClicked := fn:not (fn:empty($clickRequests))
        let $clickedPsi := if (fn:not($isClicked)) then ()
                           else
                             let $crvals := 
                               for $cr in $clickRequests
                                 let $crval := local:getParam($cr,"psi")
                                 where $crval ne ""
                                 return $crval
                             return $crvals
                                   
        let $clickRec := if (fn:empty($clickedPsi)) then ()
                         else
                          let $psis :=
      for $item in $clickedPsi
        return
          <clickedPsi>{$item}</clickedPsi>
                          return
                          <Clicked>
                               <Keyword>{$keyword}</Keyword>
                               <IsClicked>{$isClicked}</IsClicked>
                               <CustomerID>{$cid}</CustomerID>
                               {$psis}
                           </Clicked> 
                             
        let $cartItems:= 
          for $addToCartReq in $group/*[fn:matches(./REQUEST_URI/text(),$addCartReq)] 
            let $psi := local:getParam($addToCartReq,"psi") 
            let $pid := local:getParam($addToCartReq,"productid")
            let $pid := if (fn:empty($pid)) then local:getParam($addToCartReq,"productids") else $pid (: products_2, 3. 5 ... :)
            let $amount := local:getParam($addToCartReq,"amount")
            let $amount := if (fn:empty($amount))  then local:getParam($addToCartReq,"amounts") else $amount  (: scan over all products_x,amounts_x, storeids_x where x 1, n :)
            let $storeid := local:getParam($addToCartReq,"storeid") 
            let $storeid := if (fn:empty($storeid)) then  local:getParam($addToCartReq,"storeids") else $storeid  (: storeids_1,storeid2_2, etc.:)
           
            let $keywords := fn:string-join($keyword,",")
            return 
              if ( fn:empty($keyword) or $keywords eq "") then ()
              else
         for $nextpid in $pid
           return
                <AddedToCart>
                    <Keyword>{$keywords}</Keyword>
                    <ProductID>{$nextpid}</ProductID>
                    <Amount>{$amount}</Amount>
                    <StoreID>{$storeid}</StoreID>
                    <CustomerID>{$cid}</CustomerID>
                    <addToCartPsi>{$psi}</addToCartPsi>
                  </AddedToCart>
        return 
        (if (fn:not(fn:empty($clickRec))) then file:append($fileclick,$clickRec) else (),
        if (fn:not(fn:empty($cartItems))) then file:append($filecart,$cartItems) else ())
};


let $fileclick := "/tmp/clicks" || $docNum || ".xml"
let $filecart := "/tmp/carts" || $docNum || ".xml"
 
(:
let $clickDoc := fn:doc($clickCountDoc)//RECORDS
let $cartDoc := fn:doc($addCartDoc)//RECORDS
:)

let $ignores :=
"^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getFastPurchaseProductList.do|"||
"^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?lastBoughtProducts.do|"||
"^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?kangmessages.do|"||
"^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?addCustomerOpinion.do|"||
"^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showStaticHelpPage.do|"||
"^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showStaticPage.do|"||
"^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?checkProductInBasket.do|"||
"^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(prview/?)(/)?ajaxUpdateBasket.do|"||
"^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?kangmessages.do"

let $searchReq := 
"^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?searchInShop.do|"||
"^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?qs.do"

let $clickReq := 
    "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?getLazyProductDetail.do|"||
    "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?showProductDetail.do|"||
    "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?prview|/kweb/(/)?prcview"

let $addCartReq :=  
   "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?addMultipleProductsToCart.do|"||
   "^/(kweb|mobile/android|mobile/iphone|mobile/bb|mobile/qq|mobile/ipad)/(/)?addToCart.do"


return
  for $rec in (fn:doc($inputDoc)//record)
    let $cid := $rec/CUSTOMER_ID/text()
    let $ts := $rec/TIME_STAMP/text()
    let $ts := fn:replace($ts," ","T")
    let $timeStamp := xs:dateTime($ts)

    where fn:not(fn:matches($rec/REQUEST_URI/text(),$ignores))   
    order by $timeStamp
    group by $cid
    return
            let $searchGroups := 
              for tumbling window $w in $rec
                      start $first at $s when (fn:matches($first/REQUEST_URI/text(),$searchReq)) 
                      end $last next $beyond when fn:not( 
                                                   fn:matches($beyond/REQUEST_URI/text(),$clickReq) or
                                                   fn:matches($beyond/REQUEST_URI/text(),$addCartReq)) 
		return <w>{$w}</w>

            return 
                local:processOneSearchSession ($cid,$filecart,$fileclick ,$clickReq ,
                                                            $addCartReq ,$searchGroups )     
     

       

