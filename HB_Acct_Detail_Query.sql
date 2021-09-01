SELECT
 *
FROM
(
SELECT 
 harsnap.hsp_account_id HSP_ACCOUNT_ID,
 har.hsp_account_name HSP_ACCOUNT_NAME,
 sa.serv_area_name SERV_AREA_NAME,
 loc.loc_name LOC_NAME,
 harsnap.guarantor_id GUARANTOR_ID,
 ear.account_name GUARANTOR_NAME,
 accttype.name GUAR_ACCT_TYPE_NAME,
 bcls.name BASE_CLASS_NAME,
 acls.name ACCT_CLASS_NAME,
 fcls.name PRIMARY_FIN_CLASS_NAME,
 dep.department_name DISCH_DEPT,
 CASE
  WHEN  harsnap.fin_class_c is NULL or harsnap.fin_class_c = '4' THEN 'Self-pay'
  ELSE epm.payor_name 
 END PRIMARY_PAYOR_NAME,
 CASE
  WHEN  harsnap.fin_class_c is NULL or harsnap.fin_class_c = '4' THEN 'Self-pay'
  ELSE prdtyp.name 
 END PRIMARY_PROD_TYPE_NAME,
 CASE
  WHEN  harsnap.fin_class_c is NULL or harsnap.fin_class_c = '4' THEN 'Self-pay'
  ELSE epp.benefit_plan_name 
 END PRIMARY_PLAN_NAME,
  harsts.name ACCT_STATUS_NAME,
 harsnap.discharge_date DISCHARGE_DATE,
 CASE
  WHEN harsnap.discharge_date IS NULL then NULL
  ELSE EPIC_UTIL.EFN_DATEDIFF('days',harsnap.discharge_date,dt.CALENDAR_DT)
 END AGE_FROM_DISCH,
 CASE 
  WHEN harsnap.discharge_date IS NULL then 'No Discharge Date'
  WHEN EPIC_UTIL.EFN_DATEDIFF('days',harsnap.discharge_date,dt.CALENDAR_DT) <= 30 then '0-30'
  WHEN EPIC_UTIL.EFN_DATEDIFF('days',harsnap.discharge_date,dt.CALENDAR_DT) <= 60 then '31-60'
  WHEN EPIC_UTIL.EFN_DATEDIFF('days',harsnap.discharge_date,dt.CALENDAR_DT) <= 90 then '61-90'
  WHEN EPIC_UTIL.EFN_DATEDIFF('days',harsnap.discharge_date,dt.CALENDAR_DT) <= 120 then '91-120'
  WHEN EPIC_UTIL.EFN_DATEDIFF('days',harsnap.discharge_date,dt.CALENDAR_DT) <= 150 then '121-150'
  WHEN EPIC_UTIL.EFN_DATEDIFF('days',harsnap.discharge_date,dt.CALENDAR_DT) <= 180 then '151-180'
  ELSE '181+'
 END AGE_BUCKET_DISCH, 
 CASE 
  WHEN harsnap.coll_status_c = 2 OR harsnap.acct_billsts_ha_c = 20 THEN 'Yes'
  ELSE 'No'
 END BAD_DEBT_YN,
 CASE 
  WHEN harsnap.coll_status_c = 1 THEN 'Yes'
  ELSE 'No'
 END EXTERN_AR_YN,
 CASE 
  WHEN harsnap.outsourced_flag_yn = 'Y' THEN 'Yes'
  ELSE 'No'
 END OUTSOURCED_YN,
 agency.coll_agency_name AGENCY_NAME,
 harsnap.coll_agency_assn_dt AGENCY_ASSIGN_DATE,
 CASE  
  WHEN harsnap.coll_agency_assn_dt IS NULL then NULL
  ELSE EPIC_UTIL.EFN_DATEDIFF('days',harsnap.coll_agency_assn_dt,dt.CALENDAR_DT)
 END AGE_FROM_AGENCY_ASSIGN,
 splvl.name SP_LEVEL_NAME,
 harsnap.sp_cycle_start_dt SP_LEVEL_START_DATE,
 CASE
  WHEN harsnap.sp_cycle_start_dt IS NULL then NULL
  ELSE EPIC_UTIL.EFN_DATEDIFF('days',harsnap.sp_cycle_start_dt,dt.CALENDAR_DT)
 END AGE_FROM_SP_LEVEL_START,
 CASE 
  WHEN harsnap.tot_acct_bal < 0 THEN 'Yes'
  ELSE 'No'
 END ACCT_CREDIT_BALANCE_YN,
 harsnap.tot_chgs TOTAL_CHARGES,
 harsnap.tot_pmts TOTAL_PAYMENTS,
 harsnap.tot_adjs TOTAL_ADJUSTMENTS,
 harsnap.tot_acct_bal TOTAL_ACCOUNT_BALANCE,
 CASE 
  WHEN harsnap.coll_status_c IS NULL THEN harsnap.tot_acct_bal - COALESCE(bdbkt.bucket_bal,0.00)
  ELSE COALESCE(pbbkt.bucket_bal,0.00)
 END AR_BALANCE,
 CASE 
  WHEN harsnap.coll_status_c = 2 THEN harsnap.tot_acct_bal - COALESCE(pbbkt.bucket_bal,0.00)
  ELSE COALESCE(bdbkt.bucket_bal,0.00)
 END BAD_DEBT_BALANCE,
  CASE 
  WHEN harsnap.coll_status_c = 1 THEN harsnap.tot_acct_bal - COALESCE(pbbkt.bucket_bal,0.00)
  ELSE 0.00
 END EXTERNAL_AR_BALANCE,
 COALESCE(pbbkt.bucket_bal,0.00) PRE_BILL_BALANCE,
 CASE 
  WHEN harsnap.coll_status_c IS NULL THEN COALESCE(udbkt.bucket_bal,0.00)
  ELSE 0.00
 END AR_UNDIST_BALANCE,
 CASE 
  WHEN harsnap.coll_status_c IS NULL THEN harsnap.tot_acct_bal - COALESCE(spbkt.bucket_bal,0.00) - 
   COALESCE(pbbkt.bucket_bal,0.00) - COALESCE(udbkt.bucket_bal,0.00) - COALESCE(bdbkt.bucket_bal,0.00)
  ELSE 0.00
 END AR_INSURANCE_BALANCE,
  CASE 
  WHEN harsnap.coll_status_c IS NULL THEN COALESCE(spbkt.bucket_bal,0.00)
  ELSE 0.00
 END AR_PATIENT_BALANCE,
 CASE 
  WHEN harsnap.coll_status_c = 2 THEN COALESCE(udbkt.bucket_bal,0.00)
  ELSE 0.00
 END BAD_DEBT_UNDIST_BALANCE, 
 CASE 
  WHEN harsnap.coll_status_c = 2 THEN harsnap.tot_acct_bal - COALESCE(spbkt.bucket_bal,0.00) - 
   COALESCE(pbbkt.bucket_bal,0.00) - COALESCE(udbkt.bucket_bal,0.00) 
  ELSE 0.00
 END BAD_DEBT_INSURANCE_BALANCE,
 CASE 
  WHEN harsnap.coll_status_c = 2 THEN COALESCE(spbkt.bucket_bal,0.00)
  ELSE COALESCE(bdbkt.bucket_bal,0.00)
 END BAD_DEBT_PATIENT_BALANCE,
 CASE 
  WHEN harsnap.coll_status_c = 1 THEN COALESCE(udbkt.bucket_bal,0.00) 
  ELSE 0.00
 END EXTERNAL_AR_UNDIST_BALANCE,
 CASE 
  WHEN harsnap.coll_status_c = 1 THEN harsnap.tot_acct_bal - COALESCE(spbkt.bucket_bal,0.00) - 
   COALESCE(pbbkt.bucket_bal,0.00) - COALESCE(udbkt.bucket_bal,0.00) 
  ELSE 0.00
 END EXTERNAL_AR_INSURANCE_BALANCE,
 CASE 
  WHEN harsnap.coll_status_c = 1 THEN COALESCE(spbkt.bucket_bal,0.00)
  ELSE 0.00
 END EXTERNAL_AR_PATIENT_BALANCE,
 {?Report Type} REPORT_TYPE_PARAM, /*these static columns are used for the sorting options*/
 {?Sort Order} SORT_ORDER_PARAM
FROM 
 hsp_har_snapshot harsnap 
 INNER JOIN hsp_account har ON harsnap.hsp_account_id = har.hsp_account_id
 INNER JOIN date_dimension dt on harsnap.SNAP_START_DATE <= dt.CALENDAR_DT
             and harsnap.SNAP_END_DATE >= dt.CALENDAR_DT 
             and dt.CALENDAR_DT=EPIC_UTIL.EFN_DIN('{?Age Trial Balance Date}')
 LEFT OUTER JOIN clarity_sa sa ON har.serv_area_id = sa.serv_area_id
 LEFT OUTER JOIN clarity_loc loc ON har.loc_id = loc.loc_id
 LEFT OUTER JOIN clarity_dep dep ON har.disch_dept_id = dep.department_id
 LEFT OUTER JOIN account ear ON harsnap.guarantor_id = ear.account_id
 LEFT OUTER JOIN zc_account_type accttype ON ear.account_type_c = accttype.account_type_c
 LEFT OUTER JOIN hsd_base_class_map bclsmap ON harsnap.acct_class_ha_c = bclsmap.acct_class_map_c 
 LEFT OUTER JOIN zc_acct_basecls_ha bcls ON bclsmap.base_class_map_c = bcls.acct_basecls_ha_c
 LEFT OUTER JOIN zc_pat_class acls ON harsnap.acct_class_ha_c = acls.adt_pat_class_c
 LEFT OUTER JOIN zc_cur_fin_class fcls ON harsnap.fin_class_c = fcls.cur_fin_class
 LEFT OUTER JOIN zc_acct_billsts_ha harsts ON harsnap.acct_billsts_ha_c = harsts.acct_billsts_ha_c
 LEFT OUTER JOIN clarity_epm epm ON harsnap.primary_payor_id = epm.payor_id
 LEFT OUTER JOIN clarity_epp epp ON harsnap.primary_plan_id = epp.benefit_plan_id
 LEFT OUTER JOIN clarity_epp_2 epp2 ON harsnap.primary_plan_id = epp2.benefit_plan_id
 LEFT OUTER JOIN zc_prod_type prdtyp ON epp2.prod_type_c = prdtyp.prod_type_c
 LEFT OUTER JOIN hsp_bkt_snapshot spbkt ON har.self_pay_bucket_id = spbkt.bucket_id 
                  and spbkt.snap_start_date <= dt.CALENDAR_DT 
                  and spbkt.snap_end_date >= dt.CALENDAR_DT
 LEFT OUTER JOIN hsp_bkt_snapshot pbbkt ON har.prebill_bucket_id = pbbkt.bucket_id 
                  and pbbkt.snap_start_date <= dt.CALENDAR_DT 
                  and pbbkt.snap_end_date >= dt.CALENDAR_DT
 LEFT OUTER JOIN hsp_bkt_snapshot bdbkt ON har.bad_debt_bucket_id = bdbkt.bucket_id 
                  and bdbkt.snap_start_date <= dt.CALENDAR_DT 
                  and bdbkt.snap_end_date >= dt.CALENDAR_DT
 LEFT OUTER JOIN hsp_bkt_snapshot udbkt ON har.undistrb_bucket_id = udbkt.bucket_id 
                  and udbkt.snap_start_date <= dt.CALENDAR_DT 
                  and udbkt.snap_end_date >= dt.CALENDAR_DT
 LEFT OUTER JOIN cl_col_agncy agency ON harsnap.col_agncy_id = agency.col_agncy_id
 LEFT OUTER JOIN zc_sp_level splvl ON harsnap.sp_level_c = splvl.sp_level_c
WHERE
 harsnap.acct_billsts_ha_c in (1,3,4,20,99) /*include open, DNB, billed, bad debt, and combined accounts*/
 and (0 IN {?Service Area ID} OR har.serv_area_id IN {?Service Area ID})
 and (0 IN {?Location ID} OR har.loc_id IN {?Location ID})
 and (0 IN ({?Balance Type})
     OR (1 IN ({?Balance Type}) and harsnap.tot_acct_bal > 0)
     OR (2 IN ({?Balance Type}) and harsnap.tot_acct_bal < 0))
 and (0 IN ({?Report Type})
       OR (1 IN ({?Report Type}) /*include accounts that have a non-zero AR balance*/
        and (CASE 
              WHEN harsnap.coll_status_c IS NULL THEN harsnap.tot_acct_bal - COALESCE(bdbkt.bucket_bal,0.00)
              ELSE COALESCE(pbbkt.bucket_bal,0.00)
             END) <> 0)
       OR (2 IN ({?Report Type}) /*include accounts that have a non-zero bad debt or external AR balance*/
        and ((CASE 
               WHEN harsnap.coll_status_c = 2 THEN harsnap.tot_acct_bal - COALESCE(pbbkt.bucket_bal,0.00)
               ELSE COALESCE(bdbkt.bucket_bal,0.00)
              END) <> 0
             OR 
             (CASE 
               WHEN harsnap.coll_status_c = 1 THEN harsnap.tot_acct_bal - COALESCE(pbbkt.bucket_bal,0.00)
               ELSE 0.00
              END) <> 0)))
) tbl

