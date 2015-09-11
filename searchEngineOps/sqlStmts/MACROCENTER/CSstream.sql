SELECT cs.CUSTOMER_ID,
  cs.initial_referrer,
  cr.stream_id,
  cr.TIME_STAMP,
  cr.REQUEST_URI,
  cr.query_string
FROM MACROCENTER.clickstream_requests cr,
  MACROCENTER.clickstreams cs
WHERE cs.customer_id IS NOT NULL
AND cr.stream_id      = cs.STREAM_ID
AND  (REGEXP_LIKE(cr.request_uri,'^/macro/searchInShop','i') OR
 REGEXP_LIKE(cr.request_uri,'^/macro/getLazyProductDetail.do|^/macro/showProductDetail.do|^/macro/prview|/macro/prcview','i') OR
 REGEXP_LIKE(cr.request_uri,'^/macro/addMultipleProductsToCart.do|^/macro/addToCart.do','i') OR
 REGEXP_LIKE(cr.request_uri, '^/macro/scview','i') OR
 REGEXP_LIKE(cr.request_uri, '^/macro/sclist','i') OR
 REGEXP_LIKE(cr.request_uri, '^/macro/getProductList','i') OR
 REGEXP_LIKE(cr.request_uri, '^/macro/getCategoryList','i') OR
 REGEXP_LIKE(cr.request_uri, '^/macro/browseShopCatalog','i') 
)
AND  cr.time_stamp >= TO_DATE('SDATE','yyyy-mm-dd') AND  cr.time_stamp <= TO_DATE('EDATE','yyyy-mm-dd') 
