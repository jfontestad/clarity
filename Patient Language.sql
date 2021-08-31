/*****************************************
** Application	: Clarity
** Description	: Patient Language Distribution
** Author		: Margaret Horner 
** Date			: 8/6/2020
******************************************
** Change History
******************************************
** Date     Author    Description	
** ------   -------   ------------------------------------
**   	  
******************************************/


DECLARE @SERVAREAID VARCHAR(30) = '10' 
DECLARE @STARTDATE SMALLDATETIME = '2019-07-01'
DECLARE @ENDDATE  SMALLDATETIME = '2020-06-30';


/*****     Include Ethnicity to capture hispanic v. non-hispanic     *****/
with CTE as (
select 
zl.name  'Language',
count(distinct(pe.pat_id)) 'Patients',
COUNT(PE.PAT_ENC_CSN_ID) 'Visits'
from 
PAT_ENC pe
JOIN VALID_PATIENT V ON PE.PAT_ID = V.PAT_ID
join PATIENT pt on pe.PAT_ID = pt.PAT_ID
left join ZC_LANGUAGE zl on pt.LANGUAGE_C = zl.LANGUAGE_C
left join pat_enc_hsp hsp on pe.PAT_ENC_CSN_ID = hsp.PAT_ENC_CSN_ID

where pe.CONTACT_DATE between @STARTDATE and @ENDDATE
 and (pe.APPT_CANCEL_DATE is null	--exclude canceled appointments
or hsp.ED_DISPOSITION_C not in (6,19))	--exclude LWBS or Never Arrived
and pe.SERV_AREA_ID = @SERVAREAID
AND V.IS_VALID_PAT_YN = 'Y'

Group by
zl.name 

)
/***Race with ethnicity for encounters within start and end date***/
select *
, CAST(Visits*100.0 / SUM(Visits) OVER()  as Decimal(10,2)) as [%Visits]
, CAST(Patients*100.0 / SUM(Patients) OVER()  as Decimal(10,2)) as [%Patients]

FROM cte 
ORDER BY CTE.Language

;
/*****     Exclude Ethnicity    *****/

with CTE as (
select 
zl.name  'Language',
count(distinct(pe.pat_id)) 'Patients',
COUNT(distinct(PE.PAT_ENC_CSN_ID)) 'Visits'
from 
PAT_ENC pe
JOIN VALID_PATIENT V ON PE.PAT_ID = V.PAT_ID
join PATIENT pt on pe.PAT_ID = pt.PAT_ID
left join ZC_LANGUAGE zl on pt.LANGUAGE_C = zl.LANGUAGE_C
left join pat_enc_hsp hsp on pe.PAT_ENC_CSN_ID = hsp.PAT_ENC_CSN_ID
where pe.CONTACT_DATE between @STARTDATE and @ENDDATE
 and (pe.APPT_CANCEL_DATE is null	--exclude canceled appointments
or hsp.ED_DISPOSITION_C not in (6,19))	--exclude LWBS or Never Arrived
and pe.SERV_AREA_ID = @SERVAREAID
AND V.IS_VALID_PAT_YN = 'Y'

Group by
zl.name 

)
/***Race without ethnicity for encounters within start and end date***/
select *
, CAST(Visits*100.0 / SUM(Visits) OVER()  as Decimal(10,2)) as [%Visits]
, CAST(Patients*100.0 / SUM(Patients) OVER()  as Decimal(10,2)) as [%Patients]

FROM cte 
ORDER BY CTE.Language