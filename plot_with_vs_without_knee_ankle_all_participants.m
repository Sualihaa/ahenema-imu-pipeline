clear; clc; close all;

%% SELECT ROOT
rootDir = uigetdir(pwd, 'Select ROOT folder containing participant folders');

if isequal(rootDir, 0)
    error('No root folder selected.');
end

%% SETTINGS
optionName = "HybridAligned";   % change to "MagON" if needed later
nNorm = 101;                    % normalize each trial to 0–100%

participants = dir(fullfile(rootDir, 'P*'));
participants = participants([participants.isdir]);

MasterLog = table();

for p = 1:length(participants)

    participantID = string(participants(p).name);
    participantPath = fullfile(rootDir, participants(p).name);

    fprintf('\n=====================================\n');
    fprintf('Participant: %s\n', participantID);
    fprintf('=====================================\n');

    try
        status = plot_one_participant_with_vs_without( ...
            participantPath, char(participantID), char(optionName), nNorm);

        newRow = table( ...
            participantID, ...
            optionName, ...
            true, ...
            string(status.Message), ...
            'VariableNames', {'Participant','Option','Success','Message'});

        MasterLog = [MasterLog; newRow];

    catch ME

        warning('Failed for %s: %s', participantID, ME.message);

        newRow = table( ...
            participantID, ...
            optionName, ...
            false, ...
            string(ME.message), ...
            'VariableNames', {'Participant','Option','Success','Message'});

        MasterLog = [MasterLog; newRow];
    end
end

%% SAVE LOG
outFolder = fullfile(rootDir, 'WITH_vs_WITHOUT_KneeAnkle_Plots');

if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

logFile = fullfile(outFolder, 'Batch_WithVsWithout_Plot_Log.csv');
writetable(MasterLog, logFile);

fprintf('\n=====================================\n');
fprintf('WITH vs WITHOUT PLOTTING COMPLETE\n');
fprintf('=====================================\n');
fprintf('Log saved to:\n%s\n', logFile);
fprintf('Successful: %d\n', sum(MasterLog.Success));
fprintf('Failed: %d\n', height(MasterLog) - sum(MasterLog.Success));