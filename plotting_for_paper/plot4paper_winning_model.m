clear all
close all
clc

repo_home = '';
addpath(genpath(repo_home))

winning_model = '4P_SM_WSecdf_LEX_meanLevenshtein___SEM_mean.mat'; numP = 4;    % 4P, wins on AIC
mdl = load(winning_model)
clear conId patId

%-------------------------------------------------------------------------
% subject inclusion
iSja = [101,102,103,104,107,108,109,111,112,114,115,117,118,119,120,121,123,124,125,126,127,128,129,130,131,132,202,203,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229];
participant_list_module_repo
import_align_clinical_scores_repo


%% -------------------
% Parameters by group and task
figure()
set(gcf, 'Units', 'point', 'Position', [200 500 420 180])

% lexical salience  (task specific)
subplot(121)
d = mdl.best_params([patId conId], [1 3]);
g = [zeros(length(patId),1); ones(length(conId),1)];
tbl_contrast3 = simple_mixed_anova(d, g, {'task'}, {'group'});
d = {};
d{1} = mdl.best_params([conId],[1 3]);
d{2} = mdl.best_params([patId],[1 3]);
grouped_errorbar_scatter(d, {'Letter', 'Category'});
ylabel('\beta_{orthographic}')
title({sprintf('Interaction p = %.3f', tbl_contrast3.pValue(5)), ''})
ylim([0 9])

% semantic salience (task specific)
subplot(122)
d = mdl.best_params([patId conId], [2 4]);
g = [zeros(length(patId),1); ones(length(conId),1)];
tbl_contrast4 = simple_mixed_anova(d, g, {'task'}, {'group'});
d = {};
d{1} = mdl.best_params([conId],[2 4]);
d{2} = mdl.best_params([patId],[2 4]);
grouped_errorbar_scatter(d, {'Letter', 'Category'});
ylabel('\beta_{semantic}')
title({sprintf('Interaction p = %.3f', tbl_contrast4.pValue(5)), ''})
ylim([0 9])

%% goal-induced modulation
%   1. (cat_sem - cat_lex) - (let_sem - let_lex)    {between_task subtraction of weighting}     [below]
%   2. (cat_sem - let_sem) - (cat_sem - let_lex)    {weighting of betwee_task subtraction}
pred_var = (mdl.best_params(:,4)-mdl.best_params(:,3)) - (mdl.best_params(:,2)-mdl.best_params(:,1));  xl = 'goal-induced modulation (\Delta\omega)';

disp(sprintf('Group difference in %s:', xl))
mmn_group_compar(pred_var(conId), pred_var(patId));

% Correlations with symptoms, behaviour, MEG
plot_triple = 0; % (0) for paper
input_options = struct;
input_options.type = 'Spearman';        % Spearman
input_options.show_tit = 1;             %(0)
input_options.rank_regression = 0;      %(0)

if plot_triple, input_options.show_tit = 1; end

% --------
% Negative symptoms / cognitive scores 
%---------

% SELECT the appropriate variable (varId = 2 or 3)
%clinical   [panssP, panssN, panssG, MADRS]
varID = 2; clinV = new_clin(:, varID); cvn =  clinName{varID}; 

% cogntiive  [fDS bDS meanDS(**) fsIQ]
%varID = 4; clinV = new_cog(:,varID); cvn =  cogName{varID}; 

[conId_corr, patId_corr] = get_inc(conId, patId, clinV, 1)


figure()
if plot_triple, set(gcf, 'Position', [100 0 170 600]*1.5), subplot(311), else, set(gcf, 'Position', [100 0 170 170]*1.1), end
two_group_scatter(pred_var, clinV, conId_corr, patId_corr,  xl, cvn, input_options);

% idiv subscores
for n = 1:14; [r(n,1) r(n,2)] = corr(all_clin(patId_corr, n), pred_var(patId_corr), 'type', 'spearman'); end

% medication
disp(sprintf('-------------------------\nMed vs unmed:'))
disp(xl) % beh variable
[~, p_med, stats_med, normal_med] = mmn_group_compar(pred_var(new_med(patId_corr)==1), pred_var(new_med(patId_corr)==0));
disp(cvn) % symptoms
mmn_group_compar(clinV(new_med(patId_corr)==1), clinV(new_med(patId_corr)==0));


%% --------
% MEG variable (select through varID again)
%---------
% Var names = [replayChange, replayPost, ripplePost]
varID = 3; clinV = new_meg(: , varID);  cvn =  meg_name{varID}; if strcmp(cvn,  'post peakRipple'), cvn = 'Replay associated ripple power'; end
disp(sprintf('-------------------------\n%s', cvn))
[conId_corr, patId_corr] = get_inc(conId, patId, clinV, 0);

if plot_triple
    subplot(312),
    two_group_scatter(pred_var, clinV, conId_corr, patId_corr, xl, cvn, input_options);
else
    figure(),
    set(gcf, 'Position', [100 250 2.1*170 170]*1.1)

    input_options.plot_separately = 1;
    two_group_scatter(pred_var, clinV, conId_corr, patId_corr, xl, cvn, input_options);
    input_options.plot_separately = 0;
    disp('ok')

end

% medication
disp(sprintf('-------------------------\nMed vs unmed:'))
disp(cvn) % meg
mmn_group_compar(clinV(new_med(patId_corr)==1), clinV(new_med(patId_corr)==0));


%% --------
% Performance
%---------
disp(sprintf('-------------------------\nPerf'))
if mdl.analysis_options.allow_perseverations
    load('NumberAnimalsBothTasks.mat')
else
    load('NumberAnimalsBothTasks_noDup_forTS.mat')
end

ex = setdiff(1:length(iSja), [patId conId]);
numAnimals_both_tasks(ex, :) = nan(length(ex), size(numAnimals_both_tasks, 2)); % we are going to normalize or rank
clinV = mean(tiedrank(numAnimals_both_tasks(:,:)),2);    cvn = 'List lengths';
[conId_corr, patId_corr] = get_inc(conId, patId, clinV, 0);

if plot_triple, subplot(313), else, figure(), set(gcf, 'Position', [100 500 170 170]*1.1), end

% the delta sem between tasks)
two_group_scatter(pred_var, clinV, conId_corr, patId_corr, xl, cvn, input_options);

% medication
disp(sprintf('-------------------------\nMed vs unmed:'))
disp(cvn) % list length
mmn_group_compar(clinV(new_med(patId_corr)==1), clinV(new_med(patId_corr)==0));

disp(sprintf('Number controls = %i, number patients = %i', length(conId), length(patId)))
