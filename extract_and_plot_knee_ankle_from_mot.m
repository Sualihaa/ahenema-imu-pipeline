function [summaryTable, extractedTable] = extract_and_plot_knee_ankle_from_mot( ...
    motFile, plotFolder, participantID, trialName, condition, optionName)

M = read_opensim_mot(motFile);

requiredCoords = { ...
    'knee_angle_r', ...
    'knee_angle_l', ...
    'ankle_angle_r', ...
    'ankle_angle_l'};

time = M.time;

extractedTable = table();
extractedTable.time = time;

summaryTable = table();

for i = 1:length(requiredCoords)

    coord = requiredCoords{i};

    if ~ismember(coord, M.Properties.VariableNames)
        warning('Coordinate missing: %s', coord);
        continue;
    end

    y = M.(coord);
    extractedTable.(coord) = y;

    newRow = table( ...
        string(participantID), ...
        string(trialName), ...
        string(condition), ...
        string(optionName), ...
        string(coord), ...
        min(y, [], 'omitnan'), ...
        max(y, [], 'omitnan'), ...
        range(y), ...
        mean(y, 'omitnan'), ...
        std(y, 'omitnan'), ...
        'VariableNames', {'Participant','Trial','Condition','Option','Coordinate', ...
        'Min_deg','Max_deg','Range_deg','Mean_deg','Std_deg'});

    summaryTable = [summaryTable; newRow];

    %% Individual plot
    fig = figure('Visible','off');

    plot(time, y, 'LineWidth', 1.3);
    grid on;

    title(sprintf('%s %s %s: %s', participantID, trialName, optionName, coord), ...
        'Interpreter','none');

    xlabel('Time (s)');
    ylabel('Angle (deg)');

    saveas(fig, fullfile(plotFolder, [coord '.png']));
    close(fig);

end

%% Combined right side plot
fig = figure('Visible','off');

hold on;
if ismember('knee_angle_r', extractedTable.Properties.VariableNames)
    plot(time, extractedTable.knee_angle_r, 'LineWidth', 1.3);
end
if ismember('ankle_angle_r', extractedTable.Properties.VariableNames)
    plot(time, extractedTable.ankle_angle_r, 'LineWidth', 1.3);
end
hold off;

grid on;
title(sprintf('%s %s %s: Right knee and ankle', participantID, trialName, optionName), ...
    'Interpreter','none');
xlabel('Time (s)');
ylabel('Angle (deg)');
legend('Right knee','Right ankle');

saveas(fig, fullfile(plotFolder, 'Right_Knee_Ankle.png'));
close(fig);

%% Combined left side plot
fig = figure('Visible','off');

hold on;
if ismember('knee_angle_l', extractedTable.Properties.VariableNames)
    plot(time, extractedTable.knee_angle_l, 'LineWidth', 1.3);
end
if ismember('ankle_angle_l', extractedTable.Properties.VariableNames)
    plot(time, extractedTable.ankle_angle_l, 'LineWidth', 1.3);
end
hold off;

grid on;
title(sprintf('%s %s %s: Left knee and ankle', participantID, trialName, optionName), ...
    'Interpreter','none');
xlabel('Time (s)');
ylabel('Angle (deg)');
legend('Left knee','Left ankle');

saveas(fig, fullfile(plotFolder, 'Left_Knee_Ankle.png'));
close(fig);

%% Both knees
fig = figure('Visible','off');

hold on;
if ismember('knee_angle_r', extractedTable.Properties.VariableNames)
    plot(time, extractedTable.knee_angle_r, 'LineWidth', 1.3);
end
if ismember('knee_angle_l', extractedTable.Properties.VariableNames)
    plot(time, extractedTable.knee_angle_l, 'LineWidth', 1.3);
end
hold off;

grid on;
title(sprintf('%s %s %s: Bilateral knee angles', participantID, trialName, optionName), ...
    'Interpreter','none');
xlabel('Time (s)');
ylabel('Angle (deg)');
legend('Right knee','Left knee');

saveas(fig, fullfile(plotFolder, 'Both_Knees.png'));
close(fig);

%% Both ankles
fig = figure('Visible','off');

hold on;
if ismember('ankle_angle_r', extractedTable.Properties.VariableNames)
    plot(time, extractedTable.ankle_angle_r, 'LineWidth', 1.3);
end
if ismember('ankle_angle_l', extractedTable.Properties.VariableNames)
    plot(time, extractedTable.ankle_angle_l, 'LineWidth', 1.3);
end
hold off;

grid on;
title(sprintf('%s %s %s: Bilateral ankle angles', participantID, trialName, optionName), ...
    'Interpreter','none');
xlabel('Time (s)');
ylabel('Angle (deg)');
legend('Right ankle','Left ankle');

saveas(fig, fullfile(plotFolder, 'Both_Ankles.png'));
close(fig);

%% Save local summary
writetable(summaryTable, fullfile(plotFolder, ...
    ['Knee_Ankle_Summary_' optionName '.csv']));

end