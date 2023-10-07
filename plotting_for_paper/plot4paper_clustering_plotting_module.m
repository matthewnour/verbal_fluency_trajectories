% called by semantic_master_movingAv.m
disp( ' ')
disp('Cluster trajectory stats')
% stats of the community transitions (zscored and standard) from communitySequenceAnalysis
nm = {'mean lifetime', 'mean number returns'};
whichFigs = [1 2];

for nn = 1:length(whichFigs)
    this_fig = whichFigs(nn);
    disp(nm{this_fig})
    figure(),
    set(gcf, 'Units', 'point', 'Position', [200 200*nn 170 170])
    data = [];
    data{1} = z_communityStats(this_fig,conId)';
    data{2} = z_communityStats(this_fig,patId)';
    [~, p] = patient_control_bargraph_scatter(data, [nm{this_fig} '(z)']);
    title('')
    xticklabels({'Control', 'Patient'});
end


% ------------------------------------------------------------
% Cluster regression and trajectories
if exist('timeStamp')
    
    toplot = 3; nam = '\beta_{community switch}';
    
    nam = ['\beta_{' regName{toplot} '}'];
    disp(nam)
    
    
    figure()
    set(gcf, 'Position', [100 100 170 170]*1.2)
    
    data = {};
    data{1} = bbb_rt(conId_orig, toplot); 
    data{2} = bbb_rt(patId_orig, toplot); 
    [~, ~, ~, normal] = patient_control_bargraph_scatter(data, nam);
    
    if normal
        [~, p, ~, stats] = ttest([data{1}; data{2}], 0);
         disp(sprintf('Regressor different from zero,  t(%i) = %.2f, p = %.3f, one sample t-test, two tailed', ...
            length([data{1}; data{2}])-1, stats.tstat, p))
    else
        [p, ~, stats] = signrank([data{1}; data{2}], 0); % Wilcoxon sign tank test for 0 median (data assumed symmetric around median)
        disp(sprintf('Regressor different from zero, z(%i) = %.2f, P = %.3f, Wilcoxon sign tank test, two tailed', ...
            length([data{1}; data{2}])-1, stats.zval, p))
    end
end

%-----------------------------------------------------
%% exemplar trajectories
% match the colors to my ppt colorscheme for the expected 5 comms
if analysis_options.animals & length(communityAssignment)==5
    
    map = [;
        208 206 206;        % hippo (grey, 1)
        222 235 247 ;      % fish (blue, 2)
        226 240 217;        % insect (green, 3)
        255 242 204;        % bird (yellow, 4)
        251 229 214;     % dog (pink, 5)
        ];
        
    % the expected color order --> centroid
    % and also the expected community ordering in the block diagonal adj mat
    expected =  {'hippo', 'fish', 'insect', 'bird', 'dog'};
    a = word2vec(emb, expected);
    
    cos_error = []; ii = [];
    for nn = 1:length(expected)
        % cosine distance between each of the centroids and the expected centroids
        this_centroid = mean(word2vec(emb,centroids{nn})',2); % [300, 1]
        [cos_error(nn), ii(nn)] = min(abs(1- a*this_centroid./(vecnorm(a')*vecnorm(this_centroid))'));
    end
    assert(length(unique(ii)) == length(centroids), 'community colour assignment error')
    
    % re-order color map
    map = (map(ii, : )) / 256; % -100 to make darker
    
    % re-order community block diag
    clustOrd_paper_ordered = cell2mat(communityAssignment(ii)');
    figure()
    set(gcf, 'Position', [0 0 400 400])
    imagesc(consensus_input_matrix(clustOrd_paper_ordered, clustOrd_paper_ordered))
    axis square
    colormap('hot')
    caxis([0.3 .6])
    title({'Paper order', ''})
else
    map = 'jet';
end

%-------------------------------------------------
% 2 participants
subj_to_plot = [patId(2) conId(19)];

figure()
subplot(1+length(subj_to_plot), 1, 1)
imagesc([1 2 3 4 5])
xticks(1:5)
xticklabels(cellfun(@(x) x(1), centroids))

for nn = 1:length(subj_to_plot)
    subplot(1+length(subj_to_plot), 1, nn+1)
    imagesc(respByCom_log{subj_to_plot(nn)})
    box off
    axis off
    set(gcf, 'color', 'w')
end
colormap(map)
disp(' ')

