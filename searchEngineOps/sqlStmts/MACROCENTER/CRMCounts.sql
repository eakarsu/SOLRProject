SELECT p.product_id,
  SUM(crm.product_quantity_sum) "AMOUNT",
  SUM(crm.product_trans_count) "ORDER_COUNT"
FROM CRM.SPSS_VM_KART_ITEM crm,
  MACROCENTER.product_models pm,
  MACROCENTER.products p
WHERE TO_CHAR(crm.item_number) = REGEXP_REPLACE(pm.shop_code,'^0+','')
AND p.product_model_id         = pm.product_model_id
GROUP BY p.product_id
