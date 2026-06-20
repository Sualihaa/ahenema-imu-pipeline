function S = load_clean_INDIP_sensor_for_sync(sensorFile, SensorMap, static_search_seconds, static_window_seconds)

sensorFile = char(sensorFile);

[~, fileBase, ext] = fileparts(sensorFile);
fileName = string(strcat(fileBase, ext));

%% READ DEVICE ID
fileText = fileread(sensorFile);
deviceMatch = regexp(fileText, 'Id:\s*(INDIP[#]?\d+)', 'tokens');

if isempty(deviceMatch)
    deviceID = "UnknownDevice";
else
    deviceID = string(deviceMatch{1}{1});
end

if contains(deviceID, "INDIP") && ~contains(deviceID, "#")
    deviceID = replace(deviceID, "INDIP", "INDIP#");
end

%% MAP DEVICE TO SEGMENT
segment = "Unknown";

if ~isempty(SensorMap)
    idx = string(SensorMap.DeviceID) == deviceID;

    if any(idx)
        segment = string(SensorMap.Segment(find(idx, 1)));
    end
end

%% READ TABLE
opts = detectImportOptions(sensorFile, ...
    'FileType', 'text', ...
    'Delimiter', '\t');

opts.VariableNamesLine = 19;
opts.DataLines = [21 Inf];

T = readtable(sensorFile, opts);
T.Properties.VariableNames = matlab.lang.makeValidName(T.Properties.VariableNames);

%% EXTRACT RAW DATA
timestamp = T.Timestamp;

ax = T.Acc_X / 1000;
ay = T.Acc_Y / 1000;
az = T.Acc_Z / 1000;

gx = T.Gyro_X;
gy = T.Gyro_Y;
gz = T.Gyro_Z;

mx = T.Magn_X;
my = T.Magn_Y;
mz = T.Magn_Z;

%% CLEAN TIMESTAMPS
% Remove rows with NaN
valid = ~isnan(timestamp) & ...
        ~isnan(ax) & ~isnan(ay) & ~isnan(az) & ...
        ~isnan(gx) & ~isnan(gy) & ~isnan(gz);

timestamp = timestamp(valid);

ax = ax(valid); ay = ay(valid); az = az(valid);
gx = gx(valid); gy = gy(valid); gz = gz(valid);
mx = mx(valid); my = my(valid); mz = mz(valid);

% Sort by timestamp
[timestamp, sortIdx] = sort(timestamp);

ax = ax(sortIdx); ay = ay(sortIdx); az = az(sortIdx);
gx = gx(sortIdx); gy = gy(sortIdx); gz = gz(sortIdx);
mx = mx(sortIdx); my = my(sortIdx); mz = mz(sortIdx);

% Remove duplicate or non-increasing timestamps
dt = diff(timestamp);
keep = [true; dt > 0];

timestamp = timestamp(keep);

ax = ax(keep); ay = ay(keep); az = az(keep);
gx = gx(keep); gy = gy(keep); gz = gz(keep);
mx = mx(keep); my = my(keep); mz = mz(keep);

%% TIME VECTORS
t_unix_s = double(timestamp) / 1000;
t_local_s = t_unix_s - t_unix_s(1);

%% MAGNITUDES BEFORE BIAS CORRECTION
acc_mag = sqrt(ax.^2 + ay.^2 + az.^2);
gyro_mag_raw = sqrt(gx.^2 + gy.^2 + gz.^2);
mag_mag = sqrt(mx.^2 + my.^2 + mz.^2);

%% STATIC WINDOW DETECTION
fs_est = 1 / median(diff(t_local_s));
window_samples = round(static_window_seconds * fs_est);

search_idx = find(t_local_s <= static_search_seconds);

if length(search_idx) > window_samples

    scores = nan(length(search_idx), 1);

    for k = 1:(length(search_idx) - window_samples)

        idx = search_idx(k):(search_idx(k) + window_samples - 1);

        acc_mag_mean = mean(acc_mag(idx));
        acc_mag_std = std(acc_mag(idx));
        gyro_mag_mean = mean(gyro_mag_raw(idx));

        scores(k) = abs(acc_mag_mean - 1) + acc_mag_std + 0.01*gyro_mag_mean;
    end

    [~, best_k] = min(scores);

    static_start_idx = search_idx(best_k);
    static_end_idx = static_start_idx + window_samples - 1;

else

    static_start_idx = 1;
    static_end_idx = min(length(t_local_s), window_samples);

end

static_idx = false(size(t_local_s));
static_idx(static_start_idx:static_end_idx) = true;

static_start_time = t_local_s(static_start_idx);
static_end_time = t_local_s(static_end_idx);

%% GYRO BIAS CORRECTION
gyro_bias = [ ...
    mean(gx(static_idx)), ...
    mean(gy(static_idx)), ...
    mean(gz(static_idx))];

gx = gx - gyro_bias(1);
gy = gy - gyro_bias(2);
gz = gz - gyro_bias(3);

gyro_mag = sqrt(gx.^2 + gy.^2 + gz.^2);

%% STORE
S.File = fileName;
S.DeviceID = deviceID;
S.Segment = segment;

S.timestamp_ms = timestamp;
S.t_unix_s = t_unix_s;
S.t_local_s = t_local_s;

S.ax = ax;
S.ay = ay;
S.az = az;

S.gx = gx;
S.gy = gy;
S.gz = gz;

S.mx = mx;
S.my = my;
S.mz = mz;

S.acc_mag = acc_mag;
S.gyro_mag = gyro_mag;
S.mag_mag = mag_mag;

S.gyro_bias = gyro_bias;

S.static_start_time = static_start_time;
S.static_end_time = static_end_time;

end