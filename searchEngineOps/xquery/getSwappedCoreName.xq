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

let $solrURL := fn:concat("http://",$host,":",$port,"/",$webpath,"/admin/cores?action=STATUS&amp;core=",$coreName)
return
try{
  let $res := http:send-request(<http:request method='get' status-only='false'/>, $solrURL)
  
  let $returnedCoreName := fn:data($res/response/lst[@name eq "status"]/lst/@name)
  let $instanceDirStr := $res//str[@name eq "instanceDir"]
  let $tokens := fn:tokenize($instanceDirStr,"/")
  let $swappedCore := $tokens[fn:last()-1]
  let $targetCore := 
        if ($coreName eq $returnedCoreName) then
           if ($coreName eq $swappedCore) then "ProductsCoreSecond"
           else "ProductsCoreFirst"
        else ""
     
  return $targetCore
}catch * {
  ""
}
