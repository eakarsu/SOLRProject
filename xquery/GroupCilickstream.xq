let $fn := "c:/tmp/clickstream2.xml"
let $addBegin := file:append-text($fn,"<RECORDS>","UTF-8")

let $doc := fn:doc("reformattedClickstream")

let $sessions :=
  for $r in ($doc//record)
    let $ir := $r/INITIAL_REFERRER/text()
    let $cid := $r/CUSTOMER_ID/text()
    let $ru := $r/REQUEST_URI/text()
    let $qs := ($r/QUERY_STRING)[2]
    let $path :=  fn:concat($ru,"/",$qs)
    where fn:not(fn:contains($path,"/kweb/getProductList") or 
                 fn:contains($path,"/kweb/kangmessages") or
                 fn:contains($path,"/kweb/getCategoryList") or
                 fn:contains($path,"/kweb/browseShopCatalog") or
                 fn:contains($path,"/kweb/main") or
                 fn:contains($path,"/kweb/getMigroskopDiscountProductList") or
                 fn:contains($path,"/kweb/registration") or
                 fn:contains($path,"/kweb/getMccDiscountProductList") or
                  fn:contains($path,"/kweb//qs"))
    group by $cid
    return
      file:append( $fn,  
      <session CustomerID="{$cid}">
        {for $j in 1 to fn:count($path)
          return
          <httpRequest>{$path[$j]}</httpRequest>
        } 
      </session>)
    
return  ($sessions,file:append-text($fn,"</RECORDS>","UTF-8"))
           
