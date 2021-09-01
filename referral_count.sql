/*
Enter the Start Date and End Date from your SlicerDicer query below in 'yyyy-mm-dd' format.
*/
DECLARE @START_DATE AS DATE = '1/1/2020'
DECLARE @END_DATE AS DATE = '1/13/2021'
/*
In Aug 19 and Earlier:
Replace the <Value> placeholders with the service areas listed on your Cogito User Security.  

In Nov 19 and Later:
Replace the <Value> placeholders with the service areas listed in the Authorized Service Area fields (I EMP 19505) of the Referrals forms in your User Security.
We now use UserBusinessSegmentMappingFact to get this value(s), so if you update your User Security in Hyperspace, you will need to wait for ETL for the changes to be applied.
To get the current values actually being applied, you can also run the below query from PRD-Caboodle.  
SELECT DISTINCT dim.ServiceAreaEpicId 
FROM UserBusinessSegmentMappingFact fact
	INNER JOIN DepartmentDim dim
	ON dim.DepartmentKey=fact.BusinessSegmentKey
WHERE EmployeeEpicId= <Your User ID> 

In either case:
If there are no Service Areas listed, comment out the corresponding "INSERT INTO" line as well as the entire last section of the query as indicated.
*/
DECLARE @SERVICE_AREAS TABLE (VALUE NUMERIC)
INSERT INTO @SERVICE_AREAS VALUES ('10') 


 SELECT COUNT(*)
  FROM REFERRAL
    LEFT OUTER JOIN REFERRAL_2
      ON REFERRAL.REFERRAL_ID = REFERRAL_2.REFERRAL_ID
    LEFT OUTER JOIN REFERRAL_3
      ON REFERRAL.REFERRAL_ID = REFERRAL_3.REFERRAL_ID
    LEFT OUTER JOIN REFERRAL_4
      ON REFERRAL.REFERRAL_ID = REFERRAL_4.REFERRAL_ID
    LEFT OUTER JOIN F_REFERRAL_PRICE
      ON REFERRAL.REFERRAL_ID = F_REFERRAL_PRICE.REFERRAL_ID
    

    LEFT OUTER JOIN REFERRAL_SOURCE
      ON REFERRAL.REFERRING_PROV_ID = REFERRAL_SOURCE.REFERRING_PROV_ID
    LEFT OUTER JOIN ( SELECT REFERRAL_ORDER_ID.REFERRAL_ID,
                             MAX( REFERRAL_ORDER_ID.ORDER_ID ) ORDER_ID
                        FROM REFERRAL_ORDER_ID
                          INNER JOIN ORDER_METRICS
                            ON REFERRAL_ORDER_ID.ORDER_ID = ORDER_METRICS.ORDER_ID
                        WHERE NULLIF( ORDER_METRICS.ORDER_SOURCE_C, 21 ) IS NOT NULL
                        GROUP BY REFERRAL_ORDER_ID.REFERRAL_ID ) GeneratingOrder
      ON REFERRAL.REFERRAL_ID = GeneratingOrder.REFERRAL_ID
    LEFT OUTER JOIN ( SELECT REFERRAL_ID 
                        FROM REFERRAL_WQ_ITEMS
                        WHERE ITEM_ID IS NOT NULL
                          AND RELEASE_DATE IS NULL
                        GROUP BY REFERRAL_ID ) REFERRAL_WQ_ITEMS
      ON REFERRAL.REFERRAL_ID = REFERRAL_WQ_ITEMS.REFERRAL_ID  
    LEFT OUTER JOIN ( SELECT AdjustedCoverages.REFERRAL_ID,
                             MAX( CASE WHEN AdjustedCoverages.FilingOrder = 1 THEN AdjustedCoverages.CVG_ID ELSE NULL END ) PrimaryCoverage,
                             MAX( CASE WHEN AdjustedCoverages.FilingOrder = 1 THEN AdjustedCoverages.CARRIER_AUTH_CMT ELSE NULL END ) PrimaryCoverageAuthNum,
                             MAX( CASE WHEN AdjustedCoverages.FilingOrder = 2 THEN AdjustedCoverages.CVG_ID ELSE NULL END ) SecondaryCoverage,
                             MAX( CASE WHEN AdjustedCoverages.FilingOrder = 2 THEN AdjustedCoverages.CARRIER_AUTH_CMT ELSE NULL END ) SecondaryCoverageAuthNum,
                             MAX( CASE WHEN AdjustedCoverages.FilingOrder = 3 THEN AdjustedCoverages.CVG_ID ELSE NULL END ) TertiaryCoverage,
                             MAX( CASE WHEN AdjustedCoverages.FilingOrder = 3 THEN AdjustedCoverages.CARRIER_AUTH_CMT ELSE NULL END ) TertiaryCoverageAuthNum
                        FROM ( SELECT REFERRAL_CVG.REFERRAL_ID,
                                      REFERRAL_CVG.CVG_ID,
                                      REFERRAL_CVG.CARRIER_AUTH_CMT,
                                      ROW_NUMBER() OVER( PARTITION BY REFERRAL_CVG.REFERRAL_ID ORDER BY REFERRAL_CVG.LINE ) FilingOrder
                                 FROM REFERRAL_CVG
                                 WHERE REFERRAL_CVG.CVG_USED_YN = 'Y' ) AdjustedCoverages 
                        GROUP BY AdjustedCoverages.REFERRAL_ID ) ReferralCoverages
      ON REFERRAL.REFERRAL_ID = ReferralCoverages.REFERRAL_ID
    LEFT OUTER JOIN ( SELECT REFERRAL_DX.REFERRAL_ID,
                             REFERRAL_DX.DX_ID
                        FROM REFERRAL_DX
                        WHERE REFERRAL_DX.LINE = 1 ) PrimaryDiagnosis
      ON REFERRAL.REFERRAL_ID = PrimaryDiagnosis.REFERRAL_ID
    LEFT OUTER JOIN ( SELECT REFERRAL_ORDER_ID.REFERRAL_ID,
                             ORDER_PROC.PROC_ID
                        FROM REFERRAL_ORDER_ID
                          INNER JOIN ORDER_PROC
                            ON REFERRAL_ORDER_ID.ORDER_ID = ORDER_PROC.ORDER_PROC_ID
                        WHERE REFERRAL_ORDER_ID.LINE = 1 ) PrimaryProcedure
      ON REFERRAL.REFERRAL_ID = PrimaryProcedure.REFERRAL_ID
    LEFT OUTER JOIN ( SELECT REFERRAL_HIST.REFERRAL_ID,
                             MAX( CASE WHEN REFERRAL_HIST.CHANGE_TYPE_C = 1 THEN COALESCE( REFERRAL_HIST.CHANGE_LOCAL_DTTM, REFERRAL_HIST.CHANGE_DATETIME ) ELSE NULL END ) Creation,
                             MIN( CASE WHEN REFERRAL_HIST.CHANGE_TYPE_C IN ( 39, 53 ) AND REFERRAL_HIST.AUTH_HX_ITEM_VALUE = '1'
                                         THEN COALESCE( REFERRAL_HIST.CHANGE_LOCAL_DTTM, REFERRAL_HIST.CHANGE_DATETIME ) ELSE NULL END ) FirstAuth,
                             MAX( CASE WHEN REFERRAL_HIST.CHANGE_TYPE_C = 39 AND REFERRAL_HIST.AUTH_HX_ITEM_VALUE = '1'
                                         THEN 1 ELSE 0 END ) AuthorizedThroughASA,
                             MIN( CASE WHEN REFERRAL_HIST.CHANGE_TYPE_C = 51 THEN COALESCE( REFERRAL_HIST.CHANGE_LOCAL_DTTM, REFERRAL_HIST.CHANGE_DATETIME ) ELSE NULL END ) FirstAssign,
                             MIN( CASE WHEN REFERRAL_HIST.CHANGE_TYPE_C = 123 THEN COALESCE( REFERRAL_HIST.CHANGE_LOCAL_DTTM, REFERRAL_HIST.CHANGE_DATETIME ) ELSE NULL END ) FirstTriage,
                             MAX( CASE WHEN REFERRAL_HIST.CHANGE_TYPE_C = 123 THEN COALESCE( REFERRAL_HIST.CHANGE_LOCAL_DTTM, REFERRAL_HIST.CHANGE_DATETIME ) ELSE NULL END ) LastTriage
                        FROM REFERRAL_HIST
                        GROUP BY REFERRAL_HIST.REFERRAL_ID ) TurnAroundTimes
      ON REFERRAL.REFERRAL_ID = TurnAroundTimes.REFERRAL_ID
    LEFT OUTER JOIN ( SELECT REFERRAL_REASONS.REFERRAL_ID,
                             MAX( CASE WHEN REFERRAL_REASONS.LINE = 1 THEN REFERRAL_REASONS.REFERRAL_REASON_C ELSE NULL END ) FirstReason,
                             MAX( CASE WHEN REFERRAL_REASONS.LINE = 2 THEN REFERRAL_REASONS.REFERRAL_REASON_C ELSE NULL END ) SecondReason,
                             MAX( CASE WHEN REFERRAL_REASONS.LINE = 3 THEN REFERRAL_REASONS.REFERRAL_REASON_C ELSE NULL END ) ThirdReason
                        FROM REFERRAL_REASONS
                        WHERE REFERRAL_REASONS.LINE IN ( 1, 2, 3 )
                        GROUP BY REFERRAL_REASONS.REFERRAL_ID ) ReferralReasons
      ON REFERRAL.REFERRAL_ID = ReferralReasons.REFERRAL_ID
    LEFT OUTER JOIN ( SELECT PAS_TRIAGE_HX.REFERRAL_ID,
                             MAX( CASE WHEN PAS_TRIAGE_HX.PAS_TRIAGE_HX_DEC_C = 3 THEN 1 ELSE 0 END ) Redirected
                        FROM PAS_TRIAGE_HX
                        GROUP BY PAS_TRIAGE_HX.REFERRAL_ID ) TriageInfo
      ON REFERRAL.REFERRAL_ID = TriageInfo.REFERRAL_ID
    LEFT OUTER JOIN ( SELECT CAL_REFERENCE_PAT.REF_ORDER_ID,
                             MIN( CAL_COMM_TRACKING.COMM_INSTANT_DTTM ) OrderCallTime
                        FROM CAL_COMM_TRACKING
                          INNER JOIN CAL_REFERENCE_PAT
                            ON CAL_COMM_TRACKING.COMM_ID = CAL_REFERENCE_PAT.COMM_ID
                          INNER JOIN REFERRAL_ORDER_ID
                            ON CAL_REFERENCE_PAT.REF_ORDER_ID = REFERRAL_ORDER_ID.ORDER_ID
                        WHERE CAL_COMM_TRACKING.COMM_TYPE_C = 4
                        GROUP BY CAL_REFERENCE_PAT.REF_ORDER_ID ) OrderPhoneCall
      ON GeneratingOrder.ORDER_ID = OrderPhoneCall.REF_ORDER_ID
    LEFT OUTER JOIN ( SELECT CAL_REFERENCE_PAT.REF_REFERRAL_ID,
                             MIN( CAL_COMM_TRACKING.COMM_INSTANT_DTTM ) ReferralCallTime
                        FROM CAL_COMM_TRACKING
                          INNER JOIN CAL_REFERENCE_PAT
                            ON CAL_COMM_TRACKING.COMM_ID = CAL_REFERENCE_PAT.COMM_ID
                        WHERE CAL_COMM_TRACKING.COMM_TYPE_C = 4
                        GROUP BY CAL_REFERENCE_PAT.REF_REFERRAL_ID ) ReferralPhoneCall
      ON REFERRAL.REFERRAL_ID = ReferralPhoneCall.REF_REFERRAL_ID

   

     
  WHERE NULLIF( REFERRAL_3.AUTH_CERT_YN, 'N' ) IS NULL
  AND CAST(REFERRAL.ENTRY_DATE as date) between @START_DATE and @END_DATE 
  AND EXISTS( -- Comment out this line and everything below it if you don't have applicable service areas (see notes above)
      SELECT DISTINCT 1
	  FROM 
	  (



SELECT DISTINCT CAST( RFL_AUTH_SAPBS.REFERRAL_ID AS numeric(18,0) ) NUMERICBASEID, 
                CAST( RFL_AUTH_SAPBS.AUTH_SAS_PBSS_ID AS varchar(50) ) DEPARTMENTID
  FROM REFERRAL
    INNER JOIN RFL_AUTH_SAPBS
      ON REFERRAL.REFERRAL_ID = RFL_AUTH_SAPBS.REFERRAL_ID
    LEFT OUTER JOIN REFERRAL_3
      ON RFL_AUTH_SAPBS.REFERRAL_ID = REFERRAL_3.REFERRAL_ID
  WHERE RFL_AUTH_SAPBS.AUTH_SAS_PBSS_ID IS NOT NULL
    AND NULLIF( REFERRAL_3.AUTH_CERT_YN, 'N' ) IS NULL 


UNION 

SELECT DISTINCT CAST ( SERVICEAREAS.REFERRAL_ID AS numeric(18,0) ) NUMERICBASEID,
                CAST ( SERVICEAREAS.SERVICE_AREA_ID AS varchar(50) ) DEPARTMENTID

  FROM ( SELECT REFERRAL.REFERRAL_ID, 
                REFERRAL_4.REF_BY_EAF_ID SERVICE_AREA_ID
           FROM REFERRAL
             LEFT OUTER JOIN REFERRAL_3 
               ON REFERRAL.REFERRAL_ID = REFERRAL_3.REFERRAL_ID
             LEFT OUTER JOIN REFERRAL_4
               ON REFERRAL.REFERRAL_ID = REFERRAL_4.REFERRAL_ID
           WHERE REFERRAL_4.REF_BY_EAF_ID IS NOT NULL  
             AND NULLIF( REFERRAL_3.AUTH_CERT_YN, 'N' ) IS NULL


         UNION ALL
 
         SELECT REFERRAL.REFERRAL_ID, 
                REFERRAL_4.REF_TO_EAF_ID SERVICE_AREA_ID
           FROM REFERRAL
             LEFT OUTER JOIN REFERRAL_3 
               ON REFERRAL.REFERRAL_ID = REFERRAL_3.REFERRAL_ID
             LEFT OUTER JOIN REFERRAL_4
               ON REFERRAL.REFERRAL_ID = REFERRAL_4.REFERRAL_ID
           WHERE REFERRAL_4.REF_TO_EAF_ID IS NOT NULL  
             AND NULLIF( REFERRAL_3.AUTH_CERT_YN, 'N' ) IS NULL


         UNION ALL
 
         SELECT REFERRAL.REFERRAL_ID, 
                CLARITY_DEP.SERV_AREA_ID SERVICE_AREA_ID
           FROM REFERRAL
             LEFT OUTER JOIN REFERRAL_2
               ON REFERRAL.REFERRAL_ID = REFERRAL_2.REFERRAL_ID
             LEFT OUTER JOIN REFERRAL_3 
               ON REFERRAL.REFERRAL_ID = REFERRAL_3.REFERRAL_ID
             LEFT OUTER JOIN CLARITY_DEP
               ON REFERRAL_2.CREATION_DEPT_ID = CLARITY_DEP.DEPARTMENT_ID
           WHERE CLARITY_DEP.SERV_AREA_ID IS NOT NULL  
             AND NULLIF( REFERRAL_3.AUTH_CERT_YN, 'N' ) IS NULL


         UNION ALL

         SELECT REFERRAL.REFERRAL_ID,
                REFERRAL.SERV_AREA_ID SERVICE_AREA_ID
           FROM REFERRAL
             LEFT OUTER JOIN REFERRAL_3 
               ON REFERRAL.REFERRAL_ID = REFERRAL_3.REFERRAL_ID
           WHERE REFERRAL.SERV_AREA_ID IS NOT NULL
             AND NULLIF( REFERRAL_3.AUTH_CERT_YN, 'N' ) IS NULL 

 ) SERVICEAREAS ) whereExistsTable0
 
   WHERE whereExistsTable0.DEPARTMENTID IN (SELECT VALUE FROM @SERVICE_AREAS)
	AND whereExistsTable0.NUMERICBASEID = REFERRAL.REFERRAL_ID)