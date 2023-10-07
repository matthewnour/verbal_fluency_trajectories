% 1. word embedding on the loaded word lists: allAn_split --> allAn, eAll (embedding_module)
% 2. inter-word distances as per the analysis_options.multiComponentOption -->  dist_matrix (embedding_module)
% 3. transformations (e.g. zscore, range rescaling): dist_matrix --> weightedAdjMAtrix (get_semantic_distances.m)

embedding_module_repo
disp('Semantic distances')

disp(sprintf('... Rescaling range of (SEMANTIC) distances from %.2f to %.2f', analysis_options.norm_range(1), analysis_options.norm_range(2)));
dist_matrix = reshape( normalize(dist_matrix(:), 'range',  analysis_options.norm_range), [length(dist_matrix), length(dist_matrix)]);
% cosine distances > 1 occur when words have a greater than 90 degree angle between their vector representations), possible as negative values allowed in w2v
weightedAdjMatrix = 1 - dist_matrix;


