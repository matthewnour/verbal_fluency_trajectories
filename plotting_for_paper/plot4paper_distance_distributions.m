if ~exist('conId_orig', 'var')
    clear conId patId
    participant_list_module_repo     % re-laod the sample info (conId, patId)
    conId_orig = conId;
    patId_orig = patId;
end

distances_1 = [];
distances_all = [];
for iss = 1:length(id_log)
    if ismember(iss, [conId_orig patId_orig])
        this_distance_matrix = dist_matrix(id_log{iss}, id_log{iss});
        ut = logical(triu(ones(length(this_distance_matrix)),1));
        distances_1 =   [distances_1;   diag(this_distance_matrix, 1)];  % vectorised one_step_distances if inclusing all subj, all(cell2mat(one_step_distances') == distances_1)
        distances_all = [distances_all; this_distance_matrix(ut)];
    end
end


figure;
set(gcf, 'Position', [100 0 210*3 170])

% number of words
subplot(131)
data = {};
data{1} = numAnimals(conId_orig)';
data{2} = numAnimals(patId_orig)';
if analysis_options.allow_perseverations
    patient_control_bargraph_scatter(data, sprintf('Number of words'));
else
    patient_control_bargraph_scatter(data, sprintf('Number of unique words'));
end
title('')
ylim([10 100])

% histogram of pairwise distances)
subplot(132)
edges = 0:0.01:1;

if strcmp(analysis_options.distance_metric, 'lexical')
    bar_shift = 0.005;
    nam = "Orthographic ";
else
    bar_shift = 0; 
    nam = "Semantic ";
end 

[c, ~] = histcounts(distances_all, edges, 'Normalization', 'probability');
b1 = bar(edges(1:end-1)+0.005 + bar_shift,c);
hold on
[c, ~] = histcounts(distances_1, edges, 'Normalization', 'probability');
b2 = bar(edges(1:end-1)+0.005 - bar_shift,c);
b1.FaceAlpha = 1; b1.FaceColor = [.5 0.5 0.5]; b1.EdgeColor = [0.5 0.5 0.5];
b2.FaceAlpha = 0.5; b2.FaceColor = [0 1 .5]; b2.EdgeColor = [0 1 .5];
xlabel(sprintf('%s distance', nam))
xlim([0 1])
ylabel('Probability mass')
box off

disp('25th, 50th and 75th percentile similarities for 1-step and all-step distances:')
[prctile(distances_1, 25) prctile(distances_1, 50) prctile(distances_1, 75); ...
    prctile(distances_all, 25) prctile(distances_all, 50) prctile(distances_all, 75)]

mmn_group_compar(distances_1, distances_all);


% group copmpar (not on sliding window, so differs from the output of the  main plotting scripts)
disp('Mean 1-step distance, no sliding window')
mean_onestep_raw = cellfun(@(x) mean(x), one_step_distances);
data = {};
data{1} = mean_onestep_raw(conId_orig)';
data{2} = mean_onestep_raw(patId_orig)';
% figure(); set(gcf, 'Position', [0 0 200 200])
subplot(133)
patient_control_bargraph_scatter(data, 'mean consecutive distance');
title('')
ylim([0.99*min(mean_onestep_raw) 1.01*max(mean_onestep_raw)])
%ylim([0.3 0.8])


%% Can also plot distributions of words for patients and controls separately 
distances_1c = [];
distances_allc = [];

distances_1p = [];
distances_allp = [];

for iss = 1:length(id_log)
    this_distance_matrix = dist_matrix(id_log{iss}, id_log{iss});
    ut = logical(triu(ones(length(this_distance_matrix)),1));

    if ismember(iss, [conId_orig])
        distances_1c =   [distances_1c;   diag(this_distance_matrix, 1)];  % vectorised one_step_distances if inclusing all subj, all(cell2mat(one_step_distances') == distances_1)
        distances_allc = [distances_allc; this_distance_matrix(ut)];
    elseif ismember(iss, [patId_orig])
        distances_1p =   [distances_1p;   diag(this_distance_matrix, 1)];  % vectorised one_step_distances if inclusing all subj, all(cell2mat(one_step_distances') == distances_1)
        distances_allp = [distances_allp; this_distance_matrix(ut)];
    end
end

figure()
set(gcf, 'Position', [100 100 500 200])
% histogram of pairwise distances - controls)
subplot(121)
edges = 0:0.01:1;
if strcmp(analysis_options.distance_metric, 'lexical'), bar_shift = 0.005; else, bar_shift = 0; end % cosmetic

[c, ~] = histcounts(distances_allc, edges, 'Normalization', 'probability');
b1 = bar(edges(1:end-1)+0.005 + bar_shift,c);
hold on
[c, ~] = histcounts(distances_1c, edges, 'Normalization', 'probability');
b2 = bar(edges(1:end-1)+0.005 - bar_shift,c);
b1.FaceAlpha = 1; b1.FaceColor = [.5 0.5 0.5]; b1.EdgeColor = [0.5 0.5 0.5];
b2.FaceAlpha = 0.5; b2.FaceColor = [0 1 .5]; b2.EdgeColor = [0 1 .5];
xlabel(sprintf('%s distance', nam))
xlim([0 1])
ylabel('Probability mass')
title('Controls')
box off

subplot(122)
[c, ~] = histcounts(distances_allp, edges, 'Normalization', 'probability');
b1 = bar(edges(1:end-1)+0.005 + bar_shift,c);
hold on
[c, ~] = histcounts(distances_1p, edges, 'Normalization', 'probability');
b2 = bar(edges(1:end-1)+0.005 - bar_shift,c);
b1.FaceAlpha = 1; b1.FaceColor = [.5 0.5 0.5]; b1.EdgeColor = [0.5 0.5 0.5];
b2.FaceAlpha = 0.5; b2.FaceColor = [0 1 .5]; b2.EdgeColor = [0 1 .5];
xlabel(sprintf('%s distance', nam))
xlim([0 1])
ylabel('Probability mass')
title('Patients')
box off
