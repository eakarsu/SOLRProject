let $list :=
    for $record in fn:doc("CSstreamCartInfo")//AddedToCart
                 let $pid := $record/ProductID/text() 
                 where $pid ne "" and fn:not(fn:empty($pid))
                  return
                   <doc>
                       <field name="Keyword">{$record/Keyword/text()}</field>
                       <field name="CustomerID">{$record/CustomerID/text()}</field>
                        <field name="ProductID">{$record/ProductID/text()}</field>
                         <field name="StoreID">{$record/StoreID/text()}</field>
                       <field name="Amount">{$record/Amount/text()}</field>
                   </doc>

 return <add>{$list}</add>
