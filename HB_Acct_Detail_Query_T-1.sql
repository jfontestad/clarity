WITH RPT_DATE (CALENDAR_DT) AS ( Select CALENDAR_DT from date_dimension where CALENDAR_DT=EPIC_UTIL.EFN_DIN('t-1'))

SELECT
 *
FROM
(
SELECT 
 hlb.BUCKET_ID,
 hlb.hsp_account_id HSP_ACCOUNT_ID,
 har.hsp_account_name HSP_ACCOUNT_NAME,
 sa.serv_area_name SERV_AREA_NAME,
 loc.loc_name LOC_NAME,
 bcls.name BASE_CLASS_NAME,
acls.name ACCT_CLASS_NAME,
 bkttype.NAME BKT_TYPE_NAME,
 bktsts.name BKT_STS,
splvl.name SP_LEVEL_NAME,
clform.name CLM_FORM_NAME,
 coalesce(coll.name,'Active AR') COLLECTION_STS,
agency.coll_agency_name AGENCY_NAME,
(CASE
      WHEN hlb.bkt_type_ha_c in (6,7) AND hlb.interim_end_date IS NOT NULL THEN hlb.interim_end_date
      ELSE harsnap.DISCHARGE_DATE
   END
   ) CALC_DISCHARGE_DATE,
(CASE
     WHEN hlb.first_claim_date <= CALENDAR_DT then hlb.first_claim_date
      else null
   end
) FIRST_CLAIM_DATE,
hlbsnap.LAST_CLM_DATE LAST_CLAIM_DATE,
hlbsnap.FST_EXT_CLM_SNT_DT FIRST_EXT_CLAIM_DATE,
hlbsnap.LAST_EXT_CLM_SNT_DT LAST_EXT_CLAIM_DATE,
(CASE   /*not pulling from snapshot table, so only populate if <= to aging date*/
     WHEN har.frst_stmt_date <= CALENDAR_DT then har.frst_stmt_date
      else null
   end
) FIRST_STMT_DATE,
(CASE     /*not pulling from snapshot table, so only populate if <= to aging date*/
     WHEN har2.frst_full_stmt_dt <= CALENDAR_DT then har2.frst_full_stmt_dt
      else null
   end
) FIRST_FULL_STMT_DATE,
hlbsnap.FST_PYR_RCVD_DATE FIRST_PAYOR_DATE,
hlbsnap.LAST_PYR_RCVD_DATE LAST_PAYOR_DATE,
harsnap.COLL_AGENCY_ASSN_DT COLL_AGNCY_ASSN_DATE,
harsnap.SP_CYCLE_START_DT SP_CYCLE_START_DATE,
 bktBalSts.NAME BALANCE_STATUS,
hlbsnap.PREVIOUS_CREDITS,
 hlbsnap.tot_chgs TOTAL_CHARGES,
 hlbsnap.tot_pmts TOTAL_PAYMENTS,
 hlbsnap.tot_adjs TOTAL_ADJUSTMENTS,
 hlbsnap.bucket_bal TOTAL_BALANCE,
hlbsnap.EXPECTED_ALLOWED_AMT,
 hlbsnap.EXPECTED_NOT_ALLOWED_AMT,
 hlbsnap.POSTED_NOT_ALLOWED_AMT,
 hlbsnap.PAYOR_ALLOWED_AMT,
hlbsnap.PAYOR_BILLED_AMT,
hlbsnap.CLM_BILLED_AMT,
hlbsnap.BKT_BILLED_AMT,

dep.department_name DISCH_DEPT,
CASE 
	WHEN vacView.vacCount >= 1 THEN 'Y'      
	ELSE 'N'      
END AS C19_Vac_FLAG,
CASE 
	WHEN testView.testCount >= 1 THEN 'Y'      
	ELSE 'N'      
END AS C19_Test_FLAG,

(CASE 
  WHEN hlbsnap.bkt_balance_status_c=2 THEN (hlbsnap.bucket_bal -  hlbsnap.MAX_COLLECTIBLE_AR)  --Expected Contractual Calculated
  WHEN hlbsnap.bkt_balance_status_c=4 THEN 0  --Contractualized
  ELSE NULL 
  END) EXPECTED_UNPOSTED_NAA,
 hlbsnap.MAX_COLLECTIBLE_AR,
   (
   CASE
      WHEN hlb.bkt_type_ha_c = 5 OR (hlbsnap.COLL_STATUS_C = '2' AND hlb.bkt_type_ha_c <> 1) THEN 'BAD DEBT'
      WHEN hlb.bkt_type_ha_c IN (2,3,6,7,20,21,25,26) THEN 
      (
      CASE
         WHEN hlb.payor_id IS NULL THEN '*NO BUCKET PAYOR'
         ELSE COALESCE(payor.payor_name,'*UNKNOWN PAYOR') 
      END
      )
      WHEN hlb.bkt_type_ha_c = 8 THEN 'UNDISTRIBUTED'
      WHEN harsnap.PRIMARY_PAYOR_ID IS NULL THEN '{?Uninsured Self-Pay Name}'
      WHEN hlb.bkt_type_ha_c = 4 THEN '{?Residual Self-Pay Name}'
      WHEN hlb.bkt_type_ha_c = 1 THEN COALESCE(ppayor.payor_name,'*UNKNOWN PAYOR') 
   END
   ) CALC_PAYOR,
  (
   CASE
      WHEN hlb.bkt_type_ha_c = 5 OR (hlbsnap.COLL_STATUS_C = '2' AND hlb.bkt_type_ha_c <> 1) THEN 'BAD DEBT'
      WHEN hlb.bkt_type_ha_c IN (2,3,6,7,20,21,25,26) THEN 
      (
      CASE
         WHEN hlb.benefit_plan_id IS NULL THEN '*NO BUCKET PLAN'
         ELSE COALESCE(epp.benefit_plan_name,'*UNKNOWN PLAN') 
      END
      )
      WHEN hlb.bkt_type_ha_c = 8 THEN 'UNDISTRIBUTED'
      WHEN harsnap.PRIMARY_PAYOR_ID IS NULL THEN '{?Uninsured Self-Pay Name}'
      WHEN hlb.bkt_type_ha_c = 4 THEN '{?Residual Self-Pay Name}'
      WHEN hlb.bkt_type_ha_c = 1 THEN COALESCE(pepp.benefit_plan_name,'*UNKNOWN PLAN') 
   END
   ) CALC_PLAN,
   (CASE
      WHEN hlb.bkt_type_ha_c = 5 OR (hlbsnap.COLL_STATUS_C = '2' AND hlb.bkt_type_ha_c <> 1) THEN 'BAD DEBT'
      WHEN hlb.bkt_type_ha_c IN (2,3,6,7,20,21,25,26) THEN 
      (
      CASE
         WHEN epp2.PROD_TYPE_C IS NULL THEN '*NO PRODUCT TYPE DEFINED'
         ELSE COALESCE(prdtype.name,'*UNKNOWN PRODUCT TYPE') 
      END
      )
      WHEN hlb.bkt_type_ha_c = 8 THEN 'UNDISTRIBUTED'
      WHEN harsnap.PRIMARY_PAYOR_ID IS NULL THEN '{?Uninsured Self-Pay Name}'
      WHEN hlb.bkt_type_ha_c = 4 THEN '{?Residual Self-Pay Name}'
      WHEN hlb.bkt_type_ha_c = 1 THEN 
             (CASE WHEN  pepp2.PROD_TYPE_C IS NULL then '*NO PRODUCT TYPE DEFINED' else  COALESCE(pprdtype.name,'*UNKNOWN PRODUCT TYPE')  END)
   END
   ) CALC_PRODUCT_TYPE,
  (CASE
      WHEN hlb.bkt_type_ha_c = 5 OR (hlbsnap.COLL_STATUS_C = '2' AND hlb.bkt_type_ha_c <> 1) THEN 'BAD DEBT' 
      WHEN hlb.bkt_type_ha_c IN (2,3,6,7,20,21,25,26) THEN 
      (
      CASE
         WHEN payor.financial_class IS NULL THEN '*NO BUCKET FINANCIAL CLASS'
         ELSE COALESCE(fc.FINANCIAL_CLASS_name,'*UNKNOWN FINANCIAL CLASS') 
      END
      ) 
      WHEN hlb.bkt_type_ha_c = 8 THEN 'UNDISTRIBUTED'
      WHEN harsnap.FIN_CLASS_C IS NULL OR harsnap.FIN_CLASS_C = '4' THEN '{?Uninsured Self-Pay Name}' --self-pay balance with no existing primary coverage
      WHEN hlb.bkt_type_ha_c = 4 THEN '{?Residual Self-Pay Name}'  --self-pay balance with an existing primary coverage
      WHEN hlb.bkt_type_ha_c = 1 THEN COALESCE(pfc.Financial_class_name,'*UNKNOWN FINANCIAL CLASS')
   END
   ) CALC_FIN_CLASS,
 pfc.Financial_class_name PRIMARY_FIN_CLASS,
 (CASE
  WHEN  harsnap.fin_class_c is NULL or harsnap.fin_class_c = '4' THEN 'Self-pay'
  ELSE ppayor.payor_name 
 END) PRIMARY_PAYOR,
 (CASE
  WHEN  harsnap.fin_class_c is NULL or harsnap.fin_class_c = '4' THEN 'Self-pay'
  ELSE pprdtype.name 
 END) PRIMARY_PROD_TYPE,
 (CASE
  WHEN  harsnap.fin_class_c is NULL or harsnap.fin_class_c = '4' THEN 'Self-pay'
  ELSE pepp.benefit_plan_name 
 END) PRIMARY_PLAN,

--{?Sort Order} SORT_ORDER_PARAM,
CALENDAR_DT AGING_DATE
FROM 
 hsp_bkt_snapshot hlbsnap
 INNER JOIN RPT_DATE dt on hlbsnap.SNAP_START_DATE <= dt.CALENDAR_DT
             and hlbsnap.SNAP_END_DATE >= dt.CALENDAR_DT
 Inner join hsp_bucket hlb on hlbsnap.bucket_id=hlb.bucket_id
 INNER JOIN hsp_account har ON hlbsnap.hsp_account_id = har.hsp_account_id
 INNER JOIN hsp_account_2 har2 ON hlbsnap.hsp_account_id = har2.hsp_account_id
 INNER JOIN HSP_HAR_SNAPSHOT harsnap on harsnap.hsp_account_id=har.hsp_account_id
 LEFT OUTER JOIN clarity_sa sa ON hlb.serv_area_id = sa.serv_area_id
 LEFT OUTER JOIN clarity_loc loc ON har.loc_id = loc.loc_id
 INNER JOIN zc_bkt_type_ha bkttype on hlb.bkt_type_ha_c=bkttype.bkt_type_ha_c
 LEFT OUTER JOIN ZC_BKT_STS_HA bktsts on hlbsnap.BKT_STS_HA_C=bktsts.BKT_STS_HA_C
 INNER JOIN hsd_base_class_map bclsmap ON harsnap.acct_class_ha_c = bclsmap.acct_class_map_c 
 INNER JOIN zc_acct_basecls_ha bcls ON bclsmap.base_class_map_c = bcls.acct_basecls_ha_c
 LEFT OUTER JOIN ZC_EXTERNAL_AR_FLA coll on hlbsnap.COLL_STATUS_C=coll.external_ar_fla_c
 LEFT OUTER JOIN ZC_BKT_BALANCE_STATUS bktBalSts on hlbsnap.bkt_balance_status_c=bktBalSts.bkt_balance_status_c
 LEFT OUTER JOIN CLARITY_EPM payor on HLB.payor_id = PAYOR.payor_id
 LEFT OUTER JOIN CLARITY_EPM ppayor on HARsnap.primary_payor_id = PPAYOR.payor_id
 LEFT OUTER JOIN CLARITY_EPP epp on HLB.BENEFIT_PLAN_ID = epp.BENEFIT_PLAN_ID
 LEFT OUTER JOIN CLARITY_EPP_2 epp2 on HLB.BENEFIT_PLAN_ID = epp2.BENEFIT_PLAN_ID
 LEFT OUTER JOIN ZC_PROD_TYPE prdtype on epp2.PROD_TYPE_C = prdtype.PROD_TYPE_C
 LEFT OUTER JOIN CLARITY_EPP pepp on HARsnap.PRIMARY_PLAN_ID = pepp.BENEFIT_PLAN_ID
 LEFT OUTER JOIN CLARITY_EPP_2 pepp2 on HARsnap.PRIMARY_PLAN_ID = pepp2.BENEFIT_PLAN_ID
 LEFT OUTER JOIN ZC_PROD_TYPE pprdtype on pepp2.PROD_TYPE_C = pprdtype.PROD_TYPE_C
 LEFT OUTER JOIN CLARITY_FC FC ON PAYOR.FINANCIAL_CLASS=FC.FINANCIAL_CLASS
 LEFT OUTER JOIN CLARITY_FC PFC ON harsnap.FIN_CLASS_C=PFC.FINANCIAL_CLASS
 LEFT OUTER JOIN cl_col_agncy agency ON harsnap.col_agncy_id = agency.col_agncy_id
 LEFT OUTER JOIN zc_sp_level splvl ON harsnap.sp_level_c = splvl.sp_level_c
 LEFT OUTER JOIN ZC_ACCT_CLASS_HA acls ON harsnap.acct_class_ha_c = acls.acct_class_ha_c 
 LEFT OUTER JOIN zc_claim_form_type clform ON hlbsnap.claim_type_c = clform.claim_form_type_c

 LEFT OUTER JOIN clarity_dep dep ON har.disch_dept_id = dep.department_id
 LEFT JOIN
	(select HospitalAccount, count(VisitTypeId) [vacCount]
		from [UMCSN].[vw_CovidVaccineAdminView]
		where HospitalAccount IS NOT NULL
		group by HospitalAccount
	) vacView on convert(varchar(max), HAR.HSP_ACCOUNT_ID) = vacView.HospitalAccount
 LEFT JOIN
	(select HospitalAccount, count(VisitTypeId) [testCount]
		from [UMCSN].[vw_CovidPcrLabsView]
		where HospitalAccount IS NOT NULL
		group by HospitalAccount
	) testView on  convert(varchar(max), HAR.HSP_ACCOUNT_ID) = testView.HospitalAccount

WHERE
harsnap.snap_start_date <= dt.CALENDAR_DT and harsnap.snap_end_date >= dt.CALENDAR_DT
 and hlbsnap.bucket_bal <> 0 /*exclude buckets with zero dollar balance*/
 --and (0 IN {?Service Area ID} OR hlb.serv_area_id IN {?Service Area ID})
 --and (0 IN {?Location ID} OR har.loc_id IN {?Location ID})
 --and (0 IN {?Balance Status} OR hlbsnap.bkt_balance_status_c IN {?Balance Status})
 --and (({?AR Type}=3)     OR  ({?AR Type}=coalesce(hlbsnap.COLL_STATUS_C,0)) )
) tbl
--ORDER BY
--CASE WHEN tbl.SORT_ORDER_PARAM=1 THEN tbl.hsp_account_id END asc,
-- CASE WHEN tbl.SORT_ORDER_PARAM=2 THEN tbl.hsp_account_name END asc,
-- CASE WHEN tbl.SORT_ORDER_PARAM=3 THEN tbl.bucket_Id END asc