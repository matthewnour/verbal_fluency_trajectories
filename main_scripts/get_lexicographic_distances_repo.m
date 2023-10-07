% PROCESSING LEXICAL DISTANCES

% load in a pre-saved textEdit distance matrix (which becomes default) and
% performs the required checks for correspondance vs the loaded transcribed lists outside this script
disp('Lexicographic distances')

editNameToLoad = ['Levenshtein__' suffix '__indivWords_' 'time' '.mat'];
strDist = load(editNameToLoad);

temp_lexical_dist_matrix = strDist.letter_distance(inc_words, inc_words, :, :); % remove the words with no semantic embedding

item_by_item = mat2cell(temp_lexical_dist_matrix, ones(length(temp_lexical_dist_matrix),1), ones(length(temp_lexical_dist_matrix),1), 3, 3);
% {item, item} cell array of [component_source, component_target] matrices

disp(['...computing inter-item editDist as mean of the inter-component distances'])
lexical_dist_matrix = cellfun(@(x) nanmean(x, 'all'), item_by_item);    % correltion with 'whole' [animal = .38; letter = .90]
lexical_dist_matrix(logical(eye(length(lexical_dist_matrix)))) = 0;     % as per semantic embedding, set self distance to 0 (important for travelling salesman)


disp(sprintf('...Rescaling range of (LEXICAL) distances from %.2f to %.2f', analysis_options.norm_range(1), analysis_options.norm_range(2)));
lexical_dist_matrix = reshape( normalize(lexical_dist_matrix(:), 'range',  analysis_options.norm_range), [length(lexical_dist_matrix), length(lexical_dist_matrix)]);
lexical_weightedAdjMatrix = 1- lexical_dist_matrix;
