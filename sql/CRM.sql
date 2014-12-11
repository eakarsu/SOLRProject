select  p.product_id,seg.son_segment,sum(crm.product_quantity_sum)  "AMOUNT", sum(crm.product_trans_count) "ORDER_COUNT"
from CRM.SPSS_VM_KART_ITEM crm,product_models pm,products p, CRM.SPSS_VM_SEGMENT seg
where to_char(crm.item_number) = pm.shop_code
      AND crm.MIGROSCARDNUMBER = seg.MIGROSCARDNUMBER
      AND p.product_model_id = pm.product_model_id
group by p.product_id,seg.son_segment;