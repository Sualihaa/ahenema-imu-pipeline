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
fprintf('Walking duration: %.3f s\n', SyncTable_Walking.Time_s(end));

%% SETTINGS
g = 9.80665;
static_window_seconds = 2.0;

%% OUTPUT FOLDER
orientationFolder = fullfile(syncFolder, 'Orientation_Results_MagON');

if ~exist(orientationFolder, 'dir')
    mkdir(orientationFolder);
end

plotFolder = fullfile(orientationFolder, 'Euler_Plots');

if ~exist(plotFolder, 'dir')
    mkdir(plotFolder);
end

staticPlotFolder = fullfile(orientationFolder, 'Static_Calibration_Plots');

if ~exist(staticPlotFolder, 'dir')
    mkdir(staticPlotFolder);
end

%% CHECK FILTER
if exist('ahrsfilter', 'file') ~= 2
    error('ahrsfilter not found. Sensor Fusion and Tracking Toolbox is needed.');
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

%% DETECT STATIC WINDOW FROM FULL TRIAL BEFORE WALKING
gyroCols = contains(SyncTable.Properties.VariableNames, 'GyroX_dps') | ...
           contains(SyncTable.Properties.VariableNames, 'GyroY_dps') | ...
           contains(SyncTable.Properties.VariableNames, 'GyroZ_dps');

gyroData = SyncTable{:, gyroCols};
combinedGyro = mean(abs(gyroData), 2, 'omitnan');

search_idx = find(SyncTable.Time_s < walk_start_s);

if isempty(search_idx)
    error('No pre-walking region found for static calibration.');
end

window_samples = round(static_window_seconds * fs_sync);

if length(search_idx) <= window_samples
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

fig = figure('Visible','off');
plot(SyncTable.Time_s, combinedGyro);
xline(static_start_s, 'k--', 'Static Start');
xline(static_end_s, 'k--', 'Static End');
xline(walk_start_s, 'r--', 'Walk Start');
title('Detected static calibration window MagON');
xlabel('Time (s)');
ylabel('Combined gyro activity');
saveas(fig, fullfile(staticPlotFolder, 'static_calibration_window_MagON.png'));
close(fig);

%% OUTPUT TABLES
QuatFullTable = table();
QuatFullTable.Time_s = SyncTable.Time_s;

QuatWalkingTable = table();
QuatWalkingTable.Time_s = SyncTable_Walking.Time_s;

EulerWalkingTable = table();
EulerWalkingTable.Time_s = SyncTable_Walking.Time_s;

QuatStaticTable = table();
QuatStaticTable.Time_s = 0;

