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
declare variable $inputDoc as xs:string external;
declare variable $clickCountDoc as xs:string external;
declare variable $addCartDoc as xs:string external;

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
  
let $clickDoc := fn:doc($clickCountDoc)//RECORDS
let $cartDoc := fn:doc($addCartDoc)//RECORDS

let $searchReq := "^/kweb/searchInShop|^/mobile/iphone/searchInShop|^/mobile/android/searchInShop"
let $clickReq := "^/kweb/getLazyProductDetail.do|^/kweb/showProductDetail.do|^/kweb/prview|/kweb/prcview"
let $addCartReq := "^/kweb/addMultipleProductsToCart.do|^/kweb/addToCart.do"
let $clickReq := fn:concat($clickReq,"|^/mobile/android/getLazyProductDetail.do|^/mobile/android/showProductDetail.do|^/mobile/android/prview|/kweb/prcview")
let $clickReq := fn:concat($clickReq,"|^/mobile/iphone/getLazyProductDetail.do|^/mobile/iphone/showProductDetail.do|^/mobile/iphone/prview|/kweb/prcview")
let $addCartReq := fn:concat($addCartReq,"|^/mobile/android/addMultipleProductsToCart.do|^/mobile/android/addToCart.do")
let $addCartReq := fn:concat($addCartReq,"|^/iphone/android/addMultipleProductsToCart.do|^/mobile/iphone/addToCart.do")

return
  for $ses in fn:doc($inputDoc)//session
    let $cid := fn:data($ses/@CustomerID)
    let $selects := $ses/*[fn:matches(.,$searchReq) or fn:matches(.,$clickReq) or fn:matches(.,$addCartReq)]
    let $searchGroups := 
      for tumbling window $w in $selects
          start at $s when fn:true()
          end $last next $beyond when fn:matches($beyond,$searchReq)
      return <window>{ $w }</window>
    
    return
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
          for $addToCartReq in $group/*[fn:matches(.,$addCartReq)] 
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
                <AddedToCart>
                    <Keyword>{$keywords}</Keyword>
                    <ProductID>{$pid}</ProductID>
                    <Amount>{$amount}</Amount>
                    <StoreID>{$storeid}</StoreID>
                    <CustomerID>{$cid}</CustomerID>
                    <addToCartPsi>{$psi}</addToCartPsi>
                  </AddedToCart>
        return 
        (if (fn:not(fn:empty($clickRec))) then insert node $clickRec into $clickDoc else (),
        if (fn:not(fn:empty($cartItems))) then insert nodes $cartItems into $cartDoc else ())
     

       
