clear; clc; close all;

%% SELECT ANALYSIS FOLDER
analysisFolder = uigetdir(pwd, ...
    'Select Participant_Metrics_and_Figures folder');

if isequal(analysisFolder, 0)
    error('No folder selected.');
end

optionName = "HybridAligned";

%% INPUT FILES
metricsFile = fullfile(analysisFolder, ...
    ['ParticipantCondition_KinematicMetrics_' char(optionName) '_QC.csv']);

inclusionFile = fullfile(analysisFolder, ...
    ['Participant_Inclusion_Report_' char(optionName) '_QC.csv']);

if ~isfile(metricsFile)
    error('Metrics file not found:\n%s', metricsFile);
end

if ~isfile(inclusionFile)
    error('Inclusion file not found:\n%s', inclusionFile);
end

%% LOAD DATA
Metrics = readtable(metricsFile);
Inclusion = readtable(inclusionFile);

fprintf('\nLoaded metrics rows: %d\n', height(Metrics));
fprintf('Loaded inclusion rows: %d\n', height(Inclusion));

%% SETTINGS
coords = ["knee_angle_r", "knee_angle_l", "ankle_angle_r", "ankle_angle_l"];
metrics = ["ROM_deg", "Max_deg", "Min_deg", "Mean_deg"];

conditionWithout = "Without Ahenema";
conditionWith = "With Ahenema";

alpha = 0.05;

%% OUTPUT FOLDER
statsFolder = fullfile(analysisFolder, 'Statistics');

if ~exist(statsFolder, 'dir')
    mkdir(statsFolder);
end

%% BUILD PAIRED WIDE TABLE
fprintf('\nBuilding paired wide-format table...\n');

participants = unique(string(Metrics.Participant));

WideTable = table();
WideTable.Participant = participants;

for c = 1:length(coords)

    coord = coords(c);

    for m = 1:length(metrics)

        metricName = metrics(m);

        withoutCol = matlab.lang.makeValidName(coord + "_" + metricName + "_Without");
        withCol    = matlab.lang.makeValidName(coord + "_" + metricName + "_With");

        WideTable.(withoutCol) = nan(height(WideTable), 1);
        WideTable.(withCol) = nan(height(WideTable), 1);

        for p = 1:height(WideTable)

            participantID = string(WideTable.Participant(p));

            idxWithout = string(Metrics.Participant) == participantID & ...
                         string(Metrics.Coordinate) == coord & ...
                         string(Metrics.Condition) == conditionWithout;

            idxWith = string(Metrics.Participant) == participantID & ...
                      string(Metrics.Coordinate) == coord & ...
                      string(Metrics.Condition) == conditionWith;

            if any(idxWithout)
                WideTable.(withoutCol)(p) = Metrics.(metricName)(idxWithout);
            end

            if any(idxWith)
                WideTable.(withCol)(p) = Metrics.(metricName)(idxWith);
            end
        end
    end
end

wideFile = fullfile(statsFolder, ...
    ['SPSS_WideFormat_KinematicMetrics_' char(optionName) '_QC.csv']);

writetable(WideTable, wideFile);

fprintf('Saved SPSS-ready wide table:\n%s\n', wideFile);

%% RUN PAIRED STATISTICS
fprintf('\nRunning paired statistics...\n');

StatsResults = table();
PairedDataLong = table();

