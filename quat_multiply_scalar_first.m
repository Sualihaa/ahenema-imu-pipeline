function q = quat_multiply_scalar_first(qA, qB)

% qA and qB are N x 4 or 1 x 4, scalar-first: [q0 q1 q2 q3]
% Returns q = qA * qB

if size(qA,1) == 1 && size(qB,1) > 1
    qA = repmat(qA, size(qB,1), 1);
end

if size(qB,1) == 1 && size(qA,1) > 1
    qB = repmat(qB, size(qA,1), 1);
end

w1 = qA(:,1); x1 = qA(:,2); y1 = qA(:,3); z1 = qA(:,4);
w2 = qB(:,1); x2 = qB(:,2); y2 = qB(:,3); z2 = qB(:,4);

q = [ ...
    w1.*w2 - x1.*x2 - y1.*y2 - z1.*z2, ...
    w1.*x2 + x1.*w2 + y1.*z2 - z1.*y2, ...
    w1.*y2 - x1.*z2 + y1.*w2 + z1.*x2, ...
    w1.*z2 + x1.*y2 - y1.*x2 + z1.*w2];

q = q ./ vecnorm(q, 2, 2);

end