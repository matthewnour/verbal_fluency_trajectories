% called from a01_semantic_master_movingAv.m script

% load data
if analysis_options.animals
    task = 'animal';
else
    task = 'letter';
end

wL = 15;   % use the shorter window length for plotting, so we can get the whole 1st window in
fileToLoad = sprintf('travSalesman_%s_%s_win%i.mat', task, analysis_options.distance_metric, wL);
ts = load(fileToLoad);

% select subject and window to plot
subj_to_plot = 5;
win_to_plot = 1;
win_ix = win_to_plot:win_to_plot+wL-1;
assert(length(win_ix) == size(ts.optimalTravelSalesPath{subj_to_plot},1))

actual_list = id_log{subj_to_plot}(win_ix);
optimal_list = actual_list(ts.optimalTravelSalesPath{subj_to_plot}(:, win_to_plot));

% 2D projection
ndim = 2;
if isempty(reduction{ndim})
    rng(0)
    low_d_reduction
end

figure()
tiledlayout(2,1, 'TileSpacing','tight')
set(gcf, 'Position', .7*[0 0 600 1500])

nexttile
plot_trajectory(actual_list, allAn, finalPartition, reduction{ndim}, axis_nam, c_new)
title('Actual initial trajectory')
set(gca, 'FontSize', 20)

nexttile
plot_trajectory(optimal_list, allAn, finalPartition, reduction{ndim}, axis_nam, c_new)
title('Optimal initial trajectory')
set(gca, 'FontSize', 20)


function plot_trajectory(order_ix, allAn, finalPartition, reduction, axis_nam, c)

jitter = 0;

plot(reduction(order_ix,1),reduction(order_ix,2), 'Color', [0.5 0.5 0.5]);
hold on
for ii = 1:length(order_ix)
    w = order_ix(ii);
    plot(reduction(w,1),reduction(w,2), 'o', 'MarkerFaceColor', c(finalPartition(w),:), 'MarkerEdgeColor', 'w');
    text(reduction(w,1)+rand(1)*jitter+0.2,reduction(w,2)+rand(1)*jitter, allAn{w}, 'Color', c(finalPartition(w),:), 'FontSize', 11);
end

xlabel(sprintf('%s 1', axis_nam))
ylabel(sprintf('%s 2', axis_nam))
xlim([min(reduction(order_ix,1))-1, max(reduction(order_ix,1))+2.5])
ylim([min(reduction(order_ix,2))-1, max(reduction(order_ix,2))+1])

axis square
end




