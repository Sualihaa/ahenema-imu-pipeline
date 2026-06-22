clear; clc; close all;

%% SELECT ROOT FOLDER
rootDir = uigetdir(pwd, 'Select ROOT folder containing participant folders');

if isequal(rootDir, 0)
    error('No root folder selected.');
end

%% LOG FOLDER
logFolder = fullfile(rootDir, 'OPENSIM_STO_Batch_Logs');

if ~exist(logFolder, 'dir')
    mkdir(logFolder);
end

ExportLog = table();

%% FIND PARTICIPANTS
participants = dir(fullfile(rootDir, 'P*'));
participants = participants([participants.isdir]);

fprintf('\nParticipants found:\n');
disp({participants.name}');

%% LOOP THROUGH PARTICIPANTS
for p = 1:length(participants)

    participantID = string(participants(p).name);
    participantPath = fullfile(rootDir, participants(p).name);

    fprintf('\n=====================================\n');
    fprintf('PARTICIPANT %s\n', char(participantID));
    fprintf('=====================================\n');

    %% FIND TRIAL FOLDERS
    trialFolders = dir(participantPath);
    trialFolders = trialFolders([trialFolders.isdir]);
    trialFolders = trialFolders(~ismember({trialFolders.name}, {'.','..'}));

    trialNames = {trialFolders.name};

    % Keep T1, T2, T3, T1W, T2W, T3W
    keepTrial = ~cellfun(@isempty, regexp(trialNames, '^T\d+W?$', 'once', 'ignorecase'));
    trialFolders = trialFolders(keepTrial);

    for tr = 1:length(trialFolders)

        trialFolderName = string(trialFolders(tr).name);

        orientationFolder = fullfile( ...
            participantPath, ...
            trialFolders(tr).name, ...
            'SYNC_Results_TimestampBased', ...
            'Orientation_Results_MagOFF');

        quatFile = fullfile(orientationFolder, 'Segment_Quaternions_Walking_MagOFF.csv');
        outputFile = fullfile(orientationFolder, 'OpenSim_Orientations_Walking_MagOFF.sto');

        fprintf('\nExporting %s | %s\n', char(participantID), char(trialFolderName));

        %% CHECK INPUT FILE
        if ~isfile(quatFile)

            warning('Quaternion file not found. Skipping.');

            newRow = table( ...
                participantID, ...
                trialFolderName, ...
                string(orientationFolder), ...
                false, ...
                "Skipped: quaternion file not found", ...
                'VariableNames', { ...
                    'Participant', ...
                    'TrialFolder', ...
                    'OrientationFolder', ...
                    'Success', ...
                    'Message'});

            ExportLog = [ExportLog; newRow];
            continue;
        end

        %% EXPORT
        try
            QuatTable = readtable(quatFile);

            write_opensim_quaternion_sto( ...
                QuatTable, ...
                outputFile, ...
                '4.5');

            newRow = table( ...
                participantID, ...
                trialFolderName, ...
                string(orientationFolder), ...
                true, ...
                "Exported successfully", ...
                'VariableNames', { ...
                    'Participant', ...
                    'TrialFolder', ...
                    'OrientationFolder', ...
                    'Success', ...
                    'Message'});

            ExportLog = [ExportLog; newRow];

            fprintf('SUCCESS: %s | %s\n', char(participantID), char(trialFolderName));

        catch ME

            warning('FAILED: %s | %s | %s', ...
                char(participantID), char(trialFolderName), ME.message);

            newRow = table( ...
                participantID, ...
                trialFolderName, ...
                string(orientationFolder), ...
                false, ...
                string(ME.message), ...
                'VariableNames', { ...
                    'Participant', ...
                    'TrialFolder', ...
                    'OrientationFolder', ...
                    'Success', ...
                    'Message'});

            ExportLog = [ExportLog; newRow];

        end
    end
end

%% SAVE LOG
logFile = fullfile(logFolder, 'Batch_OpenSim_STO_Export_Log.csv');
writetable(ExportLog, logFile);

fprintf('\n=====================================\n');
fprintf('BATCH OPENSIM STO EXPORT COMPLETE\n');
fprintf('=====================================\n');

fprintf('\nLog saved to:\n%s\n', logFile);

fprintf('\nTrials attempted: %d\n', height(ExportLog));
fprintf('Successful exports: %d\n', sum(ExportLog.Success));
fprintf('Failed/skipped: %d\n', height(ExportLog) - sum(ExportLog.Success));