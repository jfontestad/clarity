/**********************************************************************************************

AUTHOR			: 
PROC_ NAME		: PSG_HspTrans
DESCRIPTION		: This Proc retrieves the required fields for hospital utilization to PSG
DATE CREATED   	: 2015-11-12
				: Currently setup to run from SQL Server 2012 Management Studio.
				  Some changes required to run from Virtual Studio 2012 in production environment
UPDATED			:  2/18/2019 - ADDED LOGIC TO PULL ADMIN DATE/TIME WHEN POSSIBLE.
**************************************************************************************************

Preferred file format: Pipe [|] delimited text
Preferred Naming convention: [Hospital]_HspTrans_CCYYMMDDHHMMSS.txt  ex: UMC_HspTrans_20190531164400.txt

**************************************************************************************************
Modifications: 03/22-26/2019  Braxton Broady (UMC) customization for UMC
               04/08/2019  Braxton Broady (UMC) add in logic and tables to get the ADS info for a SIM charge code
			            to be used when there is no scanned barcode.  
			   04/10/2019  Braxton Broady (UMC) Per PSG, requested to comment out all but a few columns in the final
			            output file.  Leave the logic in so any commennted out column can be added back in should 
						it be needed:  
						TX_ID
						HSP_ACCOUNT_ID
						PAT_ENC_CSN_ID
						ADMIN_DATE
						ADMIN_TIME
						MEDADMIN_DEPARTMENT_ID
						MEDADMIN_DEPARTMENT
						SIM
						RAW_11_DIGIT_NDC
						PROCEDURE_DESC
						IMPLIED_QTY
						QUANTITY
						TX_BASE_CLASS_ABBR
						PAT_BASE_CLAS_AT_CHARGE_ABBR
						ORDER_ID
						IMPLIED_QTY_UNIT_NAME_HTR
						IMPLIED_UNIT_TYPE_NAME_HTR
						UCL_ID
						SCANNED_BARCODE
						USER_ID
			   04/18/2019  Braxton Broady (UMC) Per PSG, requested UMC to comment out the code that is excluding 
			            data when the Payor is Null.  Also want the logic added into the code to pull the PB charges
						as well.  Acknowedged that their script was missing the PB logic. Want UMC to add in the PB
						transactions either in this extract or a separate extract. If we Union the files, want a 
						column at the end of the row that contains HB when Hospital Bill, or PB when Professional Bill.
			   09/10/2019  Braxton Broady (UMC) INC0222574 per PSG, the 7/09 file could not be ingested due to Nulls
			            PSG would like a new file with the 7/08 data and no nulls. Offending column was the 
						BASE_CLASS_ABBR. Now we pull it from UCL and if NULL then HTR. Created a new sql script that 
						can be ran on demand, UMC_PSG_Epic_HB_PB_Trans_OnDemand.sql
               01/09/2020  Braxton Broady (UMC) working with Lindsey Vandersteen where Pharmacy discovered that for 
			            unscanned items the SIM is defaulting to the ERX but we should check the Order information 
						for the validated NDC to get the proper SIM value.
               01/14/2020 Braxton Broady (UMC) make sure that the temp tables are not temp global tables.  
			            Ensure each temp table begins with a single # not 2 #.
			   05/24/2020 Braxton Broady (UMC) code for NULL raw_11_digit_ndc columns in final output.

*/

use clarity;   -- comment this line out for SQL job scheduling
set nocount on;
set ansi_warnings off;
--SET ANSI_WARNINGS OFF;
--SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

---- Check for existence of temp tables we'll use and drop them if needed
Drop Table if exists #tmp_PharmRevCodes
DROP TABLE if exists #tmp_PSG_PAT_CLASS 
DROP TABLE if exists #tmp_PSG_LOC
Drop Table if exists #tmp_PSG_HTRPB
Drop Table if exists #tmp_PSG_HTRHB
DROP TABLE if exists #tmp_PSG_HTR
DROP TABLE if exists #tmp_PSG_UCL
DROP TABLE if exists #tmp_PSG_MAR
DROP TABLE if exists #tmp_PSG_OM
DROP TABLE if exists #tmp_PSG_PAYOR
Drop Table if exists #tmp_PSG_Transactions


-- variables and constants
DECLARE
@StartDate DATETIME = DateAdd(D,-1,cast(GetDate() as Date)),
@EndDate DATETIME =  cast(GetDate() as Date),
@REVENUE_LOC VARCHAR(100) = '10';
set @StartDate = cast('10/12/2020' AS date)
set @EndDate = cast('11/13/2020' as date)
----SELECT @startDate,@enddate

Select 
   ub_rev_code_id as epicrevcodeid
  ,revenue_code_name as RevCodeName
  ,revenue_code as PharmRevCode
  into #tmp_PharmRevCodes
From 
     CL_UB_REV_CODE
Where revenue_code_name Like '%PHARMACY%'
      Or revenue_code = '0270'  --limit to pharmacy rev codes


/*---------------------------------------------------------------------------------------------------------------------
	BASE CLASS    
---------------------------------------------------------------------------------------------------------------------*/
SELECT 
     MAP.ACCT_CLASS_MAP_C AS PAT_CLASS_C
	 ,CLS.TITLE AS PAT_CLASS_DESC
	 ,cls.ABBR  AS PAT_CLASS_ABBR
     ,MAP.BASE_CLASS_MAP_C AS BASE_CLASS_C
	 ,BCLS.TITLE AS BASE_CLASS_DESC
	 ,BCLS.ABBR AS BASE_CLASS_ABBR
     ,MAP.MAPPING_ACTIVE_F_YN AS ACTIVE_YN

     INTO #tmp_PSG_PAT_CLASS  

