declare variable $nparts as xs:string external;
declare variable $outfolder as xs:string external;
declare variable $solrdbname as xs:string external;

let $res := if (file:exists($outfolder)) then () else file:create-dir($outfolder)   
let $d := fn:doc($solrdbname)

let $nparts := xs:int($nparts)
let $ndocs := fn:count($d//doc)
let $share := fn:ceiling ($ndocs div $nparts)
let $list :=
  for $k in 0 to $nparts - 1
    let $grp := ($d//doc)[fn:position() > $k*$share and fn:position () <= ($k+1)*$share]
    let $outfilename := fn:concat($outfolder,"/solrinput",$k,".xml")
    let $r := file:write($outfilename,<add>{$grp}</add>)
    return 
      $r
return ($list,$res)
