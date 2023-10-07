function out = map_MEG_to_lexical(in, meg_list, lex_list)
%   in is the [1:57 or 58, var] matrix of variables in MEG order
%   meg_list is the subject_list in MEG order (1:57)
%   lex_list is the subject_list in lexical order
%   out is the [1:length(lex_list), var] matrix of variables now in lexical order 
%   called by import_align_clinical_scores.m

% map from MEG --> lex numbering
if size(in,1) == 57
    temp_meg = nan(58, size(in, 2));
    temp_meg(1:57, :) = in;
elseif size(in,1) == 58
    temp_meg = in;
else
    error('unexpected numSubj in MEG_in')
end

% Find the mapping from MEG-->lex data
meg_list(58,1) = {'''s123'''};
meg_list =  cellfun(@(x) str2num(x(3:6)), meg_list);

[~, mapping_MEGtoLex] = ismember(meg_list, lex_list);

out = nan(length(lex_list), size(in, 2));

for inn = 1:size(out,1)
    out(inn, :) = temp_meg(find(mapping_MEGtoLex==inn), :);
    assert(meg_list(find(mapping_MEGtoLex==inn)) == lex_list(inn), 'error in meg --> lex snum mapping')
end

end