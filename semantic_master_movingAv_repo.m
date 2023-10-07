%% The main non-modelling wrapper script.
%
% Computes:
%   1-step mean distance for list
%   agglommerative clustering
%   Travelling salesman shortest paths, and deviation from these [option tovsave]
%
% In each case takes a sliding window zscore approach
%   sliding window: a list length window is specified to be uniform over all participants (shortest valid list)
%   each metric calculated for each sliding window individually, and as a
%   zscore on 1000 permutations on that list window (starting at '1')
%
%
% Matthew Nour, August 2021

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

saveit = 0;
saveDir = [repo_home '/data'];

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

analysis_options.allow_perseverations = 0;       % [misnomer, here it is duplicates, not perseverations... even when =0, consecutive perseverations ALWAYS removed ]
% (1) - for clustering (and modelling, not done here)
% (0) - for all else

% normalisation of pairwise distances
analysis_options.norm_range = [0, 0.99];

%--------------------------------------------------------------------------
% Clustering options
%--------------------------------------------------------------------------
%clustering (just unique words)
analysis_options.do_clustering = 1;
analysis_options.resolution = 1;                % 1.085, taken from choosing_resol_maximiseRT_prediction
analysis_options.iterations = 1000;             % (100) for consensus clustering
analysis_options.louvainThresh = 0.5;           % (0.5) for consensus clusetring
analysis_options.use_log_RT = 1;                % for RT ~ community switch analysis
analysis_options.visualise_with_umap = 1;       % trajectory plots, clustering solutions
reduction = cell(3,1);

%--------------------------------------------------------------------------
% list-specific shortest paths
%--------------------------------------------------------------------------
analysis_options.doTravellingSalesman = 0; % if 0, load in precomputed (takes v long time to re-compute)
% need to have 'allow_perseverations' turned off

%--------------------------------------------------------------------------
% number list shuffles for z score calculation
%--------------------------------------------------------------------------
% subject list permutations -  semanti_clistering_index and communitySequenceAnalysis list permutations per subject
SCIperm = 1000;   % +1 for ground truth (aka permNum1)

%--------------------------------------------------------------------------
% Other
%--------------------------------------------------------------------------
% plotting
plotit = 1;         % some summary plots

%% --------------------------------------------------------------------------
% Data processing
%--------------------------------------------------------------------------
% 1. load in the transcribed data
disp('***************************************************************')
disp(['** LOADING AND PREPROCESSING ']);
disp('** ');

%-------------------------------------------------------------------------
%TASK-SPECIFIC DATA LOAD
data_load_and_preprocess_repo    % generates numAnimalsOrig, allAn == allAn_untouched, TXTa
participant_list_module_repo

%-------------------------------------------------------------------------
% SEMANTIC word embeddings, distance matrix
inc_words = [];                     % non-embedded indices defined in embedding_module
get_semantic_distances_repo
% generates dist_matrix and weightedAdjMatrix = 1 - dist_matrix;    contains embedding module

% store
semantic_weightedAdjMatrix = weightedAdjMatrix;
semantic_dist_matrix = dist_matrix;
clear dist_matrix weightedAdjMatrix

%-------------------------------------------------------------------------
% LEXICOGRAPHIC pre-computed Levensthein distance
if analysis_options.animals
    suffix = 'animal'; % task_loop == 2
else
    suffix = 'letter'; % task_loop == 1
end

get_lexicographic_distances_repo

% Check perfect correspondance between lexicographic and semantic word lists
assert(  all(strcmp(allAn_untouched, strDist.allAn_untouched)), 'mismatch in word set for freshly generated(from data_load_and_preprocess) and pre-saved(lexical distance) word lists');
assert(  all(strcmp(allAn, strDist.allAn_untouched(inc_words))), 'mismatch after removing non-embedded words by (semantic) embedding_module')

