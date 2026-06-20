clear; clc; close all;

%% SELECT SYNC RESULT FOLDER
syncFolder = uigetdir(pwd, 'Select SYNC_Results_TimestampBased folder');

if isequal(syncFolder, 0)
    error('No folder selected.');
end

syncMatFile = fullfile(syncFolder, 'Synchronized_IMU_Data.mat');

if ~isfile(syncMatFile)
    error('Synchronized_IMU_Data.mat not found in selected folder.');
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
fprintf('Walking window: %.3f s to %.3f s\n', walk_start_s, walk_end_s);

%% SETTINGS
useMagnetometer = true;   % true = acc + gyro + mag
                          % false = acc + gyro only

g = 9.80665;

%% OUTPUT FOLDER
orientationFolder = fullfile(syncFolder, 'Orientation_Results');

if ~exist(orientationFolder, 'dir')
    mkdir(orientationFolder);
end

plotFolder = fullfile(orientationFolder, 'Euler_Plots');

if ~exist(plotFolder, 'dir')
    mkdir(plotFolder);
end

%% CHECK IF AHRFILTER EXISTS
if exist('ahrsfilter', 'file') ~= 2
    error(['ahrsfilter not found. You need MATLAB Sensor Fusion and Tracking Toolbox ', ...
           'or we need to switch to Madgwick/Mahony code.']);
end

%% DETECT SEGMENTS FROM VARIABLE NAMES
vars = SyncTable.Properties.VariableNames;

gyroXVars = vars(contains(vars, '_GyroX_dps'));

segments = strings(length(gyroXVars), 1);

for i = 1:length(gyroXVars)
    segments(i) = string(erase(gyroXVars{i}, '_GyroX_dps'));
end

fprintf('\nSegments detected:\n');
disp(segments);

%% PREPARE OUTPUT TABLES
QuatTable_Full = table();
QuatTable_Full.Time_s = SyncTable.Time_s;

EulerTable_Full = table();
EulerTable_Full.Time_s = SyncTable.Time_s;

QuatTable_Walking = table();
QuatTable_Walking.Time_s = SyncTable_Walking.Time_s;

EulerTable_Walking = table();
EulerTable_Walking.Time_s = SyncTable_Walking.Time_s;

OrientationStruct = struct();

