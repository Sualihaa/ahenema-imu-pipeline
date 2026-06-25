clear; clc; close all;

%% SELECT ROOT
rootDir = uigetdir(pwd, 'Select ROOT folder containing participant folders');

if isequal(rootDir, 0)
    error('No root folder selected.');
end

%% SETTINGS
optionName = "HybridAligned";
nNorm = 101;

participants = dir(fullfile(rootDir, 'P*'));
participants = participants([participants.isdir]);

masterCycleTable = table();
masterTrialMeanTable = table();
logTable = table();

%% LOOP PARTICIPANTS
for p = 1:length(participants)

    participantID = string(participants(p).name);
    participantPath = fullfile(rootDir, participants(p).name);

    fprintf('\n=====================================\n');
    fprintf('Participant: %s\n', participantID);
    fprintf('=====================================\n');

    trialFolders = dir(participantPath);
    trialFolders = trialFolders([trialFolders.isdir]);
    trialFolders = trialFolders(~ismember({trialFolders.name}, {'.','..'}));

    trialNames = {trialFolders.name};
    keepTrial = ~cellfun(@isempty, regexp(trialNames, '^T\d+W?$', 'once', 'ignorecase'));
    trialFolders = trialFolders(keepTrial);

    participantCycleTable = table();
    participantTrialMeanTable = table();

    for tr = 1:length(trialFolders)

        trialName = string(trialFolders(tr).name);
        trialPath = fullfile(participantPath, trialFolders(tr).name);
        condition = trial_to_condition(trialName);

        syncFolder = fullfile(trialPath, 'SYNC_Results_TimestampBased');

        fprintf('\n%s | %s | %s\n', participantID, trialName, condition);

        try
            [AllCyclesLong, MeanTrial, message] = side_specific_gaitcycle_one_trial_function( ...
                syncFolder, participantID, trialName, condition, optionName, nNorm);

            participantCycleTable = [participantCycleTable; AllCyclesLong];
            participantTrialMeanTable = [participantTrialMeanTable; MeanTrial];

            masterCycleTable = [masterCycleTable; AllCyclesLong];
            masterTrialMeanTable = [masterTrialMeanTable; MeanTrial];

            newLog = table(participantID, trialName, condition, optionName, true, string(message), ...
                'VariableNames', {'Participant','Trial','Condition','Option','Success','Message'});

        catch ME
            warning('%s | %s failed: %s', participantID, trialName, ME.message);

            newLog = table(participantID, trialName, condition, optionName, false, string(ME.message), ...
                'VariableNames', {'Participant','Trial','Condition','Option','Success','Message'});
        end

        logTable = [logTable; newLog];
    end

    %% SAVE PARTICIPANT-LEVEL CSV AND PLOTS
    if ~isempty(participantCycleTable)

        participantOutFolder = fullfile(participantPath, ...
            ['Participant_GaitCycle_WithVsWithout_' char(optionName)]);

        if ~exist(participantOutFolder, 'dir')
            mkdir(participantOutFolder);
        end

        writetable(participantCycleTable, fullfile(participantOutFolder, ...
            ['Participant_AllCycles_Long_' char(optionName) '.csv']));

        writetable(participantTrialMeanTable, fullfile(participantOutFolder, ...
            ['Participant_TrialMeans_Long_' char(optionName) '.csv']));

        participantConditionMean = make_participant_condition_mean_table( ...
            participantCycleTable, nNorm);

        writetable(participantConditionMean, fullfile(participantOutFolder, ...
            ['Participant_ConditionMean_Long_' char(optionName) '.csv']));

        plot_participant_with_vs_without_gaitcycles( ...
            participantConditionMean, participantOutFolder, participantID, optionName);

    end
end

%% SAVE GROUP MASTER FILES
groupOutFolder = fullfile(rootDir, ['SIDE_SPECIFIC_GAITCYCLE_RESULTS_' char(optionName)]);

if ~exist(groupOutFolder, 'dir')
    mkdir(groupOutFolder);
end

writetable(masterCycleTable, fullfile(groupOutFolder, ...
    ['AllParticipants_AllCycles_Long_' char(optionName) '.csv']));

writetable(masterTrialMeanTable, fullfile(groupOutFolder, ...
    ['AllParticipants_TrialMeans_Long_' char(optionName) '.csv']));

writetable(logTable, fullfile(groupOutFolder, ...
    ['Batch_SideSpecific_GaitCycle_Log_' char(optionName) '.csv']));

fprintf('\n=====================================\n');
fprintf('BATCH SIDE-SPECIFIC GAIT CYCLE COMPLETE\n');
fprintf('=====================================\n');
fprintf('Results saved to:\n%s\n', groupOutFolder);
fprintf('Successful trials: %d\n', sum(logTable.Success));
fprintf('Failed trials: %d\n', height(logTable) - sum(logTable.Success));