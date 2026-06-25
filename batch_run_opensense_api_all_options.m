clear; clc; close all;

%% IMPORT OPENSIM API
import org.opensim.modeling.*

%% USER SETTINGS
rootDir = uigetdir(pwd, 'Select ROOT folder containing participant folders');

if isequal(rootDir, 0)
    error('No root folder selected.');
end

% Change this to your actual Rajagopal OpenSense model path
modelFileName = 'C:\Users\USER\Documents\OpenSim\4.5\Code\Matlab\OpenSenseExample\Rajagopal_2015.osim';

if ~isfile(modelFileName)
    error('Model file not found:\n%s', modelFileName);
end

% Main + sensitivity options
optionsToRun = ["HybridAligned", "MagON", "MagOFF"];

% OpenSense settings
baseIMUName = 'pelvis_imu';
baseIMUHeading = 'y';

% Use the same rotation that worked in your GUI/API tests
sensor_to_opensim_rotations = Vec3(0, 0, 0);

visualizeCalibration = false;
visualizeTracking = false;

% IK weights
% Main idea: do not track pelvis during walking IK.
weights = struct();
weights.pelvis_imu  = 0;
weights.femur_r_imu = 1;
weights.tibia_r_imu = 1;
weights.calcn_r_imu = 1;
weights.femur_l_imu = 1;
weights.tibia_l_imu = 1;
weights.calcn_l_imu = 1;

%% LOG
batchLog = table();

logFolder = fullfile(rootDir, 'OPENSIM_API_Batch_Logs');

if ~exist(logFolder, 'dir')
    mkdir(logFolder);
end

%% FIND PARTICIPANTS
participants = dir(fullfile(rootDir, 'P*'));
participants = participants([participants.isdir]);

fprintf('\nParticipants found: %d\n', length(participants));

%% LOOP
for p = 1:length(participants)

    participantID = string(participants(p).name);
    participantPath = fullfile(rootDir, participants(p).name);

    trialFolders = dir(participantPath);
    trialFolders = trialFolders([trialFolders.isdir]);
    trialFolders = trialFolders(~ismember({trialFolders.name}, {'.','..'}));

    trialNames = {trialFolders.name};
    keepTrial = ~cellfun(@isempty, regexp(trialNames, '^T\d+W?$', 'once', 'ignorecase'));
    trialFolders = trialFolders(keepTrial);

    for tr = 1:length(trialFolders)

        trialName = string(trialFolders(tr).name);
        trialPath = fullfile(participantPath, trialFolders(tr).name);
        syncFolder = fullfile(trialPath, 'SYNC_Results_TimestampBased');

        for opt = 1:length(optionsToRun)

            optionName = optionsToRun(opt);

            fprintf('\n=====================================\n');
            fprintf('Running OpenSense: %s | %s | %s\n', ...
                participantID, trialName, optionName);
            fprintf('=====================================\n');

            try
                status = run_opensense_api_one_option_function( ...
                    syncFolder, ...
                    char(optionName), ...
                    modelFileName, ...
                    baseIMUName, ...
                    baseIMUHeading, ...
                    sensor_to_opensim_rotations, ...
                    weights, ...
                    visualizeCalibration, ...
                    visualizeTracking);

                newRow = table( ...
                    participantID, ...
                    trialName, ...
                    optionName, ...
                    true, ...
                    string(status.Message), ...
                    string(status.MOTFile), ...
                    'VariableNames', {'Participant','Trial','Option','Success','Message','MOTFile'});

                batchLog = [batchLog; newRow];

            catch ME

                warning('FAILED: %s | %s | %s | %s', ...
                    participantID, trialName, optionName, ME.message);

                newRow = table( ...
                    participantID, ...
                    trialName, ...
                    optionName, ...
                    false, ...
                    string(ME.message), ...
                    "", ...
                    'VariableNames', {'Participant','Trial','Option','Success','Message','MOTFile'});

                batchLog = [batchLog; newRow];

            end
        end
    end
end

%% SAVE LOG
logFile = fullfile(logFolder, 'Batch_OpenSense_API_Log.csv');
writetable(batchLog, logFile);

fprintf('\n=====================================\n');
fprintf('OPENSIM API BATCH COMPLETE\n');
fprintf('=====================================\n');
fprintf('Log saved:\n%s\n', logFile);
fprintf('Successful: %d\n', sum(batchLog.Success));
fprintf('Failed/skipped: %d\n', height(batchLog) - sum(batchLog.Success));