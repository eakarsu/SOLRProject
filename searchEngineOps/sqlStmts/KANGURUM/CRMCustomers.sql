SELECT p.product_id,
  cs.customer_id
FROM CRM.SPSS_VM_KART_ITEM crm,
  KANGURUM.product_models pm,
  KANGURUM.products p,
  KANGURUM.customers cs
WHERE TO_CHAR(crm.item_number) = REGEXP_REPLACE(pm.shop_code,'^0+','')
AND p.product_model_id         = pm.product_model_id
AND cs.migros_card_no          = TO_CHAR(crm.MIGROSCARDNUMBER)
GROUP BY cs.CUSTOMER_ID,
p.PRODUCT_ID
ORDER BY p.PRODUCT_ID

