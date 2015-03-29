SELECT p.product_id,
  seg.son_segment,
  seg.RFM_SANAL,
  SUM(crm.product_quantity_sum) "AMOUNT",
  SUM(crm.product_trans_count) "ORDER_COUNT"
FROM CRM.SPSS_VM_KART_ITEM crm,
  product_models pm,
  products p,
  CRM.SPSS_VM_SEGMENT seg
WHERE TO_CHAR(crm.item_number) = REGEXP_REPLACE(pm.shop_code,'^0+','')
AND crm.MIGROSCARDNUMBER       = seg.MIGROSCARDNUMBER
AND p.product_model_id         = pm.product_model_id
GROUP BY p.product_id,
  seg.son_segment,
  seg.RFM_SANAL
ORDER BY p.product_id
