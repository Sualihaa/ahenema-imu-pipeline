function CyclesLong = segment_side_kinematics_from_contacts(K, contactTimes, sideName, coordNames, nNorm)

percent = linspace(0, 100, nNorm)';

CyclesLong = table();

if isempty(contactTimes) || length(contactTimes) < 2
    warning('%s side: not enough contacts to create cycles.', sideName);
    return;
end

contactTimes = sort(contactTimes(:));

cycleCount = 0;

for i = 1:(length(contactTimes)-1)

    startTime = contactTimes(i);
    endTime   = contactTimes(i+1);
    duration  = endTime - startTime;

    % Same-foot gait cycle duration sanity range
    if duration < 0.7 || duration > 2.0
        fprintf('%s side: skipping cycle %d, duration %.3f s.\n', sideName, i, duration);
        continue;
    end

    idx = K.time >= startTime & K.time <= endTime;

    if sum(idx) < 10
        fprintf('%s side: skipping cycle %d, too few samples.\n', sideName, i);
        continue;
    end

    cycleCount = cycleCount + 1;

    oldPercent = linspace(0, 100, sum(idx));

    for c = 1:length(coordNames)

        coord = char(coordNames(c));

        if ~ismember(coord, K.Properties.VariableNames)
            warning('Missing coordinate: %s', coord);
            continue;
        end

        y = K.(coord)(idx);
        yNorm = interp1(oldPercent, y, percent, 'linear', 'extrap');

        temp = table();
        temp.Side = repmat(string(sideName), nNorm, 1);
        temp.Cycle = repmat(cycleCount, nNorm, 1);
        temp.Coordinate = repmat(string(coord), nNorm, 1);
        temp.StartTime_s = repmat(startTime, nNorm, 1);
        temp.EndTime_s = repmat(endTime, nNorm, 1);
        temp.Duration_s = repmat(duration, nNorm, 1);
        temp.Percent = percent;
        temp.Angle_deg = yNorm(:);

        CyclesLong = [CyclesLong; temp];
    end
end

fprintf('%s side valid gait cycles: %d\n', sideName, cycleCount);

end