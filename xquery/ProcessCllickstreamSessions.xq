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

declare function local:getParam ($searchReq as xs:string,$paramName as xs:string) as xs:string
{
     let $tokens := fn:tokenize ($searchReq,"&amp;|/")
     let $keywords := ($tokens[fn:starts-with(.,$paramName)])[1]
     let $keyword := if (fn:empty($keywords)) then ""
                     else fn:tokenize($keywords,"=")[2]
     return $keyword
};
 
let $searchReq := "^/kweb/searchInShop|^/mobile/iphone/searchInShop|^/mobile/android/searchInShop"
let $clickReq := "^/kweb/getLazyProductDetail.do|^/kweb/showProductDetail.do|^/kweb/prview|/kweb/prcview"
let $addCartReq := "^/kweb/addMultipleProductsToCart.do|^/kweb/addToCart.do"
let $clickReq := fn:concat($clickReq,"|^/mobile/android/getLazyProductDetail.do|^/mobile/android/showProductDetail.do|^/mobile/android/prview|/kweb/prcview")
let $clickReq := fn:concat($clickReq,"|^/mobile/iphone/getLazyProductDetail.do|^/mobile/iphone/showProductDetail.do|^/mobile/iphone/prview|/kweb/prcview")
let $addCartReq := fn:concat($addCartReq,"|^/mobile/android/addMultipleProductsToCart.do|^/mobile/android/addToCart.do")
let $addCartReq := fn:concat($addCartReq,"|^/iphone/android/addMultipleProductsToCart.do|^/mobile/iphone/addToCart.do")

let $list :=
  for $ses in fn:doc("ClickstreamSessions")//session
    let $cid := fn:data($ses/@CustomerID)
    let $selects := $ses/*[fn:matches(.,$searchReq) or fn:matches(.,$clickReq) or fn:matches(.,$addCartReq)]
    let $searchGroups := 
      for tumbling window $w in $selects
          start at $s when fn:true()
          end $last next $beyond when fn:contains($beyond,$searchReq)
      return <window>{ $w }</window>
    
    let $list:=
      for $group in $searchGroups
        let $searchReq := $group/*[fn:position() eq 1]
        let $keyword := local:getParam($searchReq,"searchKeyword")
        let $clickRequests := $group/httpRequest[fn:matches(.,$clickReq)] 
        let $isClicked := fn:not (fn:empty($clickRequests))
        let $clickedPsi := if (fn:not($isClicked)) then ""
                           else
                             let $crvals := 
                               for $cr in $clickRequests
                                 let $crval := local:getParam($cr,"psi")
                                 where $crval ne ""
                                 return $crval
                             return $crvals
                                   
        let $clickRec :=
                    <Clicked>
                         <Keyword>{$keyword}</Keyword>
                         <IsClicked>{$isClicked}</IsClicked>
                         <CustomerID>{$cid}</CustomerID>
                         <clickedPsi>{$clickedPsi}</clickedPsi>
                     </Clicked> 
                             
        let $cartItems:= 
          for $addToCartReq in $group/*[fn:matches(.,$addCartReq)] 
            let $psi := local:getParam($addToCartReq,"psi") 
            let $pid := local:getParam($addToCartReq,"productid")
            let $pid := if ($pid eq "") then local:getParam($addToCartReq,"productids_1") else $pid
            let $amount := local:getParam($addToCartReq,"amount")
            let $amount := if ($amount eq "")  then local:getParam($addToCartReq,"amounts_1") else $amount 
            let $storeid := local:getParam($addToCartReq,"storeid") 
            let $storeid := if ($storeid eq "") then  local:getParam($addToCartReq,"storeids_1") else $storeid  
            let $cartItem :=
                  <AddedToCart>
                    <Keyword>{$keyword}</Keyword>
                    <ProductID>{$pid}</ProductID>
                    <Amount>{$amount}</Amount>
                    <StoreID>{$storeid}</StoreID>
                    <CustomerID>{$cid}</CustomerID>
                    <addToCartPsi>{$psi}</addToCartPsi>
                  </AddedToCart>
      
            return $cartItem 
        return ($clickRec,$cartItems)
             
    return $list

return $list

    (:
 let $options := { 'lax': 'no' }
 let $csv1 := csv:serialize(<csv>{$list[fn:name() eq "Clicked"]}</csv>, $options)
 let $csv2 := csv:serialize(<csv>{$list[fn:name() eq "AddedToCart"]}</csv>, $options)
 let $l1 :=
   file:write("c:/tmp/ClickedSearches.csv",$csv1) 
 let $l2 :=
   file:write("c:/tmp/AddToCarts.csv",$csv2)   
       
 
 let $l1 :=
   file:write("c:/tmp/ClickedSearches.xml",<Records>{$list[fn:name() eq "Clicked"]}</Records>)  
 let $l2 :=
   file:write("c:/tmp/AddToCarts.xml",<Records>{$list[fn:name() eq "AddedToCart"]}</Records>)   
        
 return ($l1,$l2)
      :)
       