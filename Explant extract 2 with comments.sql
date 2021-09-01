select 
e.EXPLANT_LOG_ID	[caseNumber]
,'University Medical Center' as [hospitalLocation]
,format(c.SURGERY_DATE,'MM/dd/yyyy')	[procedureDate]
,v.PROCEDURE_NM [procedureDescription]
--,e.EXPLANT_STAFF_ID	
,PATIENT.PAT_MRN_ID [patientMRN]
,format(PATIENT.BIRTH_DATE,'MM/dd/yyyy') [patientBirthDate]
,PATIENT.PAT_FIRST_NAME [patientFirstName]
,PATIENT.PAT_LAST_NAME [patientLastName]
,SUBSTRING(s.prov_name,
     CHARINDEX(' ', s.prov_name) + 1,
     LEN(s.prov_name) - CHARINDEX(' ', s.prov_name)) AS physicianFirstName
,replace(SUBSTRING(s.prov_name, 1, CHARINDEX(' ', s.prov_name) - 1),',','') AS physicianLastName

,c.PRIMARY_PHYSICIAN_ID [physicianID ]
,s2.NPI [physicianExternalID]

,coalesce(string_agg(comms.COMMENTS,' , ')	,'')	[caseComments]
,z.NAME [caseType]
,i.MODEL_NUMBER [productCode ]
,coalesce(i.SERIAL_NUMBER,'') [serialNumber]
,e.IMPLANT_ID [implantID]
,'' [originalImplantDate]
,format(e.EXPLANTED_DATE,'MM/dd/yyyy') [secondaryActionDate]
--,i.CHARGE_CODE_EAP_ID
,i.COST_PER_UNIT [itemCost]
,epm.PAYOR_NAME [replacementPayor]
,i.IMPLANT_NAME

from OR_IMP_EXPLANT e
join OR_IMP i on e.IMPLANT_ID = i.IMPLANT_ID
join OR_CASE c on e.EXPLANT_LOG_ID = c.LOG_ID
join V_PXPASS v on e.EXPLANT_LOG_ID = v.LOG_ID
join OR_LNLG_IMPLANTS l on i.IMPLANT_ID = l.IMPLANT_ID and l.IMPLANT_ACTION_C in (2,110)
join PATIENT on c.PAT_ID = PATIENT.PAT_ID
join clarity_ser s on c.PRIMARY_PHYSICIAN_ID = s.PROV_ID
left join clarity_ser_2 s2 on c.PRIMARY_PHYSICIAN_ID = s2.PROV_ID
left join PAT_OR_ADM_LINK p on e.EXPLANT_LOG_ID = p.LOG_ID
left join PAT_ENC_HSP peh on p.OR_LINK_CSN = peh.PAT_ENC_CSN_ID
left join HSP_ACCOUNT har on peh.HSP_ACCOUNT_ID = har.HSP_ACCOUNT_ID
left join CLARITY_EPM epm on har.PRIMARY_PAYOR_ID = epm.PAYOR_ID
left join

(select distinct v.LOG_ID
,v.PROCEDURE_ID
,ap.COMMENTS
from
V_LOG_PROCEDURES v 
join OR_CASE_ALL_PROC ap on v.CASE_ID = ap.OR_CASE_ID and v.PROCEDURE_ID = ap.OR_PROC_ID
where ap.COMMENTS is not null) comms on v.LOG_ID = comms.LOG_ID
--and v.PROCEDURE_ID = comms.PROCEDURE_ID
left join ZC_IMPLANT_ACTION z on l.IMPLANT_ACTION_C = z.IMPLANT_ACTION_C
join VALID_PATIENT vp on i.PAT_ID = vp.PAT_ID and vp.IS_VALID_PAT_YN = 'Y'

where 1=1
--and e.EXPLANT_LOG_ID = '215367'
and c.CANCEL_DATE is null
and i.IMPLANT_NAME not like '%screw%'
--and e.EXPLANTED_DATE >= '2021-01-01'
and har.SERV_AREA_ID = 10
Group By
e.IMPLANT_ID 
,e.EXPLANT_LOG_ID	
,c.SURGERY_DATE
,e.EXPLANTED_DATE	
,v.PROCEDURE_NM 
--,e.EXPLANT_STAFF_ID	
,PATIENT.PAT_MRN_ID 
,PATIENT.BIRTH_DATE 
,PATIENT.PAT_FIRST_NAME 
,PATIENT.PAT_LAST_NAME 
,i.IMPLANT_NAME
,c.PRIMARY_PHYSICIAN_ID 
,s2.NPI 
,i.MODEL_NUMBER 
,i.SERIAL_NUMBER 
,i.MANUF_NUM
,i.SUP_CAT_NUM
,i.COST_PER_UNIT 
,i.PAT_ID
,s.prov_name
,l.IMPLANT_ACTION_C

,z.NAME
,epm.PAYOR_NAME

Order by patientMRN

/*
dont want screws
items that carry warranties or carry an offset
--focus on crm devices in the begin id warranty claim item the open it up for additional items
caridac rythimc management
defibulators, leads, pacemakers good starting point (cath lab, ed labs)

implant date is require need a way to deterime this (find out from clinical staff they should have date of original implant should be charted)

can do an implant and explant report or just on report showing both (implanted, explanted and implanted, explanted
warranty claim item when explanted and replace by new implant

cliff to send script that may help filter results down
*/