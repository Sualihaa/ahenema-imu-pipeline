clear; clc; close all;

%% SELECT SYNC FOLDER
syncFolder = uigetdir(pwd, 'Select SYNC_Results_TimestampBased folder');

if isequal(syncFolder, 0)
    error('No folder selected.');
end

%% SETTINGS
optionName = "HybridAligned";
nNorm = 101;
percent = linspace(0, 100, nNorm)';

%% FILE PATHS
syncMatFile = fullfile(syncFolder, 'Synchronized_IMU_Data.mat');

kneeAnkleFile = fullfile(syncFolder, ...
    'Orientation_Results_HybridAligned', ...
    'OpenSim_Results_API', ...
    'Knee_Ankle_Plots', ...
    'Extracted_Knee_Ankle_HybridAligned.csv');

if ~isfile(syncMatFile)
    error('Synchronized_IMU_Data.mat not found:\n%s', syncMatFile);
end

if ~isfile(kneeAnkleFile)
    error('Extracted knee/ankle file not found:\n%s', kneeAnkleFile);
end

%% LOAD DATA
load(syncMatFile, 'SyncTable', 'fs_sync', 'walk_start_s', 'walk_end_s');

K = readtable(kneeAnkleFile);

fprintf('\nWalking window: %.3f to %.3f s\n', walk_start_s, walk_end_s);
fprintf('Sampling rate: %.2f Hz\n', fs_sync);

%% GET TIME VECTOR
timeSync = get_sync_time_vector(SyncTable, fs_sync);

%% DETECT RIGHT AND LEFT FOOT EVENTS
rightEvents = detect_foot_contacts_from_synctable( ...
    SyncTable, timeSync, fs_sync, walk_start_s, walk_end_s, "RightFoot", true);

leftEvents = detect_foot_contacts_from_synctable( ...
    SyncTable, timeSync, fs_sync, walk_start_s, walk_end_s, "LeftFoot", true);

fprintf('\nRight foot contacts detected: %d\n', height(rightEvents));
fprintf('Left foot contacts detected: %d\n', height(leftEvents));

%% OUTPUT FOLDER
outFolder = fullfile(syncFolder, ...
    'Orientation_Results_HybridAligned', ...
    'OpenSim_Results_API', ...
    'SideSpecific_GaitCycles');

if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

%% SAVE FOOT EVENTS
writetable(rightEvents, fullfile(outFolder, 'RightFoot_Contacts.csv'));
writetable(leftEvents,  fullfile(outFolder, 'LeftFoot_Contacts.csv'));

%% ALIGN CONTACT TIMES TO KNEE/ANKLE CSV TIME BASE
% Foot events are detected in full synchronized-trial time.
% The extracted knee/ankle CSV is usually walking-only and starts near 0 s.
% Therefore, subtract walk_start_s.

rightContactTimes_forIK = rightEvents.ContactTime_s - walk_start_s;
leftContactTimes_forIK  = leftEvents.ContactTime_s  - walk_start_s;

% Keep only contacts that fall inside the knee/ankle time range
rightContactTimes_forIK = rightContactTimes_forIK( ...
    rightContactTimes_forIK >= min(K.time) & rightContactTimes_forIK <= max(K.time));

leftContactTimes_forIK = leftContactTimes_forIK( ...
    leftContactTimes_forIK >= min(K.time) & leftContactTimes_forIK <= max(K.time));

fprintf('\nRight contacts after time alignment: %d\n', length(rightContactTimes_forIK));
fprintf('Left contacts after time alignment: %d\n', length(leftContactTimes_forIK));

%% SEGMENT RIGHT SIDE USING RIGHT FOOT CONTACTS
RightCyclesLong = segment_side_kinematics_from_contacts( ...
    K, rightContactTimes_forIK, ...
    "Right", ...
    ["knee_angle_r", "ankle_angle_r"], ...
    nNorm);

%% SEGMENT LEFT SIDE USING LEFT FOOT CONTACTS
LeftCyclesLong = segment_side_kinematics_from_contacts( ...
    K, leftContactTimes_forIK, ...
    "Left", ...
    ["knee_angle_l", "ankle_angle_l"], ...
    nNorm);
%% COMBINE
AllCyclesLong = [RightCyclesLong; LeftCyclesLong];

if isempty(AllCyclesLong)
    error('No valid side-specific gait cycles were created.');
end

%% SAVE ALL CYCLES LONG FORMAT
allCycleFile = fullfile(outFolder, ...
    ['SideSpecific_GaitCycles_Long_' char(optionName) '.csv']);

writetable(AllCyclesLong, allCycleFile);

fprintf('\nSaved all side-specific cycles:\n%s\n', allCycleFile);

%% CREATE MEAN TRIAL CURVES
MeanTrial = make_mean_side_specific_cycle_table(AllCyclesLong, nNorm);

meanFile = fullfile(outFolder, ...
    ['SideSpecific_MeanTrial_' char(optionName) '.csv']);

writetable(MeanTrial, meanFile);

fprintf('Saved mean trial cycle:\n%s\n', meanFile);

%% PLOT INDIVIDUAL TRIAL
plot_side_specific_trial_cycles(AllCyclesLong, MeanTrial, outFolder, optionName);

fprintf('\nDone.\n');