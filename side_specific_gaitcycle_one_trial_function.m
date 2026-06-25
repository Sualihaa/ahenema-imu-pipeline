function [AllCyclesLong, MeanTrial, message] = side_specific_gaitcycle_one_trial_function( ...
    syncFolder, participantID, trialName, condition, optionName, nNorm)

%% CHECK FILES
syncMatFile = fullfile(syncFolder, 'Synchronized_IMU_Data.mat');

if ~isfile(syncMatFile)
    error('Synchronized_IMU_Data.mat not found.');
end

switch optionName
    case "HybridAligned"
        kneeAnkleFile = fullfile(syncFolder, ...
            'Orientation_Results_HybridAligned', ...
            'OpenSim_Results_API', ...
            'Knee_Ankle_Plots', ...
            'Extracted_Knee_Ankle_HybridAligned.csv');
    otherwise
        error('This function is currently prepared for HybridAligned only.');
end

if ~isfile(kneeAnkleFile)
    error('Extracted knee/ankle CSV not found.');
end

%% LOAD
load(syncMatFile, 'SyncTable', 'fs_sync', 'walk_start_s', 'walk_end_s');

K = readtable(kneeAnkleFile);

timeSync = get_sync_time_vector(SyncTable, fs_sync);

%% DETECT FOOT CONTACTS
rightEvents = detect_foot_contacts_from_synctable( ...
    SyncTable, timeSync, fs_sync, walk_start_s, walk_end_s, "RightFoot", false);

leftEvents = detect_foot_contacts_from_synctable( ...
    SyncTable, timeSync, fs_sync, walk_start_s, walk_end_s, "LeftFoot", false);

%% OUTPUT FOLDER
outFolder = fullfile(syncFolder, ...
    'Orientation_Results_HybridAligned', ...
    'OpenSim_Results_API', ...
    'SideSpecific_GaitCycles');

if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

writetable(rightEvents, fullfile(outFolder, 'RightFoot_Contacts.csv'));
writetable(leftEvents,  fullfile(outFolder, 'LeftFoot_Contacts.csv'));

%% ALIGN CONTACT TIMES TO KNEE/ANKLE TIME BASE
rightContactTimes_forIK = rightEvents.ContactTime_s - walk_start_s;
leftContactTimes_forIK  = leftEvents.ContactTime_s  - walk_start_s;

rightContactTimes_forIK = rightContactTimes_forIK( ...
    rightContactTimes_forIK >= min(K.time) & rightContactTimes_forIK <= max(K.time));

leftContactTimes_forIK = leftContactTimes_forIK( ...
    leftContactTimes_forIK >= min(K.time) & leftContactTimes_forIK <= max(K.time));

if length(rightContactTimes_forIK) < 2 && length(leftContactTimes_forIK) < 2
    error('Not enough aligned foot contacts for either side.');
end

%% SEGMENT RIGHT SIDE
RightCyclesLong = segment_side_kinematics_from_contacts( ...
    K, rightContactTimes_forIK, ...
    "Right", ...
    ["knee_angle_r", "ankle_angle_r"], ...
    nNorm);

%% SEGMENT LEFT SIDE
LeftCyclesLong = segment_side_kinematics_from_contacts( ...
    K, leftContactTimes_forIK, ...
    "Left", ...
    ["knee_angle_l", "ankle_angle_l"], ...
    nNorm);

AllCyclesLong = [RightCyclesLong; LeftCyclesLong];

if isempty(AllCyclesLong)
    error('No valid gait cycles were created.');
end

%% ADD METADATA
AllCyclesLong.Participant = repmat(string(participantID), height(AllCyclesLong), 1);
AllCyclesLong.Trial = repmat(string(trialName), height(AllCyclesLong), 1);
AllCyclesLong.Condition = repmat(string(condition), height(AllCyclesLong), 1);
AllCyclesLong.Option = repmat(string(optionName), height(AllCyclesLong), 1);

% Reorder columns
AllCyclesLong = movevars(AllCyclesLong, ...
    {'Participant','Trial','Condition','Option'}, ...
    'Before', 1);

%% SAVE TRIAL-LEVEL CSV
allCycleFile = fullfile(outFolder, ...
    ['SideSpecific_GaitCycles_Long_' char(optionName) '.csv']);

writetable(AllCyclesLong, allCycleFile);

%% MEAN TRIAL TABLE
MeanTrial = make_mean_side_specific_cycle_table(AllCyclesLong, nNorm);

MeanTrial.Participant = repmat(string(participantID), height(MeanTrial), 1);
MeanTrial.Trial = repmat(string(trialName), height(MeanTrial), 1);
MeanTrial.Condition = repmat(string(condition), height(MeanTrial), 1);
MeanTrial.Option = repmat(string(optionName), height(MeanTrial), 1);

MeanTrial = movevars(MeanTrial, ...
    {'Participant','Trial','Condition','Option'}, ...
    'Before', 1);

meanFile = fullfile(outFolder, ...
    ['SideSpecific_MeanTrial_' char(optionName) '.csv']);

writetable(MeanTrial, meanFile);

%% TRIAL-LEVEL PLOT
plot_side_specific_trial_cycles(AllCyclesLong, MeanTrial, outFolder, optionName);

message = sprintf('Right contacts=%d, Left contacts=%d, cycles saved.', ...
    length(rightContactTimes_forIK), length(leftContactTimes_forIK));

end