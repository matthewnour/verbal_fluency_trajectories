classdef FlowJoBridgeExamples<handle
%   AUTHORSHIP
%   Primary Developer: Connor Meehan <connor.gw.meehan@gmail.com> 
%   Secondary Developer: Stephen Meehan <swmeehan@stanford.edu>
%   Copyright (c) 2022 The Board of Trustees of the Leland Stanford Junior University; Herzenberg Lab
%   License: BSD 3 clause

    properties(Constant)
        N_FLOWJOBRIDGE_EXAMPLES = 17;
        N_EXTRA_EXAMPLES = 0;
    end

    methods(Static)
        function RunAll(whichOnes, verbose)
            addpath('../util/');
            if verLessThan('matlab', '9.3')
                msg('FlowJoBridgeExamples requires MATLAB R2017b or later...')
                return;
            end

            nExamples = FlowJoBridgeExamples.N_FLOWJOBRIDGE_EXAMPLES + FlowJoBridgeExamples.N_EXTRA_EXAMPLES;
        
            if nargin<1
                verbose=false;
                whichOnes=1:nExamples;
            else
                if nargin<2
                        verbose=true;
                end
                if isempty(verbose)
                    verbose=true;
                end
                if ischar(whichOnes)
                    whichOnes=str2double(whichOnes);
                end
                if ~isnumeric(whichOnes) || any(isnan(whichOnes)) || any(whichOnes<0) || any(whichOnes>nExamples)
                    error(['FlowJoBridgeExamples argument must be nothing or numbers from 1 to '...
                        num2str(nExamples) '!']);
                end
            end
        
            if all(whichOnes==0)
                whichOnes = 1:nExamples;
            end
        
            srcs = exampleSources(nExamples);
        
            if verbose
                if length(whichOnes) == 1
                    DataSource.DisplaySinglePub(srcs(whichOnes));
                elseif length(whichOnes) > 1
                    DataSource.DisplayMultiplePubs(unique(values(srcs, num2cell(whichOnes))));
                end
            end
            
            defaultEliverURI = getEliverURI();
            eppArgs = getEPPArgs();
            umapArgs = getUMAPArgs();
            mlpArgs = getMLPArgs();
        
            for j = whichOnes
                printExStart(j);
                switch j
                    case 1
                        run_epp(defaultEliverURI, eppArgs{:});
                    case 2
                        run_epp(defaultEliverURI, eppArgs{:}, 'flowjo_visible', true);
                    case 3
                        run_umap(defaultEliverURI, umapArgs{:});
                    case 4
                        run_umap(getEliverURI(3, 'non B cells'), umapArgs{:});
                    case 5
                        run_umap(defaultEliverURI, umapArgs{:}, 'flowjo_visible', true);
                    case 6
                        run_umap({defaultEliverURI, 'all_3-2.fcs'}, umapArgs{:}, 'fast', true);
                    case 7
                        run_umap(getGenentechURI(), umapArgs{:});
                    case 8
                        Mlp.Train(defaultEliverURI, mlpArgs{:}, 'hold', .15);
                    case 9
                        Mlp.Predict(getEliverURI(4));
                    case 10
                        Mlp.Predict({getEliverURI(4), '23414.fcs'});
                    case 11
                        Mlp.Predict(getEliverURI(2));
                    case 12
                        MlpPython.Train(defaultEliverURI, mlpArgs{:}, 'epochs', 210, 'class', .12);
                    case 13
                        MlpPython.Predict(getEliverURI(4));
                    case 14
                        MlpPython.Predict({getEliverURI(4), '23414.fcs'});
                    case 15
                        MlpPython.Predict(getEliverURI(2));
                    case 16
                        SuhDemo.ExamplefOnlyMATLAB;
                    case 17
                        SuhDemo.PhateExample;
                end
                printExEnd(j);
            end
        
            function printExStart(j)
                disp(['FlowJoBridge Example ' num2str(j) ' starting...']);
            end
            function printExEnd(j)
                disp(['FlowJoBridge Example ' num2str(j) ' completed with no MATLAB exceptions!']);
            end
            
            function map = exampleSources(nEXAMPLES)
                map = containers.Map('KeyType', 'double', 'ValueType', 'any');
            
                for i = 1:nEXAMPLES
                    if i == 7
                        map(i) = 'genentech';
                    else
                        map(i) = 'eliver';
                    end
                end
            end
            
            function uri = getEliverURI(fcsNo, restriction)
                if nargin < 2
                    restriction = 'none';      
                    if nargin < 1
                        fcsNo = 3;
                    end
                end
                if fcsNo == 2
                    uri = 'all_3-2.fcs/Sing*/Live*@https://storage.googleapis.com/cytogenie.org/GetDown2/domains/FACS/demo/bCellMacrophageDiscovery/eliver3.wsp';
                elseif fcsNo == 4
                    uri = 'all_3-4.fcs/Sing*/Live*@https://storage.googleapis.com/cytogenie.org/GetDown2/domains/FACS/demo/bCellMacrophageDiscovery/eliver3.wsp';
                elseif fcsNo == 3 && strcmpi(restriction, 'non B cells')
                    uri = 'all_3-3.fcs/Sing*/Live*/Non*@https://storage.googleapis.com/cytogenie.org/GetDown2/domains/FACS/demo/bCellMacrophageDiscovery/eliver3.wsp';
                elseif fcsNo == 3 && strcmpi(restriction, 'B cells')
                    uri = 'all_3-3.fcs/Sing*/Live*/B cells@https://storage.googleapis.com/cytogenie.org/GetDown2/domains/FACS/demo/bCellMacrophageDiscovery/eliver3.wsp';
                else
                    uri = 'all_3-3.fcs/Sing*/Live*@https://storage.googleapis.com/cytogenie.org/GetDown2/domains/FACS/demo/bCellMacrophageDiscovery/eliver3.wsp';
                end    
            end
            
            function uri = getGenentechURI()
                uri = 'export_null_Bead Rem.fcs/Subset 2*@https://storage.googleapis.com/cytogenie.org/Samples/genentech/Genentech2.wsp';
            end
            
            function args = getEPPArgs()
                args = {'label_column', 'end',  'cytometer', 'conventional'};
            end
            
            function args = getUMAPArgs()
                args = {'label_column', 'end', 'match_scenarios', 3,  'n_components', 2};
            end
            
            function args = getMLPArgs()
                columns = {'FSC-A', 'SSC-A', 'CD5:PE-Cy5-A', 'CD11b:APC-Cy7-A', 'CD11c-biot:Qdot 605-A', 'CD19:PE-Cy55-A', 'F4/80:FITC-A','IgD:APC-Cy5-5-A', 'IGM:PE-Cy7-A'};
                args = {'flowjo_columns', columns, 'flowjo_ask', false, 'confirm_model', true};
            end
        end

        function PhateExample(flowJoURI, columnNames, ttl)
            if ~PhateUtil.IsInstalled
                return;
            end
            ax=[];fig=[];

            if nargin<3
                ttl='populations';
                if nargin<2
                    columnNames=[];
                    if nargin<1
                        ttl='B cells';
                        %extract 11 FCS parameters
                        columnNames={'Gr-1:APC-A', 'I-Ad:PE-A', ...
                            'FSC-A', 'SSC-A', 'CD5:PE-Cy5-A', ...
                            'CD11b:APC-Cy7-A', 'CD11c-biot:Qdot 605-A', ...
                            'CD19:PE-Cy55-A', 'F4/80:FITC-A', ...
                            'IgD:APC-Cy5-5-A', 'IGM:PE-Cy7-A'};
                        %locate the subset hierarchy @ WSP file
                        flowJoURI=['all_3-3.fcs/Sing*/Live*/B cells' ...
                            '@https://storage.googleapis.com/cytogenie.org/' ...
                            'GetDown2/domains/FACS/demo/bCellMacrophageDiscovery/' ...
                            'eliver3.wsp'];
                    end
                end
            end            
            [data, columnNames,~,~, ~,~,~,~,gates]...
                =FlowJoTree.GetData( ...
                flowJoURI, ...
                columnNames, ... % if empty then user is asked for columns
                false, ... % do not show tree figure
                true, ... % just data no class label column
                false, ... % return data not CSV file name
                [],... %no figure to associate
                [], ... %no prior save arg
                'PHATE', ... % indicate purpose of data extraction
                false); % do not ask user to confirm anything 
                        %    (such as column selections or overlap)
            openFig;
            reduction=phate(data, 'k', 15, 'landmarks', 500);
            showResult;
            labels=computeDbmClusters(reduction);
            FlowJoTree.CreateLabelGates('PHATE',...
                'demoIcon.gif',data, labels, [], columnNames, gates);

            function clusterIds=computeDbmClusters(data)
                [~, clusterIds, dbm]=Density.GetClusters(data, ...
                    'medium', min(data), max(data));
                try
                    dbm.drawBorders(ax);
                catch ex
                    ex.getReport
                end
                    
            end

            function openFig
                fig=figure('Name', ...
                    ['PHATE visualization on FlowJo ' ttl]);
                movegui(fig, 'north');
                figure(fig);
                ax=axes('parent', fig);
                text(ax, .5, .5, {sprintf( ...
                    '\\fontsize{16}Running PHATE on %s x %d matrix ', ...
                    String.encodeInteger(size(data,1)), size(data,2)), '', ...
                    '\fontsize{12}See progress in \it"Command Window"'},...
                    'HorizontalAlignment','center',...
                    'VerticalAlignment','middle', ...
                    'Color', 'blue');
                set(ax, 'XTick', []);set(ax, 'YTick', []);
                drawnow;
            end

            function showResult
                ProbabilityDensity2.Draw(ax, reduction, ...
                    true, true, true, .05, 10);
                figure(fig);
                movegui(fig, 'center');
            end
        end

        function Umap
            columnNames={'Gr-1:APC-A',  ...
                'FSC-A', 'SSC-A', 'CD5:PE-Cy5-A', ...
                'CD11b:APC-Cy7-A', 'CD11c-biot:Qdot 605-A', ...
                'CD19:PE-Cy55-A', 'F4/80:FITC-A', ...
                'IgD:APC-Cy5-5-A', 'IGM:PE-Cy7-A'};
            %locate the subset hierarchy @ WSP file
            flowJoURI=['23414.fcs/Singlets/Live singlets' ...
                '@https://storage.googleapis.com/cytogenie.org/' ...
                'GetDown2/domains/FACS/demo/bCellMacrophageDiscovery/' ...
                'eliver3.wsp'];
            [data, columnNames,~,~, ~,~,~,~,gates]...
                =FlowJoTree.GetData( ...
                flowJoURI, ...
                columnNames, ... % if empty then user is asked for columns
                false, ... % do not show tree figure
                true, ... % just data no class label column
                false, ... % return data not CSV file name
                [],... %no figure to associate
                [], ... %no prior save arg
                'PHATE', ... % indicate purpose of data extraction
                false); % do not ask user to confirm anything
            %    (such as column selections or overlap)
            if isempty(data)
                return;
            end
            reduction=run_umap(data, 'fast', true, 'verbose', 'text');
            [~, labels]=Density.GetClusters(reduction, ...
                    'low', min(reduction), max(reduction));
            FlowJoTree.CreateLabelGates('UMAP+DBM',...
                'demoIcon.gif',data, labels, [], columnNames, gates);

        end
        
        function ExampleOfOnlyMATLAB
            %extract 11 FCS parameters
            columnNames={'FSC-A', ...
                'SSC-A', 'CD5:PE-Cy5-A', ...
                'CD11b:APC-Cy7-A', 'CD11c-biot:Qdot 605-A', ...
                'CD19:PE-Cy55-A', 'F4/80:FITC-A', ...
                'IgD:APC-Cy5-5-A', 'IGM:PE-Cy7-A',  ...
                'Gr-1:APC-A', 'I-Ad:PE-A'};
            %locate the subset hierarchy @ WSP file
            flowJoURI=['all_3-3.fcs/Sing*/Live*/B cells' ...
                '@https://storage.googleapis.com/cytogenie.org/' ...
                'GetDown2/domains/FACS/demo/bCellMacrophageDiscovery/' ...
                'eliver3.wsp'];
            [data, columnNames, ~, ~, ~,~,~,~, gates]...
                =FlowJoTree.GetData( ...
                flowJoURI, ... 
                columnNames, ... % if empty then user is asked for columns
                false, ... % do not show tree figure
                true, ... % just data no class label column
                false, ... % return data not CSV file name
                [],... %no figure to associate
                [], ... %no prior save arg
                'PHATE', ... % indicate purpose of data extraction
                false); % do not ask user to confirm anything 
                        %    (such as column selections or overlap)
            disp('Running MATLAB''s t-SNE implementation');
            reduction=tsne(data, 'perplexity', 15, 'verbose', 1);
            disp('Running DBSCAN');
            labels=dbscan(reduction, 2, 15);
            fprintf('%d clusters found by DBSCAN\n', ...
                length(unique(labels))-1);
            FlowJoTree.CreateLabelGates('tSNE_dbscan',...
                'demoIcon.gif',data, labels, [], columnNames, gates);
        end
    end
end