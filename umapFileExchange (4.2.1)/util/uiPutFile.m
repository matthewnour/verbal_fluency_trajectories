function [folder, file]=uiPutFile(proposedFldr, ...
    proposedFile, props, property, ttl, proposalIsDefault)
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Copyright (c) 2022 The Board of Trustees of the Leland Stanford Junior University; Herzenberg Lab
%   License: BSD 3 clause

if nargin<6
    proposalIsDefault=true;
    if nargin<5
        ttl='Save to which folder & file?';
        if nargin<4
            property='uiPutFile';
            if nargin<3
                props=BasicMap.Global;
            end
        end
        
    end
end
if isempty(proposedFldr)
    proposedFldr=File.Documents;
end
    File.mkDir(proposedFldr);
if ~isempty(props)
    lastFldr=props.get(property, proposedFldr);
    if ~exist(lastFldr, 'dir')
        lastFldr = proposedFldr;
    end
else
    lastFldr=proposedFldr;
end
if proposalIsDefault
    startingFldr=lastFldr;
    dfltFldr=proposedFldr;
else
    startingFldr=proposedFldr;
    dfltFldr=lastFldr;
end
[~,~,ext]=fileparts(proposedFile);
done=false;
if ismac
    jd=Gui.MsgAtTopScreen(ttl, 25);
else
    jd=[];
end
if startsWith(ttl, '<html>')
    ttl=char(edu.stanford.facs.swing.Basics.RemoveXml(ttl));
end
while ~done
    done=true;
    [file, folder]=uiputfile(['*' ext], ttl, fullfile(startingFldr, proposedFile));
    if ~isempty(jd)
        jd.dispose;
    end
    if isempty(folder) || isnumeric(folder)
        folder=[];
        file=[];
        if isequal(dfltFldr, startingFldr)
            return;
        end
        if isequal([dfltFldr filesep], startingFldr)
            return;
        end
        if isequal(dfltFldr, [startingFldr filesep])
            return;
        end
        if ~File.WantsDefaultFolder(dfltFldr) 
            return;
        end
        [file, folder]=uiputfile(['*' ext], ...
            'Save to which folder & file?', ...
            fullfile(proposedFldr, proposedFile));
        if isempty(folder)|| isnumeric(folder)
            folder=[];
            file=[];
            return;
        end
    end
end
props.set(property, folder);
end