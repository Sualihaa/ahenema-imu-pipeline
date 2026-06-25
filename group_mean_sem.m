function [percent, meanCurve, semCurve, nParticipants] = group_mean_sem(T)

percent = unique(T.Percent);
percent = sort(percent);

meanCurve = nan(length(percent),1);
semCurve = nan(length(percent),1);

participants = unique(T.Participant);
nParticipants = length(participants);

for i = 1:length(percent)

    vals = T.MeanAngle_deg(T.Percent == percent(i));

    meanCurve(i) = mean(vals, 'omitnan');
    semCurve(i) = std(vals, 'omitnan') / sqrt(sum(~isnan(vals)));
end

end