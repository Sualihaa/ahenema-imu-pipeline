function ParticipantMean = make_participant_condition_mean_table(CyclesLong, nNorm)

percent = linspace(0, 100, nNorm)';

conditions = unique(CyclesLong.Condition);
coords = unique(CyclesLong.Coordinate);

ParticipantMean = table();

for cond = 1:length(conditions)
    for c = 1:length(coords)

        conditionName = conditions(cond);
        coordName = coords(c);

        T = CyclesLong(CyclesLong.Condition == conditionName & ...
                       CyclesLong.Coordinate == coordName, :);

        if isempty(T)
            continue;
        end

        for p = 1:nNorm

            vals = T.Angle_deg(T.Percent == percent(p));

            temp = table();
            temp.Participant = T.Participant(1);
            temp.Condition = conditionName;
            temp.Option = T.Option(1);
            temp.Coordinate = coordName;
            temp.Percent = percent(p);
            temp.MeanAngle_deg = mean(vals, 'omitnan');
            temp.SDAngle_deg = std(vals, 'omitnan');
            temp.NumCycles = length(unique(strcat(string(T.Trial), "_", string(T.Side), "_", string(T.Cycle))));

            ParticipantMean = [ParticipantMean; temp];
        end
    end
end

end