USE [CLARITY]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--GROUP BY GROUPING SETS(A, B, (A, B)), C
--GROUPING SETS(D, E), F


--For example, to add a count of all encounters to the GROUPING SETS query for the previous metric, the query would look like this:
select TOP 50 department_id,
visit_prov_id
,count (*) COUNT
from pat_enc
GROUP BY GROUPING SETS(DEPARTMENT_ID,VISIT_PROV_ID,
						(DEPARTMENT_ID,VISIT_PROV_ID),
						())		-- in radar sql metrics, the () group is generally considered to be the facility level summary.

--This is equivalent to adding the result of the following query to the result set.
select TOP 50 
null department_id,
null visit_prov_id
,count (*) COUNT
from pat_enc
--GROUP BY GROUPING SETS(DEPARTMENT_ID,VISIT_PROV_ID,
--						(DEPARTMENT_ID,VISIT_PROV_ID),
--						())				

--The GROUPING_ID() aggregate function generates a value in a very particular way.  
--To understand the output of GROUPING_ID, you need to understand how binary (base 2) numbers are written and how to convert between binary numbers and decimal numbers.
SELECT 
  GROUPING_ID(DEPARTMENT_ID, VISIT_PROV_ID) [GROUP_ID]
, DEPARTMENT_ID
, VISIT_PROV_ID
, COUNT(*) [COUNT]
FROM PAT_ENC

GROUP BY 
  GROUPING SETS( DEPARTMENT_ID
                ,VISIT_PROV_ID
                ,(DEPARTMENT_ID, VISIT_PROV_ID)
                ,()) 

--This query will have three levels of granularity.  That means there will be three distinct GROUPING_IDs in the results.  
--One for each of
--Group by DEPARTMENT_ID
--Group by VISIT_PROV_ID
--Group by ENC_TYPE_C
SELECT 
  GROUPING_ID( DEPARTMENT_ID				--1
              ,VISIT_PROV_ID				--2
              ,ENC_TYPE_C) [Group ID]		--3
 --, <Some Aggregate Function>
FROM PAT_ENC
GROUP BY 
  GROUPING SETS( DEPARTMENT_ID
                ,VISIT_PROV_ID
                ,ENC_TYPE_C)

SELECT 
  GROUPING_ID( DEPARTMENT_ID ,VISIT_PROV_ID ,ENC_TYPE_C) [Group ID]
			 
			  ,DEPARTMENT_ID
              ,VISIT_PROV_ID
              ,ENC_TYPE_C
FROM PAT_ENC
GROUP BY 
  GROUPING SETS( (DEPARTMENT_ID, VISIT_PROV_ID, ENC_TYPE_C) --group 000 =0
                ,(DEPARTMENT_ID, VISIT_PROV_ID)				--group 001 =1
                ,(DEPARTMENT_ID, ENC_TYPE_C)				-- group 010 =2
                ,(VISIT_PROV_ID, ENC_TYPE_C)				-- group 100 4
                ,()) --- 111 =7

--Write a query to return the total charges from billed hospital accounts
--, broken down by service area
--, account base class
--, account class
--, financial class
--, and combinations of service area and account base class
--, service area and account class
--, and service area and financial class. Include a grand total.

--This query will be used for a metric that uses Additive rollup, attributed to the date the account was billed.


select 
--					1			2					3				4
	GROUPING_ID(SERV_AREA_ID ,ACCT_BASECLS_HA_C,ACCT_CLASS_HA_C,ACCT_FIN_CLASS_C) [Group ID]
					,SERV_AREA_ID				--service area
					,ACCT_BASECLS_HA_C			---account class
					,ACCT_CLASS_HA_C			--account class
					,ACCT_FIN_CLASS_C			--financial class	
					,ACCT_BILLED_DATE			--date the account was billed
	,sum(TOT_CHGS) [total charge]
from hsp_account
WHERE ACCT_BILLSTS_HA_C = 4 --4 means Billed
GROUP BY
	GROUPING SETS ( 
					(SERV_AREA_ID , ACCT_BASECLS_HA_C)			-- 0011  =3   --00111 = 
					,(SERV_AREA_ID ,ACCT_CLASS_HA_C )			-- 0101  =5	
					,(SERV_AREA_ID ,ACCT_FIN_CLASS_C )			-- 0110  = 6
					,SERV_AREA_ID				--service area
					,ACCT_BASECLS_HA_C			---account class
					,ACCT_CLASS_HA_C			--account class
					,ACCT_FIN_CLASS_C			--financial class	
					
					,()	)		--1111	=15
					,ACCT_BILLED_DATE			--date the account was billed



SELECT GROUPING_ID(SERV_AREA_ID,ACCT_BASECLS_HA_C, ACCT_CLASS_HA_C, ACCT_FIN_CLASS_C) GROUP_ID,
	   SERV_AREA_ID,
       ACCT_BASECLS_HA_C,
	   ACCT_CLASS_HA_C,
       ACCT_FIN_CLASS_C,
       ACCT_BILLED_DATE,
	   SUM(TOT_CHGS) TOTAL_CHARGES
  FROM HSP_ACCOUNT
  WHERE ACCT_BILLSTS_HA_C = 4 --4 means Billed
  GROUP BY GROUPING SETS((),
                         SERV_AREA_ID,
                         ACCT_BASECLS_HA_C,
                         ACCT_CLASS_HA_C,
                         ACCT_FIN_CLASS_C,
                         (SERV_AREA_ID, ACCT_BASECLS_HA_C),
                         (SERV_AREA_ID, ACCT_CLASS_HA_C),
                         (SERV_AREA_ID, ACCT_FIN_CLASS_C)),
           ACCT_BILLED_DATE		  



		   -- Datalink summary query