FROM 
     HSD_BASE_CLASS_MAP MAP
     LEFT OUTER JOIN ZC_PAT_CLASS CLS ON MAP.ACCT_CLASS_MAP_C= CLS.ADT_PAT_CLASS_C
     LEFT OUTER JOIN ZC_ACCT_BASECLS_HA BCLS ON MAP.BASE_CLASS_MAP_C= BCLS.ACCT_BASECLS_HA_C

WHERE
     MAP.ACCT_CLASS_MAP_C IS NOT NULL
     AND MAP.PROFILE_ID=1


/*---------------------------------------------------------------------------------------------------------------------
	LOCATION
---------------------------------------------------------------------------------------------------------------------*/
SELECT

	 LOC.LOC_ID
	,LOC_NAME
	,LOCATION_ABBR

INTO #tmp_PSG_LOC

FROM 
	CLARITY_LOC LOC
WHERE
	(','+ '10' /* @REVENUE_LOC */ +',' LIKE '%,'+ CAST(LOC.LOC_ID AS VARCHAR(100))+ ',%')


/*---------------------------------------------------------------------------------------------------------------------
	PB TRANSACTIONS  gather Meds administered in the PB system (outlier clinics)
---------------------------------------------------------------------------------------------------------------------*/
SELECT
    ucl1.CHARGE_FILED_TIME as TX_POST_DATE
    ,tdl.TX_ID as TX_ID
    ,tdl.HSP_ACCOUNT_ID as HSP_ACCOUNT_ID
    ,enc1.PAT_ENC_CSN_ID as PAT_ENC_CSN_ID
    ,enc1.Department_id as DEPARTMENT
    ,cdep.Department_name as DEPARTMENT_NAME
    ,ucl1.Cost_Center_id  as COST_CENTER_CODE
    ,ccc.COST_CENTER_NAME as COST_CENTER_NAME
    ,ucl1.Revenue_Location_id as REVENUE_LOC_ID
    ,loc.Loc_Name as LOC_NAME
    ,ucl1.Medication_id as ERX_ID
	---- our charge# is stored on one of 3 levels; NDC or NDG or ERX; 
	---- use the charge id if not found within the 3 NDC levels
	--,ltrim(rtrim(isnull(COALESCE(ndcADSID.MPI_ID_VAL,ndgADSID.MPI_ID,erxADSID.MPI_ID,convert(character(12),ucl1.Medication_id)),''))) as SIM
	----,ltrim(rtrim(isnull(COALESCE(ndcADSID.MPI_ID_VAL,ndgADSID.MPI_ID,erxADSID.MPI_ID
 ----                                ,convert(character(12),ucl1.Medication_id)),''))) as marSIM
	----,ltrim(rtrim(isnull(COALESCE(ndcADSID.MPI_ID_VAL,ndgADSID.MPI_ID,erxADSID.MPI_ID
 ----                                ,convert(character(12),ucl1.Medication_id)),''))) as ordSIM
 	,ltrim(rtrim(isnull(COALESCE(marndcadsid.mpi_id_val,marndgADSID.MPI_ID,erxADSID.MPI_ID),''))) as marSIM
 	,ltrim(rtrim(isnull(COALESCE(ordndcADSID.MPI_ID_VAL,ordndgADSID.MPI_ID,erxADSID.MPI_ID),''))) as ordSIM

	,NDC.RAW_11_DIGIT_NDC as RAW_11_DIGIT_NDC
	,coalesce(ndgndg.ndg_name,med.name) as ProductDesc  -- UMC is using this instead of Procedure Description
    ,tdl.Amount as TX_AMOUNT
    ,cast(etr.Debit_credit_flag * ucl1.Implied_qty as numeric(16,3))  as QUANTITY
    ,map.ACCT_CLASS_MAP_C as TX_PAT_CLASS
	,ucl1.order_id as ORDER_ID
	,ucl1.charge_filed_time as TX_FILED_TIME
	,tdl.tx_num as TX_NUM_IN_HOSPACCT
	,ucl1.created_user_id as USER_ID
	,cfc.financial_class_name as FINANCIAL_CLASS
	,zcmu.Name as IMPLIED_QTY_UNIT_NAME_HTR
	,ZIEU.NAME  AS IMPLIED_UNIT_TYPE_NAME_HTR
	--,htr1.CHG_ROUTER_SRC_ID as CHG_ROUTER_SRC_ID
	,ucl1.ucl_id as CHG_ROUTER_SRC_ID
	,ucl1.SERVICE_DATE_DT as SERVICE_DATE
	,HTR1.UB_REV_CODE_ID as UB_REV_CODE_ID 
	,'PB' as SrcSystem   -- denote this record is from PB
	----,htr.pat_id
