function qMean = average_quaternions_markley(Q)

% Q is N x 4, scalar-first [q0 q1 q2 q3]
% Returns scalar-first mean quaternion [q0 q1 q2 q3]

%% Remove NaN rows
valid = all(~isnan(Q), 2);
Q = Q(valid, :);

if isempty(Q)
    error('No valid quaternions available for averaging.');
end

%% Normalize
Q = Q ./ vecnorm(Q, 2, 2);

%% Force same hemisphere
for i = 2:size(Q,1)
    if dot(Q(1,:), Q(i,:)) < 0
        Q(i,:) = -Q(i,:);
    end
end

%% Markley quaternion average
A = zeros(4,4);

for i = 1:size(Q,1)
    q = Q(i,:)';
    A = A + q*q';
end

A = A / size(Q,1);

[V, D] = eig(A);
[~, maxIdx] = max(diag(D));

qMean = V(:, maxIdx)';
qMean = qMean ./ norm(qMean);

%% Keep scalar component positive for consistency
if qMean(1) < 0
    qMean = -qMean;
end

end