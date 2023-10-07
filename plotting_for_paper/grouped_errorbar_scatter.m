function [x_log barhandle] = grouped_errorbar_scatter(data, withinSubjectVariableName, vargin)
% WITHIN-SUBJECT VARIABLES AS THE GROUPING VARIABLE ON THE X
%
% [x_log barhandle] = grouped_errorbar(data, withinSubjectVariableName)
% grouped bar graph with errorbar (SEM) (pairs nicely with the simple_mixed_anova script)
% individual scatter of values
%
%
% INPUT
%   data    1*group (group = BETWEEN_sub_group) cell array, with each entry containing the sub*WITHIN_subject variable observations
%           e.g. data{1} = CON; data{2} = PATs; where patients = [nSubj * nSess] and cottrols = [nSubj * nSess]
%           gr1 is blue, gr2 is red
%
%   names are a cell array of names length(withinSubjectVariableName) = size(data{1},2); length(betweenSubjectVariableName) = length(data)
%   vargin is a 1*2 array of color [r g b] vals, if empty set to {'b', 'r'}
%
% OUTPUT
%   xlog    location of each bar on x (usefuo for additional plots)
%   barhandle figure handle
%
% Matthew Nour, London, April 2020

%dots
if nargin == 2
    clr = [0 0 1; 1 0 0]; % pt v con
else
    clr = [vargin{1}; vargin{2}];
end
%clr = [0 0 256; 254 22 255]/256;% magenta (unmedicated) =
%clr = [55 255 56; 254 22 255]/256;% medicated(green) v unmedicated(magenta)

%mean/SEM (marketface color. errorbars remain r/b)
%clrM = [0 0 0; 0 0 0]; % black
clrM = clr; % r/b

colormap(clr);

model_series = [];
model_error = [];

% define model_series and model_error, which are [ngroups, nWithin] - transpose below
for n = 1:length(data) % for each group
    model_series(n, :) = mean(data{n}); % group * within
    model_error(n,:) = std(data{n})/sqrt(size(data{n},1));
end

% transpose to make [nWithin, ngroups], so that we group by the probeType,
% not by the group)
model_series = model_series'; %[nWithin, ngroups]
model_error = model_error';

%barhandle = bar(model_series, 'grouped', 'LineStyle', 'none');

%set(barhandle(1),'FaceColor', clr(1,:)) % group 1 is blue
%set(barhandle(2),'FaceColor',  clr(2,:)) % group 2 is red
%set(barhandle(2),'FaceColor',[232 64 170]/256) % group 2 is pink

hold on

% Find the number of x-axis major and minor 'groups'
nWITHIN = size(model_series, 1); % nunmber WITHIN
nBETWEEN = size(model_series, 2);   % number BETWEEN
% Calculate the width for each bar group
groupwidth = min(0.8, nBETWEEN/(nBETWEEN + 1.5));
% Set the position of each error bar in the centre of the main bar
% Based on barweb.m by Bolu Ajiboye from MATLAB File Exchange

for i = 1:nBETWEEN % for each BETWEEN (i.e. diagnostic group), plot each question-type bar

    % Calculate center of each bar
    x = (1:nWITHIN) - groupwidth/2 + (2*i-1) * groupwidth / (2*nBETWEEN);
    H = errorbar(x, model_series(:,i), model_error(:,i), 'Color', clr(i,:), 'linestyle', 'none', 'MarkerFaceColor', clrM(i,:), 'Marker', 'o', 'MarkerSize', 2);

    if 1  %scatter
        % within each diagnostic group plot the individual bars, all same colour
        for level = 1:nWITHIN
            barhandle = scatter( x(level)*ones(length(data{i}),1), data{i}(:,level), 7, ...
                'MarkerFaceColor', clr(i,:), 'MarkerFaceAlpha', .2, 'MarkerEdgeColor', 'none', 'jitter', 'on', 'jitterAmount', .1);
        end
    end

    x_log(i,:) = x;
end

xticks([1:nWITHIN])
xticklabels(withinSubjectVariableName)


box off
xlim([0.5 nWITHIN+.5])

plot([0 nWITHIN+1], [0 0], ':k')

end