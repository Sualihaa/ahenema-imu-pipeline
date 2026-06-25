function plot_group_waveforms_from_participant_means(ParticipantMeanCurves, InclusionReport, outFolder, optionName)

coords = ["knee_angle_r", "knee_angle_l", "ankle_angle_r", "ankle_angle_l"];
titles = ["Right Knee", "Left Knee", "Right Ankle", "Left Ankle"];
conditions = ["Without Ahenema", "With Ahenema"];

fig = figure('Visible','off', 'Position', [100 100 1200 800]);

for i = 1:length(coords)

    coord = coords(i);

    subplot(2,2,i);
    hold on;

    includedParticipants = InclusionReport.Participant( ...
        InclusionReport.Coordinate == coord & InclusionReport.Included == true);

    for cond = 1:length(conditions)

        conditionName = conditions(cond);

        T = ParticipantMeanCurves( ...
            ParticipantMeanCurves.Coordinate == coord & ...
            ParticipantMeanCurves.Condition == conditionName & ...
            ismember(ParticipantMeanCurves.Participant, includedParticipants), :);

        if isempty(T)
            continue;
        end

        [percent, meanCurve, semCurve, nParticipants] = group_mean_sem(T);

        if conditionName == "Without Ahenema"
            plot_shaded_mean(percent, meanCurve, semCurve, [0 0 0], '-');
        else
            plot_shaded_mean(percent, meanCurve, semCurve, [0.8 0 0], '--');
        end
    end

    hold off;
    grid on;
    title(titles(i), 'Interpreter','none');
    xlabel('Gait cycle (%)');
    ylabel('Angle (deg)');

    if i == 1
        legend('Without SEM','Without mean','With SEM','With mean', ...
            'Location','best');
    end
end

sgtitle(['Group Mean Gait-Cycle Curves: ' char(optionName)], ...
    'Interpreter','none');

saveas(fig, fullfile(outFolder, ...
    ['Group_AllCoordinates_WithVsWithout_' char(optionName) '_QC.png']));

close(fig);

%% Separate coordinate plots
for i = 1:length(coords)

    coord = coords(i);

    fig = figure('Visible','off', 'Position', [100 100 800 500]);
    hold on;

    includedParticipants = InclusionReport.Participant( ...
        InclusionReport.Coordinate == coord & InclusionReport.Included == true);

    for cond = 1:length(conditions)

        conditionName = conditions(cond);

        T = ParticipantMeanCurves( ...
            ParticipantMeanCurves.Coordinate == coord & ...
            ParticipantMeanCurves.Condition == conditionName & ...
            ismember(ParticipantMeanCurves.Participant, includedParticipants), :);

        if isempty(T)
            continue;
        end

        [percent, meanCurve, semCurve, nParticipants] = group_mean_sem(T);

        if conditionName == "Without Ahenema"
            plot_shaded_mean(percent, meanCurve, semCurve, [0 0 0], '-');
        else
            plot_shaded_mean(percent, meanCurve, semCurve, [0.8 0 0], '--');
        end
    end

    hold off;
    grid on;

    title([char(titles(i)) ' With vs Without Ahenema'], 'Interpreter','none');
    xlabel('Gait cycle (%)');
    ylabel('Angle (deg)');
    legend('Without SEM','Without mean','With SEM','With mean', ...
        'Location','best');

    saveas(fig, fullfile(outFolder, ...
        ['Group_' char(coord) '_WithVsWithout_' char(optionName) '_QC.png']));

    close(fig);
end

end