function Events = detect_foot_contacts_from_synctable(SyncTable, timeSync, fs, walk_start_s, walk_end_s, footName, makePlot)

% Detect side-specific contacts using foot IMU gyro magnitude and acceleration magnitude.
% This is practical for your data because axis orientation may vary.
%
% Method:
% 1. Detect swing peaks from foot gyro magnitude.
% 2. After each swing peak, search for acceleration impact peak.
% 3. Treat that acceleration peak as approximate foot contact.

g = 9.80665;

%% Column names
accCols = [footName + "_AccX_g", footName + "_AccY_g", footName + "_AccZ_g"];
gyroCols = [footName + "_GyroX_dps", footName + "_GyroY_dps", footName + "_GyroZ_dps"];

for i = 1:3
    if ~ismember(accCols(i), string(SyncTable.Properties.VariableNames))
        error('Missing column: %s', accCols(i));
    end
    if ~ismember(gyroCols(i), string(SyncTable.Properties.VariableNames))
        error('Missing column: %s', gyroCols(i));
    end
end

%% Signals
accX = SyncTable.(accCols(1)) * g;
accY = SyncTable.(accCols(2)) * g;
accZ = SyncTable.(accCols(3)) * g;

gyroX = SyncTable.(gyroCols(1));
gyroY = SyncTable.(gyroCols(2));
gyroZ = SyncTable.(gyroCols(3));

accMag = sqrt(accX.^2 + accY.^2 + accZ.^2);
gyroMag = sqrt(gyroX.^2 + gyroY.^2 + gyroZ.^2);

accMag = accMag(:);
gyroMag = gyroMag(:);
timeSync = timeSync(:);

%% Smooth signals
gyroSmooth = movmean(gyroMag, round(0.05*fs));
accSmooth  = movmean(accMag,  round(0.03*fs));

%% Walking window
idxWalk = timeSync >= walk_start_s & timeSync <= walk_end_s;

tWalk = timeSync(idxWalk);
gWalk = gyroSmooth(idxWalk);
aWalk = accSmooth(idxWalk);

if length(tWalk) < fs
    warning('%s: walking window too short.', footName);
    Events = table();
    return;
end

%% Detect swing peaks from gyro magnitude
minPeakDistance = round(0.55 * fs);
minProm = max(0.10 * range(gWalk), 0.75 * std(gWalk, 'omitnan'));

[pks, locs] = findpeaks(gWalk, ...
    'MinPeakDistance', minPeakDistance, ...
    'MinPeakProminence', minProm);

swingTimes = tWalk(locs);

%% For each swing peak, find acceleration impact/contact shortly after
contactTimes = [];
contactAcc = [];
swingPeakTimes = [];
swingPeakValues = [];

for i = 1:length(locs)

    swingLoc = locs(i);
    swingTime = tWalk(swingLoc);

    searchStartTime = swingTime + 0.05;
    searchEndTime   = swingTime + 0.55;

    idxSearch = find(tWalk >= searchStartTime & tWalk <= searchEndTime);

    if isempty(idxSearch)
        continue;
    end

    [maxAcc, relIdx] = max(aWalk(idxSearch));
    contactLoc = idxSearch(relIdx);

    contactTimes(end+1,1) = tWalk(contactLoc);
    contactAcc(end+1,1) = maxAcc;
    swingPeakTimes(end+1,1) = swingTime;
    swingPeakValues(end+1,1) = pks(i);
end

%% Remove contacts that are too close together
if ~isempty(contactTimes)
    [contactTimes, sortIdx] = sort(contactTimes);
    contactAcc = contactAcc(sortIdx);
    swingPeakTimes = swingPeakTimes(sortIdx);
    swingPeakValues = swingPeakValues(sortIdx);

    keep = true(size(contactTimes));
    minContactGap = 0.55; % same-foot contacts should not be closer than this

    for i = 2:length(contactTimes)
        if contactTimes(i) - contactTimes(i-1) < minContactGap
            % keep the one with stronger contact acceleration
            if contactAcc(i) > contactAcc(i-1)
                keep(i-1) = false;
            else
                keep(i) = false;
            end
        end
    end

    contactTimes = contactTimes(keep);
    contactAcc = contactAcc(keep);
    swingPeakTimes = swingPeakTimes(keep);
    swingPeakValues = swingPeakValues(keep);
end

%% Build event table
Events = table();
Events.Foot = repmat(footName, length(contactTimes), 1);
Events.ContactTime_s = contactTimes;
Events.ContactAcc_mps2 = contactAcc;
Events.SwingPeakTime_s = swingPeakTimes;
Events.SwingPeakGyro_dps = swingPeakValues;

%% Plot
if makePlot
    figure('Name', char(footName));
    
    subplot(2,1,1);
    plot(tWalk, gWalk, 'b', 'LineWidth', 1.2); hold on;
    plot(swingTimes, pks, 'ro', 'LineWidth', 1.2);
    grid on;
    title(char(footName + " gyro magnitude: swing peaks"));
    xlabel('Time (s)');
    ylabel('Gyro magnitude (deg/s)');
    legend('Gyro magnitude','Swing peaks');

    subplot(2,1,2);
    plot(tWalk, aWalk, 'k', 'LineWidth', 1.2); hold on;
    plot(contactTimes, contactAcc, 'ro', 'LineWidth', 1.2);
    grid on;
    title(char(footName + " acceleration magnitude: estimated contacts"));
    xlabel('Time (s)');
    ylabel('Acceleration magnitude (m/s^2)');
    legend('Acceleration magnitude','Estimated contacts');
end

end