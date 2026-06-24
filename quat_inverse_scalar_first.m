function qInv = quat_inverse_scalar_first(q)

% q is N x 4 or 1 x 4, scalar-first: [q0 q1 q2 q3]

q = q ./ vecnorm(q, 2, 2);

qInv = [q(:,1), -q(:,2), -q(:,3), -q(:,4)];

end