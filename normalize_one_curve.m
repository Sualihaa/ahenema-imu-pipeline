function yNorm = normalize_one_curve(y, nNorm)

y = y(:);

oldX = linspace(0, 100, length(y));
newX = linspace(0, 100, nNorm);

yNorm = interp1(oldX, y, newX, 'linear', 'extrap')';