SELECT pm.PRODUCT_MODEL_ID,
  pm.PRODUCT_MODEL_NAME,
  pm.DESCRIPTION,
  pm.SHOP_CODE,
  pm.SHOP_ID,
  pm.BRAND_ID,
  pm.IS_MIGROSKOP,
  p.PRODUCT_ID,  
  pm.stock_model,
  pm.IS_NEW
FROM KANGURUM.PRODUCTS p,
  KANGURUM.PRODUCT_MODELS pm,
  KANGURUM.SHOPS s
WHERE
p.product_model_id        = pm.product_model_id
AND p.is_active               = 1
AND pm.SHOP_ID                = s.SHOP_ID
AND (s.is_active              = 1
AND s.SHOULD_PRODUCTS_INDEXED = 1)
AND pm.is_active              = 1
