set LINESIZE 5000
set pagesize 0
SET TRIMSPOOL ON
SET TRIMOUT ON
SET WRAP OFF
set trims on
SET TERMOUT OFF
SET PAGESIZE 0
set heading off
set heads off
set echo off
set feedback off
set colsep ','
set termout off
set verify off


spool RawFullCRMData.csv

SELECT p.product_id,
  cs.customer_id,
  seg.son_segment,
  SUM(crm.product_quantity_sum) "AMOUNT",
  SUM(crm.product_trans_count) "ORDER_COUNT"
FROM CRM.SPSS_VM_KART_ITEM crm,
  product_models pm,
  products p,
  customers cs,
  CRM.SPSS_VM_SEGMENT seg
WHERE TO_CHAR(crm.item_number) = pm.shop_code
AND crm.MIGROSCARDNUMBER       = seg.MIGROSCARDNUMBER
AND p.product_model_id         = pm.product_model_id
AND cs.migros_card_no          = TO_CHAR(seg.MIGROSCARDNUMBER)
GROUP BY p.product_id,
  cs.customer_id,
  seg.son_segment;

spool off;
exit;
