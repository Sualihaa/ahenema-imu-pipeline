function plot_condition_overlay_and_mean(WithoutTrials, WithTrials, coord, participantID, optionName, outFolder, nNorm)

xNorm = linspace(0, 100, nNorm)';

%% -------- RAW TRIAL OVERLAY PLOT --------
fig = figure('Visible','off');
hold on;

% Without trials
for i = 1:length(WithoutTrials)
    if isfield(WithoutTrials(i), coord) && ~isempty(WithoutTrials(i).(coord))
        t = WithoutTrials(i).Time;
        y = WithoutTrials(i).(coord);
        plot(t, y, 'LineWidth', 1.1);
    end
end

% With trials
for i = 1:length(WithTrials)
    if isfield(WithTrials(i), coord) && ~isempty(WithTrials(i).(coord))
        t = WithTrials(i).Time;
        y = WithTrials(i).(coord);
        plot(t, y, '--', 'LineWidth', 1.1);
    end
end

hold off;
grid on;
title(sprintf('%s %s Raw Trials: %s', participantID, optionName, coord), ...
    'Interpreter','none');
xlabel('Time (s)');
ylabel('Angle (deg)');

legendEntries = {};

for i = 1:length(WithoutTrials)
    if isfield(WithoutTrials(i), coord) && ~isempty(WithoutTrials(i).(coord))
        legendEntries{end+1} = ['Without - ' WithoutTrials(i).Trial];
    end
end

for i = 1:length(WithTrials)
    if isfield(WithTrials(i), coord) && ~isempty(WithTrials(i).(coord))
        legendEntries{end+1} = ['With - ' WithTrials(i).Trial];
    end
end

if ~isempty(legendEntries)
    legend(legendEntries, 'Interpreter','none', 'Location', 'best');
end

saveas(fig, fullfile(outFolder, [coord '_RawTrials.png']));
close(fig);

%% -------- NORMALIZED CONDITION MEAN PLOT --------
withoutMat = collect_normalized_trials(WithoutTrials, coord, nNorm);
withMat    = collect_normalized_trials(WithTrials, coord, nNorm);

fig = figure('Visible','off');
hold on;

if ~isempty(withoutMat)
    yMeanWithout = mean(withoutMat, 2, 'omitnan');
    plot(xNorm, yMeanWithout, 'LineWidth', 2.0);
end

if ~isempty(withMat)
    yMeanWith = mean(withMat, 2, 'omitnan');
    plot(xNorm, yMeanWith, '--', 'LineWidth', 2.0);
end

hold off;
grid on;
title(sprintf('%s %s Normalized Mean: %s', participantID, optionName, coord), ...
    'Interpreter','none');
xlabel('Normalized trial duration (%)');
ylabel('Angle (deg)');

legendEntries = {};
if ~isempty(withoutMat)
    legendEntries{end+1} = sprintf('Without mean (n=%d)', size(withoutMat,2));
end
if ~isempty(withMat)
    legendEntries{end+1} = sprintf('With mean (n=%d)', size(withMat,2));
end
if ~isempty(legendEntries)
    legend(legendEntries, 'Location', 'best');
end

saveas(fig, fullfile(outFolder, [coord '_NormalizedMean.png']));
close(fig);

%% -------- COMBINED TRIALS + MEANS --------
fig = figure('Visible','off');
hold on;

for i = 1:length(WithoutTrials)
    if isfield(WithoutTrials(i), coord) && ~isempty(WithoutTrials(i).(coord))
        yNorm = normalize_one_curve(WithoutTrials(i).(coord), nNorm);
        plot(xNorm, yNorm, 'LineWidth', 0.8);
    end
end

for i = 1:length(WithTrials)
    if isfield(WithTrials(i), coord) && ~isempty(WithTrials(i).(coord))
        yNorm = normalize_one_curve(WithTrials(i).(coord), nNorm);
        plot(xNorm, yNorm, '--', 'LineWidth', 0.8);
    end
end

if ~isempty(withoutMat)
    yMeanWithout = mean(withoutMat, 2, 'omitnan');
    plot(xNorm, yMeanWithout, 'LineWidth', 2.5);
end

if ~isempty(withMat)
    yMeanWith = mean(withMat, 2, 'omitnan');
    plot(xNorm, yMeanWith, '--', 'LineWidth', 2.5);
end

hold off;
grid on;
title(sprintf('%s %s All Normalized Trials + Means: %s', participantID, optionName, coord), ...
    'Interpreter','none');
xlabel('Normalized trial duration (%)');
ylabel('Angle (deg)');

saveas(fig, fullfile(outFolder, [coord '_NormalizedTrialsAndMean.png']));
close(fig);

end