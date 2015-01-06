SET COLSEP '|'
    SET ECHO OFF
    SET FEEDBACK OFF
    SET TERMOUT OFF
    SET PAGESIZE 0
    SET LINESIZE 30000
    SET TERM ON
    SET TRIMS ON
    SET TRIMSPOOL OFF
    SET UNDERLINE OFF
    SET ARRAYSIZE 500


SELECT cs.CUSTOMER_ID,
  cs.initial_referrer,
  cr.stream_id,
  TO_CHAR(cr.TIME_STAMP,'YYYY-MM-DD HH24:MI:SS'),
  cr.REQUEST_URI,
  cr.query_string
FROM clickstream_requests_2014 cr,
  clickstreams_2014 cs
WHERE cs.customer_id IS NOT NULL
AND cr.stream_id      = cs.STREAM_ID
AND  (REGEXP_LIKE(cr.request_uri,'^/kweb/searchInShop|^/mobile/iphone/searchInShop|^/mobile/android/searchInShop','i') OR
 REGEXP_LIKE(cr.request_uri,'^/kweb/getLazyProductDetail.do|^/kweb/showProductDetail.do|^/kweb/prview|/kweb/prcview','i') OR
 REGEXP_LIKE(cr.request_uri,'^/kweb/addMultipleProductsToCart.do|^/kweb/addToCart.do','i') OR
 REGEXP_LIKE(cr.request_uri,'^/mobile/android/getLazyProductDetail.do|^/mobile/android/showProductDetail.do|^/mobile/android/prview|/kweb/prcview','i') OR
 REGEXP_LIKE(cr.request_uri,'^/mobile/iphone/getLazyProductDetail.do|^/mobile/iphone/showProductDetail.do|^/mobile/iphone/prview|/kweb/prcview','i') OR
 REGEXP_LIKE(cr.request_uri,'^/mobile/android/addMultipleProductsToCart.do|^/mobile/android/addToCart.do','i') OR
 REGEXP_LIKE(cr.request_uri,'^/iphone/android/addMultipleProductsToCart.do|^/mobile/iphone/addToCart.do','i') )
AND  cr.time_stamp >= TO_DATE('01-&1-2014','dd-MON-yyyy') AND  cr.time_stamp < TO_DATE('5-&1-2014','dd-MON-yyyy'); 

EXIT

