/*****************************************
** Application	: Clarity
** Description	: Patient Race Distribution
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
DECLARE @STARTDATE SMALLDATETIME = '2019-01-01'
DECLARE @ENDDATE  SMALLDATETIME = '2020-12-31';


/*****     Include Ethnicity to capture hispanic v. non-hispanic     *****/
with CTE as (
select 
datepart(year,pe.CONTACT_DATE) [Year], 
z.name  'Race',
coalesce(zeg.name,'Unknown')  'Ethnic Group',
count(distinct(pe.pat_id)) 'Patients',
COUNT(PE.PAT_ENC_CSN_ID) 'Visits'
from 
PAT_ENC pe
join PATIENT_RACE on pe.PAT_ID = PATIENT_RACE.PAT_ID and patient_race.LINE = 1
join ZC_PATIENT_RACE z on PATIENT_RACE.PATIENT_RACE_C = z.PATIENT_RACE_C
JOIN VALID_PATIENT V ON PE.PAT_ID = V.PAT_ID
join PATIENT pt on pe.PAT_ID = pt.PAT_ID
left join ZC_ETHNIC_GROUP zeg on pt.ETHNIC_GROUP_C = zeg.ETHNIC_GROUP_C
left join pat_enc_hsp hsp on pe.PAT_ENC_CSN_ID = hsp.PAT_ENC_CSN_ID

where pe.CONTACT_DATE between @STARTDATE and @ENDDATE
 and (pe.APPT_CANCEL_DATE is null	--exclude canceled appointments
or hsp.ED_DISPOSITION_C not in (6,19))	--exclude LWBS or Never Arrived
and pe.SERV_AREA_ID = @SERVAREAID
AND V.IS_VALID_PAT_YN = 'Y'

Group by
datepart(year,pe.CONTACT_DATE) , 
z.name ,
zeg.name 

)
/***Race with ethnicity for encounters within start and end date***/
select *
, CAST(Visits*100.0 / SUM(Visits) OVER()  as Decimal(10,2)) as [%Visits]
, CAST(Patients*100.0 / SUM(Patients) OVER()  as Decimal(10,2)) as [%Patients]

FROM cte 
ORDER BY CTE.Race,cte.[Ethnic Group],cte.Year

;
/*****     Exclude Ethnicity    *****/

with CTE as (
select 
datepart(year,pe.CONTACT_DATE) [Year], 
z.name  'Race',
count(distinct(pe.pat_id)) 'Patients',
COUNT(PE.PAT_ENC_CSN_ID) 'Visits'
from 
PAT_ENC pe
join PATIENT_RACE on pe.PAT_ID = PATIENT_RACE.PAT_ID and patient_race.LINE = 1
join ZC_PATIENT_RACE z on PATIENT_RACE.PATIENT_RACE_C = z.PATIENT_RACE_C
JOIN VALID_PATIENT V ON PE.PAT_ID = V.PAT_ID
join PATIENT pt on pe.PAT_ID = pt.PAT_ID
left join ZC_ETHNIC_GROUP zeg on pt.ETHNIC_GROUP_C = zeg.ETHNIC_GROUP_C
left join pat_enc_hsp hsp on pe.PAT_ENC_CSN_ID = hsp.PAT_ENC_CSN_ID

where pe.CONTACT_DATE between @STARTDATE and @ENDDATE
 and (pe.APPT_CANCEL_DATE is null	--exclude canceled appointments
or hsp.ED_DISPOSITION_C not in (6,19))	--exclude LWBS or Never Arrived
and pe.SERV_AREA_ID = @SERVAREAID
AND V.IS_VALID_PAT_YN = 'Y'


Group by
datepart(year,pe.CONTACT_DATE), 
z.name 

)
/***Race without ethnicity for encounters within start and end date***/
select *
, CAST(Visits*100.0 / SUM(Visits) OVER()  as Decimal(10,2)) as [%Visits]
, CAST(Patients*100.0 / SUM(Patients) OVER()  as Decimal(10,2)) as [%Patients]

FROM cte 
ORDER BY CTE.Race,cte.Year