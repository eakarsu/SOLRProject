SELECT p.product_id,
  cs.customer_id,
  seg.son_segment,
  seg.RFM_SANAL,
  SUM(crm.product_quantity_sum) "AMOUNT",
  SUM(crm.product_trans_count) "ORDER_COUNT"
FROM CRM.SPSS_VM_KART_ITEM crm,
  KANGURUM.product_models pm,
  KANGURUM.products p,
  KANGURUM.customers cs,
  CRM.SPSS_VM_SEGMENT seg
WHERE TO_CHAR(crm.item_number) = REGEXP_REPLACE(pm.shop_code,'^0+','')
AND crm.MIGROSCARDNUMBER       = seg.MIGROSCARDNUMBER
AND p.product_model_id         = pm.product_model_id
AND cs.migros_card_no          = TO_CHAR(seg.MIGROSCARDNUMBER)
GROUP BY p.product_id,
  cs.customer_id,
  seg.son_segment,
  seg.RFM_SANAL
ORDER BY p.product_id