%% LOOP THROUGH SEGMENTS
for s = 1:length(segments)

    seg = char(segments(s));

    fprintf('\nEstimating MagON orientation for %s...\n', seg);

    %% FULL TRIAL SIGNALS
    acc_g = [ ...
        SyncTable.([seg '_AccX_g']), ...
        SyncTable.([seg '_AccY_g']), ...
        SyncTable.([seg '_AccZ_g'])];

    gyro_dps = [ ...
        SyncTable.([seg '_GyroX_dps']), ...
        SyncTable.([seg '_GyroY_dps']), ...
        SyncTable.([seg '_GyroZ_dps'])];

    mag_mGauss = [ ...
        SyncTable.([seg '_MagX_mGauss']), ...
        SyncTable.([seg '_MagY_mGauss']), ...
        SyncTable.([seg '_MagZ_mGauss'])];

    %% CONVERT UNITS
    acc_mps2 = acc_g * g;
    gyro_rads = deg2rad(gyro_dps);
    mag_uT = mag_mGauss * 0.1;

    %% FILL MISSING
    acc_mps2 = fillmissing(acc_mps2, 'nearest');
    gyro_rads = fillmissing(gyro_rads, 'nearest');
    mag_uT = fillmissing(mag_uT, 'nearest');

    %% RUN AHR FILTER: ACC + GYRO + MAG
    fuse = ahrsfilter('SampleRate', fs_sync);

    q = fuse(acc_mps2, gyro_rads, mag_uT);

    qNum = compact(q);  % [q0 q1 q2 q3]

    %% STORE FULL
    QuatFullTable.([seg '_q0']) = qNum(:,1);
    QuatFullTable.([seg '_q1']) = qNum(:,2);
    QuatFullTable.([seg '_q2']) = qNum(:,3);
    QuatFullTable.([seg '_q3']) = qNum(:,4);

    %% STATIC MEAN QUATERNION
    qStaticSamples = qNum(static_idx, :);
    qStaticMean = average_quaternions_markley(qStaticSamples);

    QuatStaticTable.([seg '_q0']) = qStaticMean(1);
    QuatStaticTable.([seg '_q1']) = qStaticMean(2);
    QuatStaticTable.([seg '_q2']) = qStaticMean(3);
    QuatStaticTable.([seg '_q3']) = qStaticMean(4);

    %% WALKING PORTION
    walking_idx = SyncTable.Time_s >= walk_start_s & SyncTable.Time_s <= walk_end_s;

    qWalk = qNum(walking_idx, :);

    nWalk = min(height(SyncTable_Walking), size(qWalk,1));
    qWalk = qWalk(1:nWalk, :);

    if height(QuatWalkingTable) > nWalk
        QuatWalkingTable = QuatWalkingTable(1:nWalk, :);
        EulerWalkingTable = EulerWalkingTable(1:nWalk, :);
    end

    eulWalk = quat_to_euler_zyx_degrees(qWalk);

    QuatWalkingTable.([seg '_q0']) = qWalk(:,1);
    QuatWalkingTable.([seg '_q1']) = qWalk(:,2);
    QuatWalkingTable.([seg '_q2']) = qWalk(:,3);
    QuatWalkingTable.([seg '_q3']) = qWalk(:,4);

    EulerWalkingTable.([seg '_Yaw_deg']) = eulWalk(:,1);
    EulerWalkingTable.([seg '_Pitch_deg']) = eulWalk(:,2);
    EulerWalkingTable.([seg '_Roll_deg']) = eulWalk(:,3);

    %% PLOT WALKING EULER
    fig = figure('Visible','off');
    plot(EulerWalkingTable.Time_s, eulWalk(:,1)); hold on;
    plot(EulerWalkingTable.Time_s, eulWalk(:,2));
    plot(EulerWalkingTable.Time_s, eulWalk(:,3)); hold off;

    title(['Euler angles during walking MagON: ', seg], 'Interpreter','none');
    xlabel('Walking time (s)');
    ylabel('Angle (deg)');
    legend('Yaw','Pitch','Roll');

    saveas(fig, fullfile(plotFolder, [seg '_Euler_Walking_MagON.png']));
    close(fig);

end

%% SAVE CSV FILES
writetable(QuatFullTable, fullfile(orientationFolder, 'Segment_Quaternions_Full_MagON.csv'));
writetable(QuatStaticTable, fullfile(orientationFolder, 'Segment_Quaternions_Static_MagON.csv'));
writetable(QuatWalkingTable, fullfile(orientationFolder, 'Segment_Quaternions_Walking_MagON.csv'));
writetable(EulerWalkingTable, fullfile(orientationFolder, 'EulerAngles_Walking_MagON.csv'));

%% WRITE RAJAGOPAL OPENSENSE STO FILES
staticSTO = fullfile(orientationFolder, 'Rajagopal_Orientations_Static_MagON.sto');
walkingSTO = fullfile(orientationFolder, 'Rajagopal_Orientations_Walking_MagON.sto');

write_opensim_quaternion_sto_rajagopal(QuatStaticTable, staticSTO, '4.5');
write_opensim_quaternion_sto_rajagopal(QuatWalkingTable, walkingSTO, '4.5');

%% SAVE MAT
save(fullfile(orientationFolder, 'Orientation_Results_MagON.mat'), ...
    'QuatFullTable', ...
    'QuatStaticTable', ...
    'QuatWalkingTable', ...
    'EulerWalkingTable', ...
    'segments', ...
    'fs_sync', ...
    'static_start_s', ...
    'static_end_s', ...
    'walk_start_s', ...
    'walk_end_s');

fprintf('\nMagON orientation estimation complete.\n');
fprintf('Static STO:\n%s\n', staticSTO);
fprintf('Walking STO:\n%s\n', walkingSTO);