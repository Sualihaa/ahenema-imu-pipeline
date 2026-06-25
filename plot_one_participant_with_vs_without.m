function status = plot_one_participant_with_vs_without(participantPath, participantID, optionName, nNorm)

status = struct();
status.Success = false;
status.Message = "";

trialFolders = dir(participantPath);
trialFolders = trialFolders([trialFolders.isdir]);
trialFolders = trialFolders(~ismember({trialFolders.name}, {'.','..'}));

trialNames = {trialFolders.name};
keepTrial = ~cellfun(@isempty, regexp(trialNames, '^T\d+W?$', 'once', 'ignorecase'));
trialFolders = trialFolders(keepTrial);

if isempty(trialFolders)
    error('No valid trial folders found.');
end

%% Storage for all valid trials
WithoutTrials = struct([]);
WithTrials = struct([]);

%% LOOP THROUGH TRIALS
for tr = 1:length(trialFolders)

    trialName = string(trialFolders(tr).name);
    trialPath = fullfile(participantPath, trialFolders(tr).name);

    switch optionName
        case "HybridAligned"
            plotFolder = fullfile(trialPath, ...
                'SYNC_Results_TimestampBased', ...
                'Orientation_Results_HybridAligned', ...
                'OpenSim_Results_API', ...
                'Knee_Ankle_Plots');
            csvFile = fullfile(plotFolder, 'Extracted_Knee_Ankle_HybridAligned.csv');

        case "MagON"
            plotFolder = fullfile(trialPath, ...
                'SYNC_Results_TimestampBased', ...
                'Orientation_Results_MagON', ...
                'OpenSim_Results_API', ...
                'Knee_Ankle_Plots');
            csvFile = fullfile(plotFolder, 'Extracted_Knee_Ankle_MagON.csv');

        case "MagOFF"
            plotFolder = fullfile(trialPath, ...
                'SYNC_Results_TimestampBased', ...
                'Orientation_Results_MagOFF', ...
                'OpenSim_Results_API', ...
                'Knee_Ankle_Plots');
            csvFile = fullfile(plotFolder, 'Extracted_Knee_Ankle_MagOFF.csv');

        otherwise
            error('Unknown optionName: %s', optionName);
    end

    if ~isfile(csvFile)
        fprintf('Missing extracted CSV for %s | %s\n', participantID, trialName);
        continue;
    end

    T = readtable(csvFile);

    if ~ismember('time', T.Properties.VariableNames)
        warning('Skipping %s because time column is missing.', trialName);
        continue;
    end

    S = struct();
    S.Trial = char(trialName);
    S.Time = T.time;

    coords = {'knee_angle_r','knee_angle_l','ankle_angle_r','ankle_angle_l'};
    for i = 1:length(coords)
        coord = coords{i};
        if ismember(coord, T.Properties.VariableNames)
            S.(coord) = T.(coord);
        else
            S.(coord) = [];
        end
    end

    if endsWith(upper(trialName), "W")
        if isempty(WithTrials)
            WithTrials = S;
        else
            WithTrials(end+1) = S;
        end
    else
        if isempty(WithoutTrials)
            WithoutTrials = S;
        else
            WithoutTrials(end+1) = S;
        end
    end
end

if isempty(WithoutTrials) && isempty(WithTrials)
    error('No extracted trial CSVs found for this participant.');
end

%% OUTPUT FOLDER
outFolder = fullfile(participantPath, ...
    ['WITH_vs_WITHOUT_Plots_' char(optionName)]);

if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

%% Save trial availability summary
trialSummary = table();

for i = 1:length(WithoutTrials)
    newRow = table(string(participantID), string(WithoutTrials(i).Trial), "Without Ahenema", ...
        'VariableNames', {'Participant','Trial','Condition'});
    trialSummary = [trialSummary; newRow];
end

for i = 1:length(WithTrials)
    newRow = table(string(participantID), string(WithTrials(i).Trial), "With Ahenema", ...
        'VariableNames', {'Participant','Trial','Condition'});
    trialSummary = [trialSummary; newRow];
end

writetable(trialSummary, fullfile(outFolder, 'Trials_Used.csv'));

%% PLOT OVERLAYS + NORMALIZED MEANS
coords = {'knee_angle_r','knee_angle_l','ankle_angle_r','ankle_angle_l'};

for c = 1:length(coords)
    coord = coords{c};

    plot_condition_overlay_and_mean( ...
        WithoutTrials, WithTrials, coord, participantID, optionName, outFolder, nNorm);

end

%% Save normalized mean curves
MeanCurves = build_mean_curve_table(WithoutTrials, WithTrials, nNorm);

writetable(MeanCurves, fullfile(outFolder, 'Normalized_Mean_Curves.csv'));

status.Success = true;
status.Message = "With vs without plots created successfully.";

end