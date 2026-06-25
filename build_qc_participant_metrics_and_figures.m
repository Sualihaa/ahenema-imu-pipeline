clear; clc; close all;

%% SELECT QC FOLDER
qcFolder = uigetdir(pwd, 'Select QC_CycleFiltering folder');

if isequal(qcFolder, 0)
    error('No folder selected.');
end

optionName = "HybridAligned";

cleanFile = fullfile(qcFolder, ...
    ['AllParticipants_AllCycles_Long_' char(optionName) '_QC_CLEAN.csv']);

if ~isfile(cleanFile)
    error('Clean cycle file not found:\n%s', cleanFile);
end

%% LOAD CLEAN CYCLES
T = readtable(cleanFile);

fprintf('\nLoaded clean cycle rows: %d\n', height(T));

requiredCols = {'Participant','Trial','Condition','Side','Cycle','Coordinate', ...
                'Percent','Angle_deg','Duration_s'};

for i = 1:length(requiredCols)
    if ~ismember(requiredCols{i}, T.Properties.VariableNames)
        error('Missing required column: %s', requiredCols{i});
    end
end

%% SETTINGS
nNorm = 101;
percent = linspace(0,100,nNorm)';

minCyclesPerCondition = 3;

coords = ["knee_angle_r", "knee_angle_l", "ankle_angle_r", "ankle_angle_l"];

%% OUTPUT FOLDER
analysisFolder = fullfile(qcFolder, 'Participant_Metrics_and_Figures');

if ~exist(analysisFolder, 'dir')
    mkdir(analysisFolder);
end

%% CREATE UNIQUE CYCLE INSTANCE
% This prevents duplicate counting across 101 percentage points.
T.CycleInstanceID = strcat( ...
    string(T.Participant), "_", ...
    string(T.Trial), "_", ...
    string(T.Condition), "_", ...
    string(T.Side), "_", ...
    string(T.Coordinate), "_C", ...
    string(T.Cycle));

%% ============================================================
%  PART 1: PARTICIPANT-CONDITION MEAN CURVES
% ============================================================

fprintf('\nBuilding participant-condition mean curves...\n');

participants = unique(string(T.Participant));
conditions = ["Without Ahenema", "With Ahenema"];

ParticipantMeanCurves = table();

for p = 1:length(participants)

    participantID = participants(p);

    for cond = 1:length(conditions)

        conditionName = conditions(cond);

        for c = 1:length(coords)

            coord = coords(c);

            idx = string(T.Participant) == participantID & ...
                  string(T.Condition) == conditionName & ...
                  string(T.Coordinate) == coord;

            C = T(idx, :);

            if isempty(C)
                continue;
            end

            uniqueCycles = unique(C.CycleInstanceID);
            numCycles = length(uniqueCycles);
            numTrials = length(unique(string(C.Trial)));

            for pp = 1:nNorm

                vals = C.Angle_deg(C.Percent == percent(pp));

                temp = table();
                temp.Participant = participantID;
                temp.Condition = conditionName;
                temp.Option = optionName;
                temp.Coordinate = coord;
                temp.Percent = percent(pp);
                temp.MeanAngle_deg = mean(vals, 'omitnan');
                temp.SDAngle_deg = std(vals, 'omitnan');
                temp.NumCycles = numCycles;
                temp.NumTrials = numTrials;

                ParticipantMeanCurves = [ParticipantMeanCurves; temp];
            end
        end
    end
end

meanCurveFile = fullfile(analysisFolder, ...
    ['ParticipantCondition_MeanCurves_' char(optionName) '_QC.csv']);

writetable(ParticipantMeanCurves, meanCurveFile);

fprintf('Saved participant-condition mean curves:\n%s\n', meanCurveFile);

%% ============================================================
%  PART 2: PARTICIPANT-CONDITION SUMMARY METRICS
% ============================================================

fprintf('\nExtracting participant-condition metrics...\n');

ParticipantMetrics = table();

groups = unique(ParticipantMeanCurves(:, {'Participant','Condition','Coordinate'}));

for i = 1:height(groups)

    participantID = groups.Participant(i);
    conditionName = groups.Condition(i);
    coord = groups.Coordinate(i);

    idx = ParticipantMeanCurves.Participant == participantID & ...
          ParticipantMeanCurves.Condition == conditionName & ...
          ParticipantMeanCurves.Coordinate == coord;

    C = ParticipantMeanCurves(idx, :);

    if isempty(C)
        continue;
    end

    y = C.MeanAngle_deg;

    ROM_deg = max(y, [], 'omitnan') - min(y, [], 'omitnan');
    Max_deg = max(y, [], 'omitnan');
    Min_deg = min(y, [], 'omitnan');
    Mean_deg = mean(y, 'omitnan');

    % Peak timing
    [~, maxIdx] = max(y);
    [~, minIdx] = min(y);

    PercentAtMax = C.Percent(maxIdx);
    PercentAtMin = C.Percent(minIdx);

    temp = table();
    temp.Participant = participantID;
    temp.Condition = conditionName;
    temp.Option = optionName;
    temp.Coordinate = coord;
    temp.ROM_deg = ROM_deg;
    temp.Max_deg = Max_deg;
    temp.Min_deg = Min_deg;
    temp.Mean_deg = Mean_deg;
    temp.PercentAtMax = PercentAtMax;
    temp.PercentAtMin = PercentAtMin;
    temp.NumCycles = C.NumCycles(1);
    temp.NumTrials = C.NumTrials(1);

    ParticipantMetrics = [ParticipantMetrics; temp];
end

metricsFile = fullfile(analysisFolder, ...
    ['ParticipantCondition_KinematicMetrics_' char(optionName) '_QC.csv']);

writetable(ParticipantMetrics, metricsFile);

