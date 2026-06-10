function QC_Trial = process_trial_QC(trialPath, participantID, trialFolderName, resultsRoot, SensorMap)

%% EXTRACT CONDITION AND TRIAL NUMBER
trialLower = lower(trialFolderName);

if contains(trialLower, "W") 
    condition = "Without Ahenema";
else
    condition = "With Ahenema"
end

trialNumMatch = regexp(trialFolderName, 'd+'. 'match');

if isempty(trialNumMatch)
    trialNumber = NaN;
else
    trialNumber = str2double(trialNumMatch{end});
end

%% OUTPUT FOLDER FOR THIS TRIAL
trialResultsFolder = fullfile(resultsRoot, participantID, trialFolderName);

if ~exist(trialResultsFolder, 'dir')
    mkdir (trialResultsFolder);
end

plotFolder = fullfile(trialResultsFolder, 'QC_Plots');

if ~exist(plotFolder, 'dir')
    mkdir(plotFolder);
end

%% FIND SENSOR FILES
files = dir(fullfile(trialPath, '*.txt'));

QC_Trial = table();

for f= 1:length(files)
    sensorFile = fullfile(trialPath, files(f).name);

    QC_Row = qc_single_INDIP_sensor(sensorFile, plotFolder);
    deviceID = QC_Row.DeviceID;

    %% FIND SEGMENT FROM MAPPING FILE
    segment = "Unknown";

    if ~isempty(SensorMap)

        idx = string(SensorMap.Participant) == participantID & ...
            string(SensorMap.Condition) == condition & ...
            SensorMap.Trial == trialNumber & ...
            string(SensorMap.DeviceID) == deviceID;

        if any(idx)
            segment= string(SensorMap.Segment(find(idx, 1)));
        end
    end

    %% APPEND METADATA
    QC_Row = addvars(QC_Row, ...
        participantID, ...
        condition, ...
        trialNumber, ...
        segment, ...
        'Before','File', ...
        'NewVariableNames', {'Participant', 'Condition', 'Trial', 'Segment'});

        QC_Trial = [QC_Trial; QC_Row];
end

