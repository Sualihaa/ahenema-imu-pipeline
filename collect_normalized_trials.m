function Y = collect_normalized_trials(Trials, coord, nNorm)

Y = [];

for i = 1:length(Trials)

    if ~isfield(Trials(i), coord) || isempty(Trials(i).(coord))
        continue;
    end

    y = Trials(i).(coord);
    yNorm = normalize_one_curve(y, nNorm);

    Y = [Y, yNorm];
end

end