%% LOOP THROUGH SEGMENTS
for s = 1:length(segments)

    seg = char(segments(s));

    fprintf('\nEstimating orientation for %s...\n', seg);

    %% GET FULL TRIAL SIGNALS
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

    %% CONVERT UNITS FOR MATLAB AHRFILTER
    % acc: g -> m/s^2
    % gyro: deg/s -> rad/s
    % mag: mGauss -> microTesla
    acc_mps2 = acc_g * g;
    gyro_rads = deg2rad(gyro_dps);
    mag_uT = mag_mGauss * 0.1;

    %% REMOVE ROWS WITH NaN IF ANY
    valid = all(~isnan(acc_mps2), 2) & ...
            all(~isnan(gyro_rads), 2) & ...
            all(~isnan(mag_uT), 2);

    if sum(~valid) > 0
        warning('%s has %d NaN rows. Filling with nearest values.', seg, sum(~valid));

        acc_mps2 = fillmissing(acc_mps2, 'nearest');
        gyro_rads = fillmissing(gyro_rads, 'nearest');
        mag_uT = fillmissing(mag_uT, 'nearest');
    end

    %% CREATE FILTER
    fuse = ahrsfilter('SampleRate', fs_sync);

    %% ESTIMATE ORIENTATION
    if useMagnetometer
        q = fuse(acc_mps2, gyro_rads, mag_uT);
    else
        q = fuse(acc_mps2, gyro_rads);
    end

    %% CONVERT QUATERNION OBJECT TO NUMERIC
    qNum = compact(q);  % [q0 q1 q2 q3], scalar-first

    %% CONVERT TO EULER ANGLES FOR INSPECTION
    eul_deg = quat_to_euler_zyx_degrees(qNum);

    %% STORE FULL QUATERNIONS
    QuatTable_Full.([seg '_q0']) = qNum(:,1);
    QuatTable_Full.([seg '_q1']) = qNum(:,2);
    QuatTable_Full.([seg '_q2']) = qNum(:,3);
    QuatTable_Full.([seg '_q3']) = qNum(:,4);

    EulerTable_Full.([seg '_Yaw_deg'])   = eul_deg(:,1);
    EulerTable_Full.([seg '_Pitch_deg']) = eul_deg(:,2);
    EulerTable_Full.([seg '_Roll_deg'])  = eul_deg(:,3);

    %% EXTRACT WALKING PORTION FROM FULL ORIENTATION
    walking_idx = SyncTable.Time_s >= walk_start_s & SyncTable.Time_s <= walk_end_s;

    qWalk = qNum(walking_idx, :);
    eulWalk = eul_deg(walking_idx, :);

    % Match length with SyncTable_Walking if off by 1 sample
    nWalk = min(height(SyncTable_Walking), size(qWalk,1));

    qWalk = qWalk(1:nWalk, :);
    eulWalk = eulWalk(1:nWalk, :);

    if height(QuatTable_Walking) > nWalk
        QuatTable_Walking = QuatTable_Walking(1:nWalk, :);
        EulerTable_Walking = EulerTable_Walking(1:nWalk, :);
    end

    QuatTable_Walking.([seg '_q0']) = qWalk(:,1);
    QuatTable_Walking.([seg '_q1']) = qWalk(:,2);
    QuatTable_Walking.([seg '_q2']) = qWalk(:,3);
    QuatTable_Walking.([seg '_q3']) = qWalk(:,4);

    EulerTable_Walking.([seg '_Yaw_deg'])   = eulWalk(:,1);
    EulerTable_Walking.([seg '_Pitch_deg']) = eulWalk(:,2);
    EulerTable_Walking.([seg '_Roll_deg'])  = eulWalk(:,3);

    %% STORE STRUCT
    OrientationStruct.(seg).Quaternion_Full = qNum;
    OrientationStruct.(seg).EulerZYX_Full_deg = eul_deg;
    OrientationStruct.(seg).Quaternion_Walking = qWalk;
    OrientationStruct.(seg).EulerZYX_Walking_deg = eulWalk;

    %% PLOT EULER ANGLES
    fig = figure('Visible','off');

    plot(EulerTable_Walking.Time_s, eulWalk(:,1)); hold on;
    plot(EulerTable_Walking.Time_s, eulWalk(:,2));
    plot(EulerTable_Walking.Time_s, eulWalk(:,3)); hold off;

    title(['Euler angles during walking: ', seg], 'Interpreter','none');
    xlabel('Walking time (s)');
    ylabel('Angle (deg)');
    legend('Yaw','Pitch','Roll');

    saveas(fig, fullfile(plotFolder, [seg '_Euler_Walking.png']));
    close(fig);

end

%% SAVE RESULTS
quatFullCSV = fullfile(orientationFolder, 'Segment_Quaternions_Full.csv');
quatWalkingCSV = fullfile(orientationFolder, 'Segment_Quaternions_Walking.csv');

eulerFullCSV = fullfile(orientationFolder, 'EulerAngles_Full.csv');
eulerWalkingCSV = fullfile(orientationFolder, 'EulerAngles_Walking.csv');

orientationMAT = fullfile(orientationFolder, 'Orientation_Results.mat');

writetable(QuatTable_Full, quatFullCSV);
writetable(QuatTable_Walking, quatWalkingCSV);

writetable(EulerTable_Full, eulerFullCSV);
writetable(EulerTable_Walking, eulerWalkingCSV);

save(orientationMAT, ...
    'QuatTable_Full', ...
    'QuatTable_Walking', ...
    'EulerTable_Full', ...
    'EulerTable_Walking', ...
    'OrientationStruct', ...
    'segments', ...
    'fs_sync', ...
    'useMagnetometer');

fprintf('\nOrientation estimation complete.\n');
fprintf('Saved:\n');
fprintf('%s\n', quatWalkingCSV);
fprintf('%s\n', eulerWalkingCSV);
fprintf('%s\n', orientationMAT);