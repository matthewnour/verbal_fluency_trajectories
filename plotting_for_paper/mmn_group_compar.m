
function [h p stats normal] = mmn_group_compar(grp1, grp2)
% [h p stats normal] = mmn_group_compar(grp1, grp2)
% grp1 and grp2 are vectors of [nsubj, 1] for both groups
%
% h p and stats are
%   from a tailed 2-sample ttest if data is normally distributed
%   from Wilcoxon rank sum test for equal medians if not
%
% normal is 1 if the null hypothesis of normality is rejected at alpha = 0.05
%
% Matthew Nour, London, August 2021

% [obs, 1] vector
if size(grp1,1) == 1 && size(grp1,2) > 1
    grp1 = grp1';
end

if size(grp2,1) == 1 && size(grp2,2) > 1
    grp2 = grp2';
end

% compatability with patient_control_bargraph
bardata = {};
bardata{1} = grp1;
bardata{2} = grp2;

% mean ± SEM
[m1 s1] = sem(bardata{1});
[m2 s2] = sem(bardata{2});

% ttest or wilcoxon? - independent samples
%[~, p_parametric] = swtest([bardata{1}; bardata{2}]);
%normal = p_parametric>0.05;

[~, p_parametric1] = swtest([bardata{1}]);
[~, p_parametric2] = swtest([bardata{2}]);
normal = all([p_parametric1 p_parametric2]>0.05);



if ~normal % p < 0.05 (reject null hypothesis of normality)
    %warning(sprintf('Shapiro-Wilk parametric hypothesis test of composite normality, p = %.3f. Outputs are Wilcoxon ranksum not ttest', p_parametric));
    [p, h, stats] = ranksum(bardata{1}, bardata{2}, 'method', 'approximate');
    disp(sprintf('grp1 = %.3f ± %.3f, grp2 = %.3f ± %.3f, z(%i) = %.3f, P = %.3f, Wilcoxon rank sum test, two tailed', m1, s1, m2, s2, length(bardata{1})+length(bardata{2})-2, stats.zval, p));
    p1 = signrank(bardata{1});
    p2 = signrank(bardata{2});
    disp(sprintf('Wilcoxon Signed rank test for median = 0, grp1 p=%.3f,  grp2 p=%.3f (two tailed)', p1, p2));
else
    [h, p, ~, stats] = ttest2(bardata{1}, bardata{2}, 'tail', 'both');
    %disp(sprintf('Shapiro-Wilk parametric hypothesis test of composite normality, p = %.3f', p_parametric));
    disp(sprintf('grp1 = %.3f ± %.3f, grp2 = %.3f ± %.3f, t(%i) = %.3f, P = %.3f, two sample t test, two tailed', m1, s1, m2, s2, stats.df, stats.tstat, p));
    [~, p1] = ttest(bardata{1});
    [~, p2] = ttest(bardata{2});
    disp(sprintf('One sample t-test for mean = 0, grp1 p=%.3f,  grp2 p=%.3f (two tailed)', p1, p2));
end


end