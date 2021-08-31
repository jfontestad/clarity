use CLARITY
set nocount on;
set ansi_warnings off;



  DROP TABLE #tALL_ROWS3

--DROP TABLE #tmonth_end

--CREATE TABLE #tmonth_end (
--	MYPT_ID VARCHAR(100),
--	is_checked BIT
--);


  --/*create temp tables for INCREMENTAL load, one to hold all rows for the staging insert and one to batch data into reporting*/
  --CREATE TABLE #ALL_ROWS (
  --  MYPT_ID VARCHAR(18) NOT NULL,
  --  UA_SESSION_NUM NUMERIC(18,0) NOT NULL,
  --  SESSION_TYPE NUMERIC(18,0) NOT NULL
  --  PRIMARY KEY (MYPT_ID,UA_SESSION_NUM,SESSION_TYPE)
  --);
  --DROP TABLE #tALL_ROWS

 -- /*create temp tables for INCREMENTAL load, one to hold all rows for the staging insert and one to batch data into reporting*/
 -- CREATE TABLE #tALL_ROWS2 (
 --   MYPT_ID VARCHAR(18) NOT NULL,
	--PAT_ID VARCHAR(18),
	--START_DATE DATETIME,
	--NAME	VARCHAR(255),
	--IS_CHARGEABLE BIT,
 --   PRIMARY KEY (MYPT_ID)
 -- );
DECLARE
  @dStartDate datetime,
  @dEndDate datetime,
  @dAnniversaryDate datetime;


SET @dStartDate			= '2021-03-01'
SET @dEndDate			= '2021-04-01'
set @dAnniversaryDate	= '2020-06-16'


/*create temp tables for INCREMENTAL load, one to hold all rows for the staging insert and one to batch data into reporting*/
CREATE TABLE #tALL_ROWS3 (
	MYPT_ID VARCHAR(18) NOT NULL,
	PAT_ID VARCHAR(18),
	IS_CHARGEABLE BIT,
	START_DATE DATETIME,
	NAME	VARCHAR(255),
	PRIMARY KEY (MYPT_ID)
);


--Create a temp table with all of the peoplewho have had mychart checkins
INSERT INTO #tALL_ROWS3 (MYPT_ID, PAT_ID, IS_CHARGEABLE)
	SELECT DISTINCT  
		MYC_PT_USER_ACCSS.MYPT_ID ,  
		PATIENT.PAT_ID, 1 
	FROM   PATIENT  
	INNER JOIN MYC_PATIENT     		ON PATIENT.PAT_ID 			= MYC_PATIENT.PAT_ID 
	INNER JOIN V_MYC_SESSIONS  		ON MYC_PATIENT.MYPT_ID 		= V_MYC_SESSIONS.MYPT_ID 
	INNER JOIN MYC_PT_USER_ACCSS  	ON V_MYC_SESSIONS.MYPT_ID 	= MYC_PT_USER_ACCSS.UA_WHO_ACCESSED 
									AND MYC_PATIENT.MYPT_ID 	= MYC_PT_USER_ACCSS.MYPT_ID
									and MYC_PT_USER_ACCSS.MYC_UA_TYPE_C IS NOT NULL
									--AND MYC_PT_USER_ACCSS.MYC_UA_TYPE_C NOT IN (0,1,18,19,20,22,71,81)
									AND MYC_PT_USER_ACCSS.MYC_UA_TYPE_C = 142 --eCheckIn
	inner join ZC_MYC_UA_TYPE	AS ZTYPE		on MYC_PT_USER_ACCSS.MYC_UA_TYPE_C = ztype.MYC_UA_TYPE_C
	where V_MYC_SESSIONS.START_DATE >= @dStartDate and  V_MYC_SESSIONS.START_DATE < @dEndDate



--SELECT DISTINCT  
--		MYC_PT_USER_ACCSS.MYPT_ID ,  
--		PATIENT.PAT_ID ,  V_MYC_SESSIONS.START_DATE, ZTYPE.NAME, 1 
--	FROM   PATIENT  
--	INNER JOIN MYC_PATIENT     		ON PATIENT.PAT_ID 			= MYC_PATIENT.PAT_ID 
--	INNER JOIN V_MYC_SESSIONS  		ON MYC_PATIENT.MYPT_ID 		= V_MYC_SESSIONS.MYPT_ID 
--	INNER JOIN MYC_PT_USER_ACCSS  	ON V_MYC_SESSIONS.MYPT_ID 	= MYC_PT_USER_ACCSS.UA_WHO_ACCESSED 
--									AND MYC_PATIENT.MYPT_ID 	= MYC_PT_USER_ACCSS.MYPT_ID
--									and MYC_PT_USER_ACCSS.MYC_UA_TYPE_C IS NOT NULL
--	inner join ZC_MYC_UA_TYPE	AS ZTYPE		on MYC_PT_USER_ACCSS.MYC_UA_TYPE_C = ztype.MYC_UA_TYPE_C
--	where V_MYC_SESSIONS.START_DATE >=@dStartDate and  V_MYC_SESSIONS.START_DATE < @dEndDate 
--	--where V_MYC_SESSIONS.START_DATE >='2021-03-01' and  V_MYC_SESSIONS.START_DATE < '2021-03-02' 