fprintf('Saved participant-condition metrics:\n%s\n', metricsFile);

%% ============================================================
%  PART 3: PARTICIPANT INCLUSION REPORT
% ============================================================

fprintf('\nBuilding participant inclusion report...\n');

InclusionReport = table();

for p = 1:length(participants)

    participantID = participants(p);

    for c = 1:length(coords)

        coord = coords(c);

        idxWithout = ParticipantMetrics.Participant == participantID & ...
                     ParticipantMetrics.Condition == "Without Ahenema" & ...
                     ParticipantMetrics.Coordinate == coord;

        idxWith = ParticipantMetrics.Participant == participantID & ...
                  ParticipantMetrics.Condition == "With Ahenema" & ...
                  ParticipantMetrics.Coordinate == coord;

        withoutCycles = 0;
        withCycles = 0;

        if any(idxWithout)
            withoutCycles = ParticipantMetrics.NumCycles(idxWithout);
        end

        if any(idxWith)
            withCycles = ParticipantMetrics.NumCycles(idxWith);
        end

        included = withoutCycles >= minCyclesPerCondition && ...
                   withCycles >= minCyclesPerCondition;

        reason = "Included";

        if withoutCycles < minCyclesPerCondition && withCycles < minCyclesPerCondition
            reason = "Too_few_cycles_both_conditions";
        elseif withoutCycles < minCyclesPerCondition
            reason = "Too_few_cycles_without";
        elseif withCycles < minCyclesPerCondition
            reason = "Too_few_cycles_with";
        end

        temp = table();
        temp.Participant = participantID;
        temp.Coordinate = coord;
        temp.WithoutCycles = withoutCycles;
        temp.WithCycles = withCycles;
        temp.MinimumCyclesRequired = minCyclesPerCondition;
        temp.Included = included;
        temp.Reason = reason;

        InclusionReport = [InclusionReport; temp];
    end
end

inclusionFile = fullfile(analysisFolder, ...
    ['Participant_Inclusion_Report_' char(optionName) '_QC.csv']);

writetable(InclusionReport, inclusionFile);

fprintf('Saved inclusion report:\n%s\n', inclusionFile);

%% ============================================================
%  PART 4: PARTICIPANT-LEVEL INDIVIDUAL PLOTS
% ============================================================

fprintf('\nCreating individual participant plots...\n');

individualPlotFolder = fullfile(analysisFolder, 'Individual_Participant_Plots');

if ~exist(individualPlotFolder, 'dir')
    mkdir(individualPlotFolder);
end

for p = 1:length(participants)

    participantID = participants(p);

    P = ParticipantMeanCurves(ParticipantMeanCurves.Participant == participantID, :);

    if isempty(P)
        continue;
    end

    plot_one_participant_condition_curves(P, individualPlotFolder, participantID, optionName);
end

fprintf('Saved individual participant plots to:\n%s\n', individualPlotFolder);

%% ============================================================
%  PART 5: GROUP WAVEFORM FIGURES
% ============================================================

fprintf('\nCreating group waveform plots...\n');

groupPlotFolder = fullfile(analysisFolder, 'Group_Plots');

if ~exist(groupPlotFolder, 'dir')
    mkdir(groupPlotFolder);
end

plot_group_waveforms_from_participant_means( ...
    ParticipantMeanCurves, InclusionReport, groupPlotFolder, optionName);

fprintf('Saved group plots to:\n%s\n', groupPlotFolder);

%% ============================================================
%  PART 6: DESCRIPTIVE SUMMARY TABLE FOR MANUSCRIPT
% ============================================================

fprintf('\nCreating descriptive summary table...\n');

DescriptiveStats = table();

metrics = ["ROM_deg", "Max_deg", "Min_deg", "Mean_deg"];

for c = 1:length(coords)

    coord = coords(c);

    includedParticipants = InclusionReport.Participant( ...
        InclusionReport.Coordinate == coord & InclusionReport.Included == true);

    for m = 1:length(metrics)

        metricName = metrics(m);

        for cond = 1:length(conditions)

            conditionName = conditions(cond);

            idx = ismember(ParticipantMetrics.Participant, includedParticipants) & ...
                  ParticipantMetrics.Coordinate == coord & ...
                  ParticipantMetrics.Condition == conditionName;

            vals = ParticipantMetrics.(metricName)(idx);

            temp = table();
            temp.Coordinate = coord;
            temp.Metric = metricName;
            temp.Condition = conditionName;
            temp.N = sum(~isnan(vals));
            temp.Mean = mean(vals, 'omitnan');
            temp.SD = std(vals, 'omitnan');
            temp.Median = median(vals, 'omitnan');
            temp.IQR = iqr(vals);
            temp.Min = min(vals, [], 'omitnan');
            temp.Max = max(vals, [], 'omitnan');

            DescriptiveStats = [DescriptiveStats; temp];
        end
    end
end

descFile = fullfile(analysisFolder, ...
    ['Descriptive_Stats_For_Manuscript_' char(optionName) '_QC.csv']);

writetable(DescriptiveStats, descFile);

fprintf('Saved descriptive stats:\n%s\n', descFile);

%% FINAL SUMMARY
fprintf('\n=====================================\n');
fprintf('PARTICIPANT METRICS + FIGURES COMPLETE\n');
fprintf('=====================================\n');
fprintf('Mean curves: %s\n', meanCurveFile);
fprintf('Metrics: %s\n', metricsFile);
fprintf('Inclusion report: %s\n', inclusionFile);
fprintf('Descriptive stats: %s\n', descFile);

disp('Participants included per coordinate:');
for c = 1:length(coords)
    coord = coords(c);
    nIncluded = sum(InclusionReport.Coordinate == coord & InclusionReport.Included);
    fprintf('%s: n = %d\n', coord, nIncluded);
end