WHERE
tbl.AR_BALANCE <> 0
OR tbl.BAD_DEBT_BALANCE <> 0
OR tbl.EXTERNAL_AR_BALANCE <> 0
OR tbl.PRE_BILL_BALANCE <> 0
OR tbl.AR_UNDIST_BALANCE <> 0
OR tbl.AR_INSURANCE_BALANCE <> 0
OR tbl.AR_PATIENT_BALANCE <> 0
OR tbl.BAD_DEBT_UNDIST_BALANCE <> 0
OR tbl.BAD_DEBT_INSURANCE_BALANCE <> 0
OR tbl.BAD_DEBT_PATIENT_BALANCE <> 0
OR tbl.EXTERNAL_AR_UNDIST_BALANCE <> 0
OR tbl.EXTERNAL_AR_INSURANCE_BALANCE <> 0
OR tbl.EXTERNAL_AR_PATIENT_BALANCE <> 0

ORDER BY
 CASE WHEN tbl.SORT_ORDER_PARAM=1 THEN tbl.hsp_account_id END asc,
 CASE WHEN tbl.SORT_ORDER_PARAM=2 THEN tbl.hsp_account_name END asc,
 CASE WHEN tbl.SORT_ORDER_PARAM=2 THEN tbl.hsp_account_id END asc,
 CASE WHEN tbl.SORT_ORDER_PARAM=3 AND tbl.REPORT_TYPE_PARAM=0 THEN tbl.TOTAL_ACCOUNT_BALANCE END asc,
 CASE WHEN tbl.SORT_ORDER_PARAM=3 AND tbl.REPORT_TYPE_PARAM=1 THEN tbl.AR_BALANCE END asc,
 CASE WHEN tbl.SORT_ORDER_PARAM=3 AND tbl.REPORT_TYPE_PARAM=2 THEN (tbl.BAD_DEBT_BALANCE + tbl.EXTERNAL_AR_BALANCE) END asc,
 CASE WHEN tbl.SORT_ORDER_PARAM=4 AND tbl.REPORT_TYPE_PARAM=0 THEN tbl.TOTAL_ACCOUNT_BALANCE END desc,
 CASE WHEN tbl.SORT_ORDER_PARAM=4 AND tbl.REPORT_TYPE_PARAM=1 THEN tbl.AR_BALANCE END desc,
 CASE WHEN tbl.SORT_ORDER_PARAM=4 AND tbl.REPORT_TYPE_PARAM=2 THEN (tbl.BAD_DEBT_BALANCE + tbl.EXTERNAL_AR_BALANCE) END desc