let $list := for tumbling window $psiRecordGroup in db:open("PSI_stock_info")//record (: test temporarily with "PSI_sorted. Change it to PSI_stock_info later":)
                  start $first next $second when $first/PRODUCT_ID eq $second/PRODUCT_ID
                  end $last next $beyond when $last/PRODUCT_ID ne $beyond/PRODUCT_ID
		 return <block>{$psiRecordGroup}</block>

return $list

