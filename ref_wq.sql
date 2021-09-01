select * from REFERRAL_WQ where workqueue_name like '%referred%' --671
select * from REFERRAL_WQ_ITEMS where WORKQUEUE_ID = 671 and RELEASE_DATE > '1/1/2021'
select * from REFERRAL_WQ_USR_HX where ITEM_ID = 51866710
select * from REFERRAL_WQ_ITEMS where ITEM_ID = 51866710

/*
workqueue, user, entry date, release date - looking for count of each over time by user
WQI .1 - WORKQUEUE_ID
WQI .2 - WORKQUEUE_NAME
WQI 31 - REFERRAL_ID
WQI 34 - ENTRY_DATE
WQI 35 - RELEASE_DATE
WQI 101 - USER_ID
WQI 104 - HISTORY_ACTIVITY_C
WQI

/*