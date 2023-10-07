%% The main modelling wrapper script.
% Combining lexicographic and semantic distances
% From both animal and letter fluency tasks
%
% Matthew Nour, London, December 2020
%--------------------------------------------------------------------------

clc
clear
close all

%--------------------------------------------------------------------------
% Choose and load semantic word embedding
%--------------------------------------------------------------------------
analysis_options = struct;

% can we re-use an existing embedding?
if exist('emb', 'var')
    disp('Using pre-loaded embedding')
else
    warning('loading emb from scratch')
    disp('loading fastText')
    emb = fastTextWordEmbedding; % fastText (Facebook AI research), 1 million word vectors trained on Wikipedia 2017, UMBC webbase corpus and statmt.org news dataset (16B tokens).
end

% --------------------------------------------------------------------------
% Paths
%--------------------------------------------------------------------------
repo_home = '';
addpath(genpath(repo_home))

saveit = 1;
saveDir = [repo_home '/modelling_output'];

%--------------------------------------------------------------------------
% WORD LIST PROCESSING SETTINGS
% --------------------------------------------------------------------------
% DATA TO ANALYSE, LIST LIMIT, LIST CLEANING

% category vs letter fluency
analysis_options.animals = 1;

% orthographic vs semantic association
%analysis_options.distance_metric = 'lexical';
analysis_options.distance_metric = 'semantic';

% some other key analysis settings
analysis_options.removeIllegal_animals = 1;      % (1) removes non-animals (category task) from lexicon and subject lists
analysis_options.removeIllegal_letters = 1;      % (1) removes non-P words (letters task) from lexicon and subject lists

