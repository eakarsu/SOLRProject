declare variable $createdDocName as xs:string external;
let $createdDoc := $createdDocName
return
  db:create($createdDoc,"<RECORDS/>")
