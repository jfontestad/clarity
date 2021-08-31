/************* Get Results for Hospital Visit Orders **************/

/* This query can be run as either a scheduled daily update, or as a one-time data backload.

To run this query as a one-time backload...
	...ensure that the section containing the "ONE-TIME BACKLOAD VERSION" is uncommented. This is the section between
	the line: "*** UNCOMMENT THIS SECTION TO RUN THE ONE-TIME BACKLOAD VERSION OF THE QUERY ***"
	and the line: "*** END ONE-TIME BACKLOAD WITHOUT TEMP TABLES ***".
	Lines that are specific to other "versions" of the query should be commented out (i.e., any other sections that
	begin with "*** UNCOMMENT THIS SECTION...").

	The QueryStart and QueryEnd parameters can be used to control the time period over which the query will run,
	and to divide the data into time-based chunks if it is too large to be run over the entire time period.

	You may need to run the query multiple times over different date-based chunks.
	This determination will be based on the size of your organization, the method by which you run the query (SQL
	Server console, stored procedure, etc.), and the time range for which data is needed.

To run this query as a scheduled daily update...
	...ensure that the section containing the "DAILY UPDATE VERSION" is uncommented. This is the section between
	the line: "*** UNCOMMENT THIS SECTION TO RUN THE DAILY UPDATE VERSION OF THE QUERY ***"
	and the line: "*** END DAILY UPDATE WITHOUT TEMP TABLES ***".
    Lines that are specific to other "versions" of the query should be commented out (i.e., any other sections that
	begin with "*** UNCOMMENT THIS SECTION... ***").

	The QueryStart and QueryEnd parameters will not be respected; instead, the appropriate data subset will be
	selected based on the current date (using GETDATE()).

If you experience poor performance running this query...
	...including temp tables may improve performance, but if the temp table version is run from a stored procedure,
	you will need to define metadata for each column on the output. Temp tables versions of the query of the query
	are contained below but commented out.

NOTE: Agathos needs column headers and delimiters that are escaped. If you can't escape delimiters, use the '`'
(backtick) character. Also, make sure columns aren't being truncated or are set to the max possible width. */


--The following parameters do not need to be modified. They can be used to exclude specific data types from the query output.
DECLARE @IncludeClinInd			INT = 1;	-- 0 to exclude Clinical Indications, 1 to include
DECLARE @IncludeApptASN			INT = 1;	-- 0 to exclude Order Comments, 1 to include
DECLARE @IncludeBillDx			INT = 1;	-- 0 to exclude Billing Dx, 1 to include
DECLARE @IncludeOrderDx			INT = 1;	-- 0 to exclude Order Dx, 1 to include
DECLARE @IncludeAccession		INT = 1;	-- 0 to exclude Accession Numbers/Specimen IDs, 1 to include
DECLARE @IncludeReadingRad		INT = 1;	-- 0 to exclude Reading Radiologists, 1 to include
DECLARE @IncludeNarrative		INT = 1;	-- 0 to exclude Narrative, 1 to include
DECLARE @IncludeNarrativeXML	INT = 0;	-- 0 to exclude Narrative XML Stuff, 1 to include
DECLARE @IncludeImpressionXML	INT = 0;	-- 0 to exclude Impression XML Stuff, 1 to include
DECLARE @IncludeImpression		INT = 1;	-- 0 to exclude Impression, 1 to include
DECLARE @IncludeQuestions		INT = 1;	-- 0 to exclude Order Questions (LQL), 1 to include
DECLARE @IncludeOrderComments	INT = 1;	-- 0 to exclude Order Comments, 1 to include

/*********************************************************************************************/
/*** SET START AND END DATE FOR BACKLOAD VERSIONS OF QUERY. DO NOT MODIFY FOR DAILY UPDATE ***/

		-- start by running over a single day to ensure the query runs
		-- 3 month chunks recommended for for backload
		DECLARE @QueryStart	DATETIME = '2018-12-01';	-- *** EDIT START DATE HERE *** Format: '2017-01-01'
		DECLARE @QueryEnd	DATETIME = '2018-12-02';	-- *** EDIT END DATE HERE *** Format: '2022-12-01'

