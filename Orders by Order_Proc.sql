/*****************************************
** Application	: Clarity
** Description	: Patient Homelessness Status
** Author		: Margaret Horner 
** Date			: 8/6/2020
******************************************
** Change History
******************************************
** Date     Author    Description	
** ------   -------   ------------------------------------
**   	  
******************************************/

DECLARE @SERVAREAID VARCHAR(30) = '10' 
DECLARE @STARTDATE SMALLDATETIME = '2020-07-01'
DECLARE @ENDDATE  SMALLDATETIME = '2020-07-31';

SELECT 
	ORD.ORDER_PROC_ID
	,CAST(ORD.ORDERING_DATE AS DATE)	AS "ORDER DATE"
	,ORD.DESCRIPTION		AS "ORDER DESC"
	,ZCOT.NAME				AS "ORDER TYPE"	
	,ZCOS.NAME				AS "ORDER STATUS"
	--,QUEST.ORD_QUEST_ID
	--,QUEST.ORD_QUEST_RESP
	--,ZCOS.NAME AS "STATUS"
	--,HNO.NOTE_ID
	--,NTYPE.NAME		AS "NOTE TYPE"
	
FROM ORDER_PROC	ORD
	 LEFT JOIN PAT_ENC		    ENC		ON ORD.PAT_ENC_CSN_ID = ENC.PAT_ENC_CSN_ID
	 LEFT JOIN ZC_ORDER_TYPE    ZCOT	ON ORD.ORDER_TYPE_C = ZCOT.ORDER_TYPE_C 
	 LEFT JOIN ZC_ORDER_STATUS  ZCOS	ON ORD.ORDER_STATUS_C = ZCOS.ORDER_STATUS_C
	 LEFT JOIN ORD_SPEC_QUEST   QUEST	ON ORD.ORDER_PROC_ID = QUEST.ORDER_ID
	 LEFT JOIN ORDER_STATUS		OSTAT	ON ORD.ORDER_PROC_ID = OSTAT.ORDER_ID
	 LEFT JOIN HNO_INFO			HNO		ON OSTAT.PROCEDURE_NOTE_ID = HNO.NOTE_ID
	 LEFT JOIN ZC_NOTE_TYPE_IP	NTYPE	ON HNO.IP_NOTE_TYPE_C = NTYPE.TYPE_IP_C

WHERE 1=1
	  AND ENC.SERV_AREA_ID = 10
	  AND ORD.ORDERING_DATE between @STARTDATE and @ENDDATE
	  --AND ORD.ORDER_TYPE_C IN (8,12,1003)		--Include Outpatient Referral, Consult, or E-Consult
	  AND (ORD.DESCRIPTION LIKE '%Ionized%'
	  or ORD.DESCRIPTION LIKE '%blood gas%')
	  --AND ENC.HOSP_ADMSN_TYPE_C = 1 --EMERGENCY
	  --AND ORD.FUTURE_OR_STAND IS NULL
	  --AND (QUEST.ORD_QUEST_ID = 1600053 AND QUEST.ORD_QUEST_RESP = 'Consult Completed')

	   --AND ORD.ORDER_STATUS_C NOT IN (4,7,8,9)	--Exclude Canceled, Denied Approval, Susped, Discontinued)

--SELECT * FROM ZC_HOSP_ADMSN_TYPE
--SELECT * FROM ZC_ORDER_TYPE
--SELECT * FROM CL_QQUEST WHERE QUEST_ID = '1600053'
