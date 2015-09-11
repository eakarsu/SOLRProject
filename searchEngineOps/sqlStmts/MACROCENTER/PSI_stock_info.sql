SELECT 
  psi.product_id,
  psi.price,
  psi.mcc_price,
  psi.action_price,
  psi.promotion_type,
  psi.product_sales_info_id,
  psi.stock_amount,
  st.store_id
FROM 
  MACROCENTER.PRODUCT_SALES_INFOS psi,
  MACROCENTER.STORES st,
  MACROCENTER.PRODUCT_MODELS pm,
  MACROCENTER.PRODUCTS p
WHERE
  p.product_model_id        = pm.product_model_id
AND p.product_id              =psi.product_id
AND psi.store_id              = st.store_id
AND st.is_active              = 1
AND (( pm.stock_model        <> 1
	AND psi.stock_amount          > 0
     )
     OR pm.stock_model             = 1) 
ORDER BY psi.product_id
