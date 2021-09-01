SELECT 
emp.USER_ID [User ID]
,emp.NAME [User Name]
,emp.SYSTEM_LOGIN [User Login]
,hx_login.LOGIN_INSTANT_DTTM [Login Date]
,hx_login.LOG_HIST_GUI_ID [Work Station]
--,hx_login.* 
from CLARITY.dbo.CLARITY_EMP emp
JOIN CLARITY.dbo.EMP_LOGIN_HX hx_login on emp.USER_ID = hx_login.USER_ID
WHERE emp.SYSTEM_LOGIN = 'AG307363' --1171
and hx_login.LOGIN_INSTANT_DTTM between '12/14/2020' and '1/31/2021'