function plot_participant_with_vs_without_gaitcycles(ParticipantMean, outFolder, participantID, optionName)

coords = ["knee_angle_r", "ankle_angle_r", "knee_angle_l", "ankle_angle_l"];
titles = ["Right Knee", "Right Ankle", "Left Knee", "Left Ankle"];

fig = figure('Visible','off', 'Position', [100 100 1300 850]);

for i = 1:length(coords)

    coord = coords(i);

    subplot(2,2,i);
    hold on;

    Twithout = ParticipantMean(ParticipantMean.Coordinate == coord & ...
        ParticipantMean.Condition == "Without Ahenema", :);

    Twith = ParticipantMean(ParticipantMean.Coordinate == coord & ...
        ParticipantMean.Condition == "With Ahenema", :);

    if ~isempty(Twithout)
        plot(Twithout.Percent, Twithout.MeanAngle_deg, ...
            'k-', 'LineWidth', 2.3);
    end

    if ~isempty(Twith)
        plot(Twith.Percent, Twith.MeanAngle_deg, ...
            'r--', 'LineWidth', 2.3);
    end

    hold off;
    grid on;

    title(titles(i), 'Interpreter','none');
    xlabel('Gait cycle (%)');
    ylabel('Angle (deg)');

    if i == 1
        legend('Without Ahenema', 'With Ahenema', 'Location', 'best');
    end
end

sgtitle([char(participantID) ' With vs Without Ahenema: ' char(optionName)], ...
    'Interpreter','none');

saveas(fig, fullfile(outFolder, ...
    [char(participantID) '_WithVsWithout_GaitCycle_' char(optionName) '.png']));

close(fig);

%% Also save separate coordinate plots
for i = 1:length(coords)

    coord = coords(i);

    Twithout = ParticipantMean(ParticipantMean.Coordinate == coord & ...
        ParticipantMean.Condition == "Without Ahenema", :);

    Twith = ParticipantMean(ParticipantMean.Coordinate == coord & ...
        ParticipantMean.Condition == "With Ahenema", :);

    fig = figure('Visible','off', 'Position', [100 100 800 500]);
    hold on;

    if ~isempty(Twithout)
        plot(Twithout.Percent, Twithout.MeanAngle_deg, ...
            'k-', 'LineWidth', 2.5);
    end

    if ~isempty(Twith)
        plot(Twith.Percent, Twith.MeanAngle_deg, ...
            'r--', 'LineWidth', 2.5);
    end

    hold off;
    grid on;

    title([char(participantID) ' ' char(titles(i))], 'Interpreter','none');
    xlabel('Gait cycle (%)');
    ylabel('Angle (deg)');
    legend('Without Ahenema', 'With Ahenema', 'Location', 'best');

    saveas(fig, fullfile(outFolder, ...
        [char(participantID) '_' char(coord) '_WithVsWithout_' char(optionName) '.png']));

    close(fig);
end

end