function MeanCurves = build_mean_curve_table(WithoutTrials, WithTrials, nNorm)

xNorm = linspace(0, 100, nNorm)';
MeanCurves = table();
MeanCurves.Percent = xNorm;

coords = {'knee_angle_r','knee_angle_l','ankle_angle_r','ankle_angle_l'};

for c = 1:length(coords)

    coord = coords{c};

    withoutMat = collect_normalized_trials(WithoutTrials, coord, nNorm);
    withMat    = collect_normalized_trials(WithTrials, coord, nNorm);

    if ~isempty(withoutMat)
        MeanCurves.([coord '_WithoutMean']) = mean(withoutMat, 2, 'omitnan');
    else
        MeanCurves.([coord '_WithoutMean']) = nan(nNorm,1);
    end

    if ~isempty(withMat)
        MeanCurves.([coord '_WithMean']) = mean(withMat, 2, 'omitnan');
    else
        MeanCurves.([coord '_WithMean']) = nan(nNorm,1);
    end
end