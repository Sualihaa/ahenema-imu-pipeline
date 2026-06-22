clear; clc; close all;

%% SELECT SYNC RESULT FOLDER
syncFolder = uigetdir(pwd, 'Select SYNC_Results_TimestampBased folder');

if isequal(syncFolder, 0)
    error('No folder selected.');
end

syncMatFile = fullfile(syncFolder, 'Synchronized_IMU_Data.mat');

if ~isfile(syncMatFile)
    error('Synchronized_IMU_Data.mat not found.');
end

%% LOAD SYNCHRONIZED DATA
load(syncMatFile, ...
    'SyncTable', ...
    'SyncTable_Walking', ...
    'fs_sync', ...
    'walk_start_s', ...
    'walk_end_s');

fprintf('\nLoaded synchronized data.\n');
fprintf('Full duration: %.3f s\n', SyncTable.Time_s(end));
fprintf('Walking starts at: %.3f s\n', walk_start_s);

%% SETTINGS
g = 9.80665;
static_window_seconds = 2.0;

%% OUTPUT FOLDER
orientationFolder = fullfile(syncFolder, 'Orientation_Results_MagOFF');

if ~exist(orientationFolder, 'dir')
    mkdir(orientationFolder);
end

plotFolder = fullfile(orientationFolder, 'Static_Calibration_Plots');

if ~exist(plotFolder, 'dir')
    mkdir(plotFolder);
end

%% CHECK FILTER
if exist('imufilter', 'file') ~= 2
    error('imufilter not found. Sensor Fusion and Tracking Toolbox is needed.');
end

%% DETECT SEGMENTS
vars = SyncTable.Properties.VariableNames;
gyroXVars = vars(contains(vars, '_GyroX_dps'));

segments = strings(length(gyroXVars), 1);

for i = 1:length(gyroXVars)
    segments(i) = string(erase(gyroXVars{i}, '_GyroX_dps'));
end

fprintf('\nSegments detected:\n');
disp(segments);

%% BUILD COMBINED GYRO SIGNAL BEFORE WALKING
gyroCols = contains(SyncTable.Properties.VariableNames, 'GyroX_dps') | ...
           contains(SyncTable.Properties.VariableNames, 'GyroY_dps') | ...
           contains(SyncTable.Properties.VariableNames, 'GyroZ_dps');

gyroData = SyncTable{:, gyroCols};
combinedGyro = mean(abs(gyroData), 2, 'omitnan');

%% SEARCH ONLY BEFORE WALKING START
search_idx = find(SyncTable.Time_s < walk_start_s);

if isempty(search_idx)
    error('No pre-walking region found for static calibration.');
end

window_samples = round(static_window_seconds * fs_sync);

if length(search_idx) <= window_samples
    warning('Pre-walking region is short. Using available pre-walking data.');
    static_start_idx = search_idx(1);
    static_end_idx = search_idx(end);
else
    scores = nan(length(search_idx), 1);

    for k = 1:(length(search_idx) - window_samples)

        idx = search_idx(k):(search_idx(k) + window_samples - 1);

        scores(k) = mean(combinedGyro(idx), 'omitnan') + std(combinedGyro(idx), 'omitnan');
    end

    [~, best_k] = min(scores);

    static_start_idx = search_idx(best_k);
    static_end_idx = static_start_idx + window_samples - 1;
end

static_start_s = SyncTable.Time_s(static_start_idx);
static_end_s = SyncTable.Time_s(static_end_idx);

fprintf('\nStatic calibration window: %.3f s to %.3f s\n', static_start_s, static_end_s);

static_idx = false(height(SyncTable), 1);
static_idx(static_start_idx:static_end_idx) = true;

%% PLOT STATIC WINDOW
fig = figure('Visible','off');
plot(SyncTable.Time_s, combinedGyro);
xline(static_start_s, 'k--', 'Static Start');
xline(static_end_s, 'k--', 'Static End');
xline(walk_start_s, 'r--', 'Walk Start');
title('Detected static calibration window');
xlabel('Time (s)');
ylabel('Combined gyro activity');
saveas(fig, fullfile(plotFolder, 'static_calibration_window.png'));
close(fig);

%% OUTPUT STATIC QUATERNION TABLE
QuatStaticTable = table();
QuatStaticTable.Time_s = 0;

%% FULL ORIENTATION TABLE FOR RECORD
QuatFullTable = table();
QuatFullTable.Time_s = SyncTable.Time_s;

%% LOOP THROUGH SEGMENTS
for s = 1:length(segments)

    seg = char(segments(s));

    fprintf('Estimating full-trial MagOFF orientation for %s...\n', seg);

    %% Extract full synchronized signals
    acc_g = [ ...
        SyncTable.([seg '_AccX_g']), ...
        SyncTable.([seg '_AccY_g']), ...
        SyncTable.([seg '_AccZ_g'])];

    gyro_dps = [ ...
        SyncTable.([seg '_GyroX_dps']), ...
        SyncTable.([seg '_GyroY_dps']), ...
        SyncTable.([seg '_GyroZ_dps'])];

    %% Convert units
    acc_mps2 = acc_g * g;
    gyro_rads = deg2rad(gyro_dps);

    %% Fill missing values
    acc_mps2 = fillmissing(acc_mps2, 'nearest');
    gyro_rads = fillmissing(gyro_rads, 'nearest');

    %% Run IMU filter on full trial
    fuse = imufilter('SampleRate', fs_sync);
    q = fuse(acc_mps2, gyro_rads);

    qNum = compact(q);  % [q0 q1 q2 q3]

    %% Save full quaternions for inspection
    QuatFullTable.([seg '_q0']) = qNum(:,1);
    QuatFullTable.([seg '_q1']) = qNum(:,2);
    QuatFullTable.([seg '_q2']) = qNum(:,3);
    QuatFullTable.([seg '_q3']) = qNum(:,4);

    %% Average quaternion during static window
    qStaticSamples = qNum(static_idx, :);
    qStaticMean = average_quaternions_markley(qStaticSamples);

    QuatStaticTable.([seg '_q0']) = qStaticMean(1);
    QuatStaticTable.([seg '_q1']) = qStaticMean(2);
    QuatStaticTable.([seg '_q2']) = qStaticMean(3);
    QuatStaticTable.([seg '_q3']) = qStaticMean(4);

end

%% SAVE CSV RECORDS
staticCSV = fullfile(orientationFolder, 'Segment_Quaternions_Static_MagOFF.csv');
fullCSV = fullfile(orientationFolder, 'Segment_Quaternions_Full_MagOFF.csv');

writetable(QuatStaticTable, staticCSV);
writetable(QuatFullTable, fullCSV);

%% WRITE OPENSIM STATIC STO
staticSTO = fullfile(orientationFolder, 'OpenSim_Orientations_Static_MagOFF.sto');

write_opensim_quaternion_sto(QuatStaticTable, staticSTO, '4.5');

%% SAVE MAT
staticMAT = fullfile(orientationFolder, 'Static_Calibration_Orientation_MagOFF.mat');

save(staticMAT, ...
    'QuatStaticTable', ...
    'QuatFullTable', ...
    'segments', ...
    'fs_sync', ...
    'static_start_s', ...
    'static_end_s', ...
    'walk_start_s');

fprintf('\nStatic calibration STO created:\n%s\n', staticSTO);
fprintf('\nStatic calibration complete.\n');