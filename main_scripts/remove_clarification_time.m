% remove_clarification_time

needClarification = find(ismember([112 114 130 202], iSja(iSj)));

if needClarification == 1
    
    % call for clarification between:
    %    (1) dolphin and shark (8.5s)
    timeStamp(4:end) = timeStamp(4:end) - 8.5;
    
    %    (2) peregrine falcon and hawk (5.5s)
    timeStamp(23:end) = timeStamp(23:end) - 5.5;
    
    %    (3) dog and crocodile (10s)
    timeStamp(37:end) = timeStamp(37:end) - 10;

elseif needClarification == 2
    % (1) between duck and ant (2s)
    timeStamp(17:end) = timeStamp(17:end) - 2;
    
    
elseif needClarification == 3
    % (1) between tiger and snow lion (3s)
    timeStamp(5:end) = timeStamp(5:end) - 3;
    
elseif needClarification == 4
    % (1) between bird and bluejay (6s)
    timeStamp(35:end) = timeStamp(35:end) - 6;
    
end