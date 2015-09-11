SELECT cs.CUSTOMER_ID,
  cs.initial_referrer,
  cr.stream_id,
  cr.TIME_STAMP,
  cr.REQUEST_URI,
  cr.query_string
FROM clickstream_requests cr,
  clickstreams cs
WHERE cs.customer_id IS NOT NULL
AND cr.stream_id      = cs.STREAM_ID
AND  cr.time_stamp >= TO_DATE('SDATE','yyyy-mm-dd hh24:mi:ss') 
AND  cr.time_stamp <= TO_DATE('EDATE','yyyy-mm-dd hh24:mi:ss') 