analysis_options.allow_perseverations = 1;       % [misnomer, here it is duplicates, not perseverations...
% [1 here, allow repeat words for modelling]

% normalisation of pairwise distances
analysis_options.norm_range = [0, 0.99];

%--------------------------------------------------------------------------
% MODELS (all softmax)
%--------------------------------------------------------------------------
% ECDF = empitical cummulative distribution funciton
% Word-specific ECDF does this transformaiton on the trial (word) specific
%   distance distribution (i.e. only considering distances to the most
%   recently uttered word)

options=optimset('Algorithm','interior-point','TolFun',1e-6,'MaxIter',1e5, 'Display', 'notify');  % for fmincon

modName_log = {};           % long name
sN_log = {};                % short name
which_distances_log = {};   % for 2P models

% 3 paramter models [general salience, and a task-specific weighting]
modName_log{1} = 'Hills2015, exponential decay (softmax) hybrid concatenated word-specific ecdf';       sN_log{1} = '3P_SM_WSecdf';         

% 4 paramter models [concat 2] [a pair of lex/sem saliencies for each task]
modName_log{2} = 'Hills2015, exponential decay (softmax) hybrid concatenated 2 word-specific ecdf';     sN_log{2} = '4P_SM_WSecdf';     

% 2 param models [each task includes a single salience] - can be used to capture single-salience estimates
modName_log{3} = 'Hills2015, exponential decay (softmax) concatenated LEX word-specific ecdf';          sN_log{3} = '2PLEX_SM_WSecdf';  which_distances_log{3} = [1 1];   
modName_log{4} = 'Hills2015, exponential decay (softmax) concatenated SEM word-specific ecdf';          sN_log{4} = '2PSEM_SM_WSecdf';  which_distances_log{4} = [2 2];   
modName_log{5} = 'Hills2015, exponential decay (softmax) concatenated TASK word-specific ecdf';        sN_log{5} = '2PTASK_SM_WSecdf';   which_distances_log{5} = [1 2]; 

which_distances_log{length(modName_log)+1} = []; % blank for all non-filled

%% --------------------------------------------------------------------------
% ANALYSIS LOOPS
%   Model loop
%--------------------------------------------------------------------------
for modelLoop = 1:length(modName_log)
    
    %--------------------------------------------------------------------------
    % Model-specific settings, overwritten each loop
    modName = modName_log{modelLoop};                   analysis_options.modName = modName;
    sN = sN_log{modelLoop};                             analysis_options.sN= sN;
    which_distances = which_distances_log{modelLoop};   analysis_options.which_distances= which_distances; % empty cells for non-2P models
    
   
    %--------------------------------------------------------------------------
    % prepare arrays for this model
    similarity_log = cell(2,1);     % {letter, animal}(word, word, distance)    where distance = [lexicographic, semantic]
    list_log = cell(2,1);
    numAnimals_log = cell(2,1);
    allAn_log = cell(2,1);
    no_embedding = cell(2,1);
    
    %--------------------------------------------------------------------------
    % Get lists and distances for each task (nested inner loop)
    for task_loop = 1:2  % [letters, then animals]
        
        % task [LETTERS, ANIMALS]
        analysis_options.animals = task_loop - 1; % [letters, then animals]
        
        if analysis_options.animals
            suffix = 'animal'; % task_loop == 2
        else
            suffix = 'letter'; % task_loop == 1
        end
        
        disp('***************************************************************')
        disp(['** LOADING AND PREPROCESSING TASK: ' suffix]);
        disp('***************************************************************')
        
        %-------------------------------------------------------------------------
        %TASK-SPECIFIC DATA LOAD
        data_load_and_preprocess_repo    % generates numAnimalsOrig, allAn == allAn_untouched, TXTa
        participant_list_module_repo
        
        %-------------------------------------------------------------------------
        % SEMANTIC word embeddings, distance matrix and dimensionality reduction
        inc_words = [];                     % non-embedded indices defined in embedding_module
        get_semantic_distances_repo
        
        % store
        semantic_weightedAdjMatrix = weightedAdjMatrix;
        semantic_dist_matrix = dist_matrix;
        clear dist_matrix weightedAdjMatrix
        
        %-------------------------------------------------------------------------
        % LEXICOGRAPHIC word embeddings, distance matrix
        get_lexicographic_distances_repo
        
        % qc
        %-------------------------------------------------------------------------
        % remove superfluous words in the loaded distance matrix
        assert(all(ismember(allAn_untouched, strDist.allAn_untouched)), 'loaded lexicographic distance matirx does not contain all words in vocabulary');
        redundant_words = ~ismember(strDist.allAn_untouched, allAn_untouched);
        if any(redundant_words)
            warning(sprintf('Number of words in loaded lexicographic matrix that are not in the vocabulary: %i', sum(redundant_words)))
            strDist.allAn_untouched = strDist.allAn_untouched(~redundant_words);
        end
        
        % Check perfect correspondance between lexicographic and semantic word lists
        assert(  all(strcmp(allAn_untouched, strDist.allAn_untouched)), 'mismatch in word set for freshly generated(from data_load_and_preprocess) and pre-saved(lexical distance) word lists');
        assert(  all(strcmp(allAn, strDist.allAn_untouched(inc_words))), 'mismatch after removing non-embedded words by (semantic) embedding_module')
        
        %--------------------------------------------------------------------------
        % Letter task clean-up
        non_p_strings = {};
        if analysis_options.removeIllegal_letters & task_loop==1 % letters task
            
            disp('...removing non-P words from both semantic and lexical distance matrices')
            
            % find non-P word IDs w.r.t. allAn (i.e. wr.t. the lexical_dist_matrix)
            p_words_id = find(cellfun(@(x) strcmp(lower(x(1)), 'p'), allAn)); 
            
            lexical_weightedAdjMatrix = lexical_weightedAdjMatrix(p_words_id, p_words_id);
            semantic_weightedAdjMatrix = semantic_weightedAdjMatrix(p_words_id, p_words_id);
            
            non_p_strings = allAn(setdiff(1:length(allAn), p_words_id));
            allAn = allAn(p_words_id);
            
        end
        
        %--------------------------------------------------------------------------
        % Directly edit imported lists (can remove but not expand)
        %
        % blank out the illegal words
        for ill = 1:length(non_p_strings)
            f = find(strcmp(TXTa, non_p_strings{ill}));
            TXTa{f} = [];
        end
        
        for ill = 1:length(no_embedding_word_strings)
            f = find(strcmp(TXTa, no_embedding_word_strings{ill}));
            TXTa{f} = [];
        end
        
        % Merge / uniform spellings
        load('merge_words.mat', 'replaced')
        for n = 1:length(replaced)
            [i,j] = ind2sub([size(TXTa, 1), size(TXTa,2)], find(strcmp(TXTa, replaced{n}{1,1})));
            if ~isempty(i)
                TXTa{i, j} = replaced{n}{1,2};
            end
        end
        
        %--------------------------------------------------------------------------
        disp(' --- ')
        disp('This task word lists and distance matirces done')
        disp(sprintf('  Number of words in semantic distance matrix = %i, and lexical distance matrix = %i', length(semantic_weightedAdjMatrix), length(lexical_weightedAdjMatrix)))
        disp([suffix sprintf('   lexical similarity matrices range from %.3f to %.3f', min(lexical_weightedAdjMatrix(:)), max(lexical_weightedAdjMatrix(:)))]);
        disp([suffix sprintf('  semantic similarity matrices range from %.3f to %.3f', min(semantic_weightedAdjMatrix(:)), max(semantic_weightedAdjMatrix(:)))]);
        
        %--------------------------------------------------------------------------
        % store in task-specific arrays
        similarity_log{task_loop} = cat(3, lexical_weightedAdjMatrix, semantic_weightedAdjMatrix); % task-specific [word, word, distance] sim matrices (lex, sem in dim3)
        list_log{task_loop} = TXTa;
        numAnimals_log{task_loop} = numAnimalsOrig;
        allAn_log{task_loop} = allAn;
        no_embedding{task_loop} = no_embedding_word_strings;
        no_p{task_loop} = non_p_strings;
        
        % clear the semantic distance variables
        clear eAll_mean  D2w2v Ds_pca score TXTa numAnimalsOrig allAn lexical_weightedAdjMatrix semantic_weightedAdjMatrix no_embedding_word_strings non_p_strings
    end % cycle over tasks (inner loop)
    
    disp('BOTH TASK DATA LOAD AND PRE-PROCESS ... done')
    disp('--------------------------------------------------')
    
    %--------------------------------------------------------------------------
    % subject-level modelling FOR BOTH TASKS (CONCAT)
    nSubj = length(numAnimals_log{1});
    
    % arrays (modelling and sub-specific lists)
    id = cell(2, nSubj);                % ARRAY OF THE RESPONSE IDS W.R.T. allAn
    list_log_clean = cell(2,  nSubj);   % ARRAY OF RESPONSE ITEMS ENTERED INTO MODEL (AFTER CLEANING)
    num_illegal_words = nan(2, nSubj);  % any words that have been removed for [non animals, non words, non P, duplicates according to criteria]
    
    % modelling array
    negLogLik = [];
    best_params = [];
    prWord = cell(nSubj ,1);
    disp('Modelling started')
    
    for iSj = 1:nSubj
        
        disp(sprintf('Subject %i started', iSj));
        
        for task_loop = 1:length(list_log)
            
            % this subject's word responses for this task
            this_sub_responses = list_log{task_loop}(1:numAnimals_log{task_loop}(iSj), iSj);
            
            % remove illegal words from subject list ...  already removed from allAn and distance/adj matrices
            disp('...Removing all illegal words from subject lists')
            index_non_word = find(cellfun(@(x) any(strcmp(x, no_embedding{task_loop} )), this_sub_responses));
            index_non_P =    find(cellfun(@(x) any(strcmp(x, no_p{task_loop} )),         this_sub_responses));
            illegal = unique([index_non_word; index_non_P]); % unique ID
            this_sub_responses = this_sub_responses(~ismember(1:length(this_sub_responses), illegal));
            
            % deal with the hard-coded removals (blanks) in data_load_and_preprocess (i.e. non-animal 'blanks')
            blank = cellfun(@(x) isempty(x), this_sub_responses);  % logical
            this_sub_responses = this_sub_responses(~blank);
            
            % now with the cleaned subject response, find the corresponding ID of allAn
            id{task_loop, iSj} = cellfun(@(x) find(strcmp(x, allAn_log{task_loop})), this_sub_responses);
            
            if ~analysis_options.allow_perseverations
                % remove ALL duplicates
                disp('...Removing all duplicates from subject lists')
                [id{task_loop, iSj}, iA, ~] = unique(id{task_loop, iSj}, 'stable');
                numDuplicates = length(id{task_loop, iSj}) - length(iA);
            else
                % remove only consecutive perseverations
                disp('...Removing only consecutive duplicates (perseverations) from subject lists')
                consecDup = find(diff(id{task_loop, iSj}) == 0);
                id{task_loop, iSj}(consecDup) = [];
                numDuplicates = length(consecDup);
            end
            
            % log the final list and the number of words removed for each subject and task
            list_log_clean{task_loop, iSj} = allAn_log{task_loop}(id{task_loop, iSj});
            num_illegal_words(task_loop, iSj) = length(illegal) + sum(blank) + numDuplicates;
            
        end % within-subj task loop
        
        % Modelling sits within the subject loop
        disp(['... subj ' num2str(iSj) ' start modeling with fmincon'])
        lexical_modeling_wrapper_repo
        
    end %iSj
    

    %-------------------
    % save each model, once all subjects completed
    saveName = [sN '_LEX__meanLevenshtein___SEM_mean.mat'];
    if ~analysis_options.allow_perseverations
        saveName = [saveName '__noDup'];
    end
    

    if saveit
        cd(saveDir)
        save(saveName, 'best_params', 'pT', 'analysis_options', ...
            'modName', 'conId', 'patId', 'similarity_log', ...
            'list_log', 'list_log_clean', 'num_illegal_words', 'id', 'numAnimals_log', 'allAn_log', 'no_embedding', 'no_p', 'prWord', 'negLogLik', 'sN')
        disp(['saved ' saveName])
    end
    
end % model loop