INTO #tmp_PSG_HTRPB   
from 
  CLARITY_TDL_TRAN  tdl
  inner join ARPB_TRANSACTIONS etr on tdl.TX_ID=etr.TX_ID
  inner join CLARITY_UCL ucl1 on etr.CHG_ROUTER_SRC_ID=ucl1.UCL_ID
  inner join CLARITY_UCL_2 ucl2 on etr.CHG_ROUTER_SRC_ID=ucl2.UCL_ID
  inner join ORDER_MED ord on ucl1.ORDER_ID=ord.ORDER_MED_ID and ord.ORDERING_MODE_C=2
  inner join CLARITY_MEDICATION med on ucl1.MEDICATION_ID=med.MEDICATION_ID  
  inner join ORDER_MEDINFO medinfo on ord.ORDER_MED_ID=medinfo.ORDER_MED_ID
  inner join PAT_ENC enc1 on etr.PAT_ENC_CSN_ID=enc1.PAT_ENC_CSN_ID
  inner join PATIENT ept on enc1.PAT_ID=ept.PAT_ID
  inner join UCL_NDC_CODES uclndc on ucl1.UCL_ID=uclndc.UCL_ID and uclndc.LINE=1
  inner join RX_NDC ndc on uclndc.NDC_CODE_ID=ndc.NDC_ID

  left outer join CL_COST_CNTR CCC ON ucl1.COST_CENTER_ID = CCC.COST_CNTR_ID
  left outer JOIN #tmp_PSG_LOC LOC ON ucl1.Revenue_Location_id = LOC.LOC_ID
  left outer join ORDER_DISP_INFO disp1 on ucl1.ORDER_ID=disp1.ORDER_MED_ID and ucl2.RX_ORDER_DTE=disp1.CONTACT_DATE_REAL
  left outer join ORDER_DISP_INFO_2 disp2 on ucl1.ORDER_ID=disp2.ORDER_ID and disp2.CONTACT_DATE_REAL=disp1.CONTACT_DATE_REAL
  left outer join Clarity_dep cdep on enc1.DEPARTMENT_ID = cdep.DEPARTMENT_ID
  left outer join HSD_BASE_CLASS_MAP map on ucl2.PAT_CLASS_AT_CHARGE_TRIGGER_C=map.ACCT_CLASS_MAP_C
  left outer join ZC_ACCT_BASECLS_HA zcbaseclass on map.BASE_CLASS_MAP_C=zcbaseclass.ACCT_BASECLS_HA_C
  left outer join RX_NDC_MPI_ID ndcADSID ON ndcADSID.NDC_ID = ndc.NDC_ID AND ndcADSID.MPI_ID_TYPE_ID =  9
  left outer join RX_NDG_MPI_ID ndgADSID ON ndgADSID.NDG_ID = ndc.ASSOCIATED_NDG AND ndgADSID.MPI_ID_TYPE_ID = 71
  left outer join RX_MED_EPI_ID_NUM erxADSID ON erxADSID.MEDICATION_ID = med.medication_id and erxADSID.MPI_ID_TYPE_ID = 10 --> may want to change this for mixtures
  left outer join RX_NDG ndgndg on ndc.associated_ndg=ndgndg.ndg_id
  left outer join hsp_transactions htr1 on tdl.tx_id=htr1.tx_id 
  left outer join hsp_transactions_2 htr2 ON tdl.tx_id=htr2.tx_id

------=====================
   left join #tmp_PharmRevCodes tprc on htr1.ub_rev_code_id=tprc.epicrevcodeid
-------- mar 
	left outer JOIN MAR_ADDL_INFO MAR ON  ucl1.ORDER_ID = MAR.ORDER_ID 
----	                                 AND HTR.ERX_ID = MAR.ERX_ID
	left outer join rx_ndc_status marrns on mar.ndc_csn_id=marrns.cnct_serial_num
    left outer join RX_NDC marndc on marrns.NDC_ID=marndc.NDC_ID                     
	left outer join RX_NDC_MPI_ID marndcADSID ON marndcADSID.NDC_ID = marndc.NDC_ID AND marndcADSID.MPI_ID_TYPE_ID =  9 
	left outer join RX_NDG_MPI_ID marndgADSID ON marndgADSID.NDG_ID = marndc.ASSOCIATED_NDG AND marndgADSID.MPI_ID_TYPE_ID = 71
------------ orders  
	left outer join v_rx_charges vrc on ucl1.order_id=vrc.order_id and etr.CHG_ROUTER_SRC_ID=vrc.ucl_id  --htr1.chg_router_src_id=vrc.ucl_id
	left outer join rx_ndc_status ordrns on vrc.disp_ndc_csn=ordrns.cnct_serial_num
    left outer join RX_NDC ordndc on ordrns.NDC_ID=ordndc.NDC_ID                     
	left outer join RX_NDC_MPI_ID ordndcADSID ON ordndcADSID.NDC_ID = ordndc.NDC_ID AND ordndcADSID.MPI_ID_TYPE_ID =  9 
	left outer join RX_NDG_MPI_ID ordndgADSID ON ordndgADSID.NDG_ID = ordndc.ASSOCIATED_NDG AND ordndgADSID.MPI_ID_TYPE_ID = 71
----------=====================


  left outer join cl_ub_rev_code clurc on htr1.dflt_ub_rev_cd_id=clurc.ub_rev_code_id
  left outer join clarity_fc cfc on etr.ORIGINAL_FC_C=cfc.financial_class
  left outer join ZC_MED_UNIT zcmu on ucl1.IMPLIED_QTY_UNIT_C=zcmu.DISP_QTYUNIT_C
  left outer join ZC_IMP_EXT_UNIT ZIEU ON HTR2.IMPLIED_UNIT_TYPE_C = ZIEU.IMP_EXT_UNIT_C

WHERE  
  tdl.DETAIL_TYPE in (1) 
--- select the records that occurred during the previous day.
 and (Convert(varchar(10), tdl.POST_DATE, 101) >= @StartDate 
     and Convert(varchar(10), tdl.POST_DATE, 101) < @EndDate)
 -- Exclude mixture charges if not charge by component (MIXTURE_TYPE_C is null is medication is not a mixture)
  and (medinfo.MIXTURE_TYPE_C is null or ((medinfo.MIXTURE_TYPE_C=1 or medinfo.MIXTURE_TYPE_C=2) and disp1.CHG_BY_COMP_YN='Y'))
-- Only include UMC patients service area 10
  and tdl.serv_area_id=10
--Exclude patient supplied charges
  and (ucl2.PT_SUPPLIED_YN is null or ucl2.PT_SUPPLIED_YN='N') 



--select * from #tmp_PSG_HTRPB
/*---------------------------------------------------------------------------------------------------------------------
	HB TRANSACTIONS
-----------------------------------------------------------------------------------------------------------------------*/
--declare @StartDate DATETIME = DateAdd(D,-1,cast(GetDate() as Date)),
--@EndDate DATETIME =  cast(GetDate() as Date),
--@REVENUE_LOC VARCHAR(100) = '10';
--set @StartDate = cast('12/23/2019' AS date)
--set @EndDate = cast('12/24/2019' as date)

