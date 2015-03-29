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
  PRODUCT_SALES_INFOS psi,
  STORES st
WHERE
 psi.store_id              = st.store_id
ORDER BY psi.product_id
