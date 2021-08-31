USE [CLARITY]
GO

SELECT p.PAT_ENC_CSN_ID
	,pe.HSP_ACCOUNT_ID
	,dep.DEPARTMENT_NAME
,depa.ADDRESS	
,dep2.ADDRESS_CITY
,z.NAME [State]
,dep2.ADDRESS_ZIP_CODE
	  ,cast (p.CONTACT_DATE as date) [Contact Date]
	  ,o.QUEST_ANSWER
  FROM PAT_ENC_QNRS_ANS p
  join PAT_ENC pe on p.PAT_ENC_CSN_ID = pe.PAT_ENC_CSN_ID
  left join CL_QANSWER_QA o on p.	APPT_QNRS_ANS_ID = o.ANSWER_ID	
  left join CLARITY_DEP dep on pe.DEPARTMENT_ID = dep.DEPARTMENT_ID
  left join CLARITY_DEP_ADDR depa on dep.DEPARTMENT_ID = depa.DEPARTMENT_ID
  left join CLARITY_DEP_2 dep2 on dep.DEPARTMENT_ID = dep2.DEPARTMENT_ID
  left join ZC_STATE z on dep2.ADDRESS_STATE_C = z.STATE_C
  where  1=1
  --p.pat_id = 'Z3322734'
  and o.quest_id = '103477'
  and o.QUEST_ANSWER is not null
  --select *
  --from cl_qanswer c
  --when c.answer_id = 1534606

