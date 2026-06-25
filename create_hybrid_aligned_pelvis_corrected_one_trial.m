clear; clc; close all;

%% SELECT SYNC RESULT FOLDER
syncFolder = uigetdir(pwd, 'Select SYNC_Results_TimestampBased folder');

if isequal(syncFolder, 0)
    error('No folder selected.');
end

%% Handle accidental folder selections
syncMatFile = fullfile(syncFolder, 'Synchronized_IMU_Data.mat');

if ~isfile(syncMatFile)
    possibleSyncFolder = fullfile(syncFolder, 'SYNC_Results_TimestampBased');
    possibleSyncMatFile = fullfile(possibleSyncFolder, 'Synchronized_IMU_Data.mat');

    if isfile(possibleSyncMatFile)
        syncFolder = possibleSyncFolder;
        syncMatFile = possibleSyncMatFile;
    end
end

if ~isfile(syncMatFile)
    [parentFolder, selectedFolderName] = fileparts(syncFolder);

    if startsWith(selectedFolderName, 'Orientation_Results')
        possibleSyncFolder = parentFolder;
        possibleSyncMatFile = fullfile(possibleSyncFolder, 'Synchronized_IMU_Data.mat');

        if isfile(possibleSyncMatFile)
            syncFolder = possibleSyncFolder;
            syncMatFile = possibleSyncMatFile;
        end
    end
end

if ~isfile(syncMatFile)
    error('Synchronized_IMU_Data.mat not found.');
end

%% USER TEST SETTINGS
% We are testing correction applied only to LowerBack / pelvis_imu.
% Start with Z because the visible side/heading lean may respond there.
% If Z does not help, test X and Y.

correctionAxis = 'z';      % try 'z' first, then 'x', then 'y'
correctionAngleDeg = -30;  % try -20, -30, -40, then positive if worse

correctionLabel = sprintf('%s_%s%d', ...
    upper(correctionAxis), ...
    ternary(correctionAngleDeg < 0, 'm', 'p'), ...
    abs(round(correctionAngleDeg)));

fprintf('\nPelvis correction test: axis %s, angle %.1f deg\n', ...
    correctionAxis, correctionAngleDeg);

%% Required folders
magONFolder = fullfile(syncFolder, 'Orientation_Results_MagON');
magOFFFolder = fullfile(syncFolder, 'Orientation_Results_MagOFF');

if ~isfolder(magONFolder)
    error('Orientation_Results_MagON folder not found. Run MagON orientation first.');
end

if ~isfolder(magOFFFolder)
    error('Orientation_Results_MagOFF folder not found. Run MagOFF orientation first.');
end

%% Input files
magONStaticFile = fullfile(magONFolder, 'Segment_Quaternions_Static_MagON.csv');
magONWalkingFile = fullfile(magONFolder, 'Segment_Quaternions_Walking_MagON.csv');

magOFFStaticFile = fullfile(magOFFFolder, 'Segment_Quaternions_Static_MagOFF.csv');
magOFFWalkingFile = fullfile(magOFFFolder, 'Segment_Quaternions_Walking_MagOFF.csv');

if ~isfile(magONStaticFile), error('Missing MagON static quaternion file.'); end
if ~isfile(magONWalkingFile), error('Missing MagON walking quaternion file.'); end
if ~isfile(magOFFStaticFile), error('Missing MagOFF static quaternion file.'); end
if ~isfile(magOFFWalkingFile), error('Missing MagOFF walking quaternion file.'); end

%% Read files
MagON_Static = readtable(magONStaticFile);
MagON_Walking = readtable(magONWalkingFile);

MagOFF_Static = readtable(magOFFStaticFile);
MagOFF_Walking = readtable(magOFFWalkingFile);

%% Output folder
hybridFolder = fullfile(syncFolder, ...
    ['Orientation_Results_HybridAligned_PelvisCorr_' correctionLabel]);

if ~exist(hybridFolder, 'dir')
    mkdir(hybridFolder);
end

plotFolder = fullfile(hybridFolder, 'Euler_Plots');

if ~exist(plotFolder, 'dir')
    mkdir(plotFolder);
end

%% Segments
pelvisSegment = "LowerBack";

segments = ["LowerBack", ...
            "RightThigh", "RightShank", "RightFoot", ...
            "LeftThigh", "LeftShank", "LeftFoot"];

%% Pelvis correction quaternion
qPelvisExtra = axis_angle_to_quat_scalar_first(correctionAxis, correctionAngleDeg);

