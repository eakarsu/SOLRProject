SET COLSEP '|'
    SET ECHO OFF
    SET FEEDBACK OFF
    SET TERMOUT OFF
    SET PAGESIZE 0
    SET LINESIZE 327 
    SET TERM OFF
    SET TRIMS ON
    SET TRIMSPOOL ON
    SET UNDERLINE OFF

    SPOOL psi_output_file_stock_info.csv
	
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
  STORES st,
  PRODUCT_MODELS pm,
  PRODUCTS p
WHERE
  p.product_model_id        = pm.product_model_id
AND p.product_id              =psi.product_id
AND psi.store_id              = st.store_id
AND st.is_active              = 1
AND (( pm.stock_model        <> 1
	AND psi.stock_amount          > 0
     )
     OR pm.stock_model             = 1) ;

SPOOL OFF
EXIT
