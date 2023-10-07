% Loads in all the trained concatenation models from `semantic_master_modelling_concatTasks_repo.m`
% Calculates various group and group*task stats
% Model comparison
%
% Matthew Nour, London, 2021

clear
close all
clc

% --------------------------------------------------------------------------
% Paths
%--------------------------------------------------------------------------
repo_home = '';
addpath(genpath(repo_home))

saveit = 1;
saveDir = [repo_home '/modelling_output'];

cd(saveDir)
nam = dir('*.mat');

fitted_models = {};
for files = 1:length(nam)
    fitted_models_log{files} = nam(files).name;
end

%---------------------------------------------------------------------
% need to compare models using the same data - select word_list inclusion
excluding_duplicates = cellfun(@(x) ~isempty(strfind(x, '__noDup.mat')), fitted_models_log);

fitted_models = fitted_models_log(~excluding_duplicates); inc_dup = 1; % DEFAULT = non-consec duplicates included
%fitted_models = fitted_models_log(excluding_duplicates); inc_dup = 0;  % non-consec duplicates EXCLUDED (_noDup)

%---------------------------------------------------------------------
% Prepare ststs arrays
int_term = nan(length(fitted_models), 4);   % interaction from above
within_paramCorrs = [];                     % within-task correlations between the two within task params ([general, weighting], or [sem, lex])
across_paramCorrs = [];                     % across-task correlations between the sem-lex contrast
r_concat = [];                              % correlation of distance metrics
p_cconcat = [];

maxLL = [];
AIC = [];

params = {}
numParams = [];
%
for fm = 1:length(fitted_models)
    disp(fitted_models{fm})

    % load
    temp = load(fitted_models{fm});
    
    best_params = temp.best_params;
    pT = temp.pT;
    numParams(fm, 1) = sum(~all(diff(best_params) == 0)); % gamma decay is not fitted, such that some models contain fewer free parameters than size(best_params,2)
    modName = temp.modName;
    conId = temp.conId;
    patId = temp.patId;
    
    params{ fm }= temp.pT;
    
    %---------------------------------------------------------------------
    % AIC
    % in the modelling scripts we estimate p(i) = pr(word_i) for each response item (under the winning parameters)
    % then compute the neg log likelihood as  sum(log(p))  (equivalent to  sum(prod(p)  -->    x = rand(100,1); [log(prod(x)), sum(log(x))]    )
    % I then negate this to get the negLL (turning a large negative number to a large positive number)
    % Here I re-negate before computing AIC by the established formula
    maxLL = -1*temp.negLogLik;                                      % maximum LL (not negative LL) of the maximum likelihood parameter settings
    numWords = temp.numAnimals_log{1} + temp.numAnimals_log{2};
    AIC(:, fm) = 2*numParams(fm, 1) - 2*maxLL;                      % AIC = 2k - 2*logLik
    
    %---------------------------------------------------------------------
    % clean
    clear tbl_contrast1 tbl_contrast2 tbl_contrast3 tbl_contrast4 p_wL p_wC r_wL r_wC p_a_contrast r_a_contrast p_a_lex r_a_lex p_a_sem r_a_sem p_a_sum r_a_sum
    clear modName best_params pT numWords maxLL temp % will be loaded in fresh for next model
    
    close all
    
end % model loop


%% Model comparison
close all
listLength_inclusion_criteria_spans_both_task = 0; 

%-------------------------------------------------------------------------
% filter model inclusion (compare all models)
comparison_set = 1:length(params);

%-------------------------------------------------------------------------
% subject inclusion (those who have a minimum list length on both lists)
min_list_length = 33 - (inc_dup == 0); % 32 if not including duplicates
analysis_options.tobi = 0;
iSja = [101,102,103,104,107,108,109,111,112,114,115,117,118,119,120,121,123,124,125,126,127,128,129,130,131,132,202,203,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229];
participant_list_module_repo     % re-laod the sample info (conId, patId)
conId_orig = conId;
patId_orig = patId;

% analysis-approprite list lengths (both tasks)
if inc_dup
    load('NumberAnimalsBothTasks.mat')
else
    load('NumberAnimalsBothTasks_noDup_forTS.mat')
end

% exclusion based on list length < winLength
if listLength_inclusion_criteria_spans_both_task
    ex_subj = find(any(numAnimals_both_tasks < min_list_length, 2));     % <-- exclusion criteria spanning both tasks
else
    ex_subj = [];
end
conId = setdiff(conId_orig, ex_subj);
patId = setdiff(patId_orig, ex_subj);


%-------------------------------------------------------------------------
AIC_filt = AIC(:, comparison_set);
fitted_models_filt = fitted_models(comparison_set);
numParams_filt = numParams(comparison_set);

% sum of AIC over participants
pat_AIC = sum(AIC_filt(patId, :));
con_AIC = sum(AIC_filt(conId, :));
all_AIC = sum(AIC_filt([patId conId], :));

[~, i_con] = sort(con_AIC); [~, i_pat] = sort(pat_AIC); to_use = all_AIC;   tit = 'AIC';

% find model ranking
[~, ranked_order] = sort(to_use);
ranked_models = fitted_models_filt(ranked_order);
table(ranked_models', to_use(ranked_order)' - to_use(ranked_order(1)), numParams_filt(ranked_order), 'VariableNames', {'Model', tit, 'numParams'})

%-------------------------------------------------------------------------
figure();
set(gcf, 'Units', 'point', 'Position', [100 500 600, 400])
barh(to_use(ranked_order)' - to_use(ranked_order(1)))
xlabel(['Summed ' tit ' vs winning model'])
yticks(1:length(to_use))
yticklabels(cellfun(@(x) x(1:6), ranked_models, 'UniformOutput', false)), ytickangle(45)
box off
axis square

%-------------------------------------------------------------------------
% display winning model graphs
winning_model = {};
winning_model = {ranked_models{1}, fitted_models_filt{i_pat(1)}, fitted_models_filt{i_con(1)}}; % [all, pat, con]
table({'all', 'patients', 'controls'}', winning_model', 'VariableNames', {'group', 'winning_model'})

to_load = winning_model{1}; % winning overall
disp(['Showing: ' to_load(1:end-4)])
load(to_load);
conId = setdiff(conId_orig, ex_subj); % ensure same sample
patId = setdiff(patId_orig, ex_subj);


