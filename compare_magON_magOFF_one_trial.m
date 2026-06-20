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
fprintf('Walking duration: %.3f s\n', SyncTable_Walking.Time_s(end));

%% SETTINGS
g = 9.80665;

%% OUTPUT FOLDER
compareFolder = fullfile(syncFolder, 'MagON_vs_MagOFF_Comparison');

if ~exist(compareFolder, 'dir')
    mkdir(compareFolder);
end

plotFolder = fullfile(compareFolder, 'Comparison_Plots');

if ~exist(plotFolder, 'dir')
    mkdir(plotFolder);
end

%% CHECK AHRFILTER
if exist('ahrsfilter', 'file') ~= 2
    error(['ahrsfilter not found. You need MATLAB Sensor Fusion and Tracking Toolbox ', ...
           'or we need to switch to Madgwick/Mahony code.']);
end

%% DETECT SEGMENTS
vars = SyncTable_Walking.Properties.VariableNames;
gyroXVars = vars(contains(vars, '_GyroX_dps'));

segments = strings(length(gyroXVars), 1);

for i = 1:length(gyroXVars)
    segments(i) = string(erase(gyroXVars{i}, '_GyroX_dps'));
end

fprintf('\nSegments detected:\n');
disp(segments);

%% OUTPUT SUMMARY TABLE
CompareSummary = table();

%% LOOP THROUGH SEGMENTS
for s = 1:length(segments)

    seg = char(segments(s));
    fprintf('\nComparing Mag ON vs OFF for %s...\n', seg);

    %% Extract walking signals
    acc_g = [ ...
        SyncTable_Walking.([seg '_AccX_g']), ...
        SyncTable_Walking.([seg '_AccY_g']), ...
        SyncTable_Walking.([seg '_AccZ_g'])];

    gyro_dps = [ ...
        SyncTable_Walking.([seg '_GyroX_dps']), ...
        SyncTable_Walking.([seg '_GyroY_dps']), ...
        SyncTable_Walking.([seg '_GyroZ_dps'])];

    mag_mGauss = [ ...
        SyncTable_Walking.([seg '_MagX_mGauss']), ...
        SyncTable_Walking.([seg '_MagY_mGauss']), ...
        SyncTable_Walking.([seg '_MagZ_mGauss'])];

    %% Convert units
    acc_mps2 = acc_g * g;
    gyro_rads = deg2rad(gyro_dps);
    mag_uT = mag_mGauss * 0.1;

    %% Fill missing values
    acc_mps2 = fillmissing(acc_mps2, 'nearest');
    gyro_rads = fillmissing(gyro_rads, 'nearest');
    mag_uT = fillmissing(mag_uT, 'nearest');

    %% Run filter with magnetometer ON
    fuseON = ahrsfilter('SampleRate', fs_sync);
    qON = fuseON(acc_mps2, gyro_rads, mag_uT);
    qON_num = compact(qON);
    eulON = quat_to_euler_zyx_degrees(qON_num);

%% Run filter with magnetometer OFF
% imufilter uses accelerometer + gyroscope only
if exist('imufilter', 'file') ~= 2
    error(['imufilter not found. You need MATLAB Sensor Fusion and Tracking Toolbox ', ...
           'for magnetometer-OFF comparison.']);
end

fuseOFF = imufilter('SampleRate', fs_sync);
qOFF = fuseOFF(acc_mps2, gyro_rads);

