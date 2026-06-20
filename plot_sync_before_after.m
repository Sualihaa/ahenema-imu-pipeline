function plot_sync_before_after(Sensors, plotFolder)

%% BEFORE ALIGNMENT: local time
fig = figure('Visible','off');
hold on;

for f = 1:length(Sensors)
    plot(Sensors(f).t_local_s, Sensors(f).gyro_mag);
end

hold off;
title('Before synchronization: Gyroscope magnitude');
xlabel('Local time per sensor (s)');
ylabel('|Gyro| (deg/s)');
legend(string({Sensors.Segment}), 'Interpreter','none');
saveas(fig, fullfile(plotFolder, 'before_sync_gyro_mag.png'));
close(fig);

%% AFTER ALIGNMENT: shifted time
fig = figure('Visible','off');
hold on;

for f = 1:length(Sensors)
    plot(Sensors(f).t_sync_source_s, Sensors(f).gyro_mag);
end

hold off;
title('After synchronization: Gyroscope magnitude');
xlabel('Shifted time (s)');
ylabel('|Gyro| (deg/s)');
legend(string({Sensors.Segment}), 'Interpreter','none');
saveas(fig, fullfile(plotFolder, 'after_sync_gyro_mag.png'));
close(fig);

%% ONSET BAR PLOT
segments = string({Sensors.Segment});
shifts = [Sensors.sync_shift_s];

fig = figure('Visible','off');
bar(shifts);
set(gca, 'XTickLabel', segments);
xtickangle(45);
ylabel('Applied shift (s)');
title('Applied synchronization shifts');
saveas(fig, fullfile(plotFolder, 'applied_sync_shifts.png'));
close(fig);

end