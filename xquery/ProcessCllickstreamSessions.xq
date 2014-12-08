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
let $searchReq := "/kweb/searchInShop"
let $clickReq := "/kweb/addCustomerOpinion"
let $addCartReq := "/kweb/checkProductInBasket"
let $list :=
  for $ses in fn:doc("ClickstreamSessions")//session
    let $cid := fn:data($ses/@CustomerID)
    let $selects := $ses/*[fn:contains(.,$searchReq) or fn:contains(.,$clickReq) or fn:contains(.,$addCartReq)]
    let $searchGroups := 
      for tumbling window $w in $selects
          start at $s when fn:true()
          end $last next $beyond when fn:contains($beyond,$searchReq)
      return <window>{ $w }</window>
    
    let $list:=
      for $group in $searchGroups
        let $searchReq := $group/*[fn:position() eq 1]
        let $tokens := fn:tokenize ($searchReq,"&amp;|/")
        let $keywords := ($tokens[fn:starts-with(.,"searchKeyword")])[1]
        let $keyword := fn:tokenize($keywords,"=")[2]
        let $isClicked := fn:not(fn:empty($group/*[fn:contains(.,$clickReq)]))
        let $clickRec :=
          <Clicked>
            <Keyword>{$keyword}</Keyword>
            <IsClicked>{$isClicked}</IsClicked>
            <CustomerID>{$cid}</CustomerID>
          </Clicked> 
        let $cartItems:=
          for $s in $group/*[fn:position() gt 1 and fn:contains(.,$addCartReq)]  
            let $tokens := fn:tokenize($s,"&amp;")
            let $pids := $tokens[fn:starts-with(.,"productid")]
            let $amounts := $tokens[fn:starts-with(.,"amount")]
            let $storeids := $tokens[fn:starts-with(.,"storeid")]
            let $allItems :=
              for $j in 1 to fn:count($pids)
                let $pid := fn:tokenize($pids[$j],"=")[2]
                let $amount := fn:tokenize($amounts[$j],"=")[2]
                let $storeid := fn:tokenize($storeids[$j],"=")[2]
                let $cartItem :=
                  <AddedToCart>
                    <Keyword>{$keyword}</Keyword>
                    <ProductID>{$pid}</ProductID>
                    <Amount>{$amount}</Amount>
                    <StoreID>{$storeid}</StoreID>
                    <CustomerID>{$cid}</CustomerID>
                  </AddedToCart>
                return $cartItem
            return $allItems
        return ($clickRec,$cartItems)
             
    return $list
    
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
      
       