qOFF_num = compact(qOFF);
eulOFF = quat_to_euler_zyx_degrees(qOFF_num);

    %% Save numeric comparison table per segment
    SegmentCompare = table();
    SegmentCompare.Time_s = SyncTable_Walking.Time_s;

    SegmentCompare.Yaw_MagON_deg = eulON(:,1);
    SegmentCompare.Pitch_MagON_deg = eulON(:,2);
    SegmentCompare.Roll_MagON_deg = eulON(:,3);

    SegmentCompare.Yaw_MagOFF_deg = eulOFF(:,1);
    SegmentCompare.Pitch_MagOFF_deg = eulOFF(:,2);
    SegmentCompare.Roll_MagOFF_deg = eulOFF(:,3);

    writetable(SegmentCompare, fullfile(compareFolder, [seg '_Euler_MagON_vs_MagOFF.csv']));

    %% Metrics
    yawRangeON = range(eulON(:,1));
    yawRangeOFF = range(eulOFF(:,1));

    pitchRangeON = range(eulON(:,2));
    pitchRangeOFF = range(eulOFF(:,2));

    rollRangeON = range(eulON(:,3));
    rollRangeOFF = range(eulOFF(:,3));

    yawDriftON = eulON(end,1) - eulON(1,1);
    yawDriftOFF = eulOFF(end,1) - eulOFF(1,1);

    magNorm = sqrt(sum(mag_uT.^2, 2));
    magMean = mean(magNorm, 'omitnan');
    magStd = std(magNorm, 'omitnan');
    magCV = magStd / magMean;

    newRow = table( ...
        string(seg), ...
        yawRangeON, yawRangeOFF, ...
        yawDriftON, yawDriftOFF, ...
        pitchRangeON, pitchRangeOFF, ...
        rollRangeON, rollRangeOFF, ...
        magMean, magStd, magCV);

    CompareSummary = [CompareSummary; newRow];

    %% Plot yaw comparison
    fig = figure('Visible','off');

    plot(SyncTable_Walking.Time_s, eulON(:,1), 'LineWidth', 1.2); hold on;
    plot(SyncTable_Walking.Time_s, eulOFF(:,1), 'LineWidth', 1.2); hold off;

    title(['Yaw comparison: ', seg], 'Interpreter','none');
    xlabel('Walking time (s)');
    ylabel('Yaw angle (deg)');
    legend('Mag ON', 'Mag OFF');

    saveas(fig, fullfile(plotFolder, [seg '_Yaw_MagON_vs_MagOFF.png']));
    close(fig);

    %% Plot pitch comparison
    fig = figure('Visible','off');

    plot(SyncTable_Walking.Time_s, eulON(:,2), 'LineWidth', 1.2); hold on;
    plot(SyncTable_Walking.Time_s, eulOFF(:,2), 'LineWidth', 1.2); hold off;

    title(['Pitch comparison: ', seg], 'Interpreter','none');
    xlabel('Walking time (s)');
    ylabel('Pitch angle (deg)');
    legend('Mag ON', 'Mag OFF');

    saveas(fig, fullfile(plotFolder, [seg '_Pitch_MagON_vs_MagOFF.png']));
    close(fig);

    %% Plot roll comparison
    fig = figure('Visible','off');

    plot(SyncTable_Walking.Time_s, eulON(:,3), 'LineWidth', 1.2); hold on;
    plot(SyncTable_Walking.Time_s, eulOFF(:,3), 'LineWidth', 1.2); hold off;

    title(['Roll comparison: ', seg], 'Interpreter','none');
    xlabel('Walking time (s)');
    ylabel('Roll angle (deg)');
    legend('Mag ON', 'Mag OFF');

    saveas(fig, fullfile(plotFolder, [seg '_Roll_MagON_vs_MagOFF.png']));
    close(fig);

    %% Combined 3-angle comparison
    fig = figure('Visible','off');

    tiledlayout(3,1);

    nexttile;
    plot(SyncTable_Walking.Time_s, eulON(:,1)); hold on;
    plot(SyncTable_Walking.Time_s, eulOFF(:,1)); hold off;
    ylabel('Yaw');
    legend('Mag ON','Mag OFF');

    nexttile;
    plot(SyncTable_Walking.Time_s, eulON(:,2)); hold on;
    plot(SyncTable_Walking.Time_s, eulOFF(:,2)); hold off;
    ylabel('Pitch');

    nexttile;
    plot(SyncTable_Walking.Time_s, eulON(:,3)); hold on;
    plot(SyncTable_Walking.Time_s, eulOFF(:,3)); hold off;
    ylabel('Roll');
    xlabel('Walking time (s)');

    sgtitle(['Mag ON vs OFF: ', seg], 'Interpreter','none');

    saveas(fig, fullfile(plotFolder, [seg '_AllEuler_MagON_vs_MagOFF.png']));
    close(fig);

end

%% SAVE SUMMARY
CompareSummary.Properties.VariableNames = { ...
    'Segment', ...
    'YawRange_MagON_deg', ...
    'YawRange_MagOFF_deg', ...
    'YawDrift_MagON_deg', ...
    'YawDrift_MagOFF_deg', ...
    'PitchRange_MagON_deg', ...
    'PitchRange_MagOFF_deg', ...
    'RollRange_MagON_deg', ...
    'RollRange_MagOFF_deg', ...
    'MagNorm_Mean_uT', ...
    'MagNorm_STD_uT', ...
    'MagNorm_CV'};

summaryFile = fullfile(compareFolder, 'MagON_vs_MagOFF_Summary.csv');
writetable(CompareSummary, summaryFile);

fprintf('\nComparison complete.\n');
fprintf('Summary saved to:\n%s\n', summaryFile);
fprintf('Plots saved to:\n%s\n', plotFolder);