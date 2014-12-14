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


spool myFile.csv

 SELECT p.product_id,
  cs.customer_id,
  csseg.name,
  csseg.segment_id,
  SUM(crm.product_quantity_sum) "AMOUNT",
  SUM(crm.product_trans_count) "ORDER_COUNT"
FROM CRM.SPSS_VM_KART_ITEM crm,
  product_models pm,
  products p,
  customers cs,
  customer_segments csseg,
[kangadm@kangapp12 production]$ cat  test.sql
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


spool myFile.csv

 SELECT p.product_id,
  cs.customer_id,
  csseg.name,
  csseg.segment_id,
  SUM(crm.product_quantity_sum) "AMOUNT",
  SUM(crm.product_trans_count) "ORDER_COUNT"
FROM CRM.SPSS_VM_KART_ITEM crm,
  product_models pm,
  products p,
  customers cs,
  customer_segments csseg,
  customer_segment_members cssegmems
WHERE TO_CHAR(crm.item_number) = pm.shop_code
AND p.product_model_id         = pm.product_model_id
AND cs.migros_card_no = TO_CHAR(crm.MIGROSCARDNUMBER)
AND csseg.segment_id = cssegmems.segment_id
AND cssegmems.customer_id = cs.customer_id
GROUP BY p.product_id,
  cs.customer_id,
  csseg.segment_id,
  csseg.name;

spool off;
exit;
