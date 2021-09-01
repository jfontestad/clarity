select 
p.pat_id, PAT_NAME,class.NAME [Class],  hsp.HOSP_ADMSN_TIME, ser.PROV_NAME [Attending Prov]
,regConfig.DISPLAY_NAME
--,reg.*
from CLARITY.dbo.PAT_ENC_HSP hsp
join CLARITY.dbo.PATIENT p on hsp.PAT_ID = p.pat_id
join CLARITY.dbo.HSP_ATND_PROV prov on hsp.PAT_ENC_CSN_ID = prov.PAT_ENC_CSN_ID and line = 1
join CLARITY.dbo.CLARITY_SER ser on prov.PROV_ID = ser.PROV_ID
left join CLARITY.dbo.PAT_ACTIVE_REG reg on hsp.pat_id = reg.PAT_ID
left join CLARITY.dbo.REGISTRY_CONFIG regConfig on reg.REGISTRY_ID = regConfig.REGISTRY_ID
left join CLARITY.dbo.ZC_PAT_CLASS class on hsp.ADT_PAT_CLASS_C = class.ADT_PAT_CLASS_C
where hsp.HOSP_ADMSN_TIME >= '3/1/2021' 
--and p.pat_id = 'Z2291100'
and hsp.ADT_PAT_CLASS_C = '101'
and reg.REGISTRY_ID = '82299' -- Wellness Registry: All