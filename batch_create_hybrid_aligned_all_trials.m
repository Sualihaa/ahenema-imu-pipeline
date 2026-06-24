clear; clc; close all;

%% SELECT ROOT FOLDER
rootDir = uigetdir(pwd, 'Select ROOT folder containing participant folders');

if isequal(rootDir, 0)
    error('No root folder selected.');
end

%% LOG FOLDER
logFolder = fullfile(rootDir, 'HYBRID_ALIGNED_Batch_Logs');

if ~exist(logFolder, 'dir')
    mkdir(logFolder);
end

HybridLog = table();

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

    trialFolders = dir(participantPath);
    trialFolders = trialFolders([trialFolders.isdir]);
    trialFolders = trialFolders(~ismember({trialFolders.name}, {'.','..'}));

    trialNames = {trialFolders.name};
    keepTrial = ~cellfun(@isempty, regexp(trialNames, '^T\d+W?$', 'once', 'ignorecase'));
    trialFolders = trialFolders(keepTrial);

    for tr = 1:length(trialFolders)

        trialFolderName = string(trialFolders(tr).name);
        trialPath = fullfile(participantPath, trialFolders(tr).name);
        syncFolder = fullfile(trialPath, 'SYNC_Results_TimestampBased');

        fprintf('\nCreating HybridAligned: %s | %s\n', ...
            char(participantID), char(trialFolderName));

        try
            status = create_hybrid_aligned_one_trial_function(syncFolder);

            newRow = table( ...
                participantID, ...
                trialFolderName, ...
                string(syncFolder), ...
                true, ...
                string(status.Message), ...
                'VariableNames', {'Participant','TrialFolder','SyncFolder','Success','Message'});

            HybridLog = [HybridLog; newRow];

            fprintf('SUCCESS: %s | %s\n', char(participantID), char(trialFolderName));

        catch ME

            warning('FAILED: %s | %s | %s', ...
                char(participantID), char(trialFolderName), ME.message);

            newRow = table( ...
                participantID, ...
                trialFolderName, ...
                string(syncFolder), ...
                false, ...
                string(ME.message), ...
                'VariableNames', {'Participant','TrialFolder','SyncFolder','Success','Message'});

            HybridLog = [HybridLog; newRow];

        end
    end
end

%% SAVE LOG
logFile = fullfile(logFolder, 'Batch_HybridAligned_Log.csv');
writetable(HybridLog, logFile);

fprintf('\n=====================================\n');
fprintf('BATCH HYBRIDALIGNED COMPLETE\n');
fprintf('=====================================\n');

fprintf('\nLog saved to:\n%s\n', logFile);
fprintf('Successful: %d\n', sum(HybridLog.Success));
fprintf('Failed/skipped: %d\n', height(HybridLog) - sum(HybridLog.Success));