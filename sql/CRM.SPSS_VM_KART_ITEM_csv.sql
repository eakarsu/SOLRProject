set lines 9999 -- the appropriate size
set head off  -- no header lines
set colsep ';' --column separator to ;
set pages 0 -- no pages
set feed off


SELECT p.product_id,
  cs.customer_id,
  seg.son_segment,
  csseg.name,
  csseg.segment_id,
  SUM(crm.product_quantity_sum) "AMOUNT",
  SUM(crm.product_trans_count) "ORDER_COUNT"
FROM CRM.SPSS_VM_KART_ITEM crm,
  product_models pm,
  products p,
  customers cs,
  customer_segments csseg,
  customer_segment_members cssegmems,
  CRM.SPSS_VM_SEGMENT seg
WHERE TO_CHAR(crm.item_number) = pm.shop_code
AND crm.MIGROSCARDNUMBER       = seg.MIGROSCARDNUMBER
AND p.product_model_id         = pm.product_model_id
AND cs.migros_card_no = TO_CHAR(seg.MIGROSCARDNUMBER)
AND csseg.segment_id = cssegmems.segment_id
AND cssegmems.customer_id = cs.customer_id
AND rownum < 1000
GROUP BY p.product_id,
  cs.customer_id,
  csseg.segment_id,
  csseg.name,
  seg.son_segment;

spool csv_file.csv
/
spool off;
exit;
