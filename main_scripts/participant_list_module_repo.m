a_priori_exclusion = [220]; 
warning(sprintf('Hard coded a priori exclusion: %i', a_priori_exclusion))
% outlier on number of duplicates in 5 min list, both tasks 
% iSja(numDuplicates > (median(numDuplicates) + 3.5*(std(numDuplicates))))

ex = find(ismember(iSja, a_priori_exclusion)); 
conId = find(iSja>=200); conId = setdiff(conId, ex);
patId = find(iSja<200); patId = setdiff(patId, ex);

sample = []; smtit = [];
sample{1} = patId; smtit{1} = 'patient';
sample{2} = conId; smtit{2} = 'control';
sample{3} = [patId conId]; smtit{3} = 'all';

mapToMEG = [15,9,12,23,1,26,2,4,5,20,7,10,11,13,14,16,58,17,18,19,21,22,24,25,27,28,30,31,34,33,35,36,37,38,39,40,41,42,43,48,44,45,46,47,49,50,51,52,53,54,55,56,57];
% to slot the subjects into the MEG order (last subject did not have MEG)
% a = [iSja' best_params]; b = nan(58,size(a,2)); b(mapToMEG,:) = a;
