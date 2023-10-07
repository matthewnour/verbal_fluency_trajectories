% Optimality deviation plots for paper

clear all
clc
close all

no_tit = 1;

input_options = struct;
input_options.show_tit = ~no_tit;
input_options.rank_regression = 0;

plot_transition_dist_also = 0;                     % (0)
listLength_inclusion_criteria_spans_both_task = 0; % (0) if 1 then excludes any subject who has ANY list < wL
effects_in_win1_only = 0;                          % (0)

if ~exist('DSCoverlapZ')
    
    % ----------
    % the epoch length used in the analysis itself
    %wL = 15;   % winLength is set to the minimum list length over both ANIMAL & LETTER tasks (i.e. no subj exclusions)
    wL = 32;    % winLength is set to the minimum list length over ANIMAL task (i.e. will need to exclude subjects in letter task if doing a direct comparison between tasks)
    
    % ----------
    task = 'animal';
    %task = 'letter';
    
    % ----------
    distance = 'semantic';
    %distance = 'lexical';
    
    % ----------% ----------% ----------
    fileToLoad = sprintf('travSalesman_%s_%s_win%i.mat', task, distance, wL);
    load(fileToLoad);
    % includes iSja, analysis_options
    % ----------% ----------% ----------
else
    fileToLoad = 'Current analysis, no new file loaded';
end

%--------------------------------------------------------------------------
% subject inclusion (those who have a minimum list length on both lists)
clear conId patId
participant_list_module_repo     % re-laod the sample info (conId, patId)
conId_orig = conId;
patId_orig = patId;

% analysis-approprite list lengths (both tasks)
if analysis_options.allow_perseverations
    error('travelling salesman analysis doesn''t allow duplicates - something has gone wrong')
else
    load('NumberAnimalsBothTasks_noDup_forTS.mat')
end

if ~listLength_inclusion_criteria_spans_both_task
    ex_subj = find(numAnimals_both_tasks(:, analysis_options.animals +1) < analysis_options.winLength);    % <-- exclude only skipped subjects from present analysis only
else
    ex_subj = find(any(numAnimals_both_tasks < analysis_options.winLength, 2));                           % <-- exclusion criteria spanning both tasks
end

if ~isempty(ex_subj), warning('Excluding further subjects -- CHECK!'), end
conId = setdiff(conId_orig, ex_subj);
patId = setdiff(patId_orig, ex_subj);


%%% --------------------------------------------------------------------------
figure()
set(gcf, 'Units', 'point', 'Position', [200 600 250, 800])

%----------------------------------
% z(1-step distance - optimal)
%----------------------------------
global_divergence_name = 'Global optimality divergence (z)';
disp('************************************')
disp(global_divergence_name)

subplot(3,1,1)
if ~effects_in_win1_only
    effect = z;
else
    effect = cellfun(@(x) x(1), z_byWin);
end
data = [];
data{1} = effect(conId,1);
data{2} = effect(patId,1);
[~, p] = patient_control_bargraph_scatter(data, '');
if no_tit, title(''), end
ylabel({global_divergence_name})


%----------------------------------
% z(1-step distance - optimal) vs behaviour
%----------------------------------
disp('************************************')
disp(sprintf('%s v list length', global_divergence_name))
subplot(3,1,2)
two_group_scatter(effect, numAnimals', conId, patId, global_divergence_name, 'List length', input_options);

%----------------------------------
% z(transition [geodesic] distance mismatch)
%----------------------------------
tit = { {'Local optimality divergence (z)'}, 'transition distance corr', 'transition distance KLD'};
nn = 1; % which traj overlap measure?
disp('************************************')
disp(tit{nn})
subplot(3,1,3)
if ~effects_in_win1_only
    effect = distMismatchZ(:,nn);
else
    effect = cellfun(@(x) x(nn, 1), allWin_distMismatchZ);
end
data = [];
data{1} = effect(conId,1);
data{2} = effect(patId,1);
[h p ts] = patient_control_bargraph_scatter(data, '');
if no_tit, title(''), end
ylabel(tit{nn})


% ----------------------------------------------------------------------
% ----------------------------------------------------------------------
% Correlations with symptoms

import_align_clinical_scores_repo
type = 'Spearman';

%--------
% Negative symptoms
%---------
%clinical   [panssP, panssN, panssG, MADRS]
varID = 2; clinV = new_clin(:, varID); cvn =  clinName{varID};
[conId_corr, patId_corr] = get_inc(conId, patId, clinV, 1);


figure()
set(gcf, 'Position', [100 0 170 170])

%----------------------------------
% z(1-step distance - optimal) vs negative symptoms
%----------------------------------
two_group_scatter(z, clinV, conId_corr, patId_corr, 'Total distance vs. optimal (z)',  cvn, analysis_options);
[rho, p] = corr(z(patId_corr), clinV(patId_corr), 'type', type);
[rho_partial, p_partial] = partialcorr(z(patId_corr), clinV(patId_corr), numAnimals(patId_corr)', 'type', type);
if ~no_tit, title({sprintf('%s r(%i) = %.2f, p = %.2f', type, length(patId_corr)-2, rho, p), ''}), end
disp('Clincial correlation:')
disp(sprintf('%s r(%i) = %.3f, p = %.3f', type, length(patId_corr)-2, rho, p))
disp(sprintf('partial out num. r = %.3f, p = %.3f', rho_partial, p_partial))

%---------------------------------------------------------------------
%--------------------------------------------------------------------------
disp(' ')
disp(sprintf('Loaded new file: %s', fileToLoad))
if ~listLength_inclusion_criteria_spans_both_task, disp('Excldued subjects meeting length criteria on this task alone'), else, warning('Excluded subjects meeting length criteria on both lists'), end
disp(sprintf('Window length: %i, number controls = %i, number patients = %i', analysis_options.winLength, length(conId), length(patId)))
if effects_in_win1_only, warning('Effects in 1st data window only, not averaged over windows'), end