SELECT
GROUPING_ID(dep.REV_LOC_ID, fact.PCP_PROV_ID) "GROUPING_ID"
, dep.REV_LOC_ID "TARGET_2"
, fact.PCP_PROV_ID "TARGET_4"
, fact.CONTACT_DATE "INTERVAL_START_DT"
, 1106854 "METRIC_ID_1" /* AMJ Visits with PCPs */
, COUNT(CASE WHEN fact.VISIT_PROV_ID = fact.PCP_PROV_ID THEN 1 ELSE NULL END) "NUMER_1"
, COUNT(1) "DENOM_1"
FROM
[CLARITY]..PAT_ENC fact
LEFT OUTER JOIN [CLARITY]..CLARITY_DEP dep on fact.DEPARTMENT_ID = dep.DEPARTMENT_ID
WHERE
(fact.PCP_PROV_ID IS NOT NULL)
AND fact.CONTACT_DATE IS NOT NULL
GROUP BY
GROUPING SETS (
dep.REV_LOC_ID
, fact.PCP_PROV_ID
, (dep.REV_LOC_ID, fact.PCP_PROV_ID)
, () )
, fact.CONTACT_DATE

--SELECT
--GROUPING_ID(dep.SERV_AREA_ID, dep.REV_LOC_ID, fact.ORDER_PAT_DEPT_ID, fact.ORDERING_PROV_ID, fact.ORDERING_USER_ID, dep.SPECIALTY_DEP_C, coalesce(dep.ADT_UNIT_TYPE_C,0), fact.PRL_ORDERSET_ID) "GROUPING_ID"
--, dep.SERV_AREA_ID "TARGET_1"
--, dep.REV_LOC_ID "TARGET_2"
--, fact.ORDER_PAT_DEPT_ID "TARGET_3"
--, fact.ORDERING_PROV_ID "TARGET_4"
--, fact.ORDERING_USER_ID "TARGET_5"
--, dep.SPECIALTY_DEP_C "TARGET_8"
--, coalesce(dep.ADT_UNIT_TYPE_C,0) "TARGET_77"
--, fact.PRL_ORDERSET_ID "TARGET_214"
--, CASE 
--	WHEN GROUPING(date_dim.YEAR_BEGIN_DT)=0 THEN 1 
--	WHEN GROUPING(date_dim.QUARTER_BEGIN_DT)=0 THEN 2 
--	WHEN GROUPING(date_dim.MONTH_BEGIN_DT)=0 THEN 3 
--	WHEN GROUPING(date_dim.WEEK_BEGIN_DT)=0 THEN 4 
--	WHEN GROUPING(fact.ORDER_DATE)=0 THEN 5 
--	END "INTERVAL_C"
--, CASE 
--	WHEN GROUPING(date_dim.YEAR_BEGIN_DT)=0 THEN date_dim.YEAR_BEGIN_DT 
--	WHEN GROUPING(date_dim.QUARTER_BEGIN_DT)=0 THEN date_dim.QUARTER_BEGIN_DT 
--	WHEN GROUPING(date_dim.MONTH_BEGIN_DT)=0 THEN date_dim.MONTH_BEGIN_DT 
--	WHEN GROUPING(date_dim.WEEK_BEGIN_DT)=0 THEN date_dim.WEEK_BEGIN_DT 
--	WHEN GROUPING(fact.ORDER_DATE)=0 THEN fact.ORDER_DATE 
--	END "INTERVAL_START_DT"
--, 11318 "METRIC_ID_1" /* IP Clarity Distinct Order Set Usage */
--, COUNT(DISTINCT fact.PRL_ORDERSET_SESSION) "VALUE_1"
--FROM
--[CLARITY]..F_IP_HSP_SUM_ORDER fact
--LEFT OUTER JOIN [CLARITY]..CLARITY_DEP dep on fact.ORDER_PAT_DEPT_ID = dep.DEPARTMENT_ID
--INNER JOIN [CLARITY]..DATE_DIMENSION date_dim ON fact.ORDER_DATE = date_dim.CALENDAR_DT
--WHERE
--fact.ORDER_DATE >= (CONVERT(DATETIME, '2021-01-01', 120)) /* extract date filter */
--GROUP BY
--GROUPING SETS (
--dep.SERV_AREA_ID
--, dep.REV_LOC_ID
--, fact.ORDER_PAT_DEPT_ID
--, fact.ORDERING_PROV_ID
--, fact.ORDERING_USER_ID
--, dep.SPECIALTY_DEP_C
--, coalesce(dep.ADT_UNIT_TYPE_C,0)
--, fact.PRL_ORDERSET_ID
--, () )
--, GROUPING SETS(date_dim.YEAR_BEGIN_DT, date_dim.QUARTER_BEGIN_DT, date_dim.MONTH_BEGIN_DT, date_dim.WEEK_BEGIN_DT, fact.ORDER_DATE)