SELECT
	
	HTR.TX_POST_DATE
	,HTR.TX_ID
	,HTR.HSP_ACCOUNT_ID
	,HTR.PAT_ENC_CSN_ID
	,HTR.DEPARTMENT
	,DEP.DEPARTMENT_NAME
	,HTR.COST_CNTR_ID			AS COST_CENTER_CODE
	,CCC.COST_CENTER_NAME
	,HTR.REVENUE_LOC_ID
	,LOC.LOC_NAME 
	,HTR.ERX_ID
	---  maybe first check to see if the NDC on the oRder has an overide NDC, otherwise try to use scan NDC first (to get NDC or NDG)
	---    If it is blank check to the order NDC  we would remove the current ndc-ndg erx logic.  
	--,ltrim(rtrim(isnull(COALESCE(ndcADSID.MPI_ID_VAL,ndgADSID.MPI_ID,erxADSID.MPI_ID),''))) as SIM
 	,ltrim(rtrim(isnull(COALESCE(marndcadsid.mpi_id_val,marndgADSID.MPI_ID,erxADSID.MPI_ID),''))) as marSIM
 	,ltrim(rtrim(isnull(COALESCE(ordndcADSID.MPI_ID_VAL,ordndgADSID.MPI_ID,erxADSID.MPI_ID),''))) as ordSIM
	,NDC.RAW_11_DIGIT_NDC
	--,HTR.PROCEDURE_DESC
	,coalesce(ndgndg.ndg_name,med.name) as ProductDesc  -- UMC is using this instead of Procedure Description
	,HTR.TX_AMOUNT
	,HTR.QUANTITY
	,HTR.ACCT_CLASS_HA_C AS TX_PAT_CLASS
	,HTR.ORDER_ID
	,HTR.TX_FILED_TIME
	,HTR.TX_NUM_IN_HOSPACCT
	,HTR.USER_ID
	,FINCLS.NAME		AS FINANCIAL_CLASS
	,ZMU2.NAME												AS IMPLIED_QTY_UNIT_NAME_HTR
	,ZIEU.NAME												AS IMPLIED_UNIT_TYPE_NAME_HTR
	,HTR.CHG_ROUTER_SRC_ID
	,HTR.SERVICE_DATE
	,HTR.UB_REV_CODE_ID
    ,'HB' as SrcSystem   -- denote this record is from HB
	--,htr.pat_id

INTO #tmp_PSG_HTRHB   -- drop table #tmp_PSG_HTRHB  -- select distinct * from #tmp_PSG_HTRhb where erx_id=129628
FROM 
	HSP_TRANSACTIONS HTR
	left outer JOIN #tmp_PSG_LOC LOC ON HTR.REVENUE_LOC_ID = LOC.LOC_ID
	INNER JOIN CLARITY_DEP DEP ON HTR.DEPARTMENT = DEP.DEPARTMENT_ID
	INNER JOIN HSP_TRANSACTIONS_2 HTR2 ON HTR.TX_ID = HTR2.TX_ID
	LEFT OUTER JOIN CL_COST_CNTR CCC ON HTR.COST_CNTR_ID = CCC.COST_CNTR_ID
	----LEFT OUTER JOIN RX_NDC NDC ON HTR.NDC_ID = NDC.NDC_ID
	LEFT OUTER JOIN ZC_FIN_CLASS FINCLS ON HTR.FIN_CLASS_C = FINCLS.FIN_CLASS_C
	LEFT OUTER JOIN ZC_MED_UNIT ZMU2 ON HTR2.IMPLIED_QTY_UNIT_C =ZMU2.DISP_QTYUNIT_C 
	LEFT OUTER JOIN ZC_IMP_EXT_UNIT ZIEU ON HTR2.IMPLIED_UNIT_TYPE_C = ZIEU.IMP_EXT_UNIT_C
   ----get ads NDC value
------=====================
   left join #tmp_PharmRevCodes tprc on htr.ub_rev_code_id=tprc.epicrevcodeid
---- mar 
	left outer JOIN MAR_ADDL_INFO MAR ON  HTR.ORDER_ID = MAR.ORDER_ID 
	                                 --AND HTR.ERX_ID = MAR.ERX_ID
	left outer join rx_ndc_status marrns on mar.ndc_csn_id=marrns.cnct_serial_num
    left outer join RX_NDC marndc on marrns.NDC_ID=marndc.NDC_ID                     
	left outer join RX_NDC_MPI_ID marndcADSID ON marndcADSID.NDC_ID = marndc.NDC_ID AND marndcADSID.MPI_ID_TYPE_ID =  9 
	left outer join RX_NDG_MPI_ID marndgADSID ON marndgADSID.NDG_ID = marndc.ASSOCIATED_NDG AND marndgADSID.MPI_ID_TYPE_ID = 71
-------- orders  
	left outer join v_rx_charges vrc on htr.order_id=vrc.order_id and htr.chg_router_src_id=vrc.ucl_id
	left outer join rx_ndc_status ordrns on vrc.disp_ndc_csn=ordrns.cnct_serial_num
    left outer join RX_NDC ordndc on ordrns.NDC_ID=ordndc.NDC_ID                     
	left outer join RX_NDC_MPI_ID ordndcADSID ON ordndcADSID.NDC_ID = ordndc.NDC_ID AND ordndcADSID.MPI_ID_TYPE_ID =  9 
	left outer join RX_NDG_MPI_ID ordndgADSID ON ordndgADSID.NDG_ID = ordndc.ASSOCIATED_NDG AND ordndgADSID.MPI_ID_TYPE_ID = 71
