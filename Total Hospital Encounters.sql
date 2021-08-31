select 
z.NAME [Patient Class]
,count(peh.PAT_ENC_CSN_ID) [Total Hospital Encounters]
--,peh.HSP_ACCOUNT_ID
--,peh.HOSP_ADMSN_TIME
--,peh.HOSP_DISCH_TIME
from PAT_ENC_HSP peh
left join ZC_PAT_CLASS z on peh.ADT_PAT_CLASS_C = z.ADT_PAT_CLASS_C
join VALID_PATIENT v on peh.PAT_ID = v.PAT_ID

where v.IS_VALID_PAT_YN = 'Y'
and cast(peh.HOSP_DISCH_TIME as date) between '2019-01-01' and '2019-12-31'
--and peh.ADT_PAT_CLASS_C = '106'
and peh.CANCEL_USER_ID is null
		AND PEH.DISCH_DISP_C is not null
		and PEH.DISCH_DISP_C not IN 
		(
			'10',
			'100',
			'98',
			'200'
		)
											/*Exclude 			Left Without Being Seen
																ED Dismiss - Never Arrived
																Left Before Triage
																ED Dismiss - Diverted Elsewhere
									*/

Group by z.NAME
