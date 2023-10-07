function [lm, r, pval] = two_group_scatter(xx, yy, conId, patId, xl, yl, input_options)
% Plots both groups on the same axis, adds trend line, performs a multiple regression
% [lm, r, pval] = two_group_scatter(xx, yy, conId, patId, xl, yl, input_options)
%
% xx        x variable, vector
% yy        y variable, vector
% conId     blue group (ID w.r.t. xx and yy)
% patId     red group (ID w.r.t. xx and yy)
% xl, yl    labels
% input_options structure
%   show_tit            bool
%   rank_regression     bool
%   plot_separately     bool
%   type                corr type (Spearman, Pearson or if blank then does normality test)
%
% outputs
%   lm      multiple regression, effects coded, contolling for group
%   r and pval  from correaltion over all subj (corr_type)
%
% Matthew Nour, London, September 2021

% populate missing options
if ~isfield(input_options, 'show_tit'), input_options.show_tit = 1; end
if ~isfield(input_options, 'rank_regression'), input_options.rank_regression = 0; end
if ~isfield(input_options, 'plot_separately'), input_options.plot_separately = 0; end

if ~isfield(input_options, 'type')
    if swtest(xx([patId conId])) || swtest(yy([patId conId]))
        input_options.type = 'Spearman';
    else
        input_options.type = 'Pearson';
    end
end



if size(xx, 1) == 1; xx = xx'; end
if size(yy, 1) == 1; yy = yy'; end


%0--------------------------------------------------
% Plot
if ~input_options.plot_separately

    % con in blue, pat in red
    both = 0;
    if ~isempty(conId)
        scatter(xx(conId), yy(conId), 'b', 'filled');
        hold on
        both = both +1;
    end

    if ~isempty(patId)
        scatter(xx(patId), yy(patId), 'r', 'filled');
        hold on
        both = both +1;
    end

    xlabel(xl)
    ylabel(yl)

    % linear trend line (over all subj)
    x = xx([patId conId]);
    y = yy([patId conId]);
    lm_line =fitlm(x, y); % includes default constant
    Xnew = linspace(min(x), max(x), 100);
    [yP, yCI] = predict(lm_line, Xnew', 'Prediction', 'curve'); % predict the 95% CI of the funciton value (curve = default), not the 95% CI of a new observation (observation)
    plot(Xnew, yP, '--k');
    hold on;
    plot(Xnew, yCI, '--k');

    % bivariate correlation
    [r, pval] = corr(xx([patId conId]), yy([patId conId]), 'type', input_options.type);
    % print output
    try
        disp(sprintf('%s correlation %s v %s, r(%i) = %.4f, p = %.4f', input_options.type, xl, yl, length([patId conId])-2, r, pval))
    catch
        disp(sprintf('%s correlation %s v %s, r(%i) = %.4f, p = %.4f', input_options.type, 'x', 'y', length([patId conId])-2, r, pval))
    end

else % plot separately

    for nn = 1:2 % group
        if nn == 1;
            inc = conId;
            c = 'b';
        else
            inc = patId;
            c = 'r';
        end

        subplot(1,2,nn)
        both = 0;
        if ~isempty(inc)
            scatter(xx(inc), yy(inc), c, 'filled');
            hold on
            both = both +1;
        end
        xlabel(xl)
        ylabel(yl)

        % linear trend line (over all subj)
        x = xx([inc]);
        y = yy([inc]);
        lm_line =fitlm(x, y); % includes default constant
        Xnew = linspace(min(x), max(x), 100);
        [yP, yCI] = predict(lm_line, Xnew', 'Prediction', 'curve'); % predict the 95% CI of the funciton value (curve = default), not the 95% CI of a new observation (observation)
        plot(Xnew, yP, '--k');
        hold on;
        plot(Xnew, yCI, '--k');


        % group specific axis lims
        xlim([min(x)-.2*nanstd(x) max(x)+.2*nanstd(x)])
        ylim([min(y)-.2*nanstd(y) max(y)+.2*nanstd(y)])

        % same axis for both groups
        %xlim([min(xx)-.1 max(xx)+.1])
        %ylim([min(yy)-.1 max(yy)+.1])


        % title and axis labels

        %-----------------------------------
        % bivariate correlation
        [r, pval] = corr(xx(inc), yy(inc), 'type', input_options.type);

        if input_options.show_tit
            title({sprintf('r_{%s}(%i) = %.3f, p = %.3f', input_options.type(1), length([inc])-2, r, pval), ''})
        end
        
        % print output
        disp(sprintf('%s correlation %s v %s, r(%i) = %.4f, p = %.4f', input_options.type, xl, yl, length([inc])-2, r, pval))

    end  % group
end  % plot separately

%-----------------------------------
% Regression done (over all participants), regardless of plot separately
% multiple regression (effects coded)
if ~isempty(patId) & ~isempty(conId)
    grp =[ -0.5*ones(length(patId),1);  0.5*ones(length(conId),1)]; % effects coded such that the main effect of slope is the linear relationship when grp=0
    try
        if input_options.rank_regression
            warning('rank regression')
            lm = fitlm([tiedrank(xx([patId conId])) grp], tiedrank(yy([patId conId])), 'interactions', 'Varnames', {xl(1), 'grp', yl(1)});
        else
            lm = fitlm([xx([patId conId]) grp], yy([patId conId]), 'interactions', 'Varnames', {xl(1), 'grp', yl(1)});
        end

        %disp(lm)
    catch
        warning('regression not performed, check why')
    end
end


% title and axis labels
if input_options.show_tit & ~input_options.plot_separately
    if exist('lm')
        title({sprintf('r_{%s}(%i) = %.3f, p = %.3f', input_options.type(1), length([patId conId])-2, r, pval), sprintf('controling for grp p = %.3f', lm.Coefficients.pValue(2))})
    else
        title({sprintf('r_{%s}(%i) = %.3f, p = %.3f', input_options.type(1), length([patId conId])-2, r, pval), ''})
    end
end

if both == 2 && exist('lm')
    disp(lm)
end

end


