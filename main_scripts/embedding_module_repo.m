% embed each item into 300D semantic space, and claucltae the cosine distance between each item
eAll = nan(length(allAn_untouched), 300, 3); % item, dimension, part-of-word component

% get the w2v embedding for each component of each item
for n=1:size(eAll,3) % component

    % consider only non-empty components for each item
    iscomponent = ~cellfun(@(x)isempty(x), {allAn_split{:,n}}');
    eAll(iscomponent,:,n) = word2vec(emb, {allAn_split{iscomponent,n}}');  % rows corresponding to emptry components = NaN

end

eAll_component = permute(eAll, [2 1 3]); % dimension * word*component
eAll_component = eAll_component(:,:);    % dimesnion * vectorised(word, component), (VECTORISATION COLUMN-WISE)

% Distance between COMPONENTS in the word2vec 300D space
D_w2v_comp = pdist(eAll_component', 'cosine'); % note transpose to input is item*dimension, distance between the mean vector for each item
Ds_w2v_comp = squareform(D_w2v_comp); % component*component distance matrix (many will be nan, i.e. the distance between blancks)

% construct the distance between each item pair as the mean of the distances between the components of each item.
Ds_w2v_op1 = []; % mean inter-word distance
for i = 1:length(allAn_untouched)
    for j = 1:length(allAn_untouched)

        % construct a item*item distance matrix (by COMPONENT) = 3*3 triangle of between-item similarities
        temp_mat = nan(3);
        temp_mat(1, :) = Ds_w2v_comp(i,                               [j j+length(allAn_untouched) j+(2*length(allAn_untouched))]);
        temp_mat(2, :) = Ds_w2v_comp(i+length(allAn_untouched),       [j j+length(allAn_untouched) j+(2*length(allAn_untouched))]);
        temp_mat(3, :) = Ds_w2v_comp(i+(2*length(allAn_untouched)),   [j j+length(allAn_untouched) j+(2*length(allAn_untouched))]);

        Ds_w2v_op1(i,j) = nanmean(temp_mat, 'all');
    end
end

% how to handle multi-component items, option specification
Ds_w2v = Ds_w2v_op1;
Ds_w2v(logical(eye(length(Ds_w2v)))) = 0; % within-item distances set to 0 (diag already 0 for option 2 and 3)
disp(['...computing inter-item semantic as a mean of the inter-component distances'])

dist_matrix = Ds_w2v;

% Identify words with no embedding representation (i.e. not real words)
no_embedding_id = find(isnan(dist_matrix(:,1)));

disp(sprintf('...removing %i words that have no semantic embedding', length(no_embedding_id)));
no_embedding_word_strings = allAn_untouched(no_embedding_id);

% remove strings that have no embedding
inc_words = setdiff(1:length(dist_matrix), no_embedding_id);

% main
allAn = allAn_untouched(inc_words); % [nWords, 1] cell array of word strings [overwrites allAn]
dist_matrix = dist_matrix(inc_words, inc_words); % [nWords, nWords] distance

% auxillary used by some other scripts
eAll_mean = nanmean(eAll,3);
eAll_mean = eAll_mean(inc_words, :); % [nWords, 300] embedded mean word vectors