% -------------------------------------------------------------------------
% Further clean up (for both lexicographic and semantic lists)
% Letter task clean-up
non_p_strings = {};
if analysis_options.removeIllegal_letters & ~analysis_options.animals

    disp('...removing non-P words from both semantic and lexical distance matrices')

    % find non-P word IDs w.r.t. allAn (i.e. wr.t. the lexical_dist_matrix)
    p_words_id = find(cellfun(@(x) strcmp(lower(x(1)), 'p'), allAn));

    lexical_dist_matrix = lexical_dist_matrix(p_words_id, p_words_id);
    lexical_weightedAdjMatrix = lexical_weightedAdjMatrix(p_words_id, p_words_id);

    semantic_dist_matrix = semantic_dist_matrix(p_words_id, p_words_id);
    semantic_weightedAdjMatrix = semantic_weightedAdjMatrix(p_words_id, p_words_id);

    non_p_strings = allAn(setdiff(1:length(allAn), p_words_id));
    allAn = allAn(p_words_id);

    % blank out the task-defined illegal words (count added to the hard-coded illegal words in data_load_and_prepocess_repo)
    for ill = 1:length(non_p_strings)
        for iss = 1:size(TXTa, 2)
            f = find(strcmp(TXTa(:,iss), non_p_strings{ill}));
            if ~isempty(f)
                TXTa{f, iss} = [];
                numIllegalWords(iss) =  numIllegalWords(iss)+1;
            end
        end
    end

end



%--------------------------------------------------------------------------
% blank out non-words
numNonWords = zeros(size(TXTa, 2), 1);
for ill = 1:length(no_embedding_word_strings)
    for iss = 1:size(TXTa, 2)
        f = find(strcmp(TXTa(:, iss), no_embedding_word_strings{ill}));
        if ~isempty(f)
            TXTa{f, iss} = [];
            numNonWords(iss) = numNonWords(iss)+1;
        end
    end
end

disp('Number of non-words (no word embedding)')
mmn_group_compar(numNonWords(conId), numNonWords(patId));
disp('Number of illegal words (non-animal or non-p)')
mmn_group_compar(numIllegalWords(conId), numIllegalWords(patId));

% Merge / uniform spellings
load('merge_words.mat', 'replaced')
for n = 1:length(replaced)
    [i,j] = ind2sub([size(TXTa, 1), size(TXTa,2)], find(strcmp(TXTa, replaced{n}{1,1})));
    if ~isempty(i)
        TXTa{i, j} = replaced{n}{1,2};
    end
end


% --------------------------------------------------------------------------
disp(' --- ')
disp('This task word lists and distance matirces done')
tri = ~eye(size(semantic_dist_matrix,1));
[r, p] = corr(semantic_dist_matrix(tri), lexical_dist_matrix(tri)); d = sum(tri(:));
disp(sprintf('Correlation between semantic and lexical inter-item distance matirces, r(%i) = %.2f, p = %.2f', d-2, r, p))
disp(sprintf('Number of words in semantic distance matrix = %i, and lexical distance matrix = %i', length(semantic_weightedAdjMatrix), length(lexical_weightedAdjMatrix)))
disp(sprintf('%s lexical similarity matrices range from %.3f to %.3f', suffix, min(lexical_weightedAdjMatrix(:)), max(lexical_weightedAdjMatrix(:))));
disp(sprintf('%s semantic similarity matrices range from %.3f to %.3f', suffix, min(semantic_weightedAdjMatrix(:)), max(semantic_weightedAdjMatrix(:))));
disp(sprintf('Using %s distances', analysis_options.distance_metric))

%-------------------------------------------------------------------------
% which distance metric?
if strcmp(analysis_options.distance_metric, 'semantic')
    input_matrix = semantic_weightedAdjMatrix; % similarity matrix (1-distance matrix)
    dist_matrix = semantic_dist_matrix;  % distance matrix
elseif strcmp(analysis_options.distance_metric, 'lexical')
    input_matrix = lexical_weightedAdjMatrix;
    dist_matrix = lexical_dist_matrix;
else
    error('Unrecognised distance - use semantic or lexical')
end


