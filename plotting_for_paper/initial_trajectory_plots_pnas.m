% modeling 'cat' starters
% called from semantic_master, after running embedding_module and single subject list ID
close all

rng(0)
ndim = 3; 
if isempty(reduction{ndim})
    low_d_reduction
end

strt = 'cat';
lim = 7; %how many words after start

% Find candidate subjects
for iSj_plot=1:length(id_log)
    sameStart(iSj_plot,1) = strcmp(strt, allAn(id_log{iSj_plot}(1)));
end
ss = find(sameStart);

% For each candidate subject, get the initial word trajectory
% (through PCA space)
trajName = cell(length(ss),1);
trajCoord = nan(length(ss), lim, ndim);
for iSj_plot = 1:length(ss)
    % [subject, word_num]
    trajName{iSj_plot} = allAn(id_log{ss(iSj_plot)}(1:lim));
    % [subject, word_num, word_dim]
    trajCoord(iSj_plot,:,1:ndim) = reduction{ndim}(id_log{ss(iSj_plot)}(1:lim),1:ndim);
end

%% Plot each subj same axis (subset subjs)
figure();
set(gcf, 'Position', [0 0 1000 1000])

for_axes = [];
subj_subset = [1 3 4];
plot_lims = [min(trajCoord(subj_subset,:,1), [],'all') max(trajCoord(subj_subset,:,1), [],'all');
    min(trajCoord(subj_subset,:,2), [],'all') max(trajCoord(subj_subset,:,2), [],'all');
    min(trajCoord(subj_subset,:,3), [],'all') max(trajCoord(subj_subset,:,3), [],'all')];
plot_lims(:,1) = plot_lims(:,1)-.5;
plot_lims(:,2) = plot_lims(:,2)+.5;
line_col = {[0 0 0], [247 213 72]/256, [234 58 182]/256};
show_text = true;
for ii = 1:length(subj_subset)
    plot_traj(subj_subset(ii), ss, trajCoord, trajName, finalPartition, ndim, id_log, lim, plot_lims, line_col{ii}, show_text, axis_nam)
    hold on
end



%--------------------------------------------------------------------------
function plot_traj(iSj_plot, ss, trajCoord, trajName, finalPartition, ndim, id_log, lim, plot_lims, line_col, show_text, axis_nam)

% add jitter for 2:end words (plotting)
trajCoord_j = trajCoord(:,2:end,:) + randn(size(trajCoord(:,2:end,:)))*0.1;
trajCoord_j = cat(2, trajCoord(:,1,:), trajCoord_j);

if ndim==3
    plot3(trajCoord_j(iSj_plot,:,1), trajCoord_j(iSj_plot,:,2), trajCoord_j(iSj_plot,:,3), 'LineWidth', 3, 'Color', line_col)
else
    plot(trajCoord_j(iSj_plot,:,1), trajCoord_j(iSj_plot,:,2), 'LineWidth', 3, 'Color', line_col)
end

hold on,

% plot words in color according to community
c = distinguishable_colors(length(unique(finalPartition)));
comMem = finalPartition(id_log{ss(iSj_plot)}(1:lim));
uc = unique(comMem);

if show_text
    for m = 1:length(uc)
        if ndim==3
            text(trajCoord(iSj_plot, comMem == uc(m),1)+0.01, trajCoord(iSj_plot, comMem == uc(m),2)+0.01, trajCoord(iSj_plot, comMem == uc(m),3)+0.01, trajName{iSj_plot}(comMem == uc(m)), 'Color', c(uc(m),:), 'FontSize', 20);
        else
            text(trajCoord(iSj_plot, comMem == uc(m),1)+0.01, trajCoord(iSj_plot, comMem == uc(m),2)+0.01, trajName{iSj_plot}(comMem == uc(m)), 'Color', c(uc(m),:), 'FontSize', 10);
        end
    end
end

xlim([plot_lims(1,1), plot_lims(1,2)]);
xticklabels([])
xlabel(sprintf('%s 1', axis_nam))
ylim([plot_lims(2,1), plot_lims(2,2)]);
yticklabels([])
ylabel(sprintf('%s 2', axis_nam))
if ndim==3
    zlim([plot_lims(3,1), plot_lims(3,2)]);
    zticklabels([])
    zlabel(sprintf('%s 3', axis_nam))
    % shaddow
    plot3(trajCoord_j(iSj_plot,:,1), trajCoord_j(iSj_plot,:,2), plot_lims(3,1)*ones(lim,1),'Color', .99*[0.97 0.97 0.97], 'LineWidth', 8)
end
grid on
box off
axis square

end