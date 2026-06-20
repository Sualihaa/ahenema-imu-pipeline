function onset_time = detect_walking_onset(t, gyro_mag, onset_search_after_s, min_onset_hold_s)

%% SMOOTH GYRO MAGNITUDE
fs_est = 1 / median(diff(t));
win = max(3, round(0.10 * fs_est));

gyro_smooth = movmean(gyro_mag, win);

%% BASELINE FROM EARLY QUIET REGION
baseline_idx = t <= onset_search_after_s;

if sum(baseline_idx) < 10
    baseline_idx = 1:min(100, length(t));
end

baseline_mean = mean(gyro_smooth(baseline_idx));
baseline_std = std(gyro_smooth(baseline_idx));

threshold = baseline_mean + max(20, 5*baseline_std);

%% SEARCH AFTER INITIAL PERIOD
search_start_idx = find(t >= onset_search_after_s, 1, 'first');

if isempty(search_start_idx)
    onset_time = t(1);
    return;
end

hold_samples = max(1, round(min_onset_hold_s * fs_est));

above = gyro_smooth > threshold;

onset_idx = NaN;

for i = search_start_idx:(length(above) - hold_samples)

    if all(above(i:i+hold_samples-1))
        onset_idx = i;
        break;
    end
end

if isnan(onset_idx)
    % Fallback: use largest rise in gyro signal
    dgyro = [0; diff(gyro_smooth)];
    [~, onset_idx] = max(dgyro);
end

onset_time = t(onset_idx);

end