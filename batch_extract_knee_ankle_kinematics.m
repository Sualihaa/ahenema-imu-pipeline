clear; clc; close all;

%% SELECT ROOT
rootDir = uigetdir(pwd, 'Select ROOT folder containing participant folders');

if isequal(rootDir, 0)
    error('No root folder selected.');
end

optionsToAnalyze = ["MagOFF"];

AllSummary = table();
ExtractLog = table();

participants = dir(fullfile(rootDir, 'P*'));
participants = participants([participants.isdir]);

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

        condition = trial_to_condition(trialName);

        for opt = 1:length(optionsToAnalyze)

            optionName = optionsToAnalyze(opt);

            switch optionName

                case "HybridAligned"
                    motFile = fullfile(trialPath, ...
                        'SYNC_Results_TimestampBased', ...
                        'Orientation_Results_HybridAligned', ...
                        'OpenSim_Results_API', ...
                        'IK_HybridAligned_pelvis0.mot');

                case "MagON"
                    motFile = fullfile(trialPath, ...
                        'SYNC_Results_TimestampBased', ...
                        'Orientation_Results_MagON', ...
                        'OpenSim_Results_API', ...
                        'IK_MagON_pelvis0.mot');

                case "MagOFF"
                    motFile = fullfile(trialPath, ...
                        'SYNC_Results_TimestampBased', ...
                        'Orientation_Results_MagOFF', ...
                        'OpenSim_Results_API', ...
                        'IK_MagOFF_pelvis0.mot');
            end

            fprintf('\nExtracting: %s | %s | %s\n', ...
                participantID, trialName, optionName);

            if ~isfile(motFile)

                warning('MOT file missing.');

                newLog = table(participantID, trialName, condition, optionName, ...
                    false, "MOT missing", string(motFile), ...
                    'VariableNames', {'Participant','Trial','Condition','Option','Success','Message','MOTFile'});

                ExtractLog = [ExtractLog; newLog];
                continue;
            end

            try
                resultFolder = fileparts(motFile);
                plotFolder = fullfile(resultFolder, 'Knee_Ankle_Plots');

                if ~exist(plotFolder, 'dir')
                    mkdir(plotFolder);
                end

                [summaryTable, extractedTable] = extract_and_plot_knee_ankle_from_mot( ...
                    motFile, ...
                    plotFolder, ...
                    char(participantID), ...
                    char(trialName), ...
                    char(condition), ...
                    char(optionName));

                AllSummary = [AllSummary; summaryTable];

                extractedFile = fullfile(plotFolder, ...
                    ['Extracted_Knee_Ankle_' char(optionName) '.csv']);

                writetable(extractedTable, extractedFile);

                newLog = table(participantID, trialName, condition, optionName, ...
                    true, "Extracted", string(motFile), ...
                    'VariableNames', {'Participant','Trial','Condition','Option','Success','Message','MOTFile'});

                ExtractLog = [ExtractLog; newLog];

            catch ME

                warning('Extraction failed: %s', ME.message);

                newLog = table(participantID, trialName, condition, optionName, ...
                    false, string(ME.message), string(motFile), ...
                    'VariableNames', {'Participant','Trial','Condition','Option','Success','Message','MOTFile'});

                ExtractLog = [ExtractLog; newLog];

            end
        end
    end
end

%% SAVE MASTER OUTPUTS
outFolder = fullfile(rootDir, 'KINEMATICS_KNEE_ANKLE_RESULTS');

if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

summaryFile = fullfile(outFolder, 'All_Knee_Ankle_Kinematic_Summary.csv');
logFile = fullfile(outFolder, 'Batch_Knee_Ankle_Extraction_Log.csv');

writetable(AllSummary, summaryFile);
writetable(ExtractLog, logFile);

fprintf('\n=====================================\n');
fprintf('KNEE/ANKLE EXTRACTION COMPLETE\n');
fprintf('=====================================\n');
fprintf('Summary saved:\n%s\n', summaryFile);
fprintf('Log saved:\n%s\n', logFile);