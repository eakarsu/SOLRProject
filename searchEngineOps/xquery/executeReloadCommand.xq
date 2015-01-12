declare variable $host as xs:string external;
declare variable $port as xs:string external;
declare variable $webpath as xs:string external;
declare variable $coreName as xs:string external;

(:
let $host := "195.87.93.139"
let $port := "8080"
let $webpath := "migrossolr"
let $coreName := "ProductsCoreFirst"
:)

(: If relaod has been executed correcly, then we will get result like this
<lst name="responseHeader">
<int name="status">0</int>
<int name="QTime">1</int>
</lst> 
:)

let $solrURL := fn:concat("http://",$host,":",$port,"/",$webpath,"/admin/cores?action=RELOAD&amp;core=",$coreName)

return
try{
  let $res := http:send-request(<http:request method='get' status-only='false'/>, $solrURL) 
  let $status := $res[2]//int[@name eq "status"]/text()
  return
    if ($status eq "0") then 0 else 1 
}catch * {
  1
}