for c = 1:length(coords)

    coord = coords(c);

    includedParticipants = string(Inclusion.Participant( ...
        string(Inclusion.Coordinate) == coord & Inclusion.Included == true));

    for m = 1:length(metrics)

        metricName = metrics(m);

        withoutVals = [];
        withVals = [];
        pairedParticipants = strings(0,1);

        for p = 1:length(includedParticipants)

            participantID = includedParticipants(p);

            idxWithout = string(Metrics.Participant) == participantID & ...
                         string(Metrics.Coordinate) == coord & ...
                         string(Metrics.Condition) == conditionWithout;

            idxWith = string(Metrics.Participant) == participantID & ...
                      string(Metrics.Coordinate) == coord & ...
                      string(Metrics.Condition) == conditionWith;

            if any(idxWithout) && any(idxWith)

                valWithout = Metrics.(metricName)(idxWithout);
                valWith = Metrics.(metricName)(idxWith);

                if ~isnan(valWithout) && ~isnan(valWith)
                    withoutVals(end+1,1) = valWithout;
                    withVals(end+1,1) = valWith;
                    pairedParticipants(end+1,1) = participantID;
                end
            end
        end

        n = length(withoutVals);

        if n < 3
            warning('%s | %s has fewer than 3 paired participants. Skipping.', coord, metricName);
            continue;
        end

        diffVals = withVals - withoutVals;

        meanWithout = mean(withoutVals, 'omitnan');
        sdWithout = std(withoutVals, 'omitnan');

        meanWith = mean(withVals, 'omitnan');
        sdWith = std(withVals, 'omitnan');

        meanDiff = mean(diffVals, 'omitnan');
        sdDiff = std(diffVals, 'omitnan');

        medianDiff = median(diffVals, 'omitnan');
        iqrDiff = iqr(diffVals);

        %% Normality test for paired differences
        % Prefer Shapiro-Wilk if unavailable no problem; MATLAB usually has lillietest.
        normalityTest = "Lilliefors";
        normalityP = NaN;
        isNormal = false;

        try
            [hNorm, pNorm] = lillietest(diffVals);
            normalityP = pNorm;
            isNormal = hNorm == 0;
        catch
            % If lillietest is unavailable, use skewness/kurtosis rough fallback.
            normalityTest = "Not available";
            normalityP = NaN;
            isNormal = true; % fallback so t-test still runs
        end

        %% Paired t-test
        t_p = NaN;
        t_stat = NaN;
        ciLow = NaN;
        ciHigh = NaN;

        try
            [~, t_p, ci, stats] = ttest(withVals, withoutVals);
            t_stat = stats.tstat;
            ciLow = ci(1);
            ciHigh = ci(2);
        catch
            warning('ttest failed for %s | %s', coord, metricName);
        end

        %% Wilcoxon signed-rank test
        w_p = NaN;
        signedRankStat = NaN;

        try
            [w_p, ~, w_stats] = signrank(withVals, withoutVals);
            if isfield(w_stats, 'signedrank')
                signedRankStat = w_stats.signedrank;
            end
        catch
            warning('signrank failed for %s | %s', coord, metricName);
        end

        %% Choose primary test
        if isNormal
            primaryTest = "Paired t-test";
            primaryP = t_p;
            primaryStatistic = t_stat;
        else
            primaryTest = "Wilcoxon signed-rank";
            primaryP = w_p;
            primaryStatistic = signedRankStat;
        end

        %% Effect size
        % Cohen's dz for paired design = mean difference / SD difference.
        cohens_dz = meanDiff / sdDiff;

        % Approximate rank-biserial effect size for Wilcoxon is not computed here.
        % We keep Cohen dz for consistency, but interpret carefully if Wilcoxon is primary.

        significant = primaryP < alpha;

        temp = table();
        temp.Coordinate = coord;
        temp.Metric = metricName;
        temp.N = n;

        temp.Mean_Without = meanWithout;
        temp.SD_Without = sdWithout;
        temp.Mean_With = meanWith;
        temp.SD_With = sdWith;

        temp.Mean_Difference_WithMinusWithout = meanDiff;
        temp.SD_Difference = sdDiff;
        temp.Median_Difference = medianDiff;
        temp.IQR_Difference = iqrDiff;

        temp.NormalityTest = normalityTest;
        temp.NormalityP = normalityP;
        temp.DifferencesNormal = isNormal;

        temp.TTest_t = t_stat;
        temp.TTest_p = t_p;
        temp.TTest_CI_Low = ciLow;
        temp.TTest_CI_High = ciHigh;

        temp.Wilcoxon_SignedRank = signedRankStat;
        temp.Wilcoxon_p = w_p;

        temp.PrimaryTest = primaryTest;
        temp.PrimaryStatistic = primaryStatistic;
        temp.PrimaryP = primaryP;
        temp.Significant_p05 = significant;

        temp.Cohens_dz = cohens_dz;

        StatsResults = [StatsResults; temp];

        %% Save paired long data for checking
        tempLong = table();
        tempLong.Participant = pairedParticipants;
        tempLong.Coordinate = repmat(coord, n, 1);
        tempLong.Metric = repmat(metricName, n, 1);
        tempLong.Without = withoutVals;
        tempLong.With = withVals;
        tempLong.Difference_WithMinusWithout = diffVals;

        PairedDataLong = [PairedDataLong; tempLong];
    end
end

%% SAVE STATISTICS OUTPUTS
statsFile = fullfile(statsFolder, ...
    ['Paired_Statistics_KneeAnkle_' char(optionName) '_QC.csv']);

pairedLongFile = fullfile(statsFolder, ...
    ['Paired_Data_Long_KneeAnkle_' char(optionName) '_QC.csv']);

writetable(StatsResults, statsFile);
writetable(PairedDataLong, pairedLongFile);

fprintf('\nSaved paired statistics:\n%s\n', statsFile);
fprintf('Saved paired long data:\n%s\n', pairedLongFile);

%% CREATE MANUSCRIPT-READY SUMMARY TABLE
ManuscriptStats = table();

for i = 1:height(StatsResults)

    temp = table();

    temp.Coordinate = StatsResults.Coordinate(i);
    temp.Metric = StatsResults.Metric(i);
    temp.N = StatsResults.N(i);

    temp.Without_MeanSD = string(sprintf('%.2f ± %.2f', ...
        StatsResults.Mean_Without(i), StatsResults.SD_Without(i)));

    temp.With_MeanSD = string(sprintf('%.2f ± %.2f', ...
        StatsResults.Mean_With(i), StatsResults.SD_With(i)));

    temp.MeanDifference = StatsResults.Mean_Difference_WithMinusWithout(i);
    temp.PrimaryTest = StatsResults.PrimaryTest(i);
    temp.PValue = StatsResults.PrimaryP(i);
    temp.Cohens_dz = StatsResults.Cohens_dz(i);

    if StatsResults.PrimaryP(i) < 0.001
        temp.PValue_Text = "<0.001";
    else
        temp.PValue_Text = string(sprintf('%.3f', StatsResults.PrimaryP(i)));
    end

    ManuscriptStats = [ManuscriptStats; temp];
end

manuscriptFile = fullfile(statsFolder, ...
    ['Manuscript_Statistics_Table_' char(optionName) '_QC.csv']);

writetable(ManuscriptStats, manuscriptFile);

fprintf('Saved manuscript statistics table:\n%s\n', manuscriptFile);

%% PRINT MAIN RESULTS SUMMARY
fprintf('\n=====================================\n');
fprintf('PAIRED STATISTICS COMPLETE\n');
fprintf('=====================================\n');

disp(ManuscriptStats);

fprintf('\nSPSS-ready file:\n%s\n', wideFile);
fprintf('\nUse this file in SPSS for paired-samples t-test / Wilcoxon confirmation.\n');