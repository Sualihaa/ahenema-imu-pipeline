function QC_Trial = process_trial_QC(trialPath, participantID, trialFolderName, resultsRoot, SensorMap)

%% EXTRACT CONDITION AND TRIAL NUMBER
trialName = char(trialFolderName);
trialUpper = upper(trialName);

% Folder naming supported:
% T1   = Without Ahenema
% T1W  = With Ahenema
% T1_WITH = With Ahenema
% T1_WITHOUT = Without Ahenema

if contains(trialUpper, 'WITHOUT')
    condition = "Without Ahenema";
elseif contains(trialUpper, 'WITH')
    condition = "With Ahenema";
elseif endsWith(trialUpper, 'W')
    condition = "With Ahenema";
else
    condition = "Without Ahenema";
end

trialNumMatch = regexp(trialName, '\d+', 'match');

if isempty(trialNumMatch)
    trialNumber = NaN;
else
    trialNumber = str2double(trialNumMatch{1});
end

%% OUTPUT FOLDER FOR THIS TRIAL
trialResultsFolder = fullfile(resultsRoot, char(participantID), trialName);

if ~exist(trialResultsFolder, 'dir')
    mkdir(trialResultsFolder);
end

plotFolder = fullfile(trialResultsFolder, 'QC_Plots');

if ~exist(plotFolder, 'dir')
    mkdir(plotFolder);
end

%% FIND SENSOR FILES
files = dir(fullfile(trialPath, '*.txt'));

QC_Trial = table();

for f = 1:length(files)

    sensorFile = fullfile(trialPath, files(f).name);

    QC_Row = qc_single_INDIP_sensor(sensorFile, plotFolder);
    deviceID = QC_Row.DeviceID;

    %% FIND SEGMENT FROM MAPPING FILE
    segment = "Unknown";
    
    if ~isempty(SensorMap)
    
        idx = string(SensorMap.DeviceID) == string(deviceID);
    
        if any(idx)
            segment = string(SensorMap.Segment(find(idx,1)));
        end
    
    end

    %% APPEND METADATA
    QC_Row = addvars(QC_Row, ...
        string(participantID), ...
        condition, ...
        trialNumber, ...
        segment, ...
        'Before', 'File', ...
        'NewVariableNames', {'Participant', 'Condition', 'Trial', 'Segment'});

    QC_Trial = [QC_Trial; QC_Row];

end

%% SAVE TRIAL QC
trialOutput = fullfile(trialResultsFolder, 'QC_Trial.csv');
writetable(QC_Trial, trialOutput);

end