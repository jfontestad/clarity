select 
EPIC_EMP_ID ,ACCESS_TIME
,[14010],[14020],[14011] --,[log off],[login failure]
from
(select 
	ACCESS_WRKF.USER_ID
	,emp.EPIC_EMP_ID
	,ACCESS_WRKF.METRIC_ID
	,ACCESS_WRKF.ACCESS_TIME
	FROM CLARITY.dbo.ACCESS_WRKF ACCESS_WRKF
	--JOIN clarity.dbo.ACCESS_LOG_METRIC logging on ACCESS_WRKF.METRIC_ID = logging.METRIC_ID
	join CLARITY.dbo.CLARITY_EMP emp on access_wrkf.USER_ID = emp.USER_ID
	WHERE emp.USER_ID = '1171'
	AND (ACCESS_WRKF.ACCESS_TIME>={ts '2020-12-14 00:00:00'} AND ACCESS_WRKF.ACCESS_TIME<{ts '2021-01-11 00:00:00'}) 
	 AND (ACCESS_WRKF.METRIC_ID=14010 OR ACCESS_WRKF.METRIC_ID=14011 
			OR ACCESS_WRKF.METRIC_ID=14020 OR ACCESS_WRKF.METRIC_ID=14030 OR ACCESS_WRKF.METRIC_ID=14050)
) results
PIVOT
	(
	MAX(results.user_id)
	--FOR results.METRIC_ID in ([log in ],[log off],[login failure])
	FOR results.METRIC_ID in ([14010],[14020],[14011])
) as PVT

--select * from CLARITY.dbo.CLARITY_EMP where user_id = '1171'
select * FROM CLARITY.dbo.ACCESS_WRKF  where user_id = '1171'