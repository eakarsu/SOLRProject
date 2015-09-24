declare namespace leven = "migros.com.Levenshtein";
declare variable $levendist as xs:string external;
declare variable $rawKeywordsFile as xs:string external;
declare variable $outputKeywordsFile as xs:string external;

declare option db:lserror "2";

let $s := ""

let $doc := fn:doc($rawKeywordsFile)
let $ldist := 2
let $list1 :=
  for $rec in $doc//record
    let $pmn := fn:lower-case($rec/ProductModelName/text())
    let $pmntoks := fn:tokenize($pmn," |\.|\(|,|'|&amp;|-" )
    let $keys :=
      for $key in $rec/Keyword
        let $freq := xs:int($key/text())
	let $wtokens := fn:tokenize($key/@value," ")
        let $vs :=
          for $k in $wtokens
	    let $klen := fn:string-length($k)
            let $pmerrs :=
              for $pmntok in $pmntoks
                 let $error := leven:Distance($pmntok,$k) 
                 let $pmtoklen := fn:string-length($pmntok)		 
                 return
                     if  ($klen le 3 or $pmtoklen le 3) then
                        if ($error eq 0 ) then 1 else 0
                     else if ($error <= $ldist and $freq ge 2) then 1 else 0
             
	    return
              sum($pmerrs)

        let $sum := fn:sum($vs)
        where $key/@value ne ""	
        return 
          if ($sum eq fn:count($wtokens)) then   
            <Keyword matches="{$sum}">{$key/@value}{$key/text()}</Keyword> 
          else
           ()(:<Keyword matches="{$sum}">{$key/@value}{$key/text()}</Keyword>  :)
    return
      <record>
        {$rec/ProductID}
        {$rec/ProductModelName}
        {$keys}
      </record>



return file:write($outputKeywordsFile,
			<add>{$list1}</add>)
