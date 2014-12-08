SELECT pm.PRODUCT_MODEL_ID,
  pm.PRODUCT_MODEL_NAME,
  pm.DESCRIPTION,
  pm.SHOP_CODE,
  pm.SHOP_ID,
  pm.BRAND_ID,
  pm.IS_MIGROSKOP,
  p.PRODUCT_ID,
  pmsk.SEARCH_KEYWORD_VALUE,
  st.store_id,
  psi.price,
  psi.mcc_price,
  psi.action_price,
  psi.promotion_type
FROM PRODUCTS p,
  PRODUCT_MODELS pm,
  SHOPS s,
  PRODUCT_MODEL_SEARCH_KEYWORDS pmsk,
  PRODUCT_SALES_INFOS psi,
  STORES st
WHERE
p.product_model_id        = pm.product_model_id
AND p.product_id              =psi.product_id
AND psi.store_id              = st.store_id
AND st.is_active              = 1
AND (( pm.stock_model        <> 1
AND psi.stock_amount          > 0)
OR pm.stock_model             = 1)
AND p.is_active               = 1
AND pm.SHOP_ID                = s.SHOP_ID
AND (s.is_active              = 1
AND s.SHOULD_PRODUCTS_INDEXED = 1)
AND pm.PRODUCT_MODEL_ID       = pmsk.PRODUCT_MODEL_ID(+)
AND pm.is_active              = 1
