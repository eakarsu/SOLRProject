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
  CRM.SPSS_VM_SEGMENT seg
WHERE TO_CHAR(crm.item_number) = pm.shop_code
AND crm.MIGROSCARDNUMBER       = seg.MIGROSCARDNUMBER
AND p.product_model_id         = pm.product_model_id
AND cs.migros_card_no = TO_CHAR(seg.MIGROSCARDNUMBER)
AND csseg.customer_id = cs.customer_id
GROUP BY p.product_id,
  cs.customer_id,
  csseg.segment_id,
  csseg.name,
  seg.son_segment;
