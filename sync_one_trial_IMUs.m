function status = sync_one_trial_IMUs(trialPath)

close all;

status = struct();
status.TrialPath = string(trialPath);
status.Success = false;
status.Message = "";

%% SETTINGS
fs_sync = 100;                 % final synchronized sampling frequency
dt_sync = 1/fs_sync;

static_search_seconds = 6;     % search first 6 sec for quiet standing
static_window_seconds = 2;     % calmest 2 sec for gyro bias

onset_search_after_s = 1.0;
min_onset_hold_s = 0.20;

crop_to_walking = true;        % true = save walking-only synchronized data too
pre_walk_buffer_s = 1.0;       % keep 1 second before detected walking onset
post_walk_buffer_s = 1.0;      % keep 1 second after detected walking end

%% OUTPUT FOLDER
syncOutputFolder = fullfile(trialPath, 'SYNC_Results_TimestampBased');

if ~exist(syncOutputFolder, 'dir')
    mkdir(syncOutputFolder);
end

plotFolder = fullfile(syncOutputFolder, 'SYNC_Plots');

if ~exist(plotFolder, 'dir')
    mkdir(plotFolder);
end

%% LOAD SENSOR MAPPING
[rootParticipantFolder, ~] = fileparts(trialPath);
[rootFolder, ~] = fileparts(rootParticipantFolder);

mappingCSV = fullfile(rootFolder, 'SensorMapping.csv');
mappingXLSX = fullfile(rootFolder, 'SensorMapping.xlsx');

if isfile(mappingCSV)
    SensorMap = readtable(mappingCSV);
elseif isfile(mappingXLSX)
    SensorMap = readtable(mappingXLSX);
else
    warning('No SensorMapping.csv/xlsx found. Segment names will be Unknown.');
    SensorMap = table();
end

%% FIND SENSOR FILES
files = dir(fullfile(trialPath, '*.txt'));

if isempty(files)
    error('No .txt sensor files found in selected trial folder.');
end

fprintf('\nFound %d sensor files.\n', length(files));

if length(files) ~= 7
    warning('Expected 7 sensors, but found %d files. Inspect this trial folder.', length(files));
end

%% LOAD EACH SENSOR
Sensors = struct();

for f = 1:length(files)

    sensorFile = fullfile(trialPath, files(f).name);

    S = load_clean_INDIP_sensor_for_sync( ...
        sensorFile, ...
        SensorMap, ...
        static_search_seconds, ...
        static_window_seconds);

    Sensors(f).File = S.File;
    Sensors(f).DeviceID = S.DeviceID;
    Sensors(f).Segment = S.Segment;

    Sensors(f).timestamp_ms = S.timestamp_ms;
    Sensors(f).t_unix_s = S.t_unix_s;
    Sensors(f).t_local_s = S.t_local_s;

    Sensors(f).ax = S.ax;
    Sensors(f).ay = S.ay;
    Sensors(f).az = S.az;

    Sensors(f).gx = S.gx;
    Sensors(f).gy = S.gy;
    Sensors(f).gz = S.gz;

    Sensors(f).mx = S.mx;
    Sensors(f).my = S.my;
    Sensors(f).mz = S.mz;

    Sensors(f).acc_mag = S.acc_mag;
    Sensors(f).gyro_mag = S.gyro_mag;
    Sensors(f).mag_mag = S.mag_mag;

    Sensors(f).gyro_bias = S.gyro_bias;
    Sensors(f).static_start_time = S.static_start_time;
    Sensors(f).static_end_time = S.static_end_time;

    Sensors(f).onset_time_local = detect_walking_onset( ...
        S.t_local_s, ...
        S.gyro_mag, ...
        onset_search_after_s, ...
        min_onset_hold_s);

    Sensors(f).onset_time_unix = S.t_unix_s(1) + Sensors(f).onset_time_local;

    fprintf('%s | %s | local onset %.3f s\n', ...
        Sensors(f).DeviceID, Sensors(f).Segment, Sensors(f).onset_time_local);

end

%% ABSOLUTE TIMESTAMP SYNCHRONIZATION
% This is the key difference from Version 1.
% We do NOT shift sensors using onset.
% We use Unix timestamp overlap.

starts = zeros(length(Sensors), 1);
ends_ = zeros(length(Sensors), 1);

for f = 1:length(Sensors)
    starts(f) = Sensors(f).t_unix_s(1);
    ends_(f) = Sensors(f).t_unix_s(end);
end

common_start_unix = max(starts);
common_end_unix = min(ends_);

if common_end_unix <= common_start_unix
    error('No overlapping Unix timestamp region across sensors.');
end

t_common_unix = (common_start_unix:dt_sync:common_end_unix)';
t_common_zero = t_common_unix - t_common_unix(1);

fprintf('\nCommon timestamp-based synchronized duration: %.3f s\n', t_common_zero(end));

%% RESAMPLE EACH SENSOR ONTO COMMON UNIX TIME VECTOR
SyncTable = table();
SyncTable.Time_s = t_common_zero;

SyncSummary = table();

