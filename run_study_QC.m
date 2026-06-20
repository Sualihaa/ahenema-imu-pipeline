clear; clc; close all;

%% ROOT DATASET FOLDER
rootDir = uigetdir(pwd, 'Select ROOT folder containing participant folders');

%% OUTPUT FOLDER
resultsRoot = fullfile(rootDir, 'QC_Results');

if ~exist(resultsRoot, 'dir')
    mkdir(resultsRoot);
end

%% SENSOR MAPPING FILE
mappingCSV  = fullfile(rootDir, 'SensorMapping.csv');
mappingXLSX = fullfile(rootDir, 'SensorMapping.xlsx');

if isfile(mappingCSV)
    SensorMap = readtable(mappingCSV);
elseif isfile(mappingXLSX)
    SensorMap = readtable(mappingXLSX);
else
    warning('SensorMapping.csv/xlsx not found. Segment names will be marked Unknown.');
    SensorMap = table();
end

%% GET PARTICIPANT FOLDERS ONLY: P2, P3, ..., P20
participants = dir(fullfile(rootDir, 'P*'));
participants = participants([participants.isdir]);

fprintf('\nParticipants found:\n');
disp({participants.name}');

QC_All = table();

for p = 1:length(participants)

    participantID = string(participants(p).name);
    participantPath = fullfile(rootDir, participants(p).name);

    fprintf('\n=====================================\n');
    fprintf('PARTICIPANT %s\n', participantID);
    fprintf('=====================================\n');

    trialFolders = dir(participantPath);
    trialFolders = trialFolders([trialFolders.isdir]);
    trialFolders = trialFolders(~ismember({trialFolders.name},{'.','..'}));

    for tr = 1:length(trialFolders)

        trialFolderName = string(trialFolders(tr).name);
        trialPath = fullfile(participantPath, trialFolders(tr).name);

        fprintf('\nProcessing %s | %s\n', participantID, trialFolderName);

        try
            QC_Trial = process_trial_QC( ...
                trialPath, ...
                participantID, ...
                trialFolderName, ...
                resultsRoot, ...
                SensorMap);

            QC_All = [QC_All; QC_Trial];

        catch ME
            fprintf('\nERROR PROCESSING:\n');
            fprintf('Participant: %s\n', participantID);
            fprintf('Trial: %s\n', trialFolderName);
            fprintf('Message: %s\n', ME.message);
        end
    end
end

%% SAVE MASTER QC FILE
masterOutput = fullfile(resultsRoot, 'QC_AllParticipants.csv');
writetable(QC_All, masterOutput);

disp(' ');
disp('FULL STUDY QC COMPLETE.');
fprintf('Master QC saved to:\n%s\n', masterOutput);