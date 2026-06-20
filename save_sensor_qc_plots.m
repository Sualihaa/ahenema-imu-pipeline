function save_sensor_qc_plots( ...
    fileName, plotFolder, ...
    t, dt, ...
    ax, ay, az, ...
    gx, gy, gz, ...
    mx, my, mz, ...
    acc_mag, gyro_mag, mag_mag, ...
    static_start_time, static_end_time, ...
    dt_expected_ms)

fileName = string(fileName);
safeName = erase(fileName, ".txt");

%% TIMESTAMP LINE PLOT
fig = figure('Visible','off');
plot(dt, 'k');
yline(dt_expected_ms, 'r--', 'Expected 10 ms');
title(['Timestamp spacing: ', char(fileName)], 'Interpreter','none');
xlabel('Sample');
ylabel('dt (ms)');
saveas(fig, fullfile(plotFolder, char(safeName + "_timestamp_dt.png")));
close(fig);

%% DT HISTOGRAM
fig = figure('Visible','off');
histogram(dt, 'BinWidth', 0.5);
xline(dt_expected_ms, 'r--', 'Expected 10 ms');
title(['dt histogram: ', char(fileName)], 'Interpreter','none');
xlabel('dt (ms)');
ylabel('Count');
saveas(fig, fullfile(plotFolder, char(safeName + "_dt_histogram.png")));
close(fig);

%% ACCELEROMETER
fig = figure('Visible','off');
plot(t, ax, t, ay, t, az);
xline(static_start_time, 'k--');
xline(static_end_time, 'k--');
legend('Acc X','Acc Y','Acc Z');
title(['Accelerometer: ', char(fileName)], 'Interpreter','none');
xlabel('Time (s)');
ylabel('Acceleration (g)');
saveas(fig, fullfile(plotFolder, char(safeName + "_acc.png")));
close(fig);

%% GYROSCOPE
fig = figure('Visible','off');
plot(t, gx, t, gy, t, gz);
xline(static_start_time, 'k--');
xline(static_end_time, 'k--');
legend('Gyro X','Gyro Y','Gyro Z');
title(['Gyroscope: ', char(fileName)], 'Interpreter','none');
xlabel('Time (s)');
ylabel('Angular velocity (deg/s)');
saveas(fig, fullfile(plotFolder, char(safeName + "_gyro.png")));
close(fig);

%% MAGNETOMETER
fig = figure('Visible','off');
plot(t, mx, t, my, t, mz);
xline(static_start_time, 'k--');
xline(static_end_time, 'k--');
legend('Mag X','Mag Y','Mag Z');
title(['Magnetometer: ', char(fileName)], 'Interpreter','none');
xlabel('Time (s)');
ylabel('Magnetic field (mGauss)');
saveas(fig, fullfile(plotFolder, char(safeName + "_mag.png")));
close(fig);

%% ACC MAG
fig = figure('Visible','off');
plot(t, acc_mag);
xline(static_start_time, 'k--');
xline(static_end_time, 'k--');
title(['Acceleration magnitude: ', char(fileName)], 'Interpreter','none');
xlabel('Time (s)');
ylabel('|Acc| (g)');
saveas(fig, fullfile(plotFolder, char(safeName + "_acc_mag.png")));
close(fig);

%% GYRO MAG
fig = figure('Visible','off');
plot(t, gyro_mag);
xline(static_start_time, 'k--');
xline(static_end_time, 'k--');
title(['Gyroscope magnitude: ', char(fileName)], 'Interpreter','none');
xlabel('Time (s)');
ylabel('|Gyro| (deg/s)');
saveas(fig, fullfile(plotFolder, char(safeName + "_gyro_mag.png")));
close(fig);

%% MAG MAG
fig = figure('Visible','off');
plot(t, mag_mag);
xline(static_start_time, 'k--');
xline(static_end_time, 'k--');
title(['Magnetometer magnitude: ', char(fileName)], 'Interpreter','none');
xlabel('Time (s)');
ylabel('|Mag| (mGauss)');
saveas(fig, fullfile(plotFolder, char(safeName + "_mag_mag.png")));
close(fig);

end