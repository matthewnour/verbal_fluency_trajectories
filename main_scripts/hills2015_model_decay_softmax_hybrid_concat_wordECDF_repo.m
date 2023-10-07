function [negLogLik prWord_log] = hills2015_model_decay_softmax_hybrid_concat_wordECDF(best_params, obs);
% SOFTMAX local search model (allows saliencies <= 0)
% but allowing arbitration between lexical and semantic similarity in the 'activation' calculation
% _concat version takes in the concatenated [LETTER, CATEGORY] list for a single participant
% and uses this to fit a general saliency param, along with task-specific weightings
%
% The W(t-1) similarity data is transformed vie the empirical CDF on each
% trial such that the values reflect the 'word-specific' similarity
% percentile w.r.t all words (not the percentile w.r.t. all word-word pairs
% in the lexicon)
%
% Throughout, ask order is [Letter, Category]
%
% param(1) = saliency of W(t-1) [GENRAL, ACROSS BOTH TASKS]
% param(2) = exponential decay of saliency for items t-2, back
% param(3) = LETTER semantic (vs lexicographic) similarity weighting, [0, 1]
% param(4) = CATEGORY semantic (vs lexicographic) similarity weighting, [0, 1]
%    beta_semantic is therefore param(1)*param(3 or 4)      [L or C]
%    beta_lexical is therefore param(1)*(1-param(3 or 4))   [L or C]
%
% obs{1} = concatenated [letter, category] list word index of this subject (w.r.t. [allAn_letter, allAn_category])
% obs{2} = {task, 1} array of similarity matrices [allAn, allAn, simType] {dim3 = LEXICAL, SEMANTIC}
% obs{3} = number of items in memory (if ==1 then exp decay (gamma) not estimated)
% obs{4} = allow_perseverations? [dictates whether we allow repeats in the denominator of te prob calculation]
% obs{5} = the index of the start of the CATEGORY task (w.r.t. obs{1})
%
%
% Matthew Nour, 2020
%--------------------------------------------------------------------------
memFactor = obs{3};

% conserved between tasks
saliency = [];
for mem = 1:memFactor
    saliency(mem) = [best_params(1)*( best_params(2) ^ (mem - 1))];
end

inc_duplicates = obs{4};

