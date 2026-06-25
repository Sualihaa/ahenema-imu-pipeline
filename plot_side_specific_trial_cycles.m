function plot_side_specific_trial_cycles(AllCyclesLong, MeanTrial, outFolder, optionName)

coords = ["knee_angle_r", "ankle_angle_r", "knee_angle_l", "ankle_angle_l"];
titles = ["Right Knee", "Right Ankle", "Left Knee", "Left Ankle"];

fig = figure('Visible','on', 'Position', [100 100 1200 800]);

for i = 1:length(coords)

    coord = coords(i);

    subplot(2,2,i);
    hold on;

    T = AllCyclesLong(AllCyclesLong.Coordinate == coord, :);
    M = MeanTrial(MeanTrial.Coordinate == coord, :);

    cycleIDs = unique(T.Cycle);

    for k = 1:length(cycleIDs)
        Tc = T(T.Cycle == cycleIDs(k), :);
        plot(Tc.Percent, Tc.Angle_deg, 'Color', [0.75 0.75 0.75], 'LineWidth', 0.8);
    end

    if ~isempty(M)
        plot(M.Percent, M.MeanAngle_deg, 'k', 'LineWidth', 2.4);
    end

    hold off;
    grid on;
    title(titles(i), 'Interpreter','none');
    xlabel('Gait cycle (%)');
    ylabel('Angle (deg)');
end

sgtitle(['Side-specific gait cycles: ' char(optionName)], 'Interpreter','none');

saveas(fig, fullfile(outFolder, ['SideSpecific_GaitCycles_' char(optionName) '.png']));

end