/********************************************************************************/
/*** UNCOMMENT THIS SECTION TO RUN THE ONE-TIME BACKLOAD VERSION OF THE QUERY ***/

	DECLARE @QueryMode VARCHAR(15) = 'BACKLOAD';
	WITH orders AS (
		SELECT ord.ORDER_PROC_ID AS order_id, ord.PAT_ENC_DATE_REAL AS res_date_real FROM ORDER_PROC ord
			INNER JOIN PAT_ENC_HSP enc_hsp ON enc_hsp.PAT_ENC_CSN_ID=ord.PAT_ENC_CSN_ID
		WHERE enc_hsp.HOSP_ADMSN_TIME >= @QueryStart AND enc_hsp.HOSP_ADMSN_TIME < @QueryEnd
		-- AND enc_hsp.ADT_SERV_AREA_ID = 1 --Service Area Restriction

/*** END ONE-TIME BACKLOAD WITHOUT TEMP TABLES ***/
/*************************************************/

/*****************************************************************************************************/
/*** UNCOMMENT THIS SECTION TO RUN THE ONE-TIME BACKLOAD WITH TEMP TABLES VERSION. THIS MAY
	INCREASE PERFORMANCE BUT CAUSE ISSUES WITH COLUMN OUTPUT METADATA IF RUN FROM STORED PROCEDURE ***/
/*
		IF (OBJECT_ID('tempdb..#temp_agathos_results') IS NOT NULL)
			DROP TABLE #temp_agathos_results
		CREATE TABLE #temp_agathos_results(order_id NUMERIC(18,0), res_date_real INT)
		CREATE CLUSTERED INDEX idx_order_id ON #temp_agathos_results(order_id, res_date_real);
		DECLARE @QueryMode VARCHAR(15) = 'BACKLOADTT';
		INSERT INTO #temp_agathos_results(order_id, res_date_real) (
			SELECT ord.ORDER_PROC_ID AS order_id, ord.PAT_ENC_DATE_REAL AS res_date_real FROM ORDER_PROC ord
				INNER JOIN PAT_ENC_HSP enc_hsp ON enc_hsp.PAT_ENC_CSN_ID=ord.PAT_ENC_CSN_ID
			WHERE enc_hsp.HOSP_ADMSN_TIME >= @QueryStart AND enc_hsp.HOSP_ADMSN_TIME < @QueryEnd
				-- AND enc_hsp.ADT_SERV_AREA_ID = 1 --Service Area Restriction
		); WITH orders AS (SELECT * FROM #temp_agathos_results
*/
/*** END ONE-TIME BACKLOAD WITH TEMP TABLES ***/
/**********************************************/

/***************************************************************************/
/*** UNCOMMENT THIS SECTION TO RUN THE DAILY UPDATE VERSION OF THE QUERY ***/
/*
		DECLARE @QueryMode VARCHAR(15) = 'DAILY';
		WITH hsp_enc AS (
			SELECT enc_hsp.PAT_ENC_CSN_ID AS visit_id FROM PAT_ENC_HSP enc_hsp
			WHERE enc_hsp.HOSP_ADMSN_TIME > (SELECT DATEADD(YEAR, -2, GETDATE()))
				-- AND enc_hsp.ADT_SERV_AREA_ID = 1 --Service Area Restriction
		), recent_hsp_enc AS (
			SELECT he.visit_id FROM PAT_ENC enc
				INNER JOIN hsp_enc he ON enc.PAT_ENC_CSN_ID=he.visit_id
			WHERE enc.UPDATE_DATE > (SELECT DATEADD(DAY, -2, GETDATE()))
		), recent_hsp_enc_orders AS (
			SELECT ord.ORDER_PROC_ID AS order_id, ord.PAT_ENC_DATE_REAL AS res_date_real FROM ORDER_PROC ord
				INNER JOIN recent_hsp_enc rhe ON rhe.visit_id=ord.PAT_ENC_CSN_ID
		), recent_order_upd AS (
			SELECT ord.ORDER_PROC_ID AS order_id, ord.PAT_ENC_DATE_REAL AS res_date_real FROM ORDER_PROC ord
				INNER JOIN HV_ORDER_PROC hvo on ord.ORDER_PROC_ID=hvo.ORDER_PROC_ID
				INNER JOIN hsp_enc he ON he.visit_id=hvo.PAT_ENC_CSN_ID					--HV_ORDER_PROC KEYS...
			WHERE ord.ORDER_INST > (SELECT DATEADD(DAY, -90, GETDATE()))				--ORDER_PROC_ID;
				AND hvo.INST_OF_UPDATE_TM > (SELECT DATEADD(DAY, -2, GETDATE()))		--PAT_ID+PAT_ENC_DATE_REAL;
		), orders AS (																	--PAT_ENC_CSN_ID;
			SELECT order_id, res_date_real FROM recent_hsp_enc_orders
			UNION SELECT order_id, res_date_real FROM recent_order_upd
*/
/*** END DAILY UPDATE WITHOUT TEMP TABLES ***/
/********************************************/

/*****************************************************************************************************/
/*** UNCOMMENT THIS SECTION TO RUN THE DAILY UPDATE WITH TEMP TABLES VERSION. THIS MAY
	INCREASE PERFORMANCE BUT CAUSE ISSUES WITH OUTPUT COLUMN METADATA IF RUN FROM STORED PROCEDURE ***/
/*
		IF (OBJECT_ID('tempdb..#temp_agathos_results') IS NOT NULL)
			DROP TABLE #temp_agathos_results
		CREATE TABLE #temp_agathos_results(order_id NUMERIC(18,0), res_date_real INT)
		CREATE CLUSTERED INDEX idx_order_id ON #temp_agathos_results(order_id, res_date_real);
		DECLARE @QueryMode VARCHAR(15) = 'DAILYTT';
		WITH hsp_enc AS (
			SELECT enc_hsp.PAT_ENC_CSN_ID AS visit_id FROM PAT_ENC_HSP enc_hsp
			WHERE enc_hsp.HOSP_ADMSN_TIME > (SELECT DATEADD(YEAR, -2, GETDATE()))
				-- AND enc_hsp.ADT_SERV_AREA_ID = 1 --Service Area Restriction
		), recent_hsp_enc AS (
			SELECT he.visit_id FROM PAT_ENC enc
				INNER JOIN hsp_enc he ON enc.PAT_ENC_CSN_ID=he.visit_id
			WHERE enc.UPDATE_DATE > (SELECT DATEADD(DAY, -2, GETDATE()))
		), recent_hsp_enc_orders AS (
			SELECT ord.ORDER_PROC_ID AS order_id, ord.PAT_ENC_DATE_REAL AS res_date_real FROM ORDER_PROC ord
				INNER JOIN recent_hsp_enc rhe ON rhe.visit_id=ord.PAT_ENC_CSN_ID
		), recent_order_upd AS (
			SELECT ord.ORDER_PROC_ID AS order_id, ord.PAT_ENC_DATE_REAL AS res_date_real FROM ORDER_PROC ord
				INNER JOIN HV_ORDER_PROC hvo on ord.ORDER_PROC_ID=hvo.ORDER_PROC_ID
				INNER JOIN hsp_enc he ON he.visit_id=hvo.PAT_ENC_CSN_ID					--HV_ORDER_PROC KEYS...
			WHERE ord.ORDER_INST > (SELECT DATEADD(DAY, -90, GETDATE()))				--ORDER_PROC_ID;
				AND hvo.INST_OF_UPDATE_TM > (SELECT DATEADD(DAY, -2, GETDATE()))		--PAT_ID+PAT_ENC_DATE_REAL;
		) INSERT INTO #temp_agathos_results(order_id, res_date_real) (					--PAT_ENC_CSN_ID;
			SELECT order_id, res_date_real FROM recent_hsp_enc_orders
			UNION SELECT order_id, res_date_real FROM recent_order_upd
		); WITH orders AS (SELECT * FROM #temp_agathos_results
*/
/*** END DAILY UPDATE WITH TEMP TABLES ***/
/*****************************************/

/********************************/
/*** END CONFIGURABLE SECTION ***/
/********************************/

/*****************************************************************************/
/*** THIS SECTION WILL BE USED FOR BOTH BACKLOAD AND DAILY UPDATE VERSIONS ***/

) SELECT
	CASE WHEN row_number() OVER (ORDER BY res.PAT_ENC_CSN_ID, ord.order_id ASC) < 1000
		THEN 'mode=' + isnull(cast(@QueryMode AS VARCHAR(15)), '') +
			'^queryStart=' + isnull(cast(@QueryStart AS VARCHAR), '') +
			'^queryEnd=' + isnull(cast(@QueryEnd AS VARCHAR), '') +
			'^currentTime=' +isnull(convert(VARCHAR, GETDATE(), 127), '') +
			'^currentUTCTime=' +isnull(convert(VARCHAR, SYSUTCDATETIME(), 127), '')
		ELSE '' END																							AS 'version_client_results_v2_2'
	, 'COMP'																								AS 'type'
	, isnull(cast(res.PAT_ID AS VARCHAR), '')																AS ept_id
	, isnull(cast(res.PAT_ENC_CSN_ID AS VARCHAR), '')														AS visit_id
	, isnull(cast(ord.order_id AS VARCHAR(256)), '')														AS order_id
	, isnull(cast(res.LAB_STATUS_C AS VARCHAR(10)), '')														AS lab_status
	, isnull(cast(res.RESULT_STATUS_C AS VARCHAR), '')														AS result_status
	, isnull(cast(res.resulting_lab_id AS VARCHAR), '')														AS resulting_agency_llb_id
	, isnull(convert(VARCHAR, res.RESULT_TIME, 127), '')													AS result_dttm
	, isnull(convert(VARCHAR, res.COMP_OBS_INST_TM, 127), '')												AS observation_dttm
	, res.LINE																								AS line
	, isnull(cast(res.COMPONENT_ID AS VARCHAR) + '^' + isnull(replace(cc.NAME, '`', CHAR(39)), ''), '')		AS component
	, isnull(cast(res.DATA_TYPE_C AS VARCHAR) + '^' + isnull(c_data_type.NAME, ''), '')						AS data_type
	, isnull(replace(cast(res.ORD_VALUE AS VARCHAR(999)), '`', CHAR(39)), '')								AS text_value
	, isnull(cast(res.ORD_NUM_VALUE AS VARCHAR), '')														AS numeric_value
	, isnull((SELECT stuff((SELECT
				'~' + isnull(replace(replace(orcc.RESULTS_COMP_CMT, '`', CHAR(39)), '~', '\R\'), '')
			FROM ORDER_RES_COMP_CMT orcc
			WHERE orcc.ORDER_ID=ord.order_id
				AND res.LINE=orcc.LINE_COMP
				AND res.ORD_END_DATE_REAL=orcc.CONTACT_DATE_REAL

			ORDER BY orcc.LINE_COMMENT
			FOR XML PATH ('')), 1, 1, '')), '')																AS multiline_value
	, isnull(cast(res.VALUE_NORMALIZED AS VARCHAR), '')														AS normalized_value
	, isnull(isnull(cast(res.REFERENCE_UNIT AS VARCHAR(256)), '') + isnull('^PRECISION=' +
		cast(res.NUMERIC_PRECISION AS VARCHAR), ''), '')													AS reference_unit
	, isnull(replace(res.COMPONENT_COMMENT, '`', CHAR(39)), '')	+
		isnull((SELECT stuff((SELECT '~' +
				replace(replace(isnull(ors.RESULTS_CMT, ''), '~', '\R\'), '`', CHAR(39))
			FROM ORDER_RES_COMMENT ors
			WHERE ors.ORDER_ID=res.ORDER_PROC_ID
				AND res.LINE=ors.LINE
				AND res.ORD_END_DATE_REAL=ors.CONTACT_DATE_REAL
			ORDER BY ors.LINE_COMMENT
			FOR XML PATH ('')), 1, 1, '')), '')																AS comment
	, isnull(coalesce(cast(res.RESULT_FLAG_C AS VARCHAR) + '^' + isnull(c_result_flag.NAME, ''),
		res.RESULT_IN_RANGE_YN), '')																		AS within_ref_range
	, isnull(cast(res.REFERENCE_LOW AS VARCHAR(256)), '')													AS reference_low
	, isnull(cast(res.REFERENCE_HIGH AS VARCHAR(256)), '')													AS reference_high
	, isnull(cast(res.REF_NORMAL_VALS AS VARCHAR(999)), '')													AS reference_normal
	, isnull(res.INTERFACE_YN, '')																			AS interfaced_yn
	, isnull(cast(res.LRR_BASED_ORGAN_ID AS VARCHAR), '')													AS micro_organism_llo_id
	, isnull(cast(res.RESULT_SUB_IDN AS VARCHAR), '')														AS micro_organism_sub_id
		--> unique organism identifier (OVR 700 or interface) when the component of an order
		--> result is an organism. Join to ORDER_SENSITIVITY.SENS_ORGANISM_SID
	, isnull(isnull(cast(loinc.LNC_CODE AS VARCHAR(255)), '') + '^' +
		isnull(cast(loinc.LNC_VER AS VARCHAR(255)), '') + '^' +
		cast(res.COMPON_LNC_ID AS VARCHAR) + isnull('^' +
		CASE WHEN res.COMPON_LNC_SRC_C=2 THEN 'Inferred[2]' ELSE NULL END, ''), '')							AS loinc__version__lnc_id
	, isnull(cast(res.COMP_RES_TECHNICIA AS VARCHAR(256)), '')												AS technician_user_id
	, isnull(isnull('RPTBL=' + cast(res.RSLT_REPORTABLE_YN AS VARCHAR), '') +
		isnull('^SNOMED_SRC=' + CASE WHEN res.COMP_SNOMED_SRC_C=2 THEN 'Inferred[2]' ELSE NULL END, '') +
		isnull('^REF_RNG_TYP=' + cast(res.REF_RANGE_TYPE AS VARCHAR(256)), '') +
		isnull('^ANLZD=' + convert(VARCHAR, res.COMP_ANL_INST_TM, 127), '') +
		isnull('^IS_CALC=' + cast(res.COMPONENT_TYPE_C AS VARCHAR), '') +
		isnull('^QNTY=' + cast(res.ORGANISM_QUANTITY AS VARCHAR(256)), '') +
		isnull('^QNTY_UNIT=' + cast(res.ORGANISM_QUANTITY_UNIT AS VARCHAR(256)), ''), '')					AS other_info
	, ''																									AS answered_by_proc_yn
	, ''																									AS is_resp_req_yn
	, ''																									AS is_mult_resp_yn
FROM orders ord
	INNER JOIN ORDER_RESULTS res			--keys: ORDER_PROC_ID+ORD_DATE_REAL+LINE;RESULT_DATE;COMPONENT_ID
		ON res.ORDER_PROC_ID=ord.order_id	--		LRR_BASED_ORGAN_ID+ORDER_PROC_ID;PAT_ENC_CSN_ID;
			AND (res.ORD_DATE_REAL > (ord.res_date_real-30))
	LEFT JOIN CLARITY_COMPONENT cc ON res.COMPONENT_ID=cc.COMPONENT_ID
	LEFT JOIN LNC_DB_MAIN loinc ON loinc.RECORD_ID=res.COMPON_LNC_ID

	LEFT JOIN ZC_RESULT_FLAG c_result_flag ON c_result_flag.RESULT_FLAG_C=res.RESULT_FLAG_C
	LEFT JOIN ZC_RESULT_STATUS c_result_status ON c_result_status.RESULT_STATUS_C=res.RESULT_STATUS_C
	LEFT JOIN ZC_LAB_STATUS c_lab_status2 ON c_lab_status2.LAB_STATUS_C=res.LAB_STATUS_C
	LEFT JOIN ZC_RES_DATA_TYPE c_data_type ON c_data_type.RES_DATA_TYPE_C=res.DATA_TYPE_C

UNION ALL SELECT
	CASE WHEN row_number() OVER (ORDER BY sens.ORDER_PROC_ID ASC) = 1
		THEN 'mode=' + isnull(cast(@QueryMode AS VARCHAR(15)), '') +
			'^queryStart=' + isnull(cast(@QueryStart AS VARCHAR), '') +
			'^queryEnd=' + isnull(cast(@QueryEnd AS VARCHAR), '') +
			'^currentTime=' +isnull(convert(VARCHAR, GETDATE(), 127), '') +
			'^currentUTCTime=' +isnull(convert(VARCHAR, SYSUTCDATETIME(), 127), '')
		ELSE '' END																							AS 'version_client_results_v2_2'
	, 'MICRO_SENS'																							AS 'type'
	, ''																									AS ept_id
	, ''																									AS visit_id
	, isnull(cast(ord.order_id AS VARCHAR(256)), '')														AS order_id
	, isnull(cast(sens.LAB_STATUS_C AS VARCHAR) + '^' + isnull(c_lab_sts.NAME, ''), '')						AS lab_status

	, isnull(cast(sens.SENS_STATUS_C AS VARCHAR) + '^' + isnull(c_res_sts.NAME, ''), '')					AS result_status
	, isnull(cast(sens.RESULTING_LAB_ID AS VARCHAR), '')													AS resulting_agency_llb_id
	, isnull(coalesce(convert(VARCHAR, sens.SENS_ANL_INST_TM, 127),
		convert(VARCHAR(10), sens.RESULT_DATE, 127)), '')													AS result_dttm
	, isnull(convert(VARCHAR, sens.SENS_OBS_INST_TM, 127), '')												AS observation_dttm
	, sens.LINE																								AS line
	, isnull(cast(sens.ANTIBIOTIC_C AS VARCHAR) + '^' + isnull(c_antibiotic.NAME, ''), '')					AS component
	, ''																									AS data_type
	, isnull(cast(sens.SUSCEPT_C AS VARCHAR) + '^' + isnull(c_suscept.NAME, ''), '')						AS text_value
	, isnull(cast(sens.SENSITIVITY_VALUE		AS	VARCHAR(256)), '')										AS numeric_value
	, ''																									AS multiline_value
	, isnull('MTHD_EAP=' + cast(sens.SENS_METHOD_ID AS VARCHAR), '')										AS normalized_value
	, isnull(cast(sens.SENSITIVITY_UNITS AS VARCHAR), '')													AS reference_unit
	, isnull(isnull(replace(replace(cast(sens.SENS_COMM AS VARCHAR), '`', CHAR(39)), '^', '\S\'), '') +
		isnull('^SENS_COMM_START_LN=' + cast(sens.SENS_COMM_START_LN AS VARCHAR), '') +
		isnull('^SENS_COMM_END_LN=' + cast(sens.SENS_COMM_END_LN AS VARCHAR), ''), '')						AS comment
	, ''																									AS within_ref_range
	, ''																									AS reference_low
	, ''																									AS reference_high
	, isnull('^SENS_REF_RANGE=' + cast(sens.SENS_REF_RANGE AS VARCHAR(256)), '')							AS reference_normal
	, ''																									AS interfaced_yn
	, isnull(cast(sens.ORGANISM_ID	AS VARCHAR), '')														AS micro_organism_llo_id
	, isnull(cast(sens.SENS_ORGANISM_SID AS VARCHAR), '')													AS micro_organism_sub_id
	, isnull(isnull(cast(loinc.LNC_CODE AS VARCHAR(255)), '') + '^' +
		isnull(cast(loinc.LNC_VER AS VARCHAR(255)), '') + '^' +
		cast(sens.ANTIBIO_LNC_ID AS VARCHAR) + isnull('^' +
		CASE WHEN sens.ANTIBIO_LNC_SRC_C=2 THEN 'Inferred[2]' ELSE NULL END, ''), '')						AS loinc__version__lnc_id
	, ''																									AS technician_user_id
	, isnull(isnull('^SENS_COM_ORG_RES_ID=' + cast(sens.SENS_COM_ORG_RES_ID AS VARCHAR), '') +
		isnull('^METHOD_LNC_ID=' + cast(sens.METHOD_LNC_ID AS VARCHAR), '') +
		isnull('^' + CASE WHEN sens.METHOD_LNC_SRC_C=2 THEN 'Inferred[2]' ELSE NULL END, '') +
		isnull('^HIDE_ANTIBIO=' + cast(sens.HIDE_ANTIBIOTIC_YN AS VARCHAR), '') +
		isnull('^SENS_UNIT_UOM_ID=' + cast(sens.SENS_UNIT_UOM_ID AS VARCHAR), '') +
		isnull('^SENS_START_LN=' + cast(sens.SENS_START_LN AS VARCHAR), '') +
		isnull('^SENS_END_LN=' + cast(sens.SENS_END_LN AS VARCHAR), ''), '')								AS other_info
	, ''																									AS answered_by_proc_yn
	, ''																									AS is_resp_req_yn
	, ''																									AS is_mult_resp_yn
FROM orders ord
	INNER JOIN ORDER_SENSITIVITY sens ON sens.ORDER_PROC_ID=ord.order_id
        --> KEYS: ORGANISM_ID+ORDER_ORIC_ID;ORDER_PROC_ID+ORD_DATE_REAL+LINE;
	LEFT JOIN LNC_DB_MAIN loinc ON loinc.RECORD_ID=sens.ANTIBIO_LNC_ID
	LEFT JOIN ZC_ANTIBIOTIC c_antibiotic ON c_antibiotic.ANTIBIOTIC_C=sens.ANTIBIOTIC_C
	LEFT JOIN ZC_SUSCEPT c_suscept ON c_suscept.SUSCEPT_C=sens.SUSCEPT_C
	LEFT JOIN ZC_LAB_STATUS c_lab_sts ON c_lab_sts.LAB_STATUS_C=sens.LAB_STATUS_C
	LEFT JOIN ZC_RESULT_STATUS c_res_sts ON c_res_sts.RESULT_STATUS_C=sens.SENS_STATUS_C

UNION ALL SELECT
	CASE WHEN row_number() OVER (ORDER BY ind.ORDER_ID ASC) = 1
		THEN 'mode=' + isnull(cast(@QueryMode AS VARCHAR(15)), '') +
			'^queryStart=' + isnull(cast(@QueryStart AS VARCHAR), '') +
			'^queryEnd=' + isnull(cast(@QueryEnd AS VARCHAR), '') +
			'^currentTime=' +isnull(convert(VARCHAR, GETDATE(), 127), '') +
			'^currentUTCTime=' +isnull(convert(VARCHAR, SYSUTCDATETIME(), 127), '')
		ELSE '' END																							AS 'version_client_results_v2_2'
	, 'CLIN_IND'																							AS 'type'
	, ''																									AS ept_id
	, ''																									AS visit_id
	, isnull(cast(ord.order_id AS VARCHAR(256)), '')														AS order_id
	, ''																									AS lab_status

	, ''																									AS result_status
	, ''																									AS resulting_agency_llb_id
	, ''																									AS result_dttm
	, ''																									AS observation_dttm
	, ind.LINE																								AS line
	, ''																									AS component
	, ''																									AS data_type
	, isnull(replace(ind.CLIN_IND_TEXT, '`', CHAR(39)), '')													AS text_value
	, ''																									AS numeric_value
	, ''																									AS multiline_value
	, ''																									AS normalized_value
	, ''																									AS reference_unit
	, isnull(replace(ind.CLIN_IND_CMT_TEXT, '`', CHAR(39)), '')												AS comment
	, ''																									AS within_ref_range
	, ''																									AS reference_low
	, ''																									AS reference_high
	, ''																									AS reference_normal
	, ''																									AS interfaced_yn
	, ''																									AS micro_organism_llo_id
	, ''																									AS micro_organism_sub_id
	, ''																									AS loinc__version__lnc_id
	, ''																									AS technician_user_id
	, ''																									AS other_info
	, ''																									AS answered_by_proc_yn
	, ''																									AS is_resp_req_yn
	, ''																									AS is_mult_resp_yn
FROM orders ord
	INNER JOIN ORD_CLIN_IND ind ON ord.order_id=ind.ORDER_ID
		AND @IncludeClinInd > 0

UNION ALL SELECT
	CASE WHEN row_number() OVER (ORDER BY oai.ORDER_ID ASC) = 1
		THEN 'mode=' + isnull(cast(@QueryMode AS VARCHAR(15)), '') +
			'^queryStart=' + isnull(cast(@QueryStart AS VARCHAR), '') +
			'^queryEnd=' + isnull(cast(@QueryEnd AS VARCHAR), '') +
			'^currentTime=' +isnull(convert(VARCHAR, GETDATE(), 127), '') +
			'^currentUTCTime=' +isnull(convert(VARCHAR, SYSUTCDATETIME(), 127), '')
		ELSE '' END																							AS 'version_client_results_v2_2'
	, 'ASN'																									AS 'type'
	, ''																									AS ept_id
	, ''																									AS visit_id
	, isnull(cast(ord.order_id AS VARCHAR(256)), '')														AS order_id
	, isnull(cast(oai.APPT_STUDY_STATUS_C AS VARCHAR) + '^' + isnull(c_rad_sts.NAME, ''), '')				AS lab_status

	, ''																									AS result_status
	, ''																									AS resulting_agency_llb_id
	, isnull('BEGIN_EXAM=' + convert(VARCHAR(10), oai.APPT_EXAM_BGN_DATE, 127), '') +
		isnull(substring(convert(VARCHAR, oai.APPT_EXAM_BGN_TIME, 127), 11, 19), '')						AS result_dttm
	, isnull('END_EXAM=' + convert(VARCHAR(10), oai.APPT_EXAM_END_DATE, 127), '') +
		isnull(substring(convert(VARCHAR, oai.APPT_EXAM_END_TIME, 127), 11, 19), '')						AS observation_dttm
	, coalesce(oai.line, oasn.LINE)																			AS line
	, ''																									AS component
	, ''																									AS data_type
	, ''																									AS text_value
	, ''																									AS numeric_value
	, ''																									AS multiline_value
	, isnull(cast(coalesce(oai.LINKED_APPOINTMENTS, oasn.APPTS_SCHEDULED) AS VARCHAR), '')					AS normalized_value
	, ''																									AS reference_unit
	, ''																									AS comment
	, ''																									AS within_ref_range
	, ''																									AS reference_low
	, ''																									AS reference_high
	, ''																									AS reference_normal
	, ''																									AS interfaced_yn
	, ''																									AS micro_organism_llo_id
	, ''																									AS micro_organism_sub_id
	, ''																									AS loinc__version__lnc_id
	, isnull(cast(oai.APPT_TECH_ID AS VARCHAR), '')															AS technician_user_id
	, ''																									AS other_info
	, ''																									AS answered_by_proc_yn
	, ''																									AS is_resp_req_yn
	, ''																									AS is_mult_resp_yn
from orders ord
	LEFT JOIN ORDER_APPT_INFO oai ON oai.ORDER_ID=ord.order_id
	LEFT JOIN ORD_APPT_SRL_NUM oasn ON oasn.ORDER_PROC_ID=ord.order_id
		AND NOT EXISTS (SELECT 1 FROM ORDER_APPT_INFO oai2
						WHERE oai2.LINKED_APPOINTMENTS=oasn.APPTS_SCHEDULED)
	LEFT JOIN ZC_RADIOLOGY_STS c_rad_sts ON c_rad_sts.RADIOLOGY_STATUS_C=oai.APPT_STUDY_STATUS_C
WHERE @IncludeApptASN > 0
	AND (oai.ORDER_ID IS NOT NULL
		OR oasn.ORDER_PROC_ID IS NOT NULL)

UNION ALL SELECT
	CASE WHEN row_number() OVER (ORDER BY chgdx.ORDER_ID ASC) = 1
		THEN 'mode=' + isnull(cast(@QueryMode AS VARCHAR(15)), '') +
			'^queryStart=' + isnull(cast(@QueryStart AS VARCHAR), '') +
			'^queryEnd=' + isnull(cast(@QueryEnd AS VARCHAR), '') +
			'^currentTime=' +isnull(convert(VARCHAR, GETDATE(), 127), '') +
			'^currentUTCTime=' +isnull(convert(VARCHAR, SYSUTCDATETIME(), 127), '')
		ELSE '' END																							AS 'version_client_results_v2_2'
	, 'DXBILL'																								AS 'type'
	, ''																									AS ept_id
	, ''																									AS visit_id
	, isnull(cast(ord.order_id AS VARCHAR(256)), '')														AS order_id
	, ''																									AS lab_status

	, ''																									AS result_status
	, ''																									AS resulting_agency_llb_id
	, ''																									AS result_dttm
	, ''																									AS observation_dttm
	, chgdx.GROUP_LINE*100 + chgdx.VALUE_LINE																AS line
	, isnull(cast(chgdx.CHARGE_DIAGNOSES_ID AS VARCHAR), '')												AS component
	, ''																									AS data_type
	, isnull(replace(edg.PAT_FRIENDLY_TEXT, '`', CHAR(39)), '')												AS text_value
	, isnull(cast(edg.CURRENT_ICD9_LIST AS VARCHAR)+ '^ICD9', '')											AS numeric_value
	, ''																									AS multiline_value
	, isnull(cast(edg.CURRENT_ICD10_LIST AS VARCHAR)+ '^ICD10', '')											AS normalized_value
	, ''																									AS reference_unit
	, ''																									AS comment
	, ''																									AS within_ref_range
	, ''																									AS reference_low
	, ''																									AS reference_high
	, ''																									AS reference_normal
	, ''																									AS interfaced_yn
	, ''																									AS micro_organism_llo_id
	, ''																									AS micro_organism_sub_id
	, ''																									AS loinc__version__lnc_id
	, ''																									AS technician_user_id
	, isnull('MOD_ID=' + cast(chmod.CHARGE_MODIFIERS_ID AS VARCHAR), '')									AS other_info
	, ''																									AS answered_by_proc_yn
	, ''																									AS is_resp_req_yn
	, ''																									AS is_mult_resp_yn
from orders ord
	INNER JOIN ORDER_CHG_DXMOD_1 chgdx --keys: ORDER_ID+GROUP_LINE+VALUE_LINE
        --> billing diagnoses and modifiders associated with a charge
		ON chgdx.ORDER_ID=ord.order_id
			AND @IncludeBillDx > 0
	INNER JOIN CLARITY_EDG edg
		ON chgdx.CHARGE_DIAGNOSES_ID=edg.DX_ID
	LEFT JOIN ORDER_CHG_DXMOD_2 chmod --keys: ORDER_ID+GROUP_LINE+VALUE_LINE
        --> entered at end exam (related multiple item ORD 52407)
		ON chmod.ORDER_ID=chgdx.ORDER_ID
			AND chmod.ORDER_ID=ord.order_id
			AND chmod.GROUP_LINE=chgdx.GROUP_LINE
			AND chmod.VALUE_LINE=chgdx.VALUE_LINE

UNION ALL SELECT
	CASE WHEN row_number() OVER (ORDER BY odx.ORDER_PROC_ID ASC) = 1
		THEN 'mode=' + isnull(cast(@QueryMode AS VARCHAR(15)), '') +
			'^queryStart=' + isnull(cast(@QueryStart AS VARCHAR), '') +
			'^queryEnd=' + isnull(cast(@QueryEnd AS VARCHAR), '') +
			'^currentTime=' +isnull(convert(VARCHAR, GETDATE(), 127), '') +
			'^currentUTCTime=' +isnull(convert(VARCHAR, SYSUTCDATETIME(), 127), '')
		ELSE '' END																							AS 'version_client_results_v2_2'
	, 'DXORD'																								AS 'type'
	, isnull(cast(odx.PAT_ID AS VARCHAR), '')																AS ept_id
	, isnull(cast(odx.PAT_ENC_CSN_ID AS VARCHAR), '')														AS visit_id
	, isnull(cast(ord.order_id AS VARCHAR(256)), '')														AS order_id
	, ''																									AS lab_status

	, ''																									AS result_status
	, ''																									AS resulting_agency_llb_id
	, ''																									AS result_dttm
	, ''																									AS observation_dttm
	, odx.LINE																								AS line
	, isnull(cast(odx.DX_ID AS VARCHAR), '')																AS component
	, ''																									AS data_type
	, isnull(replace(coalesce(odx.ASSOC_DX_DESC, edg.PAT_FRIENDLY_TEXT),'`',CHAR(39)), '')					AS text_value
	, isnull(cast(edg.CURRENT_ICD9_LIST AS VARCHAR)+ '^ICD9', '')											AS numeric_value
	, ''																									AS multiline_value
	, isnull(cast(edg.CURRENT_ICD10_LIST AS VARCHAR)+ '^ICD10', '')											AS normalized_value
	, ''																									AS reference_unit
	, isnull(replace(cast(odx.COMMENTS AS VARCHAR), '`', CHAR(39)), '')										AS comment
	, ''																									AS within_ref_range
	, ''																									AS reference_low
	, ''																									AS reference_high
	, ''																									AS reference_normal
	, ''																									AS interfaced_yn
	, ''																									AS micro_organism_llo_id
	, ''																									AS micro_organism_sub_id
	, ''																									AS loinc__version__lnc_id
	, ''																									AS technician_user_id
	, CASE WHEN odx.DX_CHRONIC_YN='Y' THEN 'CHRONIC' ELSE '' END											AS other_info
	, ''																									AS answered_by_proc_yn
	, ''																									AS is_resp_req_yn
	, ''																									AS is_mult_resp_yn
from orders ord
	INNER JOIN ORDER_DX_PROC odx --keys: ORDER_PROC_ID+LINE;PAT_ID;DX_ID;PAT_ENC_CSN_ID
		ON odx.ORDER_PROC_ID=ord.order_id
			AND @IncludeOrderDx > 0
	INNER JOIN CLARITY_EDG edg ON odx.DX_ID=edg.DX_ID

UNION ALL SELECT
	CASE WHEN row_number() OVER (ORDER BY oran.ORDER_PROC_ID ASC) = 1
		THEN 'mode=' + isnull(cast(@QueryMode AS VARCHAR(15)), '') +
			'^queryStart=' + isnull(cast(@QueryStart AS VARCHAR), '') +
			'^queryEnd=' + isnull(cast(@QueryEnd AS VARCHAR), '') +
			'^currentTime=' +isnull(convert(VARCHAR, GETDATE(), 127), '') +
			'^currentUTCTime=' +isnull(convert(VARCHAR, SYSUTCDATETIME(), 127), '')
		ELSE '' END																							AS 'version_client_results_v2_2'
	, 'ACCN'																								AS 'type'
	, ''																									AS ept_id
	, ''																									AS visit_id
	, isnull(cast(ord.order_id AS VARCHAR(256)), '')														AS order_id
	, ''																									AS lab_status

	, ''																									AS result_status
	, ''																									AS resulting_agency_llb_id
	, ''																									AS result_dttm
	, ''																									AS observation_dttm
	, oran.LINE																								AS line
	, ''																									AS component
	, ''																									AS data_type
	, ''																									AS text_value
	, ''																									AS numeric_value
	, ''																									AS multiline_value
	, isnull(replace(oran.ACC_NUM, '`', CHAR(39)) + '^' + isnull(oran.SPECIMEN_APP_IDN, ''), '')			AS normalized_value
	, ''																									AS reference_unit
	, ''																									AS comment
	, ''																									AS within_ref_range
	, ''																									AS reference_low
	, ''																									AS reference_high
	, ''																									AS reference_normal
	, ''																									AS interfaced_yn
	, ''																									AS micro_organism_llo_id
	, ''																									AS micro_organism_sub_id
	, ''																									AS loinc__version__lnc_id
	, ''																									AS technician_user_id
	, ''																									AS other_info
	, ''																									AS answered_by_proc_yn
	, ''																									AS is_resp_req_yn
	, ''																									AS is_mult_resp_yn
from orders ord
	INNER JOIN ORDER_RAD_ACC_NUM oran --key: ORDER_PROC_ID+LINE
		ON oran.ORDER_PROC_ID=ord.order_id
			AND @IncludeAccession > 0

UNION ALL SELECT
	CASE WHEN row_number() OVER (ORDER BY orr.ORDER_PROC_ID ASC) = 1
		THEN 'mode=' + isnull(cast(@QueryMode AS VARCHAR(15)), '') +
			'^queryStart=' + isnull(cast(@QueryStart AS VARCHAR), '') +
			'^queryEnd=' + isnull(cast(@QueryEnd AS VARCHAR), '') +
			'^currentTime=' +isnull(convert(VARCHAR, GETDATE(), 127), '') +
			'^currentUTCTime=' +isnull(convert(VARCHAR, SYSUTCDATETIME(), 127), '')
		ELSE '' END																							AS 'version_client_results_v2_2'
	, 'RADREAD'																								AS 'type'
	, ''																									AS ept_id
	, ''																									AS visit_id
	, isnull(cast(ord.order_id AS VARCHAR(256)), '')														AS order_id
	, ''																									AS lab_status

	, ''																									AS result_status
	, ''																									AS resulting_agency_llb_id
	, ''																									AS result_dttm
	, isnull(convert(VARCHAR(10), orr.READING_DT, 127), '')													AS observation_dttm
	, orr.LINE																								AS line
	, ''																									AS component
	, isnull(cast(orr.READ_PHYS_SPEC_C AS VARCHAR) + '^' + isnull(c_read_spec.NAME, ''), '')				AS data_type
	, ''																									AS text_value
	, ''																									AS numeric_value
	, ''																									AS multiline_value
	, isnull(cast(orr.PROV_ID AS VARCHAR), '')																AS normalized_value
	, ''																									AS reference_unit
	, ''																									AS comment
	, ''																									AS within_ref_range
	, ''																									AS reference_low
	, ''																									AS reference_high
	, ''																									AS reference_normal
	, ''																									AS interfaced_yn
	, ''																									AS micro_organism_llo_id
	, ''																									AS micro_organism_sub_id
	, ''																									AS loinc__version__lnc_id
	, ''																									AS technician_user_id
	, isnull('RESIDENT_SER=' + cast(orr.READING_RESIDENT_ID AS VARCHAR), '')								AS other_info
	, ''																									AS answered_by_proc_yn
	, ''																									AS is_resp_req_yn
	, ''																									AS is_mult_resp_yn
from orders ord
	INNER JOIN ORDER_RAD_READING orr --keys: ORDER_PROC_ID+LINE;READING_DT;PROV_ID
		ON orr.ORDER_PROC_ID=ord.order_id
			AND @IncludeReadingRad > 0
	LEFT JOIN ZC_READ_PHYS_SPEC c_read_spec	ON c_read_spec.READ_PHYS_SPEC_C=orr.READ_PHYS_SPEC_C

UNION ALL SELECT
	CASE WHEN row_number() OVER (ORDER BY ordn.ORDER_PROC_ID ASC) = 1
		THEN 'mode=' + isnull(cast(@QueryMode AS VARCHAR(15)), '') +
			'^queryStart=' + isnull(cast(@QueryStart AS VARCHAR), '') +
			'^queryEnd=' + isnull(cast(@QueryEnd AS VARCHAR), '') +
			'^currentTime=' +isnull(convert(VARCHAR, GETDATE(), 127), '') +
			'^currentUTCTime=' +isnull(convert(VARCHAR, SYSUTCDATETIME(), 127), '')
		ELSE '' END																							AS 'version_client_results_v2_2'
	, 'NARR'																								AS 'type'
	, ''																									AS ept_id
	, ''																									AS visit_id
	, isnull(cast(ord.order_id AS VARCHAR(256)), '')														AS order_id
	, ''																									AS lab_status

	, ''																									AS result_status
	, ''																									AS resulting_agency_llb_id
	, ''																									AS result_dttm
	, ''																									AS observation_dttm
	, ordn.LINE																								AS line
	, ''																									AS component
	, ''																									AS data_type
	, isnull(replace(cast(ordn.NARRATIVE AS VARCHAR(999)), '`', CHAR(39)), '')								AS text_value
	, ''																									AS numeric_value
	, ''																									AS multiline_value
	, ''																									AS normalized_value
	, ''																									AS reference_unit
	, ''																									AS comment
	, ''																									AS within_ref_range
	, ''																									AS reference_low
	, ''																									AS reference_high
	, ''																									AS reference_normal
	, ''																									AS interfaced_yn
	, ''																									AS micro_organism_llo_id
	, ''																									AS micro_organism_sub_id
	, ''																									AS loinc__version__lnc_id
	, ''																									AS technician_user_id
	, ''																									AS other_info
	, ''																									AS answered_by_proc_yn
	, ''																									AS is_resp_req_yn
	, ''																									AS is_mult_resp_yn
from orders ord
	INNER JOIN ORDER_NARRATIVE ordn --key: ORDER_PROC_ID+ORD_DATE_REAL+LINE
		ON ordn.ORDER_PROC_ID=ord.order_id
			AND @IncludeNarrative > 0
			AND ordn.ORD_DATE_REAL > (ord.res_date_real -2)
			AND ordn.NARRATIVE IS NOT NULL
			AND ordn.NARRATIVE<>' '

UNION ALL SELECT
	CASE WHEN row_number() OVER (ORDER BY ordi.ORDER_PROC_ID ASC) = 1
		THEN 'mode=' + isnull(cast(@QueryMode AS VARCHAR(15)), '') +
			'^queryStart=' + isnull(cast(@QueryStart AS VARCHAR), '') +
			'^queryEnd=' + isnull(cast(@QueryEnd AS VARCHAR), '') +
			'^currentTime=' +isnull(convert(VARCHAR, GETDATE(), 127), '') +
			'^currentUTCTime=' +isnull(convert(VARCHAR, SYSUTCDATETIME(), 127), '')
		ELSE '' END																							AS 'version_client_results_v2_2'
	, 'IMPR'																								AS 'type'
	, ''																									AS ept_id
	, ''																									AS visit_id
	, isnull(cast(ord.order_id AS VARCHAR(256)), '')														AS order_id
	, ''																									AS lab_status

	, ''																									AS result_status
	, ''																									AS resulting_agency_llb_id
	, ''																									AS result_dttm
	, ''																									AS observation_dttm
	, ordi.LINE																								AS line
	, ''																									AS component
	, ''																									AS data_type
	, isnull(replace(cast(ordi.IMPRESSION AS VARCHAR(5000)), '`', CHAR(39)), '')							AS text_value
	, ''																									AS numeric_value
	, ''																									AS multiline_value
	, ''																									AS normalized_value
	, ''																									AS reference_unit
	, ''																									AS comment
	, ''																									AS within_ref_range
	, ''																									AS reference_low
	, ''																									AS reference_high
	, ''																									AS reference_normal
	, ''																									AS interfaced_yn
	, ''																									AS micro_organism_llo_id
	, ''																									AS micro_organism_sub_id
	, ''																									AS loinc__version__lnc_id
	, ''																									AS technician_user_id
	, ''																									AS other_info
	, ''																									AS answered_by_proc_yn
	, ''																									AS is_resp_req_yn
	, ''																									AS is_mult_resp_yn
from orders ord
	INNER JOIN ORDER_IMPRESSION ordi --key: ORDER_PROC_ID+ORD_DATE_REAL+LINE
		ON ordi.ORDER_PROC_ID=ord.order_id
			AND @IncludeImpression > 0
			AND ordi.ORD_DATE_REAL > (ord.res_date_real -2)
			AND ordi.IMPRESSION IS NOT NULL
			AND ordi.IMPRESSION<>' '

UNION ALL SELECT
	CASE WHEN row_number() OVER (ORDER BY ord.order_id ASC) = 1
		THEN 'mode=' + isnull(cast(@QueryMode AS VARCHAR(15)), '') +
			'^queryStart=' + isnull(cast(@QueryStart AS VARCHAR), '') +
			'^queryEnd=' + isnull(cast(@QueryEnd AS VARCHAR), '') +
			'^currentTime=' +isnull(convert(VARCHAR, GETDATE(), 127), '') +
			'^currentUTCTime=' +isnull(convert(VARCHAR, SYSUTCDATETIME(), 127), '')
		ELSE '' END																							AS 'version_client_results_v2_2'
	, 'CMT'																									AS 'type'
	, ''																									AS ept_id
	, ''																									AS visit_id
	, isnull(cast(ord.order_id AS VARCHAR(256)), '')														AS order_id
	, ''																									AS lab_status

	, ''																									AS result_status
	, ''																									AS resulting_agency_llb_id
	, ''																									AS result_dttm
	, ''																									AS observation_dttm
	, 0																										AS line
	, ''																									AS component
	, ''																									AS data_type
	, ''																									AS text_value
	, ''																									AS numeric_value
	, ''																									AS multiline_value
	, ''																									AS normalized_value
	, ''																									AS reference_unit
	, isnull((SELECT stuff((SELECT '~' +
			replace(replace(isnull(ordcom.ORDERING_COMMENT, ''), '~', '\S\'), '`',CHAR(39))
		FROM ORDER_COMMENT ordcom
		WHERE ordcom.ORDER_ID=ord.order_id
		ORDER BY ordcom.LINE
		FOR XML PATH ('')), 1, 1, '')), '')																	AS comment
	, ''																									AS within_ref_range
	, ''																									AS reference_low
	, ''																									AS reference_high
	, ''																									AS reference_normal
	, ''																									AS interfaced_yn
	, ''																									AS micro_organism_llo_id
	, ''																									AS micro_organism_sub_id
	, ''																									AS loinc__version__lnc_id
	, ''																									AS technician_user_id
	, ''																									AS other_info
	, ''																									AS answered_by_proc_yn
	, ''																									AS is_resp_req_yn
	, ''																									AS is_mult_resp_yn
from orders ord
WHERE EXISTS (SELECT 1 FROM ORDER_COMMENT ord_com --ORDER_COMMENT INDEX: ORDER_ID+LINE
				WHERE ord.order_id=ord_com.ORDER_ID)
	AND @IncludeOrderComments > 0

UNION ALL SELECT
	CASE WHEN row_number() OVER (ORDER BY aoe.ORDER_ID ASC) = 1
		THEN 'mode=' + isnull(cast(@QueryMode AS VARCHAR(15)), '') +
			'^queryStart=' + isnull(cast(@QueryStart AS VARCHAR), '') +
			'^queryEnd=' + isnull(cast(@QueryEnd AS VARCHAR), '') +
			'^currentTime=' +isnull(convert(VARCHAR, GETDATE(), 127), '') +
			'^currentUTCTime=' +isnull(convert(VARCHAR, SYSUTCDATETIME(), 127), '')
		ELSE '' END																							AS 'version_client_results_v2_2'
	, 'QSTN'																								AS 'type'
	, ''																									AS ept_id
	, ''																									AS visit_id
	, isnull(cast(ord.order_id AS VARCHAR(256)), '')														AS order_id
	, ''																									AS lab_status

	, ''																									AS result_status
	, ''																									AS resulting_agency_llb_id
	, ''																									AS result_dttm
	, ''																									AS observation_dttm
	, aoe.LINE																								AS line
	, isnull(cast(aoe.ORD_QUEST_ID AS VARCHAR) + '^' +
		isnull(cast(questionaire.QUEST_NAME AS VARCHAR(256)), ''), '')										AS component
	, isnull(cast(questions.RESP_TYPE_C AS VARCHAR) + '^' + isnull(resp_type.NAME, ''), '')					AS data_type
	, isnull(replace(cast(questions.QUESTION AS VARCHAR(1000)), '`', CHAR(39)), '')							AS text_value
	, ''																									AS numeric_value
	, isnull(cast(replace(replace(aoe.ORD_QUEST_RESP, '^', '\S\'), '`', CHAR(39)) AS VARCHAR(1000)), '')	AS multiline_value
	, isnull(cast(questions.FILE_INI AS VARCHAR) +
		isnull('-' + cast(questions.FILE_ITEM AS VARCHAR), ''), '')											AS normalized_value
	, isnull(cast(questions.RESP_INI AS VARCHAR) +
		isnull('-' + cast(questions.RESP_ITEM AS VARCHAR), ''), '')											AS reference_unit
	, isnull(replace(aoe.ORD_QUEST_CMT, '`',CHAR(39)), '')													AS comment
	, ''																									AS within_ref_range
	, ''																									AS reference_low
	, ''																									AS reference_high
	, ''																									AS reference_normal
	, ''																									AS interfaced_yn
	, ''																									AS micro_organism_llo_id
	, ''																									AS micro_organism_sub_id
	, ''																									AS loinc__version__lnc_id
	, ''																									AS technician_user_id
	, isnull('^FLO_ID=' + cast(questionaire.FLO_ID AS VARCHAR), '')											AS other_info
	, isnull(aoe.IS_ANSWR_BYPROC_YN, '')																	AS answered_by_proc_yn
	, isnull(questions.IS_RESP_REQ_YN, '')																	AS is_resp_req_yn
	, isnull(questions.IS_MULT_RESP_YN, '')																	AS is_mult_resp_yn
from orders ord
	INNER JOIN ORD_SPEC_QUEST aoe ON aoe.ORDER_ID=ord.order_id
		AND @IncludeQuestions > 0
	INNER JOIN CL_QQUEST_OVTM questions ON questions.QUEST_ID=aoe.ORD_QUEST_ID
		AND NOT EXISTS(SELECT 1 FROM CL_QQUEST_OVTM cqo
						WHERE cqo.QUEST_ID=aoe.ORD_QUEST_ID
							AND cqo.CONTACT_DATE_REAL > questions.CONTACT_DATE_REAL)
	INNER JOIN CL_QQUEST questionaire ON questionaire.QUEST_ID=aoe.ORD_QUEST_ID
	INNER JOIN ZC_RESP_TYPE resp_type ON resp_type.RESP_TYPE_C=questions.RESP_TYPE_C
