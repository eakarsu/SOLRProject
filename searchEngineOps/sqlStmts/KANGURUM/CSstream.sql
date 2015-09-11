SELECT cs.CUSTOMER_ID,
  cs.initial_referrer,
  cr.stream_id,
  cr.TIME_STAMP,
  cr.REQUEST_URI,
  cr.query_string
FROM KANGURUM.clickstream_requests_2014 cr,
  KANGURUM.clickstreams_2014 cs
WHERE cs.customer_id IS NOT NULL
AND cr.stream_id      = cs.STREAM_ID
AND  (REGEXP_LIKE(cr.request_uri,'^/kweb/searchInShop|^/mobile/iphone/searchInShop|^/mobile/android/searchInShop','i') OR
 REGEXP_LIKE(cr.request_uri,'^/kweb/getLazyProductDetail.do|^/kweb/showProductDetail.do|^/kweb/prview|/kweb/prcview','i') OR
 REGEXP_LIKE(cr.request_uri,'^/kweb/addMultipleProductsToCart.do|^/kweb/addToCart.do','i') OR
 REGEXP_LIKE(cr.request_uri,'^/mobile/android/getLazyProductDetail.do|^/mobile/android/showProductDetail.do|^/mobile/android/prview|/kweb/prcview','i') OR
 REGEXP_LIKE(cr.request_uri,'^/mobile/iphone/getLazyProductDetail.do|^/mobile/iphone/showProductDetail.do|^/mobile/iphone/prview|/kweb/prcview','i') OR
 REGEXP_LIKE(cr.request_uri,'^/mobile/android/addMultipleProductsToCart.do|^/mobile/android/addToCart.do','i') OR
 REGEXP_LIKE(cr.request_uri,'^/iphone/android/addMultipleProductsToCart.do|^/mobile/iphone/addToCart.do','i') OR
 REGEXP_LIKE(cr.request_uri, '^/kweb/scview|^/kweb/mobile/iphone/scview|^/kweb/mobile/android/scview','i') OR
 REGEXP_LIKE(cr.request_uri, '^/kweb/sclist|^/kweb/mobile/iphone/sclist|^/kweb/mobile/android/sclist','i') OR
 REGEXP_LIKE(cr.request_uri, '^/kweb/getProductList|^/kweb/mobile/iphone/getProductList|^/kweb/mobile/android/getProductList','i') OR
 REGEXP_LIKE(cr.request_uri, '^/kweb/getCategoryList|^/kweb/mobile/iphone/getCategoryList|^/kweb/mobile/android/getCategoryList','i') OR
 REGEXP_LIKE(cr.request_uri, '^/kweb/browseShopCatalog|^/kweb/mobile/iphone/browseShopCatalog|^/kweb/mobile/android/browseShopCatalog','i') 
)
AND  cr.time_stamp >= TO_DATE('SDATE','yyyy-mm-dd') AND  cr.time_stamp <= TO_DATE('EDATE','yyyy-mm-dd') 
