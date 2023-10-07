function [negLogLik prWord_log] = hills2015_model_decay_softmax_concat_2P_wordECDF(best_params, obs)
% The W(t-1) similarity data is transformed vie the empirical CDF on each
% trial such that the values reflect the 'word-specific' similarity
% percentile w.r.t all words (not the percentile w.r.t. all word-word pairs
% in the lexicon)
% Throughout, task order is [Letter, Category]
%
% SOFTMAX local search model (allows saliencies <= 0)
%
% The 2P models concatenate the LETTER, CATEGORY data, but models each separately with a single saliency parameter
% obs{6} determines whether this is
%   [LEX, LEX]  = [1 1]
%   [SEM, SEM] = [2 2]
%   [LEX, SEM] = [1 2] ... i.e. task-appropriate
%
%
% param(1) = salience_LETTER_task
% param(2) = salience_CATEGORY_task
% param(3) = exponential decay of all saliency for items t-2, back
%
% obs{1} = concatenated [letter, category] list word index of this subject (w.r.t. [allAn_letter, allAn_category])
% obs{2} = {task, 1} array of similarity matrices [allAn, allAn, simType] {dim3 = LEXICAL, SEMANTIC}
% obs{3} = number of items in memory (if ==1 then exp decay (gamma) param not estimated)
% obs{4} = allow_perseverations? [dictates whether we allow repeats in the denominator of the prob calculation]
% obs{5} = the index of the start of the CATEGORY task (w.r.t. obs{1})
% obs{6} = which distances to use for task 1 and 2 (LEX=1, SEM=2)
%
% Matthew Nour, 2020
%--------------------------------------------------------------------------

memFactor = obs{3};  % how many words back do we consider
which_distances = obs{6};

% exponentially decreasing saliencies (one pair per task)
saliency_single = cell(2,1); % {task, 1}
for mem = 1:memFactor
    saliency_single{1}(mem) = [best_params(1)*( best_params(3) ^ (mem - 1))]; % letter task
    saliency_single{2}(mem) = [best_params(2)*( best_params(3) ^ (mem - 1))]; % category task
end

inc_duplicates = obs{4};

starts = [1 obs{5} length(obs{1})+1];
prWord_log  = [];
for task_loop = 1:length(obs{2}) % [letter, animal]

    this_id = obs{1}(starts(task_loop) : starts(task_loop+1)-1);

    % item*item SIMILARITY in lexicon without repeats (over all subjects)
    sim_matrix1 = obs{2}{task_loop}(:,:,which_distances(task_loop));

    histID = nan(length(this_id ), memFactor);
    simToAllWords1 = nan(size(sim_matrix1,1), length(this_id ), memFactor);

    % for each response number, what were the ids of the last 'memFactor' words
    % (w.r.t. the full item*item sim matrix (over combined sample))
    for nn =  1:length(this_id )

        past = [(nn-1):-1:(nn-memFactor)];
        past(past<=0) = [];
        histID(nn, 1:length(past)) = this_id(past); %ID of the last mem words at this 'trial'

        % similarity of the words in the memory bank (mem) at each trial, to all words in the lexicon
        for WW = 1:size(sim_matrix1,1) % for all potential words in the lexicon
            simToAllWords1(WW, nn, 1:length(past)) = sim_matrix1(WW, histID(nn, 1:length(past))); % [numWord, numTrial, similarityToLastThreeWords] ... lexical

        end

        % to implement the word-specific ECDF transform we need to work on dim3
        % (target words in memory, which for memFactor=1 will be just W(t-1)
        % similarities now [0, 1]
        for pp = 1:length(past)

            % SIGLE SIMILARITY
            old_sim_vector = simToAllWords1(:, nn, pp);
            [ff, xx] = ecdf(old_sim_vector);
            [temp_C, ~, temp_iC] = unique(old_sim_vector);
            reverse_mapping = temp_iC + 1;
            new_sim_vector = ff(reverse_mapping);
            simToAllWords1(:, nn, pp) = new_sim_vector;

        end

    end % item nn


    prWord = [];
    prWord(1) = NaN;
    simToActualWord1 = []; % lexical
    for nn = 2:length(this_id ) % for each trial, t

        % similarity of all words in the memory bank to the actually-emitted item
        simToActualWord1(nn,:) = squeeze(simToAllWords1( this_id(nn), nn, :)); % [numTrial, similarityOfActualWordToLast_m_Words] (identical to 'mem')
        num = simToActualWord1(nn,:);

        if inc_duplicates
            remaining_words = setdiff(1:size(sim_matrix1,1), this_id((nn-1))); % remaining words (all excluding the just-emitted word)
            denom =  squeeze(simToAllWords1(remaining_words,nn, :));
        else
            remaining_words = setdiff(1:size(sim_matrix1,1), this_id(1:(nn-1))); % remaining words, including the emitted item on this trial
            denom =  squeeze(simToAllWords1(remaining_words,nn, :));
        end

        % SALIENCY WEIGHTED ACTIVATIONS (specific saliencies for each similarity type)
        salienceWeigthed = [];
        salienceWeigthedDenom = [];

        for numProd = 1:sum(~isnan(num)) % how many items were in the memory bank

            salienceWeigthed(numProd) = exp(num(numProd)*saliency_single{task_loop}(numProd)); % softmax implementation

            salienceWeigthedDenom(:,numProd) = exp(denom(:,numProd).*saliency_single{task_loop}(numProd));

        end

        num = prod(salienceWeigthed);
        denom = sum(prod(salienceWeigthedDenom,2));

        prWord(nn, 1) = num/denom;
    end

    prWord_log = [prWord_log; prWord]; % save the likelihoods for each task

end % task

negLogLik = -1*nansum(log(prWord_log ));

end
