clear; clc; close all;

%%ROOT DATASET FOLDER
rootDir = uigetdir(pwd, 'Select root folder with participant foldrs');

%%OUTPUT
resultsRoot = fullfile(rootDir, 'QC_Results');

if ~exist(resultsRoot, 'dir')
    mkdir(resultsRoot);
end

%%SENSOR MAPPING FILE
mappingFile = fullfile(rootDir, 'SensorMapping.csv');

if isfile(mappingFile)
    SensorMap = readtable(mappingFile);
else 
    warning('SensorMapping.csv not found. Segment names will be marked Unknown');
    SensorMap = table();
end

%%GET PARTICIPANT FOLDERS
participants = dir(rootDir);
participants = participants([participants.isdir]);
participants = participants(~ismember({participants.name}, {'.','..','QC_Results'}));

QC_All = table();

for p = 1;length(participants)

    participantID = string(participants(p).name);
    participantPath = fullfile(rootDir, participantID);

    trialFolders = dir(participantPath);
    trialFolders = trialFolders([trialFolders.isdir]);
    trialFolders = trialFolders(~ismember({trialFolders.name},{'.', '..'}));

    for tr = 1:length(trialFolders)

        trialFolderName = string(trialFolders(tr).name);
        trialPath = fullfile(participantPath, trialFolderName);

        fprintf('Processing %s | %s\n', participantsID, trialFolderName);

        QC_Trial = process_trial_QC( ...
            trialPath, ...
            participantID, ...
            trialFolderName, ...
            resultsRoot, ...
            SensorMap);

        QC_All = [QC_All; QC_Trial];

    end
end

%%SAVE MASTER QC FILE
masterOutput = fullfile(resultsRoot, 'QC_AllParticipants.csv');
writetable(QC_All, masterOutput);

disp(' ');
disp('FULL STUDY QC COMPLETE.');
fprintf('Master QC saved to:\n%s\n', masterOutput);
