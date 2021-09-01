select distinct  HGR.report_id [1], hgr.REPORT_NAME [2], HRX.report_info_id,  hrx.REPORT_INFO_NAME 
,emp.NAME
--,hrx.*
from rw_rpt_run_data HRN
left outer join report_info HRX on HRX.report_info_id = coalesce(HRN.source_report_id,HRN.rep_settings_id)
left outer join template_info HGR on HGR.report_id = HRN.report_template_id
left join CLARITY_EMP emp on hrx.OWNED_BY_USER_ID = emp.USER_ID
where HGR.report_id in (34458 , 100223)
--order by REPORT_INFO_ID