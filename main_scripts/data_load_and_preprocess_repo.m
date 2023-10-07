%--------------------------------------------------------------------------
% Load the raw lists (5 min)
if analysis_options.animals
    [iSja, TXTa, ~] = xlsread('transcription_a.xlsx', 'animals');
else
    [iSja, TXTa, ~] = xlsread('transcription_p.xlsx', 'letters');
end

numAnimalsOrig = sum(cellfun('isempty', TXTa) == 0); % how many animals did this participant name in the time limit


%--------------------------------------------------------------------------
% Remove ([]) illegal words (hard coded for animals)
% but keep numAnimalsOrig the same as these entries remain, just blanck

numIllegalWords = zeros(length(numAnimalsOrig),1);

if analysis_options.removeIllegal_animals
    % MPC animals task - non-animals
    if analysis_options.animals
        disp('...removing non-animals')
        TXTa(1,19) = {[]}; %numAnimalsOrig(19) = numAnimalsOrig (19)-1; % 'animal'
        TXTa(1,22) = {[]}; %numAnimalsOrig(22) = numAnimalsOrig (22)-1; 'bible'
        numIllegalWords(19) = 1;
        numIllegalWords(22) = 1;
        if numAnimalsOrig(24) >= 34
            TXTa(34,24)= {[]};% numAnimalsOrig(24) = numAnimalsOrig (24)-1;  % 'seaweed'
            numIllegalWords(24) = 1;
        end

    end
end

%--------------------------------------------------------------------------
% Enumerate all non-illegal words (alphabetically)
allAn = TXTa(:);
allAn = allAn(~cellfun('isempty', allAn));  % no empty (illegal / over 5 min)
[~, idx] = unique(allAn);                   % unique() sorts the output alphabetically (capitals first)
%raw_allAn = allAn;                         % including duplicates over participants, not sorted (used for frequency then deleted)

allAn = allAn(idx);                         % no duplicates, sorted (will later have non-embedded words removed)
allAn_untouched = allAn;


%--------------------------------------------------------------------------
% split ITEMS into isolated COMPONENT WORDS [this will introduce more duplicates [black widow, black bear], but no further duplicate deletion at this stage]
allAn_split = cell(length(allAn), 3);
for nw = 1:length(allAn)
    sp = strsplit(allAn{nw});
    allAn_split(nw, 1:length(sp)) = sp;
end
allAn_split(cellfun('isempty', allAn_split)) = {''}; % so that all the entries are the same type (char)


