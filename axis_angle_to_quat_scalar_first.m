function q = axis_angle_to_quat_scalar_first(axisName, angleDeg)

% Returns scalar-first quaternion [q0 q1 q2 q3]
% axisName can be 'x', 'y', or 'z'
% angleDeg is in degrees

axisName = lower(string(axisName));
theta = deg2rad(angleDeg);

switch axisName
    case "x"
        axisVec = [1 0 0];
    case "y"
        axisVec = [0 1 0];
    case "z"
        axisVec = [0 0 1];
    otherwise
        error('axisName must be x, y, or z.');
end

q0 = cos(theta/2);
qv = sin(theta/2) * axisVec;

q = [q0 qv];

q = q ./ norm(q);

end