fprintf('Pelvis correction quaternion: [%.5f %.5f %.5f %.5f]\n', ...
    qPelvisExtra(1), qPelvisExtra(2), qPelvisExtra(3), qPelvisExtra(4));

%% Initialize output tables
Hybrid_Static = table();
Hybrid_Static.Time_s = 0;

Hybrid_Walking = table();
Hybrid_Walking.Time_s = MagOFF_Walking.Time_s;

Hybrid_Euler = table();
Hybrid_Euler.Time_s = MagOFF_Walking.Time_s;

CorrectionTable = table();

%% Build corrected HybridAligned orientations
for s = 1:length(segments)

    seg = char(segments(s));

    fprintf('\nProcessing %s...\n', seg);

    requiredCols = { ...
        [seg '_q0'], ...
        [seg '_q1'], ...
        [seg '_q2'], ...
        [seg '_q3']};

    for c = 1:length(requiredCols)

        if ~ismember(requiredCols{c}, MagON_Static.Properties.VariableNames)
            error('Missing column in MagON static: %s', requiredCols{c});
        end

        if ~ismember(requiredCols{c}, MagON_Walking.Properties.VariableNames)
            error('Missing column in MagON walking: %s', requiredCols{c});
        end

        if ~ismember(requiredCols{c}, MagOFF_Static.Properties.VariableNames)
            error('Missing column in MagOFF static: %s', requiredCols{c});
        end

        if ~ismember(requiredCols{c}, MagOFF_Walking.Properties.VariableNames)
            error('Missing column in MagOFF walking: %s', requiredCols{c});
        end
    end

    %% Get quaternions
    qON_static = [ ...
        MagON_Static.([seg '_q0'])(1), ...
        MagON_Static.([seg '_q1'])(1), ...
        MagON_Static.([seg '_q2'])(1), ...
        MagON_Static.([seg '_q3'])(1)];

    qOFF_static = [ ...
        MagOFF_Static.([seg '_q0'])(1), ...
        MagOFF_Static.([seg '_q1'])(1), ...
        MagOFF_Static.([seg '_q2'])(1), ...
        MagOFF_Static.([seg '_q3'])(1)];

    qON_walk = [ ...
        MagON_Walking.([seg '_q0']), ...
        MagON_Walking.([seg '_q1']), ...
        MagON_Walking.([seg '_q2']), ...
        MagON_Walking.([seg '_q3'])];

    qOFF_walk = [ ...
        MagOFF_Walking.([seg '_q0']), ...
        MagOFF_Walking.([seg '_q1']), ...
        MagOFF_Walking.([seg '_q2']), ...
        MagOFF_Walking.([seg '_q3'])];

    %% Normalize
    qON_static = qON_static ./ norm(qON_static);
    qOFF_static = qOFF_static ./ norm(qOFF_static);
    qON_walk = qON_walk ./ vecnorm(qON_walk, 2, 2);
    qOFF_walk = qOFF_walk ./ vecnorm(qOFF_walk, 2, 2);

    %% Hybrid rule
    if string(seg) == pelvisSegment

        % Original pelvis comes from MagON
        qHybrid_static_uncorrected = qON_static;
        qHybrid_walk_uncorrected = qON_walk;

        % Apply extra pelvis/root correction.
        % Pre-multiply means correction is applied in the global/world frame.
        qHybrid_static = quat_multiply_scalar_first(qPelvisExtra, qHybrid_static_uncorrected);
        qHybrid_walk = quat_multiply_scalar_first(qPelvisExtra, qHybrid_walk_uncorrected);

        fusionMode = "MagON_pelvis_with_manual_correction";

        qCorrection = qPelvisExtra;

    else

        % Lower limbs remain MagOFF aligned into MagON static frame
        qCorrection = quat_multiply_scalar_first( ...
            qON_static, ...
            quat_inverse_scalar_first(qOFF_static));

        qHybrid_static = quat_multiply_scalar_first(qCorrection, qOFF_static);
        qHybrid_walk = quat_multiply_scalar_first(qCorrection, qOFF_walk);

        fusionMode = "MagOFF_aligned_to_MagON_static";

    end

    %% Store static
    Hybrid_Static.([seg '_q0']) = qHybrid_static(1);
    Hybrid_Static.([seg '_q1']) = qHybrid_static(2);
    Hybrid_Static.([seg '_q2']) = qHybrid_static(3);
    Hybrid_Static.([seg '_q3']) = qHybrid_static(4);

    %% Store walking
    Hybrid_Walking.([seg '_q0']) = qHybrid_walk(:,1);
    Hybrid_Walking.([seg '_q1']) = qHybrid_walk(:,2);
    Hybrid_Walking.([seg '_q2']) = qHybrid_walk(:,3);
    Hybrid_Walking.([seg '_q3']) = qHybrid_walk(:,4);

    %% Euler for checking
    eul = quat_to_euler_zyx_degrees(qHybrid_walk);

    Hybrid_Euler.([seg '_Yaw_deg']) = eul(:,1);
    Hybrid_Euler.([seg '_Pitch_deg']) = eul(:,2);
    Hybrid_Euler.([seg '_Roll_deg']) = eul(:,3);

    %% Log correction
    newRow = table( ...
        string(seg), ...
        fusionMode, ...
        qCorrection(1), qCorrection(2), qCorrection(3), qCorrection(4), ...
        string(correctionAxis), ...
        correctionAngleDeg, ...
        'VariableNames', {'Segment','FusionMode','Correction_q0','Correction_q1','Correction_q2','Correction_q3','PelvisCorrectionAxis','PelvisCorrectionAngleDeg'});

    CorrectionTable = [CorrectionTable; newRow];

    %% Plot Euler
    fig = figure('Visible','off');

    plot(Hybrid_Euler.Time_s, eul(:,1)); hold on;
    plot(Hybrid_Euler.Time_s, eul(:,2));
    plot(Hybrid_Euler.Time_s, eul(:,3)); hold off;

    title(['Hybrid aligned pelvis corrected Euler: ', seg], 'Interpreter','none');
    xlabel('Walking time (s)');
    ylabel('Angle (deg)');
    legend('Yaw','Pitch','Roll');

    saveas(fig, fullfile(plotFolder, [seg '_Euler_Walking_PelvisCorrected.png']));
    close(fig);

