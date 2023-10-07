function [conId_corr, patId_corr] = get_inc(conId, patId, clinV, patOnly)
% [conId_corr, patId_corr] = get_inc(conId, patId, clinV, patOnly)
%
% returns the indices of conId and patId that are non-nan in clinV
% patOnly is 0/1 depending on whether you want to include controls at all (e.g. clinical plots)
% designed to provide conId and patId input into two_group_scatter
conId_corr =  setdiff(conId, find(isnan(clinV)));
if patOnly, conId_corr = []; end
patId_corr = setdiff(patId, find(isnan(clinV)));
end