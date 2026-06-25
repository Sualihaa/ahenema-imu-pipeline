function plot_shaded_mean(x, yMean, ySEM, colorVal, lineStyle)

x = x(:);
yMean = yMean(:);
ySEM = ySEM(:);

upper = yMean + ySEM;
lower = yMean - ySEM;

valid = ~isnan(yMean) & ~isnan(ySEM);

xv = x(valid);
upperv = upper(valid);
lowerv = lower(valid);

fill([xv; flipud(xv)], [upperv; flipud(lowerv)], colorVal, ...
    'FaceAlpha', 0.18, ...
    'EdgeColor', 'none');

plot(x, yMean, ...
    'Color', colorVal, ...
    'LineStyle', lineStyle, ...
    'LineWidth', 2.5);

end