end

%% Save CSV files
writetable(Hybrid_Static, fullfile(hybridFolder, ...
    ['Segment_Quaternions_Static_HybridAligned_PelvisCorr_' correctionLabel '.csv']));

writetable(Hybrid_Walking, fullfile(hybridFolder, ...
    ['Segment_Quaternions_Walking_HybridAligned_PelvisCorr_' correctionLabel '.csv']));

writetable(Hybrid_Euler, fullfile(hybridFolder, ...
    ['EulerAngles_Walking_HybridAligned_PelvisCorr_' correctionLabel '.csv']));

writetable(CorrectionTable, fullfile(hybridFolder, ...
    ['HybridAligned_PelvisCorr_' correctionLabel '_Correction_Table.csv']));

%% Also save generic names for OpenSim scripts
writetable(Hybrid_Static, fullfile(hybridFolder, ...
    'Segment_Quaternions_Static_HybridAligned_PelvisCorrected.csv'));

writetable(Hybrid_Walking, fullfile(hybridFolder, ...
    'Segment_Quaternions_Walking_HybridAligned_PelvisCorrected.csv'));

%% Write Rajagopal OpenSense STO files
staticSTO = fullfile(hybridFolder, ...
    'Rajagopal_Orientations_Static_HybridAligned_PelvisCorrected.sto');

walkingSTO = fullfile(hybridFolder, ...
    'Rajagopal_Orientations_Walking_HybridAligned_PelvisCorrected.sto');

write_opensim_quaternion_sto_rajagopal(Hybrid_Static, staticSTO, '4.5');
write_opensim_quaternion_sto_rajagopal(Hybrid_Walking, walkingSTO, '4.5');

%% Save MAT
save(fullfile(hybridFolder, ...
    ['Orientation_Results_HybridAligned_PelvisCorr_' correctionLabel '.mat']), ...
    'Hybrid_Static', ...
    'Hybrid_Walking', ...
    'Hybrid_Euler', ...
    'CorrectionTable', ...
    'segments', ...
    'pelvisSegment', ...
    'correctionAxis', ...
    'correctionAngleDeg', ...
    'qPelvisExtra');

fprintf('\nPelvis-corrected HybridAligned export complete.\n');
fprintf('Folder:\n%s\n', hybridFolder);
fprintf('Static STO:\n%s\n', staticSTO);
fprintf('Walking STO:\n%s\n', walkingSTO);

%% Small local helper
function out = ternary(condition, a, b)
    if condition
        out = a;
    else
        out = b;
    end
end