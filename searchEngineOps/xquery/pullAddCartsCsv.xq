let $doc := fn:doc("CSstreamCartInfo")

let $outfile := "/oraexport/searchEngineOps/SQLExtracts/addcarts.csv"
let $res := file:append-text($outfile,"Keyword,ProductID,Amount,StoreID,CustomerID"||"&#xa;")

let $list :=
  for $rec in $doc//AddedToCart
    let $keyword := $rec/Keyword/text()
    let $pid := $rec/ProductID/text()
    let $amount := $rec/Amount/text()
    let $storeid := $rec/StoreID/text()
    let $cid := $rec/CustomerID/text()
    return
        file:append-text($outfile,$keyword||","||$pid||","||$amount||","||$storeid||","||$cid||"&#xa;")
      

return ($res,$list)
              
              