%% -------------------------------------------------------------------------
% Clustering (adapted from BCT/2017_01_15_BCT Brain Connectivity Toolbox (Rubinov))
if analysis_options.do_clustering

    consensus_input_matrix = (input_matrix+input_matrix')./2;                       % undireced, weighted
    consensus_input_matrix(logical(eye(size(consensus_input_matrix,1)))) = 0;       % self = 0 (Rubinov and Sporns, 2010)

    %Louvain community detection algorithm to break into communities that maximise whole-network modularity
    disp('Louvain community detection')
    disp(['resolution ' num2str(analysis_options.resolution)]);
    rng(0)
    [finalPartition, numIter, communityAssignment,  fullUnfoldingCommAllocation, modularity] = ...
        consensus_clustering_louvain_lex(consensus_input_matrix, analysis_options.iterations, analysis_options.louvainThresh, 'modularity', analysis_options.resolution);

    %-----------------------------------------------------------
    % Plot the ordered similarity matrix by cluster and exteract the words closest to the centroid
    % we fix the 'paper order' in the clustering_plotting_module.m
    clustOrd = cell2mat(communityAssignment');
    centroids = {};
    for nn = 1:length(communityAssignment)
        centroids{nn} = vec2word(emb, mean(eAll_mean(communityAssignment{nn}, :)), 4); % top 3 words to cluster center
    end


    % -------------------------------------------------------------
    disp(sprintf('Final modularity %.3f', modularity))
    disp(sprintf('Reached after %i iterations of the consensus clustering procedure', numIter))

    % colors for communities
    c = linspecer(length(unique(finalPartition)));
    % reorder colours to match paper convention
    comm_order = finalPartition(cellfun(@(x) find(strcmp(x, allAn)), {'fish', 'dog', 'insect', 'bird', 'tiger'}));
    c_new = [];
    for cc = 1:length(comm_order)
        c_new(comm_order(cc),:) = c(cc, :);
    end
end


%% -------------------------------------------------------------------------
% subject-level analysis

% Arrays
%---------------------------------
% Subject-evel arrays
nSubj = length(numAnimalsOrig);
respByCom_log = cell(nSubj,1); % to store the full 5 min data
id_log = cell(nSubj,1);
timeStamp_log = id_log;
one_step_distances = {};

% effects per sliding window
relDist_byWin = cell(nSubj,1);
DCz_byWin = cell(nSubj,1);
z_communityStats_byWin = cell(nSubj,1);
no_z_communityStats_byWin = cell(nSubj,1);
optimalDistance_byWin = cell(nSubj,1);
normalisedDist_byWin =  cell(nSubj,1);
z_byWin =  cell(nSubj,1);
optimalTravelSalesPath = cell(nSubj,1);

% mean effects over sliding windows
% nSubj, 1] mean z scores over sliWin
DCz = [];                    % [sub * 1], z-score 1-step distance
relDist = [];                % [sub * 1], raw 1-step distance
optimalDistance = [];        %  [sub * 1], t.s. optimal distance
normalisedDist = [];         % [sub * 1], raw 1-step distance - optimal
z = [];                      % [sub * 1], z(raw 1-step distance - optimal)
no_z_communityStats = [];
z_communityStats = [];

% trav salesman
DSCoverlapZ = nan(nSubj, 1);
distMismatchZ = nan(nSubj, 3);          % 3 different transition distance metrics (1st one used in paper)
DSCoverlap_raw = nan(nSubj, 1);
distMismatch_raw = nan(nSubj, 3);  % 3 different transition distance metrics (1st one used in paper)

allWin_DSC_z = cell(nSubj,1); %         logs the window-wise result for each participant
allWin_distMismatchZ= cell(nSubj,1);
allWin_DSC_raw = cell(nSubj,1); %         logs the window-wise result for each participant
allWin_distMismatch_raw= cell(nSubj,1);


%-------------------------------------------------------------------------
numAnimals = numAnimalsOrig;  % list length of each subject
numDuplicates = nan(nSubj, 1);

% Loop 1 - subject level clean up and minimum list length
for iSj = 1:nSubj % loop 1

    % get total 5-min list and clean it
    this_sub_responses = TXTa(1:numAnimals(iSj), iSj);                     % will include [] blanks where illegal/non-p items were removed

    if analysis_options.do_clustering & analysis_options.animals
        clear timeStamp
        load([num2str(iSja(iSj)) '_timeStamp.mat'], 'timeStamp')
        remove_clarification_time
        if any(diff(timeStamp)<=0), error('non consecutively increasing response times'), end
        if iSj == 1; disp('Time stamps loaded'); end
        disp(sprintf('Raw number words: %i      Raw number time stamps: %i     (sub %i)', numAnimalsOrig(iSj), length(timeStamp), iSj))
        if  numAnimalsOrig(iSj) ~= length(timeStamp), warning('Number timestamp mismatch'), end
    end

    % remove non-words and non-P from subject list ...  already removed from allAn and distance/adj matrices
    index_non_word = find(cellfun(@(x) any(strcmp(x, no_embedding_word_strings  )), this_sub_responses));
    index_non_P =    find(cellfun(@(x) any(strcmp(x, non_p_strings)), this_sub_responses));
    illegal = unique([index_non_word; index_non_P]); % unique ID
    assert(isempty(illegal), 'All non-embedded and non-p words should have been set to []')
    this_sub_responses = this_sub_responses(~ismember(1:length(this_sub_responses), illegal)); % redundant
    if exist('timeStamp'), timeStamp(illegal) = []; end

    % clean lists and timestamps
    blanck = cellfun(@(x) isempty(x), this_sub_responses);
    this_sub_responses = this_sub_responses(~blanck); % remove any blank cells from illegal item removal
    if exist('timeStamp'), timeStamp(blanck) = []; end
    numAnimals(iSj) = numAnimals(iSj) - sum(blanck);

    % now with the cleaned subject response, find the corresponding ID of allAn
    id_log{iSj} = cellfun(@(x) find(strcmp(x, allAn)), this_sub_responses);
    if exist('timeStamp'),timeStamp_log{iSj} = timeStamp; end

    if ~analysis_options.allow_perseverations
        % remove ALL duplicates
        [id_log{iSj}, iA, ~] = unique(id_log{iSj}, 'stable');
        if exist('timeStamp'), timeStamp_log{iSj} = timeStamp_log{iSj}(iA); assert(all(cellfun(@(x,y) length(x) == length(y), id_log, timeStamp_log)), 'error in word list and time stamp preprocessing'), end
        numDuplicates(iSj) = numAnimals(iSj) - length(iA);
        numAnimals(iSj) = length(iA); % number post duplication removal
    else
        % remove only consecutive perseverations
        consecDup = find(diff(id_log{iSj}) == 0);
        id_log{iSj}(consecDup) = [];
        if exist('timeStamp'),timeStamp_log{iSj}(consecDup) = []; assert(all(cellfun(@(x,y) length(x) == length(y), id_log, timeStamp_log)), 'error in word list and time stamp preprocessing'), end
        numDuplicates(iSj) = length(consecDup);
        numAnimals(iSj) = numAnimals(iSj) - length(consecDup);
    end

    %----------------------------------------------------------------------
    % Clustering
    if analysis_options.do_clustering
        respByCom_log{iSj} = finalPartition(id_log{iSj})';
    end

    % 1-step distances trajectory
    one_step_distances{iSj} = diag(dist_matrix(id_log{iSj}, id_log{iSj}), 1);

end % 1st subject loop

% minimum window size (not accounting for removal of duplicates, but accounting for illegal words)
minList = min(cellfun(@(x) length(x), id_log));
analysis_options.winLength = minList; % overwrite
disp(['min list length (and window size) = ' num2str(analysis_options.winLength)])

% --------------------------------------------------------------------------
% Visualise initial trajectories
if analysis_options.do_clustering
    initial_trajectory_plots_pnas

    % can run the optimal trajectory plots here (use c_new, above)
    optimal_v_actual_trajectory_plot
end

%% --------------------------------------------------------------------------
% MAIN LOOPS
%
%   --> subj
%      --> win
%         --> perm

ex_subj_this_analysis = [];
bbb_rt = []; bbb_rt_lapse = [];
wF_by_clust = [];

for iSj = 1:nSubj
    disp(sprintf('Subject %i started', iSj));

    %--------------------------------------------------------------
    % go through the list in overlapping sliding windows, advancing 1-step at a time
    % within each window calculate summary effects for 1-step distance, community transitions, and deviation from optimality
    %--------------------------------------------------------------

    for sliWin = 1:( length(id_log{iSj})- (analysis_options.winLength-1) ) % loop 2

        epoch_win = [sliWin:(sliWin+analysis_options.winLength-1)]; % QC at end

        % This segment of the subject's word list
        % i.e. we permute the within-segment order, keeping the segment
        % itself constant between permutations
        id = id_log{iSj}(epoch_win);

        if analysis_options.do_clustering
            respByCom = respByCom_log{iSj}(epoch_win);
        end

        % overwrites each window (temporary stores of intra-window permutations)
        summaryStretch = [];
        totDistCovered = [];
        tempDistMismatch = []; % populate afresh for each window
        tempDSC = [];

        %--------------------------------------------------------------
        % permute lists 1000 times to enable z-scores of these effects also
        %--------------------------------------------------------------
        for nP = 1:(SCIperm+1) % loop 3

            % permute the within-window order, keeping the 1st item fixed
            if nP == 1
                order = 1:analysis_options.winLength;
            else
                order =  [1 1+randperm(analysis_options.winLength-1)];
            end


            %--------------------------------------------------------------
            if analysis_options.do_clustering
                % 1. community trajectory analysis at each window

                this_nP = respByCom(order); % community index

                comDiff = diff(this_nP)~=0; %
                iS = find([true comDiff]);  % indices of start first item is start of stretch
                iE = find([comDiff true]);  % last item is end stretch
                stretches = (iE - iS)+1;    % the number of items in each new community entry (not done community-wise!)

                % length of path stays
                summaryStretch(1, nP) = mean(stretches);
              
                % community-specific returns
                rt_log = [];
                rt_count = [];
                for sm = 1:max(this_nP)
                    this_indices = find(this_nP == sm);

                    if ~isempty(this_indices) % visited this community

                        return_time = diff(this_indices); % 1 = consecutive

                        % non-consecutive indices indicate jumps ('returns')
                        return_time(return_time == 1) = []; % remove the '1' return times, which are within-community transitions

                        % duration of away time (return time)
                        rt_log = [rt_log return_time];                 % vectorised for each community return

                        rt_count = [rt_count length(return_time)];     % number of returns in window for this community
                    end

                end

                if ~isempty(rt_count)
                    summaryStretch(2, nP) = mean(rt_count); % average return per community visited
                else
                    summaryStretch(2, nP) = NaN;
                end

            end % clustering section

            %--------------------------------------------------------------
            % 2.  mean 1-step distance and z-score of this effect
            this_list = id(order); % word index

            % distance traversed to cover the whole item list
            this_distSC = dist_matrix( this_list, this_list);
            totDistCovered(nP) = sum(diag(this_distSC,1)); % [1* numPerms], normalise by list length below

            %--------------------------------------------------------------
            % 3. travelling salesman (optimal transition through each window's items)
            if ~analysis_options.allow_perseverations &&  analysis_options.doTravellingSalesman

                % Find the optimal path through this window's word list
                if nP == 1

                    disp(sprintf( ' ... ... travelling salesman. Subject %i, window number %i of %i', iSj, sliWin, (length(id_log{iSj})-(analysis_options.winLength-1))))

                    tsp;
                    % input:    this_distSC         [winLength, winLength]
                    % output:   distLog, toursLog   [winLength-1, 1] (optimal for each potential end point)

                    [optimalDistance_byWin{iSj}(1, sliWin)  winningPath] = min(distLog);        % length = numAnimals(iSj) the optimal path length(mean over numItems) for this participant (iterating through possible end states)
                    thisOptimal =  [1 toursLog{winningPath}(1:end-2)];                          % optimal permutaion of observed items (w.r.t. intra-window item index), ends with      {this endState}-->{dummy state}-->{1}
                    optimalTravelSalesPath{iSj}(:, sliWin) = thisOptimal;                       % optimal permutation, stating 1, length = winLength

                end

                % Local path overlap analysis
                %   A - asking the degree of perfect 1-step edge overlap
                %   B - asking the softer question of the overlap in item-item distances in both

                % optimalTravelSalesPath{iSj}(:, n)
                % 	optimal permutation of items in epoch |n|
                %   where value of each entry (1:winLength) is the observed (within window) ordering in empirical data

                % Observed word list =      allAn(id)
                % Optimal word list =       allAn(id(thisOptimal))
                % Permuted word list  =     allAn(id(order))

                %----------------------------------------
                % Edge overlap
                %----------------------------------------
                % Populate transition matirx
                % identify each 1-step edge (all in upper triangle, i.e. blind to direction)
                optimal_edges = accumarray(sort([thisOptimal(1:end-1); thisOptimal(2:end)]',2), 1);     % optimal
                actual_edges = accumarray(sort([order(1:end-1)' order(2:end)'],2), 1);                  % observed (1:winLength if np=1, else a random permutation starting at 1)
                optimal_edges( analysis_options.winLength , analysis_options.winLength ) = 0;           % complete square transition matrix
                actual_edges( analysis_options.winLength, analysis_options.winLength ) = 0;

                % vectorise upper triangle
                ut = logical(triu(ones(analysis_options.winLength), 1));
                optimal_edges = optimal_edges(ut);
                actual_edges = actual_edges(ut);

                % edge overlap
                tempDSC(nP) = 2*sum(all([optimal_edges actual_edges],2))...
                    /(sum(optimal_edges) + sum(actual_edges)); % 2*|A & B| / ( |A| + |B| )

                %----------------------------------------
                % Transition distance overlap
                %----------------------------------------
                % ordered 'transition number' distance matrix normalised by list length
                % Assume we are in the 'optimal' order
                optimalDD = squareform( (pdist([1:analysis_options.winLength]', 'cityblock')-1) ...
                    / ( analysis_options.winLength -1) );

                % Now re-order the rows and columns to get to the observed (permuted) 'order'

                [~, I] = sort(thisOptimal);
                % 'I' is a permutation from         [optimal-->ground_truth]
                % 'order' is the 'permuted ground truth' for this permutation
                %
                % we need a permutation 'pp' that permutes 'optimal' order (= 'thisOptimal') so that == 'permuted' order (= 'order')
                pp = I(order);
                actualDD = optimalDD(pp, pp); % observed transition distance (w.r.t. optimal)
                assert(all( thisOptimal(pp) == order ), 'error in mapping optimal-->observed trajectory')
                assert(issymmetric(actualDD), 'remapped matrix not symmetrical')

                %------------------
                % Taking optimalDD as the ground truth transition distance, how far did the observed list deviate from this?

                % 1. The mean 'transition distance deviation' of the actual observed transitions [if 0 then identical to optimal]
                tempDistMismatch(nP,1) = mean(diag(actualDD,1));

                % 2. taking into account the whole upper triangle
                tempDistMismatch(nP,2) = corr(actualDD(ut), optimalDD(ut), 'Type', 'Spearman'); % preserved rank order

                % zero transition distances not allowed
                P1 = (actualDD(ut)+1)/sum(actualDD(ut)+1);           % 'to'
                P2 = (optimalDD(ut)+1)/sum(optimalDD(ut)+1);         % 'from'
                tempDistMismatch(nP,3) = -P1'*log(P2./P1);           % relative entropy (KLD) from optimal to actual


            end % trav salesman analysis
        end % loop 3, over within-list permutation (each list a separate window)
        % ----------------------


        %--------------------------------------------------------------------------
        %--------------------------------------------------------------------------
        % calculate z-scores and other summary effects within each window
        % z(distance) == z(distance - optimal)  

        %-------------------------------------------------
        % 1. community traj (effect * 1)
        if analysis_options.do_clustering
            no_z_communityStats_byWin{iSj}(:,sliWin) = summaryStretch(:,1);
            z_communityStats_byWin{iSj}(:,sliWin) = (summaryStretch(:,1) - nanmean(summaryStretch(:,2:end),2))./nanstd(summaryStretch(:,2:end),[],2);
        end

        %-------------------------------------------------
        % 2. distance [1 * perm]
        temp_relDistAll = totDistCovered/(analysis_options.winLength-1); % mean dist per edge

        relDist_byWin{iSj}(1,sliWin) = temp_relDistAll(1); % mean ground truth distance (or similarity) per 1 step [depends on doSim]
        DCz_byWin{iSj}(1,sliWin) = (temp_relDistAll(1) - mean(temp_relDistAll(2:end)) ) ... % zscored distance (w.r.t. permuted lists)
            / std( temp_relDistAll(2:end));

        %-------------------------------------------------
        % 3. vs optimal trajectory
        if ~analysis_options.allow_perseverations &&  analysis_options.doTravellingSalesman

            % distance - optimal [GLOBAL]
            normalisedDist_byWin{iSj}(:, sliWin) = temp_relDistAll - optimalDistance_byWin{iSj}(1,sliWin);      % ABSOLUTE (mean) deviation from optimal, larger  values = less efficient

            z_byWin{iSj}(1, sliWin) = (normalisedDist_byWin{iSj}(1, sliWin) - mean(normalisedDist_byWin{iSj}(2:end, sliWin), 1 )) ...
                / std(normalisedDist_byWin{iSj}(2:end, sliWin), [], 1 ); % larger values (closer to zero) = closer to random shuffle

            % distance vs optimal [LOCAL - e.g. observed edge overlap and step distance of optimally adjacent words]
            allWin_DSC_z{iSj}(1, sliWin) = ( tempDSC(1) - mean(tempDSC(2:end)) )/ std(tempDSC(2:end));
            allWin_DSC_raw{iSj}(1, sliWin) =  tempDSC(1);

            for nn = 1:size(tempDistMismatch, 2)
                allWin_distMismatchZ{iSj}(nn, sliWin) =  ( tempDistMismatch(1,nn) - mean(tempDistMismatch(2:end,nn)) )/ std(tempDistMismatch(2:end,nn));
                allWin_distMismatch_raw{iSj}(nn, sliWin) = tempDistMismatch(1,nn);
            end

        end

    end % loop 2, over within-sub sliding windows
    % ----------------------
    assert(epoch_win(end) == length(id_log{iSj}), 'windows didn''t reach the end of the list'); % QC


    %--------------------------------------------------------------------------
    %--------------------------------------------------------------------------
    % average sumamry (z) effects across sliding windows
    if analysis_options.do_clustering
        no_z_communityStats(:, iSj) = nanmean(no_z_communityStats_byWin{iSj}, 2);  %  [effect * sub] - no zscore
        z_communityStats(:,iSj) = nanmean(z_communityStats_byWin{iSj},2); %  [effect * sub]
    end

    % average effects over all windows
    DCz(iSj,1) = nanmean(DCz_byWin{iSj});                       % [sub * 1], z-score 1-step distance
    relDist(iSj,1) = nanmean(relDist_byWin{iSj});               % [sub * 1],  raw 1-step distance

    if ~analysis_options.allow_perseverations &&  analysis_options.doTravellingSalesman
        normalisedDist(iSj,1) = mean(normalisedDist_byWin{iSj}(1,:));                       % [sub * 1], ground truth actual - optimal 1-step distance (optimality deviation)
        z(iSj,1) = mean(z_byWin{iSj});                                                      % [sub * 1],  zscore optimality deviation
        optimalDistance(iSj,1) = mean(optimalDistance_byWin{iSj});                          % [sub * 1], optimal 1-step distance

        DSCoverlapZ(iSj,1) =   mean(allWin_DSC_z{iSj});                                     % [sub, 1]   edge overlap
        distMismatchZ(iSj,:)  = mean(allWin_distMismatchZ{iSj},2)';                         % [sub, 3]   transition distance metrics (1-step, correlation_upper_tr,  relative_entroipy_upper_tri)

        DSCoverlap_raw(iSj, 1) = mean(allWin_DSC_raw{iSj});
        distMismatch_raw(iSj,:)  = mean(allWin_distMismatch_raw{iSj},2)';
    end

    % -----------------------------------------------------------------
    % subject level effects (mean over(z) efefct calculated at each sliding window)
    % -----------------------------------------------------------------
    % GLOBAL DISTANCE effects egenrated (mean over sliding windows)
    %   1.  relDist         average 1-step distance per edge
    %   2.  DCz             z(relDist)
    %   3.  normlaisedDist  average (1-step distance - optimal) per edge
    %   4.  z               z(normlaisedDist )    [2. == 4.]
    %
    % LOCAL TRAJECTORY effects
    %   1. DSCoverlapZ      z(edge overlap) vs optimal
    %   2. distMismatchZ    z(step distance of optimally-adjacent word pairs)
    %
    % COMMUNITY EFFECTS
    % ...



    %----------------------------------------------------------------------
    %----------------------------------------------------------------------
    % RT modelling, no sliding window
    %----------------------------------------------------------------------
    %----------------------------------------------------------------------
    if exist('timeStamp')
        % How well do community switches predict time intervals between words?
        % (no perms, no sliding window)

        timingVector = timeStamp_log{iSj} - timeStamp_log{iSj}(1);
        if analysis_options.use_log_RT
            y = log(diff(timingVector));   % entry(1) is RT from 1-->2
        else
            y = diff(timingVector);
        end


        this_list = id_log{iSj};
        this_distSC = dist_matrix( this_list, this_list);
        x1 = normalize(diag(this_distSC, 1), 'center');     % cosine distance (demean), entry(1) is dist from 1-->2
        x2 = linspace(0, 1, length(x1))';                   % proportion through list
        x3 = transpose(diff(respByCom_log{iSj})~=0);       % community switch

        regName = {'semantic distance', 'fatigue (item num)', 'community switch', 'baseline'};
        X = [x1 x2 x3 ones(length(x1),1)];

        bbb_rt(iSj,:) = pinv(X)*y;

    end


end %iSj (loop 1)

if ~analysis_options.allow_perseverations &&  analysis_options.doTravellingSalesman
    assert(max(abs(DCz - z))< 1*10^-10, 'the zscored distance and (distance-optimal) should be the same, see |distance_metrixc_exploration.m|')
end

%--------------------------------------------------------------------------
%--------------------------------------------------------------------------
% save travelling salesman
if saveit & analysis_options.doTravellingSalesman & ~analysis_options.allow_perseverations
    file_name = sprintf('travSalesman_%s_%s_win%i.mat', suffix, analysis_options.distance_metric, analysis_options.winLength);
    saveit = 0; % helps with reusing loaded file
    saveName = fullfile(saveDir, file_name);
    save(saveName, 'iSja',  'relDist', 'DCz', 'normalisedDist', 'z', 'optimalDistance', 'optimalTravelSalesPath', 'z_communityStats',    ...    % GLOBAL / COMMUNITY summary metrics (averaged over windows)
        'relDist_byWin', 'DCz_byWin', 'normalisedDist_byWin', 'z_byWin', 'optimalDistance_byWin','z_communityStats_byWin',  ...                 % effects per window
        'distMismatchZ', 'distMismatch_raw', 'DSCoverlapZ', 'DSCoverlap_raw', 'allWin_DSC_z', 'allWin_DSC_raw', 'allWin_distMismatchZ', 'allWin_distMismatch_raw', ...                                                             % LOCAL DISTANCE overlap metrics
        'analysis_options', 'allAn', 'numAnimals', 'patId', 'conId', 'saveit', 'suffix', 'ex_subj_this_analysis', '-v7.3');
    disp('travelling salesman saved')
end

%-----------------------------------------------------------------------
%% stats and plots
if plotit

    %--------------------------------------------------------------------------
    clear conId patId
    participant_list_module_repo     % re-laod the sample info (conId, patId)
    conId_orig = conId;
    patId_orig = patId;

    % analysis-approprite list lengths (both tasks)
    if analysis_options.allow_perseverations
        load('NumberAnimalsBothTasks.mat')
    else
        load('NumberAnimalsBothTasks_noDup_forTS.mat')
    end

    % exclusion based on list length < winLength
    ex_subj = ex_subj_this_analysis;                                                % <-- exclude only skipped subjects from present analyssi
    conId = setdiff(conId_orig, ex_subj);
    patId = setdiff(patId_orig, ex_subj);


    %--------------------------------------------------------------------------
    % FIG - standard distance metrics
    %--------------------------------------------------------------------------
    % distance measures (1-step)
    tt = ' distance ';
    close all

    figure(),
    set(gcf, 'Units', 'point', 'Position', [200 800 500, 200])

    subplot(1,2,1)
    data = [];
    data{1} = DCz(conId,1);
    data{2} = DCz(patId,1);
    [~, p] = patient_control_bargraph_scatter(data, 'z');
    ylabel('Z-score vs permuted lists')
    xticklabels({'Control', 'Patient'});

    subplot(1,2,2)
    scatter(DCz(patId), numAnimals(patId), 20, 'r', 'filled')
    hold on
    scatter(DCz(conId), numAnimals(conId), 20, 'b', 'filled')
    xlabel(['z(' tt ')'])
    ylabel('number items in 5 minutes')
    grp =[ -0.5*ones(length(patId),1);  0.5*ones(length(conId),1)];
    lm = fitlm([DCz([patId conId]) grp], numAnimals([patId conId]), 'interactions', 'Varnames', {tt, 'group', 'numberWords'})
    [r p] = corr(DCz([patId conId]), numAnimals([patId conId])');
    title({sprintf('Pearson r = %.2f, p = %.4f', r, p), sprintf('Linear model, p = %.4f', lm.Coefficients.pValue(2))});

    %--------------------------------------------------------------------------
    % FIG - cluster trajectories
    %--------------------------------------------------------------------------
    if analysis_options.do_clustering
        plot4paper_clustering_plotting_module
    end

    % --------------------------------------------------------------------------
    % distance prob distribution plot + Number of words
    plot4paper_distance_distributions
    % green = 1-step distances
    % grey = all inter-item distances (subj-specific, concatenated)

    %--------------------------------------------------------------------------
    % simple mean of the 1-step distances
    [~, p] = ttest2(cellfun(@(x) mean(x), one_step_distances(conId)),cellfun(@(x) mean(x), one_step_distances(patId)));
    disp(sprintf('Mean 1-step distance (no windowing), pat v con, %.4f', p))

    %--------------------------------------------------------------------------
    disp(' ')
    disp('Analysis options:')
    disp(['Task: ' suffix])
    disp(sprintf('Window length: %i, number controls = %i, number patients = %i', analysis_options.winLength, length(conId), length(patId)))

end % plotit

