clear; clc; close all;

%% SELECT ROOT FOLDER
rootDir = uigetdir(pwd, 'Select ROOT folder containing participant folders');

if isequal(rootDir, 0)
    error('No root folder selected.');
end

%% LOG FOLDER
logFolder = fullfile(rootDir, 'MAGOFF_RAJAGOPAL_STO_Batch_Logs');

if ~exist(logFolder, 'dir')
    mkdir(logFolder);
end

BatchLog = table();

%% FIND PARTICIPANTS
participants = dir(fullfile(rootDir, 'P*'));
participants = participants([participants.isdir]);

fprintf('\nParticipants found: %d\n', length(participants));

%% LOOP THROUGH PARTICIPANTS
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
        magOffFolder = fullfile(syncFolder, 'Orientation_Results_MagOFF');

        fprintf('\nExporting MagOFF Rajagopal STO: %s | %s\n', ...
            participantID, trialName);

        try
            status = export_magoff_rajagopal_sto_one_trial_function(magOffFolder);

            newRow = table( ...
                participantID, ...
                trialName, ...
                string(magOffFolder), ...
                true, ...
                string(status.Message), ...
                'VariableNames', {'Participant','Trial','MagOFFFolder','Success','Message'});

            BatchLog = [BatchLog; newRow];

            fprintf('SUCCESS: %s | %s\n', participantID, trialName);

        catch ME

            warning('FAILED: %s | %s | %s', ...
                participantID, trialName, ME.message);

            newRow = table( ...
                participantID, ...
                trialName, ...
                string(magOffFolder), ...
                false, ...
                string(ME.message), ...
                'VariableNames', {'Participant','Trial','MagOFFFolder','Success','Message'});

            BatchLog = [BatchLog; newRow];

        end
    end
end

%% SAVE LOG
logFile = fullfile(logFolder, 'Batch_MagOFF_Rajagopal_STO_Log.csv');
writetable(BatchLog, logFile);

fprintf('\n=====================================\n');
fprintf('MAGOFF RAJAGOPAL STO EXPORT COMPLETE\n');
fprintf('=====================================\n');
fprintf('Log saved:\n%s\n', logFile);
fprintf('Successful: %d\n', sum(BatchLog.Success));
fprintf('Failed/skipped: %d\n', height(BatchLog) - sum(BatchLog.Success));