function MeanTrial = make_mean_side_specific_cycle_table(AllCyclesLong, nNorm)

percent = linspace(0, 100, nNorm)';

sides = unique(AllCyclesLong.Side);
coords = unique(AllCyclesLong.Coordinate);

MeanTrial = table();

for s = 1:length(sides)
    for c = 1:length(coords)

        sideName = sides(s);
        coordName = coords(c);

        T = AllCyclesLong(AllCyclesLong.Side == sideName & ...
                          AllCyclesLong.Coordinate == coordName, :);

        if isempty(T)
            continue;
        end

        for p = 1:nNorm

            vals = T.Angle_deg(T.Percent == percent(p));

            temp = table();
            temp.Side = sideName;
            temp.Coordinate = coordName;
            temp.Percent = percent(p);
            temp.MeanAngle_deg = mean(vals, 'omitnan');
            temp.SDAngle_deg = std(vals, 'omitnan');
            temp.NumCycles = length(unique(T.Cycle));

            MeanTrial = [MeanTrial; temp];
        end
    end
end

end