for f = 1:length(Sensors)

    seg = char(matlab.lang.makeValidName(char(Sensors(f).Segment)));

    ax_i = interp1(Sensors(f).t_unix_s, Sensors(f).ax, t_common_unix, 'linear');
    ay_i = interp1(Sensors(f).t_unix_s, Sensors(f).ay, t_common_unix, 'linear');
    az_i = interp1(Sensors(f).t_unix_s, Sensors(f).az, t_common_unix, 'linear');

    gx_i = interp1(Sensors(f).t_unix_s, Sensors(f).gx, t_common_unix, 'linear');
    gy_i = interp1(Sensors(f).t_unix_s, Sensors(f).gy, t_common_unix, 'linear');
    gz_i = interp1(Sensors(f).t_unix_s, Sensors(f).gz, t_common_unix, 'linear');

    mx_i = interp1(Sensors(f).t_unix_s, Sensors(f).mx, t_common_unix, 'linear');
    my_i = interp1(Sensors(f).t_unix_s, Sensors(f).my, t_common_unix, 'linear');
    mz_i = interp1(Sensors(f).t_unix_s, Sensors(f).mz, t_common_unix, 'linear');

    SyncTable.([seg '_AccX_g']) = ax_i;
    SyncTable.([seg '_AccY_g']) = ay_i;
    SyncTable.([seg '_AccZ_g']) = az_i;

    SyncTable.([seg '_GyroX_dps']) = gx_i;
    SyncTable.([seg '_GyroY_dps']) = gy_i;
    SyncTable.([seg '_GyroZ_dps']) = gz_i;

    SyncTable.([seg '_MagX_mGauss']) = mx_i;
    SyncTable.([seg '_MagY_mGauss']) = my_i;
    SyncTable.([seg '_MagZ_mGauss']) = mz_i;

    startOffset_s = Sensors(f).t_unix_s(1) - common_start_unix;
    endOffset_s = Sensors(f).t_unix_s(end) - common_end_unix;

    newSummary = table( ...
        string(Sensors(f).File), ...
        string(Sensors(f).DeviceID), ...
        string(Sensors(f).Segment), ...
        Sensors(f).t_unix_s(1), ...
        Sensors(f).t_unix_s(end), ...
        startOffset_s, ...
        endOffset_s, ...
        Sensors(f).onset_time_local, ...
        Sensors(f).onset_time_unix, ...
        Sensors(f).gyro_bias(1), ...
        Sensors(f).gyro_bias(2), ...
        Sensors(f).gyro_bias(3), ...
        Sensors(f).static_start_time, ...
        Sensors(f).static_end_time);

    SyncSummary = [SyncSummary; newSummary];

end

SyncSummary.Properties.VariableNames = { ...
    'File', ...
    'DeviceID', ...
    'Segment', ...
    'StartUnix_s', ...
    'EndUnix_s', ...
    'StartOffsetFromCommon_s', ...
    'EndOffsetFromCommon_s', ...
    'DetectedOnsetLocal_s', ...
    'DetectedOnsetUnix_s', ...
    'GyroBiasX_dps', ...
    'GyroBiasY_dps', ...
    'GyroBiasZ_dps', ...
    'StaticStart_s', ...
    'StaticEnd_s'};

%% CREATE COMBINED GYRO MAGNITUDE FOR WALKING CROP
gyroCols = contains(SyncTable.Properties.VariableNames, 'GyroX_dps') | ...
           contains(SyncTable.Properties.VariableNames, 'GyroY_dps') | ...
           contains(SyncTable.Properties.VariableNames, 'GyroZ_dps');

gyroData = SyncTable{:, gyroCols};
combinedGyro = mean(abs(gyroData), 2, 'omitnan');

[walk_start_s, walk_end_s] = detect_walking_window_from_combined_signal( ...
    SyncTable.Time_s, ...
    combinedGyro, ...
    pre_walk_buffer_s, ...
    post_walk_buffer_s);

fprintf('\nDetected walking window: %.3f s to %.3f s\n', walk_start_s, walk_end_s);

%% CROP WALKING SECTION
walking_idx = SyncTable.Time_s >= walk_start_s & SyncTable.Time_s <= walk_end_s;
SyncTable_Walking = SyncTable(walking_idx, :);

% Reset walking time to start at zero
SyncTable_Walking.Time_s = SyncTable_Walking.Time_s - SyncTable_Walking.Time_s(1);

%% SAVE OUTPUTS
syncCSV = fullfile(syncOutputFolder, 'Synchronized_IMU_Data_Full.csv');
walkingCSV = fullfile(syncOutputFolder, 'Synchronized_IMU_Data_WalkingOnly.csv');
summaryCSV = fullfile(syncOutputFolder, 'Synchronization_Summary.csv');
syncMAT = fullfile(syncOutputFolder, 'Synchronized_IMU_Data.mat');

writetable(SyncTable, syncCSV);
writetable(SyncTable_Walking, walkingCSV);
writetable(SyncSummary, summaryCSV);

save(syncMAT, ...
    'SyncTable', ...
    'SyncTable_Walking', ...
    'SyncSummary', ...
    'Sensors', ...
    't_common_zero', ...
    'fs_sync', ...
    'walk_start_s', ...
    'walk_end_s');

fprintf('\nSaved full synchronized data:\n%s\n', syncCSV);
fprintf('\nSaved walking-only synchronized data:\n%s\n', walkingCSV);
fprintf('\nSaved synchronization summary:\n%s\n', summaryCSV);

%% PLOTS
plot_timestamp_based_sync(Sensors, SyncTable, combinedGyro, walk_start_s, walk_end_s, plotFolder);

disp(' ');
disp('Timestamp-based synchronization complete.');

status.Success = true;
status.Message = "Synchronization completed successfully.";

end