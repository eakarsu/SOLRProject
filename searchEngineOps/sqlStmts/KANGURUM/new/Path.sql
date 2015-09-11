SELECT DISTINCT pm.product_model_id,
  shop_code,
  c.* ,
  sc.shop_category_id "SHOP_CATEGORY_ID"
FROM product_models pm,
  categorized_product_models cpm,
  shop_categories sc,
  (SELECT category_id,
    name "SHOP_CATEGORY_NAME",
	name_en "SHOP_CATEGORY_NAME_EN",
    CONNECT_BY_ISLEAF "IsLeaf",
    LEVEL,
    SYS_CONNECT_BY_PATH(name, '\') "Path"
  FROM categories
  WHERE migroscategory           =1
  AND is_active                  =1
    START WITH category_id      IN (0)
    CONNECT BY PRIOR category_id = parent_category_id
  ) c
WHERE pm.product_model_id  =cpm.product_model_id
AND is_not_default_category=0
AND cpm.shop_category_id   =sc.shop_category_id
AND sc.category_id         =c.category_id