--Get the patients who have checked in since the last anniversary date, and exclude them from chargeable encounters for this month
UPDATE #tALL_ROWS3
set IS_CHARGEABLE = 0 --' where col3=1250
from #tALL_ROWS3
where #tALL_ROWS3.MYPT_ID in (
				select DISTINCT ses_last.MYPT_ID
				FROM V_MYC_SESSIONS				AS ses_last
				INNER JOIN MYC_PT_USER_ACCSS				ON  MYC_PT_USER_ACCSS.UA_WHO_ACCESSED = ses_last.MYPT_ID 
															AND MYC_PT_USER_ACCSS.UA_SESSION_NUM = ses_last.UA_SESSION_NUM 
															and MYC_PT_USER_ACCSS.MYC_UA_TYPE_C IS NOT NULL	
															--AND MYC_PT_USER_ACCSS.MYC_UA_TYPE_C NOT IN (0,1,18,19,20,22,71,81)
															AND MYC_PT_USER_ACCSS.MYC_UA_TYPE_C = 142 --eCheckIn
															where ses_last.start_date >= @dAnniversaryDate and  ses_last.start_date < @dStartDate
);


 SELECT --TOP (5000) 
	myc1.PAT_ID, myc1.line, myc1.MYC_STAT_HX_MTHD_C
	,myc1.MYC_STAT_HX_TMSTP as ActivatedTimestamp
	,myc1.MYC_STAT_HX_C As ActivatedStatus
	,myc1.DEPARTMENT_ID, #tALL_ROWS3.*
--	,dep.DEPARTMENT_NAME
--	,dep.SERV_AREA_ID
	--,dateadd(year,myc1.MYC_STAT_HX_TMSTP,myc2.MYC_STAT_HX_TMSTP)
--	,myc1.*
  FROM  #tALL_ROWS3
 INNER JOIN PAT_MYC_STAT_HX			as myc1		ON #tALL_ROWS3.PAT_ID = MYC1.PAT_ID
-- inner join CLARITY_DEP			as dep			on myc1.DEPARTMENT_ID = dep.DEPARTMENT_ID
-- inner join PAT_MYC_STAT_HX		as myc2			on myc1.PAT_ID			= myc2.PAT_ID
--												and myc2.MYC_STAT_HX_TMSTP > myc1.MYC_STAT_HX_TMSTP
												--and myc2.
 
 where myc1.MYC_STAT_HX_C = 1
 and myc1.MYC_STAT_HX_TMSTP >=@dStartDate and  myc1.MYC_STAT_HX_TMSTP < @dEndDate 
 --and dep.SERV_AREA_ID = 15 --UNLV
 --and dep.SERV_AREA_ID = 10 --UMC
 order by myc1.pat_id, myc1.line



  --select *
  --from #tALL_ROWS3
  --inner join V_MYC_SESSIONS					As ses_activate on #tALL_ROWS3.MYPT_ID = ses_activate.MYPT_ID
  --WHERE #tALL_ROWS3.IS_CHARGEABLE = 1


  --select COUNT(*) from #tALL_ROWS3
  --WHERE #tALL_ROWS3.IS_CHARGEABLE = 1

  DROP TABLE #tALL_ROWS3
--DROP TABLE #tALL_ROWS
  --INSERT INTO #tALL_ROWS (MYPT_ID, PAT_ID, IS_CHARGEABLE)
  --    SELECT 
  --      wpr500.UA_WHO_ACCESSED,
  --      wpr500.UA_SESSION_NUM,
  --      CASE 
  --        WHEN wpr500.MYC_UA_TYPE_C IS NOT NULL THEN 24 
  --        WHEN wpr500.BEDSIDE_UA_TYPE_C IS NOT NULL THEN 96 
  --      END AS SESSION_TYPE
  --    FROM ##F_MYC_SESSIONS__MYC_PT_USER_ACCSS_TEMP alteredRows
  --      INNER JOIN [{{REPORTING_DATABASE}}]..MYC_PT_USER_ACCSS wpr500 ON wpr500.MYPT_ID = alteredRows.MYPT_ID AND wpr500.LINE = alteredRows.LINE
  --    WHERE wpr500.UA_SESSION_NUM IS NOT NULL AND wpr500.UA_WHO_ACCESSED IS NOT NULL AND ((wpr500.MYC_UA_TYPE_C IS NOT NULL AND wpr500.MYC_UA_TYPE_C<>161) OR wpr500.BEDSIDE_UA_TYPE_C IS NOT NULL)  --QAN 3572278 Ignore device remove for now
  --    GROUP BY wpr500.UA_WHO_ACCESSED,wpr500.UA_SESSION_NUM, CASE WHEN wpr500.MYC_UA_TYPE_C IS NOT NULL THEN 24 WHEN wpr500.BEDSIDE_UA_TYPE_C IS NOT NULL THEN 96 END;


----select count( DISTINCT ses_now.UA_SESSION_NUM ),count( DISTINCT ses_now.MYPT_ID )

--insert into #tmonth_end
--select DISTINCT ses_now.MYPT_ID, 1
--FROM V_MYC_SESSIONS				AS ses_now
--INNER JOIN MYC_PT_USER_ACCSS				ON  MYC_PT_USER_ACCSS.UA_WHO_ACCESSED = ses_now.MYPT_ID 
--											AND MYC_PT_USER_ACCSS.UA_SESSION_NUM = ses_now.UA_SESSION_NUM 
--											and MYC_PT_USER_ACCSS.MYC_UA_TYPE_C IS NOT NULL
--where ses_now.start_date >='2021-03-01' and  ses_now.start_date <= '2021-03-02' 
----and ses_now.MYPT_ID = 259189

--SELECT * FROM #tmonth_end

--DROP TABLE #tmonth_end


