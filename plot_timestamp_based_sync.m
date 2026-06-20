function plot_timestamp_based_sync(Sensors, SyncTable, combinedGyro, walk_start_s, walk_end_s, plotFolder)

%% Plot local sensor gyro before timestamp overlap
fig = figure('Visible','off');
hold on;

for f = 1:length(Sensors)
    plot(Sensors(f).t_local_s, Sensors(f).gyro_mag);
end

hold off;
title('Raw local time: Gyroscope magnitude');
xlabel('Local time per sensor (s)');
ylabel('|Gyro| (deg/s)');
legend(string({Sensors.Segment}), 'Interpreter','none');
saveas(fig, fullfile(plotFolder, 'raw_local_time_gyro_mag.png'));
close(fig);

%% Plot timestamp-synchronized gyro magnitude
fig = figure('Visible','off');
hold on;

vars = SyncTable.Properties.VariableNames;

gyroXVars = vars(contains(vars, 'GyroX_dps'));

for i = 1:length(gyroXVars)

    base = erase(gyroXVars{i}, '_GyroX_dps');

    gx = SyncTable.([base '_GyroX_dps']);
    gy = SyncTable.([base '_GyroY_dps']);
    gz = SyncTable.([base '_GyroZ_dps']);

    gyroMag = sqrt(gx.^2 + gy.^2 + gz.^2);

    plot(SyncTable.Time_s, gyroMag);
end

xline(walk_start_s, 'k--', 'Walk Start');
xline(walk_end_s, 'k--', 'Walk End');

hold off;
title('Timestamp synchronized: Gyroscope magnitude');
xlabel('Synchronized time (s)');
ylabel('|Gyro| (deg/s)');
legend(erase(gyroXVars, '_GyroX_dps'), 'Interpreter','none');
saveas(fig, fullfile(plotFolder, 'timestamp_sync_gyro_mag.png'));
close(fig);

%% Combined walking detection plot
fig = figure('Visible','off');
plot(SyncTable.Time_s, combinedGyro);
xline(walk_start_s, 'k--', 'Walk Start');
xline(walk_end_s, 'k--', 'Walk End');
title('Combined gyro signal used for walking crop');
xlabel('Synchronized time (s)');
ylabel('Mean absolute gyro signal');
saveas(fig, fullfile(plotFolder, 'walking_window_detection.png'));
close(fig);

end