set LINESIZE 32000
set LONG 32000
set LONGCHUNKSIZE 32000
SET TRIMSPOOL ON
SET TRIMOUT ON
SET WRAP OFF
SET TERMOUT OFF
SET PAGESIZE 0
set hea off
set heads off
set echo off
set feedback off

!echo '<RECORDS>' > CRM.xml

spool CRM.xml append

SELECT  XMLElement("record",
XMLElement("PRODUCT_ID",p.product_id),
	 XMLElement("CUSTOMER_ID",cs.customer_id),
      XMLElement("SON_SEGMENT",seg.SON_SEGMENT),
	 XMLElement("CUSTOMER_SEGMENT_NAME",csseg.name ),
	 XMLElement("CUSTOMER_SEGMENT_ID",csseg.segment_id ),
      XMLElement("AMOUNT",SUM(crm.PRODUCT_QUANTITY_SUM)),
      XMLElement("ORDER_COUNT",SUM(crm.PRODUCT_TRANS_COUNT))) as "RESULT"
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

spool off;
!echo '</RECORDS>' >> CRM.xml
exit
