declare variable $host as xs:string external;
declare variable $port as xs:string external;
declare variable $webpath as xs:string external;
declare variable $coreName as xs:string external;
declare variable $outFileName as xs:string external;

(:
let $host := "192.168.191.150"
let $port := "8080"
let $webpath := "migrossolr"
let $coreName := "ProductsCoreFirst"
let $outFileName := "c:/tmp/addDocs.xml"
:)

(: http://192.168.191.150:8080/migrossolr/ProductsCoreFirst/select?q=BrandName%3AP%C4%B1nar&fl=ProductID&wt=json&indent=true :)
 
let $solrURLForCamp := "http://"||$host||":"||$port||"/"||$webpath||"/Campaigns/select?q=*:*&amp;wt=xml&amp;indent=true"

let $res := http:send-request(<http:request method='get' status-only='false'/>, $solrURLForCamp)
let $addedDocs :=
  for $doc in $res[2]//doc
    let $type := $doc/str[@name eq "CampaignType"]
    let $searchField := if ($type eq "Brand") then "BrandName" else if ($type eq "Category") then "PathLevel2" else ""
    let $rawFilter := $doc/str[@name eq "CampaignFilter"]/text()
    let $id := $doc/str[@name eq "id"]/text()
    let $filter := '"'||encode-for-uri($rawFilter)||'"'
    let $docs :=
      if ($searchField ne "") then 
          let $solrURLForField := "http://"||$host||":"||$port||"/"||$webpath||"/"||$coreName||"/select?q="||$searchField||":"||$filter||"&amp;fl=ProductID,ProductModelName&amp;wt=xml&amp;indent=true&amp;rows=300"
          let $brandRes := http:send-request(<http:request method='get' status-only='false'/>, $solrURLForField)
          let $pids :=
            for $rec  in $brandRes[2]//result//doc
              return
                (<field name="ProductID" update="set">{$rec/str[@name eq "ProductID"]/text()}</field>,
                <field name="ProductModelName" update="set">{$rec/str[@name eq "ProductModelName"]/text()}</field>)
          return
            <doc>
            {$solrURLForField}
              <field name="id" >{$id}</field>
              {$pids}
            </doc>
       else ()
    return $docs

return 
  (file:write($outFileName, <add>{$addedDocs}</add>))  