starts = [1 obs{5} length(obs{1})+1];
prWord_log  = [];
for task_loop = 1:length(obs{2}) % [letter, animal]

    this_id = obs{1}(starts(task_loop) : starts(task_loop+1)-1);

    sem_weight = best_params(2 + task_loop); % params 3 and 4 [task specific beta_weight]

    % item*item :SIMILARITY in lexicon without repeats (over all subjects)
    sim_matrix1 = obs{2}{task_loop}(:,:,1);  % LEXICAL
    sim_matrix2 = obs{2}{task_loop}(:,:,2);  % SEMANTIC

    histID = nan(length(this_id ), memFactor);
    simToAllWords1 = nan(size(sim_matrix1,1), length(this_id ), memFactor);
    simToAllWords2 = nan(size(sim_matrix2,1), length(this_id ), memFactor);

    % for each response number, what were the ids of the last 'memFactor' words
    % (w.r.t. the full item*item sim matrix (over combined sample))
    for nn =  1:length(this_id )

        past = [(nn-1):-1:(nn-memFactor)]; % nn-1 when memFactor = 1
        past(past<=0) = [];
        histID(nn, 1:length(past)) = this_id(past); %ID of the last mem words at this 'trial'

        % similarity of the words in the memory bank (mem) at each trial, to all words in the lexicon
        % expressed after passing through the empirical CDF for that word's similarities
        for WW = 1:size(sim_matrix1,1) % for all potential words in the lexicon
            simToAllWords1(WW, nn, 1:length(past)) = sim_matrix1(WW, histID(nn, 1:length(past))); % [allWordsInLexicon, allTrials, similarityToLast_m_Words_inTrial] ... lexical
            simToAllWords2(WW, nn, 1:length(past)) = sim_matrix2(WW, histID(nn, 1:length(past))); % [numWord, numTrial, similarityToLast_m_Words] ... semantic
        end

        % to implement the word-specific ECDF transform we need to work on dim3
        % (target words in memory, which for memFactor=1 will be just W(t-1)
        % similarities now [0, 1]
        for pp = 1:length(past)

            % LEXICAL SIMILARITY
            old_sim_vector = simToAllWords1(:, nn, pp);
            [ff, xx] = ecdf(old_sim_vector);
            [temp_C, ~, temp_iC] = unique(old_sim_vector);
            reverse_mapping = temp_iC + 1; % first entry of ff is 0
            new_sim_vector = ff(reverse_mapping);
            simToAllWords1(:, nn, pp) = new_sim_vector;


            % SEMANTIC SIMILARITY
            old_sim_vector = simToAllWords2(:, nn, pp);
            [ff, xx] = ecdf(old_sim_vector);
            [temp_C, ~, temp_iC] = unique(old_sim_vector);
            reverse_mapping = temp_iC + 1; % first entry of ff is 0
            new_sim_vector = ff(reverse_mapping);
            simToAllWords2(:, nn, pp) = new_sim_vector;
        end
    end

    prWord = [];
    prWord(1) = NaN;
    simToActualWord1 = []; % lexical
    simToActualWord2 = []; % semantic
    for nn = 2:length(this_id ) % for each trial, t

        % UNWEIGHTED ACTIVATIONS (EDIT_DIST AND COSINE SIM - arbitrated by weighting param)
        % similarity of all words in the memory bank to the actually-emitted item
        simToActualWord1(nn,:) = squeeze(simToAllWords1( this_id(nn), nn, :)); % [numTrial, similarityOfActualWordToLast_m_Words] (identical to 'mem')
        simToActualWord2(nn,:) = squeeze(simToAllWords2( this_id(nn), nn, :)); % [numTrial, similarityOfActualWordToLast_m_Words] (identical to 'mem')

        % sem_weight is task-specific semantic vs. textEdit arbitration
        num = (1-sem_weight)*simToActualWord1(nn,:) + sem_weight*simToActualWord2(nn,:); % numerator

        if inc_duplicates
            remaining_words = setdiff(1:size(sim_matrix1,1), this_id(nn-1)); % remaining words (all excluding the just-emitted word)
            denom = (1-sem_weight)*squeeze(simToAllWords1(remaining_words ,nn, :)) + sem_weight*squeeze(simToAllWords2(remaining_words ,nn, :));
        else
            remaining_words = setdiff(1:size(sim_matrix1,1), this_id(1:(nn-1))); % remaining words, including the emitted item on this trial
            denom = (1-sem_weight)*squeeze(simToAllWords1(remaining_words,nn, :)) + sem_weight*squeeze(simToAllWords2(remaining_words,nn, :));
        end

        % SALIENCY WEIGHTED ACTIVATIONS (general, conserved over tasks, saliency) (softmax)
        salienceWeigthed = [];
        salienceWeigthedDenom = [];

        for numProd = 1:sum(~isnan(num)) % how many items were in the memory bank

            salienceWeigthed(numProd) = exp(num(numProd)*saliency(numProd)); % softmax implementation
            salienceWeigthedDenom(:,numProd) = exp(denom(:,numProd).*saliency(numProd));

        end

        % PRODUCT OF THE EXPONENTIALLY DECAYED SALIENCY-WEIGHTED ACTIVATIONS OF ITEMS IN MEMORY
        num = prod(salienceWeigthed);
        denom = sum(prod(salienceWeigthedDenom,2));

        % PROBABILITY
        prWord(nn, 1) = num/denom;
    end

    prWord_log = [prWord_log; prWord]; % save the likelihoods for each task

end % task

negLogLik = -1*nansum(log(prWord_log ));

end
