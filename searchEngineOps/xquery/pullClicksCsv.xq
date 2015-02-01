let $doc := fn:doc("CSstreamClickInfoPidEnhanced")

let $outfile := "/oraexport/searchEngineOps/SQLExtracts/clicks.csv"

let $res := file:append-text($outfile,"Keyword,IsClicked,CustomerID,ProductID"||"&#xa;")

let $list :=
  for $rec in $doc//record
    let $keyword := $rec/Keyword/text()
    let $clicked := $rec/IsClicked/text()
    let $cid := $rec/CustomerID/text()
    return
      if ($clicked eq "false") then
        file:append-text($outfile,$keyword||","||$clicked||","||$cid||",&#xa;")
      else
        let $pids := $rec/PRODUCT_ID/text()
        return
          for $pid in $pids
            return
              file:append-text($outfile,$keyword||","||$clicked||","||$cid||","||$pid||"&#xa;")

return ($res,$list)
