select top 100
* 
from CLARITY_EAP
where proc_code like '%M0239%' --,'Q0239')

select MEDICATION_ID, * from ORDER_MED where MEDICATION_ID in ('183105','183168','183341','4082015','4082016') 
select top 10  * from ORDER_DISP_INFO
select * from CLARITY_MEDICATION where name like '%BAMLANIVIMAB%'
select top 10 * from MAR_ADMIN_INFO
 select top 100 * from CLARITY_PRC where PRC_ABBR = 'Q0239'
select top 100 * from HSP_TRANSACTIONS where CPT_CODE =  'Q0239'
select top 10 * from CLARITY_EDG where CURRENT_ICD10_LIST = 'Q0239' or CURRENT_ICD9_LIST = 'Q0239'
----------------------------------

SELECT 
med.NAME, omed.ORDER_MED_ID, mar.CONTACT_DATE,rslt.NAME
,marInfo.* 
FROM ORDER_MED omed 
join ORDER_DISP_INFO odi on omed.ORDER_MED_ID = odi.ORDER_MED_ID 
join MAR_ADDL_INFO mar on odi.ORDER_MED_ID = mar.ORDER_ID and odi.CONTACT_DATE_REAL = mar.CONTACT_DATE_REAL
left join MAR_ADMIN_INFO marInfo on mar.ORDER_ID = marInfo.ORDER_MED_ID
join CLARITY_MEDICATION med on omed.MEDICATION_ID = med.MEDICATION_ID
join 	ZC_MAR_RSLT rslt on marInfo.MAR_ACTION_C = rslt.RESULT_C
where omed.MEDICATION_ID in ('183105','183168','183341','4082015','4082016') 
--and odi.ORDER_MED_ID = '48780294'
and odi.ORD_CNTCT_TYPE_C = '7' --administration
and marInfo.MAR_ACTION_C in ('6') --,'9','14','100')
order by mar.CONTACT_DATE, omed.ORDER_MED_ID

select 
top 100 rslt.NAME, f.MAR_ACTION_C,
f.* 
from F_IP_HSP_SUM_MED_ADMIN f
join 	ZC_MAR_RSLT rslt on f.MAR_ACTION_C = rslt.RESULT_C
where DISPLAY_NAME like  '%BAMLANIVIMAB%'
order by ORDER_MED_ID
