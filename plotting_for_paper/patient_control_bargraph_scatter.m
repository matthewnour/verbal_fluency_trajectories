function [h p stats normal] = patient_control_bargraph_scatter(bardata, yl, vargin)
% [h p stats normal] = patient_control_bargraph(bardata, yl)
% with scatter barplot and mean ± SEM errorbars
%
% bardata is a length 2 cell array of nSubj*1 vectors (controls, then patients)
% Performs Shapiro Wilk test of composite normality on combined data
%
% h p and stats are
%   from a tailed 2-sample ttest if data is normally distributed
%   from Wilcoxon rank sum test for equal medians if not
%
% normal is 1 if the null hypothesis of normality is rejected at alpha = 0.05
%
% yl is the ylabel
%   if using varginis
%       vargin{1} = 1*2 array of color [r g b] vals, if empty set to {'b', 'r'}
%       vargin{2} = {'GRP1', 'GRP2'}
%
% Matthew Nour, London, May 2020

xlog = [1 2];
if nargin == 2
    clr = [0 0 1; 1 0 0]; % pt v con
    grp_nam = {'Control', 'Patient'};
else
    if iscell(vargin) && numel(vargin) == 2
        clr = [vargin{1}{1}; vargin{1}{2}];
        grp_nam = vargin{2};
    end
end

xticks(xlog)
xticklabels(grp_nam)

%figure()
%bhandle = bar(xlog, [mean(bardata{1}) mean(bardata{2})], 'LineStyle', 'none');
%bhandle.FaceColor = 'flat';
%bhandle.CData(1,:) = [0 0 1];
%bhandle.CData(2,:) = [1 0 0];

%errorbar(xlog, [mean(bardata{1}) mean(bardata{2})], [std(bardata{1})/sqrt(length(bardata{1})) std(bardata{2})/sqrt(length(bardata{2}))], '*k'), hold on






% scatter
hold on
for nG = 1:2;
    scatter(xlog(nG)*ones(length(bardata{nG}),1), bardata{nG}, 20, 'MarkerFaceColor', clr(nG,:), 'MarkerFaceAlpha', .5, 'MarkerEdgeColor', 'none', 'jitter', 'on', 'jitterAmount', 0.2) ;
end

% errorbars (1st line gives matching colors)
for nG = 1:2;
    errorbar(xlog(nG), [mean(bardata{nG})], std(bardata{nG})/sqrt(length(bardata{nG})), 'Color', clr(nG,:), 'linestyle', 'none', 'MarkerFaceColor', clr(nG,:), 'Marker', 'o', 'MarkerSize', 2);
    % errorbar(xlog(nG), [mean(bardata{nG})], std(bardata{nG})/sqrt(length(bardata{nG})), 'Color', 'k', 'linestyle', 'none', 'MarkerFaceColor', 'k', 'Marker', 'o', 'MarkerSize', 5);
    hold on
end


xlim([xlog(1)-1, xlog(2)+1])
ylabel(yl)
box off
plot([0 3], [0 0], ':k')


[m1 s1] = sem(bardata{1});
[m2 s2] = sem(bardata{2});

[~, p_parametric] = swtest([bardata{1}; bardata{2}]);
normal = p_parametric>0.05;



if ~normal % p < 0.05 (reject null hypothesis of normality)
    warning(sprintf('Shapiro-Wilk parametric hypothesis test of composite normality, p = %.3f. Outputs are Wilcoxon ranksum not ttest', p_parametric))
    [p, h, stats] = ranksum(bardata{1}, bardata{2});
    disp(sprintf('Control (%.3f ± %.3f) > patient (%.3f ± %.3f) (Wilcoxon rank sum): z(%i) = %.3f, p = %.3f', m1, s1, m2, s2, length(bardata{1})+length(bardata{2})-2, stats.zval, p))
else
    [h, p, ~, stats] = ttest2(bardata{1}, bardata{2}, 'tail', 'both');
    disp(sprintf('Shapiro-Wilk parametric hypothesis test of composite normality, p = %.3f', p_parametric))
    disp(sprintf('Control (%.3f ± %.3f) > patient (%.3f ± %.3f)  (2 tailed 2 sample ttest: t(%i) = %.3f, p = %.3f', m1, s1, m2, s2, stats.df, stats.tstat, p))
end


if normal
    title({sprintf('ttest, t(%i) = %.2f, p = %.2f', length(bardata{1})+length(bardata{2})-2, stats.tstat, p), ''})
else
    title({sprintf('Wilcoxon, z(%i) = %.2f, p = %.2f', length(bardata{1})+length(bardata{2})-2, stats.zval, p), ''})
end

end