/*****************************************
** Application	: Clarity
** Description	: Patient Homelessness Status
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
/***Homelessness for encounters within start and end date***/

with CTE AS (
select  distinct
pe.PAT_ENC_CSN_ID
,PE.PAT_ID
,pt.ADD_LINE_1
,pt.ADD_LINE_2
,pa.ADDRESS [address1]
,pa2.ADDRESS [address2]
,pt.ZIP
,pe.CONTACT_DATE
,pt.BIRTH_DATE
,FLOOR(DATEDIFF(day, pt.BIRTH_DATE,pe.CONTACT_DATE ) / 365.25) as [AGE]
,case
	when pa.ADDRESS like '%General Delivery%'		--Per Patient Registration, General Delivery is the address entered for homeless patients 
		or pa2.address like '%homeless%'			--address 2 also may have entered a 'homeless' designation
		then 'Homeless'
		else 'Not Homeless'
		end as 'Homeless Status'
from pat_enc pe
join patient pt on pe.PAT_ID = pt.PAT_ID
join PAT_ADDRESS pa on pe.pat_id = pa.PAT_ID and pa.LINE = 1			--capture general delivery
left join PAT_ADDRESS pa2 on pe.PAT_ID = pa2.PAT_ID and pa2.LINE = 2	--capture "homeless"
JOIN VALID_PATIENT V ON PE.PAT_ID = V.PAT_ID
left join pat_enc_hsp hsp on pe.PAT_ENC_CSN_ID = hsp.PAT_ENC_CSN_ID

where 1=1
and pe.CONTACT_DATE between @STARTDATE and @ENDDATE
and (pe.APPT_CANCEL_DATE is null	--exclude canceled appointments
or hsp.ED_DISPOSITION_C not in (6,19))	--exclude LWBS or Never Arrived
and pe.SERV_AREA_ID = @SERVAREAID
AND V.IS_VALID_PAT_YN = 'Y'

)

,
SUMMARY AS (SELECT 
PE.[Homeless Status],
count(distinct(pe.pat_id)) [Patients],
COUNT(PE.PAT_ENC_CSN_ID) [Patient Visits]
FROM CTE PE
where AGE >17
Group by PE.[Homeless Status]

)




select *
, CAST([Patient Visits]*100.0 / SUM([Patient Visits]) OVER()  as Decimal(10,2)) as [%Visits]
, CAST([Patients]*100.0 / SUM([Patients]) OVER()  as Decimal(10,2)) as [%Patients]

FROM SUMMARY 
