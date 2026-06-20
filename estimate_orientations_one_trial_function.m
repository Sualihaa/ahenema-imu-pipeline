function status = estimate_orientations_one_trial_function(syncFolder)

close all;

status = struct();
status.SyncFolder = string(syncFolder);
status.Success = false;
status.Message = "";

%% CHECK SYNC FILE
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

%% SETTINGS
useMagnetometer = false;   % IMPORTANT: Mag OFF
g = 9.80665;

%% OUTPUT FOLDER
orientationFolder = fullfile(syncFolder, 'Orientation_Results_MagOFF');

if ~exist(orientationFolder, 'dir')
    mkdir(orientationFolder);
end

plotFolder = fullfile(orientationFolder, 'Euler_Plots');

if ~exist(plotFolder, 'dir')
    mkdir(plotFolder);
end

%% CHECK FILTER
if exist('imufilter', 'file') ~= 2
    error(['imufilter not found. You need MATLAB Sensor Fusion and Tracking Toolbox ', ...
           'for accelerometer-gyroscope orientation estimation.']);
end

%% DETECT SEGMENTS
vars = SyncTable_Walking.Properties.VariableNames;
gyroXVars = vars(contains(vars, '_GyroX_dps'));

segments = strings(length(gyroXVars), 1);

for i = 1:length(gyroXVars)
    segments(i) = string(erase(gyroXVars{i}, '_GyroX_dps'));
end

if isempty(segments)
    error('No segment gyroscope columns found in SyncTable_Walking.');
end

%% PREPARE OUTPUT TABLES
QuatTable_Walking = table();
QuatTable_Walking.Time_s = SyncTable_Walking.Time_s;

EulerTable_Walking = table();
EulerTable_Walking.Time_s = SyncTable_Walking.Time_s;

OrientationStruct = struct();

%% LOOP THROUGH SEGMENTS
for s = 1:length(segments)

    seg = char(segments(s));

    fprintf('Estimating MagOFF orientation for %s...\n', seg);

    %% EXTRACT WALKING SIGNALS
    acc_g = [ ...
        SyncTable_Walking.([seg '_AccX_g']), ...
        SyncTable_Walking.([seg '_AccY_g']), ...
        SyncTable_Walking.([seg '_AccZ_g'])];

    gyro_dps = [ ...
        SyncTable_Walking.([seg '_GyroX_dps']), ...
        SyncTable_Walking.([seg '_GyroY_dps']), ...
        SyncTable_Walking.([seg '_GyroZ_dps'])];

    %% CONVERT UNITS
    acc_mps2 = acc_g * g;
    gyro_rads = deg2rad(gyro_dps);

    %% CLEAN MISSING VALUES
    acc_mps2 = fillmissing(acc_mps2, 'nearest');
    gyro_rads = fillmissing(gyro_rads, 'nearest');

    %% RUN IMU FILTER: ACC + GYRO ONLY
    fuse = imufilter('SampleRate', fs_sync);

    q = fuse(acc_mps2, gyro_rads);

    qNum = compact(q);  % [q0 q1 q2 q3]

    %% EULER ANGLES FOR INSPECTION
    eul_deg = quat_to_euler_zyx_degrees(qNum);

    %% STORE QUATERNIONS
    QuatTable_Walking.([seg '_q0']) = qNum(:,1);
    QuatTable_Walking.([seg '_q1']) = qNum(:,2);
    QuatTable_Walking.([seg '_q2']) = qNum(:,3);
    QuatTable_Walking.([seg '_q3']) = qNum(:,4);

    %% STORE EULER ANGLES
    EulerTable_Walking.([seg '_Yaw_deg'])   = eul_deg(:,1);
    EulerTable_Walking.([seg '_Pitch_deg']) = eul_deg(:,2);
    EulerTable_Walking.([seg '_Roll_deg'])  = eul_deg(:,3);

    %% STORE STRUCT
    OrientationStruct.(seg).Quaternion_Walking = qNum;
    OrientationStruct.(seg).EulerZYX_Walking_deg = eul_deg;

    %% PLOT EULER ANGLES
    fig = figure('Visible','off');

    plot(EulerTable_Walking.Time_s, eul_deg(:,1)); hold on;
    plot(EulerTable_Walking.Time_s, eul_deg(:,2));
    plot(EulerTable_Walking.Time_s, eul_deg(:,3)); hold off;

    title(['Euler angles during walking MagOFF: ', seg], 'Interpreter','none');
    xlabel('Walking time (s)');
    ylabel('Angle (deg)');
    legend('Yaw','Pitch','Roll');

    saveas(fig, fullfile(plotFolder, [seg '_Euler_Walking_MagOFF.png']));
    close(fig);

end

%% SAVE RESULTS
quatWalkingCSV = fullfile(orientationFolder, 'Segment_Quaternions_Walking_MagOFF.csv');
eulerWalkingCSV = fullfile(orientationFolder, 'EulerAngles_Walking_MagOFF.csv');
orientationMAT = fullfile(orientationFolder, 'Orientation_Results_MagOFF.mat');

writetable(QuatTable_Walking, quatWalkingCSV);
writetable(EulerTable_Walking, eulerWalkingCSV);

save(orientationMAT, ...
    'QuatTable_Walking', ...
    'EulerTable_Walking', ...
    'OrientationStruct', ...
    'segments', ...
    'fs_sync', ...
    'useMagnetometer', ...
    'walk_start_s', ...
    'walk_end_s');

status.Success = true;
status.Message = "Orientation estimation completed successfully.";
status.NumSegments = length(segments);
status.Duration_s = SyncTable_Walking.Time_s(end);

end