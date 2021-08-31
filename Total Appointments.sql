USE [CLARITY]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



-- =====================================================================
-- Author:		M Horner
-- Create date: 6/7/2021
-- Description:	Total Appointments
-- =====================================================================
-- Change Log
-- =====================================================================
-- Date of Change |Change                                   | Developer
-- =====================================================================
-- 00/00/00       |                                         | 
-- 00/00/00       |                                         | 
-- =====================================================================


with appt as (
SELECT DISTINCT
v.PAT_ENC_CSN_ID
,v.HSP_ACCOUNT_ID
,p.PAT_MRN_ID
,p.PAT_NAME
,CONVERT(DATE,v.APPT_MADE_DATE)	'Sched_Date'
,CONVERT(DATE,v.CONTACT_DATE)	'Appt_Date'
,v.APPT_DTTM
,v.APPT_SCHED_SOURCE_C
,v.APPT_SCHED_SOURCE_NAME
,v.PRC_ID
,v.PRC_NAME
,v.DEPARTMENT_ID
,v.DEPARTMENT_NAME
,v.SERV_AREA_ID
,v.LOC_ID
,v.LOC_NAME
,v.WALK_IN_YN
,v.PAT_ONLINE_YN
,v.PAT_SCHED_MYC_STAT_C
,v.PAT_SCHED_MYC_STAT_NAME
,v.APPT_STATUS_C
,v.APPT_STATUS_NAME
,COALESCE(p3.EMPL_ID_NUM,a2.EMPL_ID_NUM,a22.EMPL_ID_NUM,'') 'Employee_Id'

FROM
V_SCHED_APPT v
JOIN VALID_PATIENT vp ON v.PAT_ID = vp.PAT_ID AND vp.IS_VALID_PAT_YN = 'Y'
JOIN PATIENT p ON v.PAT_ID = p.PAT_ID
left JOIN CLARITY_PRC prc ON v.PRC_ID = prc.PRC_ID
	--AND prc.RPT_GRP_TWENTY_C in (3)
LEFT JOIN PATIENT_3 p3 ON p.PAT_ID = p3.PAT_ID
LEFT JOIN HSP_ACCOUNT ha ON v.HSP_ACCOUNT_ID = ha.HSP_ACCOUNT_ID
LEFT JOIN ACCOUNT_2 a2 ON ha.GUARANTOR_ID = a2.ACCT_ID  --EMP ID from HAR
LEFT JOIN PAT_ACCT_CVG pac ON p.PAT_ID = pac.PAT_ID AND pac.LINE = 1
LEFT JOIN ACCOUNT_2 a22 ON pac.ACCOUNT_ID = a22.ACCT_ID  --EMP ID from EAR

WHERE 1=1
AND v.SERV_AREA_ID = 10
and cast(v.APPT_DTTM as date) between '2019-01-01' and '2019-12-01'
and v.APPT_CANC_DTTM is null
and v.APPT_STATUS_C = 2 --completed only
)


select 
LOC_NAME
,DEPARTMENT_NAME
,count(PAT_ENC_CSN_ID) [Total Appts]
from appt

group by 

LOC_NAME
,DEPARTMENT_NAME
order by LOC_NAME

