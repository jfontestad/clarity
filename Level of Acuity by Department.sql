DECLARE @SERVAREAID VARCHAR(30) = '10' 
DECLARE @STARTDATE SMALLDATETIME = '2020-01-01'
DECLARE @ENDDATE  SMALLDATETIME = '2021-02-28';
;
select distinct
peh.pat_id
,peh.pat_enc_csn_id
--,peh.adt_pat_class_c
,z.name [Patient Class]
,peh.hosp_admsn_time
,peh.hosp_disch_time
,adt.department_id
,dep.department_name 
,ze.NAME [Event Type]
--,peh.ACUITY_LEVEL_C
,za.name [Acuity Level]
,lvl.name	[Level of Care]
from PAT_ENC_HSP peh
join CLARITY_ADT adt
	on peh.PAT_ENC_CSN_ID = adt.PAT_ENC_CSN_ID
	AND ADT.EVENT_TYPE_C in (1,2,3)  		--census
left join clarity_dep	dep on adt.department_id = dep.department_id
left join ZC_PAT_CLASS z on peh.ADT_PAT_CLASS_C = z.ADT_PAT_CLASS_C
left join zc_acuity_level	za on peh.ACUITY_LEVEL_C= za.ACUITY_LEVEL_C
left join ZC_LVL_OF_CARE LVL 
      ON ADT.PAT_LVL_OF_CARE_C = LVL.LEVEL_OF_CARE_C 
   JOIN
      VALID_PATIENT VP 
      ON PEH.PAT_ID = VP.PAT_ID 
left join ZC_EVENT_TYPE ze on adt.EVENT_TYPE_C = ze.EVENT_TYPE_C
where peh.HOSP_DISCH_TIME between @startdate and @enddate
and peh.adt_pat_class_c in (101,104)
and peh.ADT_SERV_AREA_ID = 10
and dep.department_id not in ('100000101','100000103','100000161','100000104','100000191','100000202')
AND VP.IS_VALID_PAT_YN = 'Y' 
and peh.CANCEL_USER_ID is null
order by peh.PAT_ENC_CSN_ID