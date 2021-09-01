SELECT 
emp.USER_ID
,emp.SYSTEM_LOGIN
,emp.NAME [USER NAME]
,zcUser.NAME [Active Status] --1 active 2 inactive
,emp_demo.EMAIL
,ser.PROV_NAME [Provider Name]
,ser.PROV_ID [Provider ID]
,id.[RESIDENT ID]
,id.[PROVIDER ECHO ID]
,id.[PROVIDER NPI]
,id.SPI
,zcProv.NAME [Provider Type]
,zcStat.NAME [Status]
,ser.DEA_NUMBER
,ser.EPRESCRIBING_YN [Eprescribing Provider]
,svcLvl.[Service Level]
,ser2.EPRESC_CNTRLD_YN [Eprescribe Controlled Substances]
,zcProp.NAME [Proposed Security]

FROM CLARITY.dbo.CLARITY_EMP emp
JOIN CLARITY.dbo.CLARITY_SER ser on emp.PROV_ID = ser.PROV_ID
JOIN CLARITY.dbo.CLARITY_SER_2 ser2 on ser.PROV_ID = ser2.PROV_ID
JOIN (
	SELECT
	PROV_ID
	,[RESIDENT ID]
	,[SPI]
	,[PROVIDER NPI]
	,[PROVIDER ECHO ID]
	FROM
		(SELECT
			PROV_ID
			,IDENTITY_ID
			,ID_TYPE_NAME
			FROM
			CLARITY.dbo.IDENTITY_SER_ID serIID
			LEFT JOIN CLARITY.dbo.IDENTITY_ID_TYPE idType on serIID.IDENTITY_TYPE_ID= idType.ID_TYPE
		)results
	PIVOT
	(
		MAX(results.IDENTITY_ID)
		FOR results.ID_TYPE_NAME in ([RESIDENT ID],[SPI],[PROVIDER NPI],[PROVIDER ECHO ID])
	) as PVT
)id on ser.PROV_ID = id.PROV_ID
LEFT JOIN CLARITY.dbo.CLARITY_EMP_DEMO emp_demo on emp.USER_ID = emp_demo.USER_ID
LEFT JOIN 
(
	SELECT PROV_ID,
	STRING_AGG(zcLvl.NAME,', ') [Service Level]
	FROM CLARITY.dbo.PROV_EPRSC_SVC_LVL provLvl
	LEFT JOIN CLARITY.dbo.ZC_SERVICE_LEVEL zcLvl on provLvl.E_PRES_SERV_LEVEL_C = zcLvl.SERVICE_LEVEL_C
	GROUP BY PROV_ID
) svcLvl on ser.PROV_ID = svcLvl.PROV_ID
LEFT JOIN CLARITY.dbo.SER_EPRESC_CNTRLD serEpresc on ser.PROV_ID = serEpresc.PROV_ID
LEFT JOIN CLARITY.dbo.ZC_PTY_I_PROPOSAL zcProp on serEpresc.PTY_I_PROPOSAL_C = zcProp.PTY_I_PROPOSAL_C
LEFT JOIN CLARITY.dbo.ZC_PROV_TYPE zcProv on ser.PROVIDER_TYPE_C = zcProv.PROV_TYPE_C
LEFT JOIN CLARITY.dbo.ZC_ACTIVE_STATUS_2 zcStat on ser.ACTIVE_STATUS_C = zcStat.ACTIVE_STATUS_2_C
LEFT JOIN CLARITY.dbo.ZC_USER_STATUS zcUser on emp.USER_STATUS_C = zcUser.USER_STATUS_C

--WHERE emp.USER_ID = '10012'

