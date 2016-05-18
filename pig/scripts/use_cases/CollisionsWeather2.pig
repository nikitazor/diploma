import 'pig/macro/LoadCSVData.macro';
import 'pig/macro/LoadCSVData1.macro';
import 'pig/macro/StoreCSVData.macro';

wdata = LoadCSVData('/user/nik/midas_wxhrly_201401-201412.csv');
cdata = LoadCSVData1('/user/nik/full.csv');

t2 = FOREACH wdata GENERATE FLATTEN(STRSPLIT(OB_TIME,' ')),ID,ID_TYPE,MET_DOMAIN_NAME,SRC_ID ,REC_ST_IND,WIND_SPEED_UNIT_ID ,SRC_OPR_TYPE ,WIND_DIRECTION ,WIND_SPEED ,PRST_WX_ID ,PAST_WX_ID_1 ,PAST_WX_ID_2 ,CLD_TTL_AMT_ID ,LOW_CLD_TYPE_ID,MED_CLD_TYPE_ID,HI_CLD_TYPE_ID ,CLD_BASE_AMT_ID,CLD_BASE_HT,VISIBILITY ,MSL_PRESSURE ,VERT_VSBY,AIR_TEMPERATURE ,DEWPOINT,WETB_TEMP,STN_PRES ,ALT_PRES ,GROUND_STATE_ID ,Q10MNT_MXGST_SPD ,CAVOK_FLAG ,CS_HR_SUN_DUR,WMO_HR_SUN_DUR, SNOW_DEPTH ,DRV_HR_SUN_DUR;
--t2 = FILTER t1 BY (($0 matches '2014.+') OR ($0 matches '2014-02.+'));
t3 = GROUP t2 BY ($0, $5);

define kok com.google.transit.realtime.BatteryUsage();
t4 = FOREACH t3 GENERATE FLATTEN (kok(t2));


--cdata = FILTER cdata1 BY ((Date matches '../01/2014') OR (Date matches '../02/2014'));
--grouped = GROUP cdata BY (w_src, Date);
--comb = FOREACH grouped GENERATE
--        FLATTEN(group) AS (w_src, Date),
--        COUNT (cdata),
--        MAX (cdata.dist);

fin = FOREACH cdata GENERATE
        ToDate(Date,'dd/mm/yyyy') as Tate:datetime,
        Accident_Index,Location_Easting_OSGR,Location_Northing_OSGR,Longitude,Latitude,Police_Force,Accident_Severity,Number_of_Vehicles,Number_of_Casualties,Date,Day_of_Week,Time,Local_Authority_District,Local_Authority_Highway,st_Road_Class,st_Road_Number,Road_Type,Speed_limit,Junction_Detail,Junction_Control,nd_Road_Class,nd_Road_Number,Pedestrian_Crossing_Human_Control,Pedestrian_Crossing_Physical_Facilities,Light_Conditions,Weather_Conditions,Road_Surface_Conditions,Special_Conditions_at_Site,Carriageway_Hazards,Urban_or_Rural_Area,Did_Police_Officer_Attend_Scene_of_Accident,LSOA_of_Accident_Location,w_src,dist;
fin1 = FOREACH fin GENERATE
        CONCAT (ToString(Tate,'yyyy'),CONCAT('-',CONCAT(ToString(Tate,'mm'),CONCAT('-',ToString(Tate,'dd'))))) as Tate:chararray,
        Accident_Index,Location_Easting_OSGR,Location_Northing_OSGR,Longitude,Latitude,Police_Force,Accident_Severity,Number_of_Vehicles,Number_of_Casualties,Date,Day_of_Week,Time,Local_Authority_District,Local_Authority_Highway,st_Road_Class,st_Road_Number,Road_Type,Speed_limit,Junction_Detail,Junction_Control,nd_Road_Class,nd_Road_Number,Pedestrian_Crossing_Human_Control,Pedestrian_Crossing_Physical_Facilities,Light_Conditions,Weather_Conditions,Road_Surface_Conditions,Special_Conditions_at_Site,Carriageway_Hazards,Urban_or_Rural_Area,Did_Police_Officer_Attend_Scene_of_Accident,LSOA_of_Accident_Location,w_src,dist;
joined = JOIN fin1 BY (w_src, Tate) LEFT, t4 by (SRC_ID, DATE);

f1 = FILTER joined BY (NOT (t4::ResultBag::VISIBILITY == ' '));
f2 = FILTER joined BY (NOT (t4::ResultBag::SNOW_DEPTH == ' '));
f3 = FILTER joined BY (NOT (t4::ResultBag::GROUND_STATE_ID == ' '));
f4 = FILTER joined BY (NOT (t4::ResultBag::PRST_WX_ID == ' '));

gf1 = GROUP f1 BY (t4::ResultBag::VISIBILITY);
cf1 = FOREACH gf1 GENERATE
        group,
        COUNT (f1);
mf1 = GROUP t2 BY ($20);
kf1 = FOREACH mf1 GENERATE
        group,
        COUNT (t2);
jf1 = JOIN kf1 BY ($0) LEFT, cf1 BY ($0);
-------------------------------------------------------------
gf2 = GROUP f2 BY (t4::ResultBag::SNOW_DEPTH);
cf2 = FOREACH gf2 GENERATE
        group,
        COUNT (f2);
mf2 = GROUP t2 BY ($34);
kf2 = FOREACH mf1 GENERATE
        group,
        COUNT (t2);
jf2 = JOIN kf2 BY ($0) LEFT, cf2 BY ($0);
-------------------------------------------------------------
gf3 = GROUP f3 BY (t4::ResultBag::GROUND_STATE_ID);
cf3 = FOREACH gf3 GENERATE
        group,
        COUNT (f3);
mf3 = GROUP t2 BY ($28);
kf3 = FOREACH mf3 GENERATE
        group,
        COUNT (t2);
jf3 = JOIN kf3 BY ($0) LEFT, cf3 BY ($0);
-------------------------------------------------------------
gf4 = GROUP f4 BY (t4::ResultBag::PRST_WX_ID);
cf4 = FOREACH gf4 GENERATE
        group,
        COUNT (f4);
mf4 = GROUP t2 BY ($11);
kf4 = FOREACH mf4 GENERATE
        group,
        COUNT (t2);
jf4 = JOIN kf4 BY ($0) LEFT, cf4 BY ($0);

--dump f1;
StoreCSVData('/user/nik/visibility', jf1);
StoreCSVData('/user/nik/snow', jf2);
StoreCSVData('/user/nik/ground', jf3);
StoreCSVData('/user/nik/prst_wx', jf4);

