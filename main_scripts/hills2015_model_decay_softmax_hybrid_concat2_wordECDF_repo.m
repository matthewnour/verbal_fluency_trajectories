function [negLogLik prWord_log] = hills2015_model_decay_softmax_hybrid_concat2_wordECDF(best_params, obs);
% SOFTMAX local search model (allows saliencies <= 0)
%
% _vers2 does not explicitly model a 'general' saliency with
% semantic_weighting [0, 1] to arbitrate semantic vs lexical similarity.
% Instead it directly fits a semantic and lexical beta to each task (which
% captures the general and specific component)
%
% _concat version takes in the concatenated [LETTER, CATEGORY] list for a single participant
%
% The W(t-1) similarity data is transformed vie the empirical CDF on each
% trial such that the values reflect the 'word-specific' similarity
% percentile w.r.t all words (not the percentile w.r.t. all word-word pairs
% in the lexicon)
% Throughout, task order is [Letter, Category]
%
% param(1) = lexical_saliency_LETTERtask
% param(2) = semantic_saliency_LETTERtask
% param(3) = lexical_saliency_CATEGORYtask
% param(4) = semantic_saliency_CATEGORYtask
% param(5) = exponential decay of all saliency for items t-2, back
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

% exponentially decreasing saliencies (one pair per task)
saliency_lexical = cell(2,1); % {task, 1}
saliency_semantic = cell(2,1);
for mem = 1:memFactor
    saliency_lexical{1}(mem) = [best_params(1)*( best_params(5) ^ (mem - 1))]; % letter task
    saliency_semantic{1}(mem) = [best_params(2)*( best_params(5) ^ (mem - 1))];

    saliency_lexical{2}(mem) = [best_params(3)*( best_params(5) ^ (mem - 1))]; % category task
    saliency_semantic{2}(mem) = [best_params(4)*( best_params(5) ^ (mem - 1))];
end

inc_duplicates = obs{4};

starts = [1 obs{5} length(obs{1})+1];
prWord_log  = [];

for task_loop = 1:length(obs{2}) % [letter, animal]

    this_id = obs{1}(starts(task_loop) : starts(task_loop+1)-1);

    % item*item :SIMILARITY in lexicon without repeats (over all subjects)
    sim_matrix1 = obs{2}{task_loop}(:,:,1);  % LEXICAL
    sim_matrix2 = obs{2}{task_loop}(:,:,2);  % SEMANTIC

    histID = nan(length(this_id ), memFactor);
    simToAllWords1 = nan(size(sim_matrix1,1), length(this_id ), memFactor);
    simToAllWords2 = nan(size(sim_matrix2,1), length(this_id ), memFactor);

    % for each response number, what were the ids of the last 'memFactor' words
    % (w.r.t. the full item*item sim matrix (over combined sample))
    for nn =  1:length(this_id )

        past = [(nn-1):-1:(nn-memFactor)];
        past(past<=0) = [];
        histID(nn, 1:length(past)) = this_id(past); % ID of the last mem words at this 'trial'

        % similarity of the words in the memory bank (mem) at each trial, to all words in the lexicon
        %   dim1 = all words in lexicon, [word, word] similarity matrix
        %   dim2 = current trial
        %   dim3 = words in memory on that trial (1 if memFactor = 1)
        for WW = 1:size(sim_matrix1,1) % for all potential words in the lexicon
            simToAllWords1(WW, nn, 1:length(past)) = sim_matrix1(WW, histID(nn, 1:length(past))); % [numWord, numTrial, similarityToWordsInMemory] ... lexical
            simToAllWords2(WW, nn, 1:length(past)) = sim_matrix2(WW, histID(nn, 1:length(past))); % [numWord, numTrial, similarityToWordsInMemory] ... semantic
        end


        % word-specific ECDF transform
        for pp = 1:length(past) % separately for each word in the memory

            % LEXICAL SIMILARITY
            old_sim_vector = simToAllWords1(:, nn, pp);
            [ff, xx] = ecdf(old_sim_vector);
            [temp_C, ~, temp_iC] = unique(old_sim_vector);
            assert(all(xx(2:end) == temp_C), 'error in ecdf');  % first entry of ff is 0
            reverse_mapping = temp_iC + 1;                      % first entry of ff is 0
            new_sim_vector = ff(reverse_mapping);               % no zero
            assert((corr(old_sim_vector, new_sim_vector, 'Type', 'spearman')-1)<10^-14, 'error in ecdf')
            simToAllWords1(:, nn, pp) = new_sim_vector;


            % SEMANTIC SIMILARITY
            old_sim_vector = simToAllWords2(:, nn, pp);
            [ff, xx] = ecdf(old_sim_vector);
            [temp_C, ~, temp_iC] = unique(old_sim_vector);
            reverse_mapping = temp_iC + 1; % first entry of ff is 0
            new_sim_vector = ff(reverse_mapping);
            assert((corr(old_sim_vector, new_sim_vector, 'Type', 'spearman')-1)<10^-14, 'error in ecdf')
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
        num_lex = simToActualWord1(nn,:);
        num_sem = simToActualWord2(nn,:);

        if inc_duplicates
            remaining_words = setdiff(1:size(sim_matrix1,1), this_id((nn-1))); % remaining words (all excluding the just-emitted word)
            denom_lex =  squeeze(simToAllWords1(remaining_words,nn, :));
            denom_sem =  squeeze(simToAllWords2(remaining_words,nn, :));
        else
            remaining_words = setdiff(1:size(sim_matrix1,1), this_id(1:(nn-1))); % remaining words, including the emitted item on this trial
            denom_lex =  squeeze(simToAllWords1(remaining_words,nn, :));
            denom_sem =  squeeze(simToAllWords2(remaining_words,nn, :));
        end

        %% SALIENCY WEIGHTED ACTIVATIONS (specific saliencies for each similarity type)
        salienceWeigthed = [];
        salienceWeigthedDenom = [];

        for numProd = 1:sum(~isnan(num_lex)) % how many items were in the memory bank

            salienceWeigthed(numProd) = exp(...
                num_lex(numProd)*saliency_lexical{task_loop}(numProd) + ...
                num_sem(numProd)*saliency_semantic{task_loop}(numProd) ...
                ); % softmax implementation

            salienceWeigthedDenom(:,numProd) = exp( ...
                denom_lex(:,numProd).*saliency_lexical{task_loop}(numProd) + ...
                denom_sem(:,numProd).*saliency_semantic{task_loop}(numProd)...
                );

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