------=====================

    left outer join CLARITY_MEDICATION med on htr.ERX_ID=med.MEDICATION_ID
    left outer join HSP_TX_NDC_CODES txndc on htr.TX_ID=txndc.TX_ID and txndc.LINE=1
    left outer join RX_NDC ndc on  txndc.NDC_CODE_RG_ID=ndc.NDC_ID
	left outer join RX_NDC_MPI_ID ndcADSID ON ndcADSID.NDC_ID = ndc.NDC_ID AND ndcADSID.MPI_ID_TYPE_ID =  9
	left outer join RX_NDG_MPI_ID ndgADSID ON ndgADSID.NDG_ID = ndc.ASSOCIATED_NDG AND ndgADSID.MPI_ID_TYPE_ID = 71
	left outer join RX_MED_EPI_ID_NUM erxADSID ON erxADSID.MEDICATION_ID = med.medication_id AND erxADSID.MPI_ID_TYPE_ID = 10 --> may want to change this for mixtures 
	left outer join RX_NDG ndgndg on ndc.associated_ndg=ndgndg.ndg_id
WHERE
--- select the records that occurred during the previous day.
	   (HTR.TX_POST_DATE >= @StartDate AND HTR.TX_POST_DATE < @EndDate) 
	   --htr.order_id=27210673   --31879618  --1041428

	----AND HTR.ERX_ID IS NOT NULL
	and htr.cost_cntr_id=71
	AND HTR.TX_TYPE_HA_C = 1  -- CHARGES
	----AND HTR.UB_REV_CODE_ID <> '7171'             --SKIP ADMIN CHARGE  --- UMC charges on Administration
	AND HTR.TX_AMOUNT <> 0
	and tprc.PharmRevCode is not null


