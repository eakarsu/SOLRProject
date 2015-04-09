declare namespace leven = "migros.com.Levenshtein";

declare option db:lserror "2";

let $s := ""

let $doc := fn:doc("searchKeywords")
let $ldist := 3
let $list1 :=
  for $rec in $doc//record
    let $pmn := fn:lower-case($rec/ProductModelName/text())
    let $pmntoks := fn:tokenize($pmn," |\.|\(|,|'|&amp;|-" )
    let $keys :=
      for $key in $rec/Keyword
        let $vs :=
          for $k in fn:tokenize($key/@value," ")
            let $pmerrs :=
              for $pmntok in $pmntoks
                 let $error := leven:Distance($pmntok,$k) 
                 let $klen := fn:string-length($pmntok)
                 return
                     if  ($klen le 3) then
                        if ($error eq 0 or $error lt 3) then 1 else 0
                     else if ($error <= $ldist and $k ne "cola") then 1 else 0
                    
            return
              sum($pmerrs)
        let $sum := fn:sum($vs)
        return 
          if ($sum ge 1) then   
            <Keyword matches="{$sum}">{$key/@value}{$key/text()}</Keyword> 
          else
           ()(:<Keyword matches="{$sum}">{$key/@value}{$key/text()}</Keyword>  :)
    return
      <record>
        {$rec/ProductID}
        {$rec/ProductModelName}
        {$keys}
      </record>



return $list1