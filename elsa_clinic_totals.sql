--LVCC
select 
--top 100 
departmentid, max(DepartmentName) dept ,count(*) Total
--* 
from 
[UMCSN].[vw_CovidPcrLabsView]
where convert(date, OrderInstant) between '3/1/2020' and '3/18/2021'
--and DepartmentName like 'LVCC%' 

group by DepartmentId
--order by  convert(date, OrderInstant)

--CLINICS
select 
--top 100 
max(LocationName) location ,count(*) Total
--* 
from 
[UMCSN].[vw_CovidPcrLabsView]
where convert(date, OrderInstant) between '3/1/2020' and '3/18/2021'
and LocationId in (100003,100011,100005,100007,100002,100009,100004,100010,100006,100008)
--order by  convert(date, OrderInstant)