------======================================================
------ UMC debugging
------select distinct * from #tmp_PSG_HTRhb	
----select top 10 * from #tmp_PSG_HTRHB; 	select top 10 * from #tmp_PSG_HTRPB; 
----select count(*) from #tmp_PSG_HTRHB; 	select count(*) from #tmp_PSG_HTRPB; 
----Select 
----  Distinct htrboth.*
---- into #tmp_PSG_HTR
----From (
----(select * from #tmp_PSG_HTRPB)
----union all
----(select * from #tmp_PSG_HTRHB )
----) as htrboth
--select top 1 * from #tmp_PSG_HTRPB;select top 1 * from #tmp_PSG_HTRHB   select * from #tmp_psg_htr
/*---------------------------------------------------------------------------------------------------------------------
---- Merge the #..HTRPB and #..HTRHB rows together into a single HRT file via Union ALL
---------------------------------------------------------------------------------------------------------------------*/
Select 
  Distinct htrboth.*
 into #tmp_PSG_HTR
From (
(select * from #tmp_PSG_HTRPB
union all
select * from #tmp_PSG_HTRHB )
) as htrboth

/*---------------------------------------------------------------------------------------------------------------------
	UCL
---------------------------------------------------------------------------------------------------------------------*/
SELECT
	 HTR.TX_ID
	,UCL.CHARGE_FILED_TIME
	,UCL.IMPLIED_QTY
	,UCL.UCL_ID
	,UCL.REVENUE_LOCATION_ID
	,ucl.DEPARTMENT_ID   -- added to return the charge department 2/13/2019
	,dep.DEPARTMENT_NAME  -- added to return the charge department 2/13/2019
	,LOC2.LOC_NAME
	,UCL2.PAT_CLASS_AT_CHARGE_TRIGGER_C  AS PAT_CLASS_AT_CHARGE

     
INTO #tmp_PSG_UCL

FROM
	#tmp_PSG_HTR HTR
	INNER JOIN CLARITY_UCL UCL ON HTR.CHG_ROUTER_SRC_ID = UCL.UCL_ID
	INNER JOIN CLARITY_UCL_2 UCL2 ON UCL.UCL_ID = UCL2.UCL_ID
	INNER JOIN CLARITY_LOC LOC2 ON UCL.REVENUE_LOCATION_ID = LOC2.LOC_ID
	join CLARITY_DEP dep on dep.DEPARTMENT_ID = ucl.DEPARTMENT_ID
WHERE

	UCL.CHARGE_SOURCE_C IN (43,501)    --review for SLUH


/*---------------------------------------------------------------------------------------------------------------------
	MAR BARCODE 
---------------------------------------------------------------------------------------------------------------------*/
SELECT
	 HTR.ORDER_ID						AS HTR_ORDER_ID		
	,MAR.ORDER_ID
	,MAR.ERX_ID
	,MAX(MAR.SCANNED_BARCODE)			AS SCANNED_BARCODE
	,MAX(MAR.NDC_CSN_ID)				AS NDC_CSN

INTO #tmp_PSG_MAR

FROM 
	#tmp_PSG_HTR HTR
	INNER JOIN MAR_ADDL_INFO MAR ON  HTR.ORDER_ID = MAR.ORDER_ID 
	                                 --AND HTR.ERX_ID = MAR.ERX_ID

GROUP BY
	 HTR.ORDER_ID
	,MAR.ORDER_ID
	,MAR.ERX_ID	


----select top 100
----ORDER_ID,	ERX_ID,	SCANNED_BARCODE,	NDC_CSN_id, count(*)
----from mar_addl_info 
----group by ORDER_ID,	ERX_ID ,scanned_barcode, NDC_CSN_id
----having count(*)>1
----order by order_id   
/*---------------------------------------------------------------------------------------------------------------------
	ORDER INSTANCE from  ORDER_MED ORDER_MED  
---------------------------------------------------------------------------------------------------------------------*/
SELECT
	 HTR.ORDER_ID						AS HTR_ORDER_ID		
	,OM.ORDER_MED_ID
	,OM.ORDER_INST

INTO #tmp_PSG_OM
FROM
	#tmp_PSG_HTR HTR
	INNER JOIN ORDER_MED OM ON  HTR.ORDER_ID = OM.ORDER_MED_ID 
GROUP BY
	 HTR.ORDER_ID
	,OM.ORDER_MED_ID
	,OM.ORDER_INST
--	select * from  #tmp_PSG_OM
/*---------------------------------------------------------------------------------------------------------------------
	Payors
---------------------------------------------------------------------------------------------------------------------*/

SELECT
	 CVG.HSP_ACCOUNT_ID
	,MAX(CASE WHEN CVG.LINE=1 THEN EPM.PAYOR_ID END)AS PRIM_PAYOR_ID
	,MAX(CASE WHEN CVG.LINE=1 THEN EPP.BENEFIT_PLAN_ID END) AS PRIM_PLAN_ID
	,MAX(CASE WHEN CVG.LINE=1 THEN EPM.PAYOR_NAME END)AS PRIMARY_PAYOR_NAME
	,MAX(CASE WHEN CVG.LINE=1 THEN EPP.BENEFIT_PLAN_NAME END) AS PRIM_BENEFIT_PLAN_NAME
	--,MAX(CASE WHEN CVG.LINE=1 THEN EPP.PRODUCT_TYPE END) AS PRIM_PRODUCT_TYPE
	,max(case when cvg.line=1 then epp2.prod_type_c end) as prim_product_type

	,MAX(CASE WHEN CVG.LINE=2 THEN EPM.PAYOR_ID END)AS PAYOR_ID_2
	,MAX(CASE WHEN CVG.LINE=2 THEN EPP.BENEFIT_PLAN_ID END) AS PLAN_ID_2
	,MAX(CASE WHEN CVG.LINE=2 THEN EPM.PAYOR_NAME END)AS PAYOR_NAME_2
	,MAX(CASE WHEN CVG.LINE=2 THEN EPP.BENEFIT_PLAN_NAME END) AS BENEFIT_PLAN_NAME_2
	--,MAX(CASE WHEN CVG.LINE=2 THEN EPP.PRODUCT_TYPE END) AS PRODUCT_TYPE_2  
	,max(case when cvg.line=2 then epp2.prod_type_c end) as product_type_2
			
			
	,MAX(CASE WHEN CVG.LINE=3 THEN EPM.PAYOR_ID END)AS PAYOR_ID_3
	,MAX(CASE WHEN CVG.LINE=3 THEN EPP.BENEFIT_PLAN_ID END) AS PLAN_ID_3
	,MAX(CASE WHEN CVG.LINE=3 THEN EPM.PAYOR_NAME END)AS PAYOR_NAME_3
	,MAX(CASE WHEN CVG.LINE=3 THEN EPP.BENEFIT_PLAN_NAME END) AS BENEFIT_PLAN_NAME_3
	--,MAX(CASE WHEN CVG.LINE=3 THEN EPP.PRODUCT_TYPE END) AS PRODUCT_TYPE_3   
	,max(case when cvg.line=3 then epp2.prod_type_c end) as product_type_3
		
INTO #tmp_PSG_PAYOR   -- select count(*) from #tmp_PSG_PAYOR  3447 or 113920

FROM 
	#tmp_PSG_HTR HTR
	INNER JOIN 	HSP_ACCT_CVG_LIST CVG ON HTR.HSP_ACCOUNT_ID = CVG.HSP_ACCOUNT_ID
	INNER JOIN COVERAGE COV ON CVG.COVERAGE_ID = COV.COVERAGE_ID
	INNER JOIN CLARITY_EPM EPM ON COV.PAYOR_ID = EPM.PAYOR_ID
	INNER JOIN CLARITY_EPP EPP ON COV.PLAN_ID =  EPP.BENEFIT_PLAN_ID  
	inner join clarity_epp_2 epp2 on cov.plan_id=epp2.benefit_plan_id
		
WHERE
	CVG.LINE<=3
		
GROUP BY CVG.HSP_ACCOUNT_ID

/*---------------------------------------------------------------------------------------------------------------------
	MAIN QUERY    04/10/2019  Per PSG, requested to comment out all but a few columns in the final output file.
---------------------------------------------------------------------------------------------------------------------*/
SELECT DISTINCT
	---- CONVERT(VARCHAR,UCL.CHARGE_FILED_TIME,101) AS UCL_CHARGE_FILED_DATE
	----,LEFT (Convert (VARCHAR,ucl.CHARGE_FILED_TIME, 14),8) AS UCL_CHARGED_FILED_TIME
	----,ucl.CHARGE_FILED_TIME					as UCL_CHARGE_FILED_DTTM
	----,CONVERT(VARCHAR(10),HTR.TX_POST_DATE,101) AS TX_POST_DATE
	HTR.TX_ID
	,HTR.HSP_ACCOUNT_ID
	,HTR.PAT_ENC_CSN_ID
	,II.IDENTITY_ID											AS MRN
    --,hx.ACTION_DATE
    --,hx.ACTION_DTTM
	----,hx.ACTION_TYPE
	,convert(varchar,coalesce(mai.TAKEN_TIME,charge.report_date),101)				as ADMIN_DATE
	,left(convert(varchar,coalesce(mai.TAKEN_TIME,hx.action_dttm),14),8)		as ADMIN_TIME

	,ucl.DEPARTMENT_ID										as MEDADMIN_DEPARTMENT_ID
	,ucl.DEPARTMENT_NAME									AS MEDADMIN_DEPARTMENT
	--,HTR.DEPARTMENT   --removed charge department 2/13/2019
	--,HTR.DEPARTMENT_NAME   --removed charge department 2/13/2019
	----,HTR.COST_CENTER_CODE
	----,HTR.COST_CENTER_NAME
	----,HTR.REVENUE_LOC_ID
	----,coalesce(HTR.LOC_NAME,'') as LOC_NAME
	----,HTR.ERX_ID
	--,htr.SIM    
	--,htr.marsim,htr.ordsim,htr.erx_id 
	--,coalesce(htr.marsim,htr.ordsim,convert(character(12),htr.ERX_ID),'') as SIM
	,case when htr.marsim is not null or htr.marsim = '' then
	       case when htr.ordsim is null or htr.ordsim='' then convert(character(12),htr.ERX_ID) 
		        else htr.ordsim end
		  else htr.marsim end
		  as SIM
		      
	
	--,htr.ordsim,convert(character(12),htr.ERX_ID) as SIM
	,HTR.RAW_11_DIGIT_NDC
	--,HTR.PROCEDURE_DESC
	,htr.productdesc   -- UMC use this to insure the NDG description is use when present
	,HTR.TX_AMOUNT
	,UCL.IMPLIED_QTY
	,HTR.QUANTITY
	----,HTR.TX_PAT_CLASS
	----,HTRCLS.PAT_CLASS_ABBR									AS TX_PAT_CLASS_DESC
	,HTRCLS.BASE_CLASS_ABBR									AS TX_BASE_CLASS_ABBR
	----,UCL.PAT_CLASS_AT_CHARGE				
	----,UCLCLS.PAT_CLASS_ABBR									AS PAT_CLASS_AT_CHARGE_DESC
	,coalesce(UCLCLS.BASE_CLASS_ABBR,HTRCLS.BASE_CLASS_ABBR,'')	AS PAT_BASE_CLAS_AT_CHARGE_ABBR
	,HTR.ORDER_ID
	,isnull(HTR.IMPLIED_QTY_UNIT_NAME_HTR,'')				as IMPLIED_QTY_UNIT_NAME_HTR
	,isnull(HTR.IMPLIED_UNIT_TYPE_NAME_HTR,'')				as IMPLIED_UNIT_TYPE_NAME_HTR
	,UCL.UCL_ID
	----,HTR.TX_NUM_IN_HOSPACCT
	,isnull(MAR.SCANNED_BARCODE,'')							as SCANNED_BARCODE
	,HTR.USER_ID
	,HTR.SrcSystem
	,MEDICATION_ID
----	,HTR.FINANCIAL_CLASS
------/* NOTE: Payor info only necessary if Medicaid is to be carved OUT
----	,coalesce(convert(varchar,PAY.PRIM_PAYOR_ID),'') as PRIM_PAYOR_ID
----	,coalesce(convert(varchar,PAY.PRIM_PLAN_ID),'') as PRIM_PLAN_ID
----	,PAY.PRIMARY_PAYOR_NAME
----	,PAY.PRIM_BENEFIT_PLAN_NAME
----	,coalesce(PAY.PRIM_PRODUCT_TYPE,'') as PRIM_PRODUCT_TYPE
----	,coalesce(convert(varchar,PAY.PAYOR_ID_2),'') as PAYOR_ID_2
----	,coalesce(convert(varchar,PAY.PLAN_ID_2),'') as PLAN_ID_2
----	,coalesce(PAY.PAYOR_NAME_2,'') as PAYOR_NAME_2
----	,coalesce(PAY.BENEFIT_PLAN_NAME_2,'') as  BENEFIT_PLAN_NAME_2
----	,coalesce(PAY.PRODUCT_TYPE_2,'') as  PRODUCT_TYPE_2 
----	,coalesce(convert(varchar,PAY.PAYOR_ID_3),'') as  PAYOR_ID_3
----	,coalesce(convert(varchar,PAY.PLAN_ID_3),'') as  PLAN_ID_3
----	,coalesce(PAY.PAYOR_NAME_3,'') as PAYOR_NAME_3
----	,coalesce(PAY.BENEFIT_PLAN_NAME_3,'') as BENEFIT_PLAN_NAME_3
----	,coalesce(PAY.PRODUCT_TYPE_3,'') as PRODUCT_TYPE_3
------*/
----	,HTR.service_date
----	,OM.ORDER_INST
----	,UCL.REVENUE_LOCATION_ID   AS  UCL_REV_LOC_ID
----	,UCL.LOC_NAME             AS  UCL_LOC_NAME

into #tmp_PSG_Transactions	
FROM

	#tmp_PSG_HTR HTR 
	INNER JOIN HSP_ACCOUNT ACCT ON HTR.HSP_ACCOUNT_ID=ACCT.HSP_ACCOUNT_ID
	INNER JOIN PATIENT PAT ON ACCT.PAT_ID = PAT.PAT_ID
	inner join valid_patient vp
	   on pat.pat_id=vp.pat_id
	inner join patient_3 pat3
	   on acct.pat_id=pat3.pat_id
    INNER JOIN IDENTITY_ID II ON PAT.PAT_ID = II.PAT_ID AND II.IDENTITY_TYPE_ID = 14 --0  UMC uses 14 as UMC MRN type
    LEFT OUTER JOIN #tmp_PSG_UCL UCL on HTR.TX_ID = ucl.tx_id
	LEFT OUTER JOIN #tmp_PSG_OM OM on HTR.order_id = om.order_med_id
	INNER JOIN #tmp_PSG_PAT_CLASS HTRCLS ON HTR.TX_PAT_CLASS = HTRCLS.PAT_CLASS_C
    LEFT OUTER JOIN #tmp_PSG_PAT_CLASS UCLCLS ON UCL.PAT_CLASS_AT_CHARGE = UCLCLS.PAT_CLASS_C
    LEFT OUTER JOIN #tmp_PSG_MAR MAR ON HTR.ORDER_ID = MAR.ORDER_ID AND HTR.ERX_ID = MAR.ERX_ID  
    LEFT OUTER JOIN #tmp_PSG_PAYOR PAY ON HTR.HSP_ACCOUNT_ID = PAY.HSP_ACCOUNT_ID
/* Added below tables to pull in admin date/time associated to charges...  created duplicates, added distinct to query....  future review and optimization might be needed.  */
	left outer join V_RX_CHARGES charge on charge.UCL_ID = ucl.UCL_ID
	left outer join V_RX_ORDER_HISTORY	hx on hx.ORDER_MED_ID = charge.ORDER_ID and hx.CONTACT_DATE_REAL = charge.ORDER_DATE_REAL
	left outer join MAR_ADMIN_INFO	mai on mai.ORDER_MED_ID = hx.ORDER_MED_ID and mai.line = hx.MAR_ADMIN_INFO_LINE

WHERE
   pat3.is_test_pat_yn <>'Y'
   and vp.is_valid_pat_yn = 'Y'
	----PAT.PAT_NAME NOT LIKE 'ZZ%'
--	AND PAT.SSM_TEST_TYPE IS NULL
    AND htr.service_date >= '11/01/2018' --'2015-10-01'  -- ask Joan why this date??
----	AND PAY.PRIM_PAYOR_ID IS NOT NULL    --per webex meeting 4/18/2019 with PSG Joann Olson 
--	and mar.ORDER_ID = 48566142    
--	and htr.TX_ID = 242509575
    and (hx.ACTION_TYPE is not Null
	     and UCL.IMPLIED_QTY is not Null
	     and htr.order_id is not Null)  -- used to ignore orphaned transactions where most columns are Null

ORDER BY  
   HTR.HSP_ACCOUNT_ID
   --,UCL.CHARGE_FILED_TIME
   ,ucl.ucl_id
;
--select distinct * from 	#tmp_PSG_HTRPB where order_id=33476269
--select * from clarity_tdl where tx_id=5732993 and detail_type=1 
--select * from hsp_transactions where tx_id=5732993
--select * from arpb_transactions where tx_id=5732993
--select * from clarity_ucl where ucl_id=20009829 ;
--select * from mar_admin_info where order_med_id=33476269;
--select convert(varchar,mai.TAKEN_TIME,101) from mar_admin_info mai where order_med_id=33476269; 
--select * from v_rx_charges where ucl_id=20009829
--select * from v_rx_order_history where order_med_id=33476269 and contact_date_real=65365
--select * from #tmp_PSG_Transactions where tx_id=5732993

---- dump the table out to a pipe-delimited file with Header row.
--select * from #tmp_PSG_Transactions 
----where tx_id = 43916331 --16923 no header (problem child 43916331)
--where SIM is null or ProductDesc is null 

select
  ('TX_ID|HSP_ACCOUNT_ID|PAT_ENC_CSN_ID|MRN|ADMIN_DATE|ADMIN_TIME|MEDADMIN_DEPARTMENT_ID|' +
   'MEDADMIN_DEPARTMENT|SIM|RAW_11_DIGIT_NDC|productdesc|TX_AMOUNT|IMPLIED_QTY|QUANTITY|' +
   'TX_BASE_CLASS_ABBR|PAT_BASE_CLAS_AT_CHARGE_ABBR|ORDER_ID|IMPLIED_QTY_UNIT_NAME_HTR|' +
   'IMPLIED_UNIT_TYPE_NAME_HTR|UCL_ID|SCANNED_BARCODE|USER_ID|SrcSystem')

Union All 

select 
   ISNULL(convert(varchar,tx_id),'') + '|' +
   ISNULL(convert(varchar,hsp_account_id),'') + '|' +
   ISNULL(convert(varchar,pat_enc_csn_id),'') + '|' +
   ISNULL(convert(varchar,mrn),'') + '|' +
   ISNULL(convert(varchar,admin_date),'') + '|' +
   ISNULL(convert(varchar,admin_time),'') + '|' +
   ISNULL(convert(varchar,medadmin_department_id),'') + '|' +
   ISNULL(convert(varchar,medadmin_department),'') + '|' +
   ISNULL(convert(varchar,sim),'') + '|' +
   ISNULL(convert(varchar,raw_11_digit_ndc),'') + '|' +
   ISNULL(convert(varchar,productdesc),'') + '|' +
   ISNULL(convert(varchar,tx_amount),'') + '|' +
   ISNULL(convert(varchar,implied_qty),'') + '|' +
   ISNULL(convert(varchar,quantity),'') + '|' +
   ISNULL(tx_base_class_abbr,'') + '|' +
   ISNULL(pat_base_clas_at_charge_abbr,'') + '|' +
   ISNULL(convert(varchar,order_id),'') + '|' +
   ISNULL(implied_qty_unit_name_htr,'') + '|' +
   ISNULL(convert(varchar,implied_unit_type_name_htr),'') + '|' +
   ISNULL(convert(varchar,ucl_id),'') + '|' +
   ISNULL(convert(varchar,scanned_barcode),'') + '|' +
   ISNULL(convert(varchar,user_id),'') + '|' +
   srcsystem
from
   #tmp_PSG_Transactions
   where SIM is null or ProductDesc is null
-----------------------------------------------------------------------------
-- drop any of the temp tables that may have been used
----Drop Table if exists #tmp_PSG_PAT_CLASS 
----Drop Table if exists #tmp_PSG_HTRPB
----Drop Table if exists #tmp_PSG_HTRHB
----Drop Table if exists #tmp_PSG_LOC
----Drop Table if exists #tmp_PSG_HTR
----Drop Table if exists #tmp_PSG_UCL
----Drop Table if exists #tmp_PSG_MAR
----Drop Table if exists #tmp_PSG_OM
----Drop Table if exists #tmp_PSG_PAYOR
----Drop Table if exists #tmp_PSG_Transactions
--select * from #tmp_psg_htr where srcsystem='HB'


 --  SELECT * FROM #tmp_PSG_Transactions where PAT_BASE_CLAS_AT_CHARGE_ABBR	 is null


---- select 
----     htr.*,vrx.*
----from #tmp_PSG_HTR htr
----   left join v_rx_charges vrx
----      on htr.chg_router_src_id=vrx.ucl_id

----	  select top 1 * from #tmp_PSG_HTR
--select * from #tmp_psg_htr where (marsim is null or marsim='') and (ordsim is null or ordsim='')