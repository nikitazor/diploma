import 'pig/macro/GetLogBounds.macro';
import 'pig/macro/LoadBeans.macro';
import 'pig/macro/StoreCSVData.macro';

-- Load all beans from log files
all_beans = LoadBeans('$INPUT_LOG_FILE');


--Battery State united with Self state
--In self state beans 'Level' is -1 for user defined function InterpolateBatteryLevel to recognize moments of shutdown
--Also in this beans timestamp is replaced with startTime, for correct sort
battery_beans = filter all_beans by BEAN_TYPE == 'BATTERY_STATE' or BEAN_TYPE=='SELF_STATE';
battery_levels = foreach battery_beans generate
DEVICE_ID as DeviceID,
(BEAN_FIELDS#'startTime' is null ? TIMESTAMP:BEAN_FIELDS#'startTime') as Timestamp,
((int)BEAN_FIELDS#'Level' is null ? -1:(int)BEAN_FIELDS#'Level') as Level:int,
BEAN_FIELDS#'PlugState' as PlugState:chararray;






--dump battery_beans;
--dump battery_levels;
-- Group Battery State beans by device ID and sort them by timestamp
battery_levels_grouped = group battery_levels by DeviceID;
battery_levels_grouped_sorted = foreach battery_levels_grouped {
sorted = order battery_levels by Timestamp;
generate group as DeviceID, sorted as SortedBeans;
};

--dump battery_levels_grouped;
--dump battery_levels_grouped_sorted;

-- Interpolate battery level for whole log
-- Intervals with self state bean between battery beans are not being interpolated
define interpolateBatteryLevel com.motorolasolutions.bigdata.mcdf.pig.eval.InterpolateBatteryLevel();
battery_levels_interpolated = foreach battery_levels_grouped_sorted generate
DeviceID,
flatten(interpolateBatteryLevel(SortedBeans))
as (Timestamp, Level, PlugState, PointType);

--dump battery_levels_interpolated;


--StoreCSVData('$OUTPUT_BATTERY_STATE_FILE', battery_levels_interpolated);


-- Applications beans united with self state beans
-- Self state bean are replace with Application beans with empty Appsrun field
app_beans_0 = filter all_beans by BEAN_TYPE == 'APPLICATIONS' or BEAN_TYPE == 'SELF_STATE';
app_beans = foreach app_beans_0 generate
    'APPLICATIONS' as BEAN_TYPE,
    DEVICE_ID,
    (BEAN_FIELDS#'startTime' is null ? TIMESTAMP:BEAN_FIELDS#'startTime') as TIMESTAMP,
    (BEAN_FIELDS#'AppsRun' is null ? '': BEAN_FIELDS#'AppsRun') as AppsRun;


  --  dump app_beans;

-- Group beans by device ID and sort them by Timestamp in ascending order
beans_filtered_grouped = group app_beans by DEVICE_ID;
beans_filtered_grouped_sorted = foreach beans_filtered_grouped {
    sorted = order app_beans by TIMESTAMP;

    generate group as DeviceID, sorted as Messages;
};

--dump beans_filtered_grouped_sorted;

-- Get separate application events: (App list change events ) --> (App Start) & (App Stop)
define getAppEvent com.motorolasolutions.bigdata.mcdf.pig.eval.ApplicationEvent('Please, round timestamps');
app_events = foreach beans_filtered_grouped_sorted generate
    DeviceID,
    flatten(getAppEvent(Messages))
    as (Timestamp, App, Flag);

--dump app_events;
-- Join battery levels and application events
battery_apps_join = join
    battery_levels_interpolated by (DeviceID, Timestamp) full outer,
    app_events by (DeviceID, Timestamp);
--dump battery_apps_join;
--StoreCSVData('$OUTPUT_BATTERY_STATE_FILE', battery_apps_join);
-- Filter out unnecessary joined rows
battery_apps_filtered = filter battery_apps_join by
    (app_events::App is not null AND SIZE(app_events::App) > 0) OR
    (
        battery_levels_interpolated::PointType is not null AND
        battery_levels_interpolated::PointType == 'NODAL_POINT'
    );
--dump battery_apps_filtered;



-- Reduce number of fields
battery_apps_data = foreach battery_apps_filtered generate
    (
        battery_levels_interpolated::DeviceID is not null
            ? battery_levels_interpolated::DeviceID
            : app_events::DeviceID
    ) as DeviceID,
    (
        battery_levels_interpolated::Timestamp is not null
            ? battery_levels_interpolated::Timestamp
            : app_events::Timestamp
    ) as Timestamp,
    battery_levels_interpolated::Level as Level,
    battery_levels_interpolated::PlugState as PlugState,
    app_events::App as Application,
    app_events::Flag as Flag;
    --dump battery_apps_data;
-- Group battery and apps data by device ID and sort them by timestamp
battery_apps_grouped = group battery_apps_data by DeviceID;
battery_apps_grouped_sorted = foreach battery_apps_grouped {
    sorted = order battery_apps_data by Timestamp;
    generate group as DeviceID, sorted as SortedData;
};

--dump battery_apps_data;
--StoreCSVData('$OUTPUT_BATTERY_USAGE_FILE', battery_apps_data);
-- Get battery usage intervals for each application
define getBatteryUsage com.motorolasolutions.bigdata.mcdf.pig.eval.BatteryUsage();
battery_usage = foreach battery_apps_grouped_sorted generate
    DeviceID,
    flatten(getBatteryUsage(SortedData))
    as (Application, Timestamp, BatteryUsage);
--dump battery_usage;
StoreCSVData('$OUTPUT_BATTERY_USAGE_FILE', battery_usage);


-- Calculate battery usage speed
battery_usage_grouped = group battery_usage by (DeviceID, Application);
battery_usage_speed = foreach battery_usage_grouped generate
    group.DeviceID, group.Application,
    SUM(battery_usage.BatteryUsage) / COUNT(battery_usage.BatteryUsage) as BatteruUsageRatio;
--dump battery_usage_speed;
--StoreCSVData('$OUTPUT_BATTERY_USAGE_SPEED_FILE', battery_usage_speed);