clear; clc; close all;

%% SELECT ROOT FOLDER
rootDir = uigetdir(pwd, 'Select ROOT folder containing participant folders');

if isequal(rootDir, 0)
    error('No root folder selected.');
end

%% OUTPUT LOG FOLDER
batchLogFolder = fullfile(rootDir, 'SYNC_Batch_Logs');

if ~exist(batchLogFolder, 'dir')
    mkdir(batchLogFolder);
end

%% FIND PARTICIPANT FOLDERS
participants = dir(fullfile(rootDir, 'P*'));
participants = participants([participants.isdir]);

fprintf('\nParticipants found:\n');
disp({participants.name}');

%% INITIALIZE LOG
SyncLog = table();

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

    % Keep only folders like T1, T2, T3, T1W, T2W, T3W
    trialNames = {trialFolders.name};
    keepTrial = ~cellfun(@isempty, regexp(trialNames, '^T\d+W?$', 'once', 'ignorecase'));
    trialFolders = trialFolders(keepTrial);

    for tr = 1:length(trialFolders)

        trialFolderName = string(trialFolders(tr).name);
        trialPath = fullfile(participantPath, trialFolders(tr).name);

        fprintf('\nProcessing %s | %s\n', char(participantID), char(trialFolderName));

        %% CHECK NUMBER OF SENSOR FILES
        txtFiles = dir(fullfile(trialPath, '*.txt'));
        nFiles = length(txtFiles);

        if nFiles ~= 7
            warning('Expected 7 sensor files, found %d. Trial will be skipped.', nFiles);

            newRow = table( ...
                participantID, ...
                trialFolderName, ...
                string(trialPath), ...
                nFiles, ...
                false, ...
                "Skipped: expected 7 sensor files", ...
                'VariableNames', {'Participant','TrialFolder','TrialPath','NumSensorFiles','Success','Message'});

            SyncLog = [SyncLog; newRow];
            continue;
        end

        %% RUN SYNCHRONIZATION
        try
            status = sync_one_trial_IMUs(trialPath);

            newRow = table( ...
                participantID, ...
                trialFolderName, ...
                string(trialPath), ...
                nFiles, ...
                logical(status.Success), ...
                string(status.Message), ...
                'VariableNames', {'Participant','TrialFolder','TrialPath','NumSensorFiles','Success','Message'});

            SyncLog = [SyncLog; newRow];

            fprintf('SUCCESS: %s | %s\n', char(participantID), char(trialFolderName));

        catch ME

            warning('FAILED: %s | %s | %s', char(participantID), char(trialFolderName), ME.message);

            newRow = table( ...
                participantID, ...
                trialFolderName, ...
                string(trialPath), ...
                nFiles, ...
                false, ...
                string(ME.message), ...
                'VariableNames', {'Participant','TrialFolder','TrialPath','NumSensorFiles','Success','Message'});

            SyncLog = [SyncLog; newRow];

        end

    end
end

%% SAVE BATCH LOG
logFile = fullfile(batchLogFolder, 'Batch_Synchronization_Log.csv');
writetable(SyncLog, logFile);

fprintf('\n=====================================\n');
fprintf('BATCH SYNCHRONIZATION COMPLETE\n');
fprintf('=====================================\n');

fprintf('\nLog saved to:\n%s\n', logFile);

%% SUMMARY
nTotal = height(SyncLog);
nSuccess = sum(SyncLog.Success);
nFailed = nTotal - nSuccess;

fprintf('\nTrials attempted: %d\n', nTotal);
fprintf('Successful: %d\n', nSuccess);
fprintf('Failed/skipped: %d\n', nFailed);