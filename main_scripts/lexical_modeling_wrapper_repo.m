
obs = {};
switch modName
    
       
    case 'Hills2015, exponential decay (softmax) hybrid concatenated word-specific ecdf'
        
        itemsInMemory = 1; 
        initparams = [1 0.9 0.5 0.5]; % [beta_general, gamma, semWeight.LET, semWeight.CAT]
        LB = [0 0 0 0];
        UB = [100 0.99 1 1]; 
        
        concat_list = [];
        concat_list = [id{1, iSj}; id{2, iSj}]; % letter, category
        category_start = length(id{1, iSj}) + 1; % first element new list
        
        obs{1} = concat_list; 
        obs{2} = similarity_log;
        obs{3} = itemsInMemory;
        obs{4} = analysis_options.allow_perseverations; 
        obs{5} = category_start;
        
        pT = {'\beta_{gen BOTH}', '\gamma', '\beta_{sem. weighting LETTER}', '\beta_{sem. weighting CATEGORY}'};
        
        if obs{3} == 1 
            initparams(2) = 0;  
            UB(2) = 0;
            LB(2) = 0;
        end
        
        disp(['... ... ' modName])
        params = fmincon(@hills2015_model_decay_softmax_hybrid_concat_wordECDF_repo, initparams, [], [], [], [], LB, UB, [], options, obs);
        [negLogLik(iSj,1) prWord{iSj}] = hills2015_model_decay_softmax_hybrid_concat_wordECDF_repo(params, obs);
        best_params(iSj,:) = params;
 
     case 'Hills2015, exponential decay (softmax) hybrid concatenated 2 word-specific ecdf' %
        
        itemsInMemory = 1;  
        initparams = [1 1 1 1 0.9]; % [beta_otho.LET, beta_sem.LET, beta_othro.CAT, beta_sem.CAT, gamma]
        LB = [0 0 0 0 0];
        UB = [100 100 100 100 1]; 
        
        concat_list = [];
        concat_list = [id{1, iSj}; id{2, iSj}]; 
        category_start = length(id{1, iSj}) + 1; 
        
        obs{1} = concat_list; 
        obs{2} = similarity_log;
        obs{3} = itemsInMemory; 
        obs{4} = analysis_options.allow_perseverations; 
        obs{5} = category_start;
        
        pT = {'\beta_{lex. LETTER}', '\beta_{sem. LETTER}', '\beta_{lex. CAT}', '\beta_{sem. CAT}', '\gamma'};
        
        if obs{3} == 1 
            initparams(5) = 0; 
            UB(5) = 0;
            LB(5) = 0;
        end
        
        disp(['... ... ' modName]) 
        params = fmincon(@hills2015_model_decay_softmax_hybrid_concat2_wordECDF_repo, initparams, [], [], [], [], LB, UB, [], options, obs);
        [negLogLik(iSj,1) prWord{iSj}] = hills2015_model_decay_softmax_hybrid_concat2_wordECDF_repo(params, obs);
        best_params(iSj,:) = params;
        
        
        
    case {'Hills2015, exponential decay (softmax) concatenated LEX word-specific ecdf', ...
            'Hills2015, exponential decay (softmax) concatenated SEM word-specific ecdf', ...
            'Hills2015, exponential decay (softmax) concatenated TASK word-specific ecdf'};
        
        itemsInMemory = 1; 
        initparams = [1 1 0.9];  % [beta.LET, beta.CAT, gamma]
        LB = [0 0 0];
        UB = [100 100 1]; 
        
        concat_list = [];
        concat_list = [id{1, iSj}; id{2, iSj}]; 
        category_start = length(id{1, iSj}) + 1;
        
        obs{1} = concat_list; 
        obs{2} = similarity_log;
        obs{3} = itemsInMemory; 
        obs{4} = analysis_options.allow_perseverations; 
        obs{5} = category_start;
        obs{6} = which_distances; 
        
        
        pT = {};
        % letter task
        if obs{6}(1) == 1;
            pT{1} = '\beta_{lex. LETTER}';
        else
            pT{1}= '\beta_{sem. LETTER}';
        end
        
        % category task
        if obs{6}(2) == 1;
            pT{2} = '\beta_{lex. CATEGORY}';
        else
            pT{2}= '\beta_{sem. CATEGORY}';
        end
        pT{3} =  '\gamma';
        
        
        if obs{3} == 1 
            initparams(3) = 0;  
            UB(3) = 0;
            LB(3) = 0;
        end
        
        disp(['... ... ' modName])
        params = fmincon(@hills2015_model_decay_softmax_concat_2P_wordECDF_repo, initparams, [], [], [], [], LB, UB, [], options, obs);
        [negLogLik(iSj,1) prWord{iSj}] = hills2015_model_decay_softmax_concat_2P_wordECDF_repo(params, obs);
        best_params(iSj,:) = params;
        
         
end

