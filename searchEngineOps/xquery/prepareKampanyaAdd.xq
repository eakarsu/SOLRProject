declare variable $host as xs:string external;
declare variable $port as xs:string external;
declare variable $webpath as xs:string external;
declare variable $outFileName as xs:string external;
declare variable $process as xs:string external;

(:
let $host := "192.168.191.150"
let $port := "8080"
let $webpath := "migrossolr"
let $outFileName := "c:/tmp/populateKamp.xml"
let $process := "unset"
:)

let $curTime := fn:current-dateTime() 
let $solrURLForCamp := fn:concat("http://",$host,":",$port,"/",$webpath,"/Campaigns/select?q=*:*&amp;wt=xml&amp;indent=true")

let $res := http:send-request(<http:request method='get' status-only='false'/>, $solrURLForCamp)
let $addedDocs :=
  for $doc in $res[2]//doc
    let $type := $doc/str[@name eq "CampaignType"]
    let $startTime := xs:dateTime($doc/date[@name eq "CampaignStartDate"]/text())
    let $endTime := xs:dateTime($doc/date[@name eq "CampaignEndDate"]/text())
    
    let $fieldName := if ($type eq "Category") then "IsInCampaignCategory"
                      else if ($type eq "Brand") then "IsInCampaignBrand"
                      else "IsInCampaign"
    let $list :=
        for $pid in $doc/arr[@name eq "ProductID"]/str/text()
           return
              <doc>
                <field name="ProductID">{$pid}</field>
                { if ($process eq "set") then
                      <field name="{$fieldName}" update="set">true</field>  
                  else
                    <field name="IsInCampaign" update="set" null="true" />
              }              
              </doc>
    where $curTime ge $startTime and $curTime le $endTime 
    return ($list)
  
return 
  (file:write($outFileName, <add>{$addedDocs}</add>))

   

