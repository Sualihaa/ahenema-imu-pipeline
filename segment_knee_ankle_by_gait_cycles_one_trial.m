clear; clc; close all;

%% SELECT THE SYNC FOLDER
syncFolder = uigetdir(pwd, 'Select SYNC_Results_TimestampBased folder');

if isequal(syncFolder, 0)
    error('No folder selected.');
end

%% SETTINGS
optionName = "HybridAligned";
nNorm = 101;
percent = linspace(0, 100, nNorm)';

%% FILE PATHS
icFile = fullfile(syncFolder, ...
    'MobiliseD_GaitEvents', ...
    'InitialContacts_MobiliseD.csv');

kneeAnkleFile = fullfile(syncFolder, ...
    'Orientation_Results_HybridAligned', ...
    'OpenSim_Results_API', ...
    'Knee_Ankle_Plots', ...
    'Extracted_Knee_Ankle_HybridAligned.csv');

if ~isfile(icFile)
    error('Initial contacts file not found:\n%s', icFile);
end

if ~isfile(kneeAnkleFile)
    error('Extracted knee/ankle file not found:\n%s', kneeAnkleFile);
end

%% LOAD FILES
ICtable = readtable(icFile);
K = readtable(kneeAnkleFile);

if ~ismember('IC_Time_s', ICtable.Properties.VariableNames)
    error('IC_Time_s column not found in InitialContacts_MobiliseD.csv');
end

if ~ismember('time', K.Properties.VariableNames)
    error('time column not found in extracted knee/ankle CSV');
end

IC = ICtable.IC_Time_s;
IC = IC(~isnan(IC));
IC = sort(IC);

fprintf('\nLoaded %d initial contacts.\n', length(IC));

%% REMOVE EDGE CONTACTS IF NEEDED
% We use IC(i) to IC(i+2), so we need at least 3 ICs.
if length(IC) < 3
    error('Not enough initial contacts to form gait cycles.');
end

%% COORDINATES TO SEGMENT
coords = {'knee_angle_r', ...
          'knee_angle_l', ...
          'ankle_angle_r', ...
          'ankle_angle_l'};

for c = 1:length(coords)
    if ~ismember(coords{c}, K.Properties.VariableNames)
        error('Missing coordinate in knee/ankle CSV: %s', coords{c});
    end
end

%% CREATE OUTPUT FOLDER
outFolder = fullfile(syncFolder, ...
    'Orientation_Results_HybridAligned', ...
    'OpenSim_Results_API', ...
    'GaitCycle_KneeAnkle');

if ~exist(outFolder, 'dir')
    mkdir(outFolder);
end

%% SEGMENT STRIDE / GAIT CYCLES
% Full gait cycle/stride: IC(i) to IC(i+2)
% because ICs alternate left-right-left-right.
AllCycles = table();

cycleCount = 0;

for i = 1:(length(IC)-2)

    startTime = IC(i);
    endTime   = IC(i+2);

    duration = endTime - startTime;

    % Basic sanity check for stride duration
    % Human stride duration is commonly around 0.8–1.5 s during normal walking.
    % We keep a wider range here because walkway data can be variable.
    if duration < 0.6 || duration > 2.0
        fprintf('Skipping cycle %d: duration %.3f s outside range.\n', i, duration);
        continue;
    end

    idx = K.time >= startTime & K.time <= endTime;

    if sum(idx) < 10
        fprintf('Skipping cycle %d: too few samples.\n', i);
        continue;
    end

    cycleCount = cycleCount + 1;

    tCycle = K.time(idx);
    tNormOld = linspace(0, 100, length(tCycle));
    tNormNew = percent;

    temp = table();
    temp.Cycle = repmat(cycleCount, nNorm, 1);
    temp.StartTime_s = repmat(startTime, nNorm, 1);
    temp.EndTime_s = repmat(endTime, nNorm, 1);
    temp.Duration_s = repmat(duration, nNorm, 1);
    temp.Percent = percent;

    for c = 1:length(coords)

        coord = coords{c};
        y = K.(coord)(idx);

        yNorm = interp1(tNormOld, y, tNormNew, 'linear', 'extrap');

        temp.(coord) = yNorm(:);
    end

    AllCycles = [AllCycles; temp];

end

fprintf('\nValid gait cycles created: %d\n', cycleCount);

if cycleCount == 0
    error('No valid gait cycles were created.');
end

%% SAVE ALL NORMALIZED CYCLES
allCycleFile = fullfile(outFolder, ...
    ['GaitCycle_KneeAnkle_' char(optionName) '.csv']);

writetable(AllCycles, allCycleFile);

fprintf('Saved all normalized cycles:\n%s\n', allCycleFile);

%% CREATE MEAN GAIT CYCLE FOR THIS TRIAL
MeanCycle = table();
MeanCycle.Percent = percent;

for c = 1:length(coords)

    coord = coords{c};
    meanVals = nan(nNorm,1);
    sdVals = nan(nNorm,1);

    for p = 1:nNorm
        vals = AllCycles.(coord)(AllCycles.Percent == percent(p));
        meanVals(p) = mean(vals, 'omitnan');
        sdVals(p) = std(vals, 'omitnan');
    end

    MeanCycle.([coord '_Mean']) = meanVals;
    MeanCycle.([coord '_SD']) = sdVals;
end

meanCycleFile = fullfile(outFolder, ...
    ['MeanGaitCycle_KneeAnkle_' char(optionName) '.csv']);

writetable(MeanCycle, meanCycleFile);

fprintf('Saved mean gait cycle:\n%s\n', meanCycleFile);

%% PLOT MEAN GAIT CYCLES
coordLabels = {'Right Knee Angle', ...
               'Left Knee Angle', ...
               'Right Ankle Angle', ...
               'Left Ankle Angle'};

fig = figure('Visible','on', 'Position', [100 100 1100 750]);

for c = 1:length(coords)

    coord = coords{c};

    subplot(2,2,c);
    hold on;

    yMean = MeanCycle.([coord '_Mean']);
    ySD = MeanCycle.([coord '_SD']);

    upper = yMean + ySD;
    lower = yMean - ySD;

    fill([percent; flipud(percent)], [upper; flipud(lower)], ...
        [0.7 0.7 0.7], ...
        'FaceAlpha', 0.25, ...
        'EdgeColor', 'none');

    plot(percent, yMean, 'k', 'LineWidth', 2.2);

    hold off;
    grid on;

    title(coordLabels{c}, 'Interpreter','none');
    xlabel('Gait cycle (%)');
    ylabel('Angle (deg)');
end

sgtitle(['Mean Gait Cycle: ' char(optionName)], 'Interpreter','none');

plotFile = fullfile(outFolder, ...
    ['MeanGaitCycle_KneeAnkle_' char(optionName) '.png']);

saveas(fig, plotFile);

fprintf('Saved plot:\n%s\n', plotFile);