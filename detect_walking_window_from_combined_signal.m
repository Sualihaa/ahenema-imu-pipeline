function [walk_start_s, walk_end_s] = detect_walking_window_from_combined_signal(t, signal, pre_buffer_s, post_buffer_s)

%% Smooth signal
fs_est = 1 / median(diff(t));
win = max(3, round(0.20 * fs_est));

signal_smooth = movmean(signal, win);

%% Estimate quiet baseline from first 2 seconds
baseline_idx = t <= 2;

if sum(baseline_idx) < 10
    baseline_idx = 1:min(100, length(t));
end

baseline_mean = mean(signal_smooth(baseline_idx), 'omitnan');
baseline_std = std(signal_smooth(baseline_idx), 'omitnan');

threshold = baseline_mean + max(10, 4*baseline_std);

active = signal_smooth > threshold;

%% Remove tiny isolated activity
min_active_duration_s = 0.30;
min_active_samples = max(1, round(min_active_duration_s * fs_est));

active_clean = false(size(active));

i = 1;

while i <= length(active)

    if active(i)
        j = i;

        while j <= length(active) && active(j)
            j = j + 1;
        end

        run_length = j - i;

        if run_length >= min_active_samples
            active_clean(i:j-1) = true;
        end

        i = j;
    else
        i = i + 1;
    end
end

active_idx = find(active_clean);

if isempty(active_idx)
    warning('Could not reliably detect walking window. Using full trial.');
    walk_start_s = t(1);
    walk_end_s = t(end);
    return;
end

raw_start = t(active_idx(1));
raw_end = t(active_idx(end));

walk_start_s = max(t(1), raw_start - pre_buffer_s);
walk_end_s = min(t(end), raw_end + post_buffer_s);

end