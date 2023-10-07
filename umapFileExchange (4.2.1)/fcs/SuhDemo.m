classdef SuhDemo < handle
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Copyright (c) 2022 The Board of Trustees of the Leland Stanford Junior University; Herzenberg Lab
%   License: BSD 3 clause

methods(Static)
    function gt=Omip47_wayne
            gt=FlowJoTree.NewOrReuse(...
                'https://storage.googleapis.com/cytogenie.org/Samples/omipB/omip47_swm.wsp',...
                {'Publication', ...
                'https://onlinelibrary.wiley.com/doi/full/10.1002/cyto.a.23488',...
                'Gating chart', ...
                'https://storage.googleapis.com/cytogenie.org/Tutorials/omipB.png'});
        end
        
        function gt=Omip47
            gt=FlowJoTree.NewOrReuse(...
                'https://storage.googleapis.com/cytogenie.org/Samples/omipB/omip47.wsp',...
                {'Publication', ...
                'https://onlinelibrary.wiley.com/doi/full/10.1002/cyto.a.23488',...
                'Gating chart', ...
                'https://storage.googleapis.com/cytogenie.org/Tutorials/omipB.png'});
        end

        function gt=Omip47Epp
            gt=FlowJoTree.NewOrReuse(...
                'https://storage.googleapis.com/cytogenie.org/Samples/omipB/omip47_EPP.wsp',...
                {'Publication', ...
                'https://onlinelibrary.wiley.com/doi/full/10.1002/cyto.a.23488',...
                'Gating chart', ...
                'https://storage.googleapis.com/cytogenie.org/Tutorials/omipB.png'});
        end

        function gt=Omip47Old
            gt=FlowJoTree.NewOrReuse(...
                'https://storage.googleapis.com/cytogenie.org/Samples/omipB/OMIP47_Bcells.wsp',...
                {'Publication', ...
                'https://onlinelibrary.wiley.com/doi/full/10.1002/cyto.a.23488',...
                'Gating chart', ...
                'https://storage.googleapis.com/cytogenie.org/Tutorials/omipB.png'});
        end
        
        function gt=Omip69
            gt=FlowJoTree.NewOrReuse(...
                'https://storage.googleapis.com/cytogenie.org/Samples/OMIP40Color/omip69.wsp',...
                {'Publication', ...
                'https://onlinelibrary.wiley.com/doi/full/10.1002/cyto.a.24213',...
                'Gating chart', 'https://storage.googleapis.com/cytogenie.org/Tutorials/OMIP69.jpg'});
        end

        function uri=UriEliver
            uri='https://storage.googleapis.com/cytogenie.org/GetDown2/domains/FACS/demo/bCellMacrophageDiscovery/eliver3.wsp';
        end
        
        
        function gt=Eliver
            gt=FlowJoTree.NewOrReuse(SuhDemo.UriEliver, {'Publication', ...
                'https://www.pnas.org/content/107/6/2568', ...
                'Gating chart', ...
                'https://storage.googleapis.com/cytogenie.org/Tutorials/Ghosn1.jpg'});
        end
         
        function uri=UriUmap
            uri='https://storage.googleapis.com/cytogenie.org/GetDown2/domains/FACS/demo/bCellMacrophageDiscovery/demoEliver2.wsp';
        end
        
        function gt=Umap
            gt=FlowJoTree.NewOrReuse(SuhDemo.UriUmap, {'Publication', ...
                'https://www.pnas.org/content/107/6/2568', ...
                'Gating chart', ...
                'https://storage.googleapis.com/cytogenie.org/Tutorials/Ghosn1.jpg'});
        end
        
        function gt=Omip44
            gml=['https://storage.googleapis.com/cytogenie.org/' ...
                'Samples/omip44/omip44swm.wsp'];
            gt=FlowJoTree.NewOrReuse(gml, {'Publication', ...
                'https://onlinelibrary.wiley.com/doi/10.1002/cyto.a.23331',...
                'Gating chart', ...
                ['https://storage.googleapis.com/' ...
                'cytogenie.org/Tutorials/omip44.png']});
        end
        
        function gt=Omip44Epp
            gml=['https://storage.googleapis.com/cytogenie.org/Samples/omip44/omip44_EPP.wsp'];
            gt=FlowJoTree.NewOrReuse(gml, {'Publication', ...
                'https://onlinelibrary.wiley.com/doi/10.1002/cyto.a.23331',...
                'Gating chart', ...
                ['https://storage.googleapis.com/' ...
                'cytogenie.org/Tutorials/omip44.png']});
        end
        
        function uri=UriGenentech
            %uri='https://storage.googleapis.com/cytogenie.org/Samples/genentech/Genentech3.wsp';
            uri='https://storage.googleapis.com/cytogenie.org/Samples/genentech/Genentech_SWM_2022-10-01.wsp';
        end
        
        function gt=Genentech
            gt=FlowJoTree.NewOrReuse(SuhDemo.UriGenentech, ...
                {'Publication', ...
                'https://www.frontiersin.org/articles/10.3389/fimmu.2019.01194/full', ...
                'Gating chart', 'https://storage.googleapis.com/cytogenie.org/Tutorials/genentech.jpg'});
        end
        
        function uri=UriGenentech10Samples
            uri='https://storage.googleapis.com/cytogenie.org/Samples/genentech/Genentech3.wsp';
        end
        
        function gt=Genentech10Samples
            gt=FlowJoTree.NewOrReuse(SuhDemo.UriGenentech10Samples, ...
                {'Publication', ...
                'https://www.frontiersin.org/articles/10.3389/fimmu.2019.01194/full', ...
                'Gating chart', 'https://storage.googleapis.com/cytogenie.org/Tutorials/genentech.jpg'});
        end
        
        function uri=UriPanorama
            uri='https://storage.googleapis.com/cytogenie.org/Samples/Nikolay/CyTOF_Panorama2.wsp';
        end
        
        function gt=Panorama
            gt=FlowJoTree.NewOrReuse(SuhDemo.UriPanorama, {...
                'Publication', ...
                'https://www.nature.com/articles/nmeth.3863?WT.feed_name=subjects_haematopoiesis',...
                'Gating chart', ...
                'https://storage.googleapis.com/cytogenie.org/Tutorials/Panorama.pdf'...
                });
            
        end
        
        function uri=UriMaecker
            uri='https://storage.googleapis.com/cytogenie.org/Samples/maecker/Maecker2.wsp';
        end
        
        function gt=Maecker
            gt=FlowJoTree.NewOrReuse(SuhDemo.UriMaecker, {'Publication',...
                'https://www.sciencedirect.com/science/article/pii/S0022175917304908?via%3Dihub', ...
                'Gating chart', 'https://storage.googleapis.com/cytogenie.org/Tutorials/maecker.pdf'});
        end

        function uri=UriDylan
            uri='https://storage.googleapis.com/cytogenie.org/Samples/demoForDylan.wsp';
        end

        function gt=Dylan
            gt=FlowJoTree.NewOrReuse(SuhDemo.UriDylan);
        end
        
        function btn=GetButton(callback, ...
                txt, icon, tip, closeParentWindow)
            if nargin<5
                closeParentWindow=true;
                if nargin<4
                    tip='Play with an example FlowJo workspace...';
                    if nargin<3
                        icon='demoIcon.gif';
                        if nargin<2
                            txt='Demos';
                        end
                    end
                end
            end
            btn=Gui.NewBtn(txt, @(h,e)ask(h), tip, icon);

            function ask(h)
                jw=Gui.WindowAncestor(h);
                    
                opts=cell(1,6);
                opts{1}=['<html>Macrophages & B cells<br>'...
                    '&nbsp;&nbsp;<i>from Eliver Ghosn et al</i></html>'];
                opts{2}=['<html>CyTOF Quantitative Comparison<br>'...
                    '&nbsp;&nbsp;<i>from William O''Gorman et al</i></html>'];
                opts{3}=['<html>OMIP-069 40 color<br>'...
                    '&nbsp;&nbsp;<i>from Lily Park et al</i></html>'];
                opts{4}=['<html>OMIP-047 B cells<br>'...
                    '&nbsp;&nbsp;<i>from Thomas Liechti</i></html>'];
                opts{5}=['<html>OMIP-044 28 color<br>'...
                    '&nbsp;&nbsp;<i>from Florian Mair et al</i></html>'];
                opts{6}=['<html>CyTOF Comparison across sites<br>'...
                    '&nbsp;&nbsp;<i>from Michael Leipold et al</i></html>'];
                opts{7}=['<html>CyTOF Panorama with X-shift<br>'...
                    '&nbsp;&nbsp;<i>from Nikolay Samusik et al</i></html>'];
                idx=mnuMultiDlg(struct('javaWindow', jw, ...
                    'msg', Html.WrapHr([...
                    'Explore one of our example<br>'...
                    'workspaces built with FlowJo 10.8.1'])), ...
                    'FlowJoBridge Demos', opts, 1, true, ...
                    true, [], [], [], [], 7, 'south east');
                if isempty(idx)
                    return;
                end
                if closeParentWindow
                    if ~isempty(jw)
                        jw.dispose
                    end
                end
                switch(idx) 
                    case 1
                        SuhDemo.Eliver;
                    case 2
                        SuhDemo.Genentech;
                    case 3
                        SuhDemo.Omip69;
                    case 4
                        SuhDemo.Omip47;
                    case 5
                        SuhDemo.Omip44;
                    case 7
                        SuhDemo.Panorama;
                    case 6
                        SuhDemo.Maecker
                end
                if ~isempty(callback)
                    feval(callback, idx, opts{idx});
                end
            end
        end       
end
end
