function eul_deg = quat_to_euler_zyx_degrees(q)

% q must be [q0 q1 q2 q3]
% q0 = scalar part
% Output:
% eul_deg(:,1) = yaw   about Z
% eul_deg(:,2) = pitch about Y
% eul_deg(:,3) = roll  about X

q0 = q(:,1);
q1 = q(:,2);
q2 = q(:,3);
q3 = q(:,4);

%% Normalize quaternions
norm_q = sqrt(q0.^2 + q1.^2 + q2.^2 + q3.^2);

q0 = q0 ./ norm_q;
q1 = q1 ./ norm_q;
q2 = q2 ./ norm_q;
q3 = q3 ./ norm_q;

%% ZYX Euler angles
yaw = atan2( ...
    2 .* (q0 .* q3 + q1 .* q2), ...
    1 - 2 .* (q2.^2 + q3.^2));

pitch_arg = 2 .* (q0 .* q2 - q3 .* q1);
pitch_arg = max(min(pitch_arg, 1), -1);
pitch = asin(pitch_arg);

roll = atan2( ...
    2 .* (q0 .* q1 + q2 .* q3), ...
    1 - 2 .* (q1.^2 + q2.^2));

eul_deg = rad2deg([yaw, pitch, roll]);

end