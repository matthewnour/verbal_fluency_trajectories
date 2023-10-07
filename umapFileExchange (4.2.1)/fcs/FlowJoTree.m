classdef FlowJoTree < handle
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Copyright (c) 2022 The Board of Trustees of the Leland Stanford Junior University; Herzenberg Lab
%   License: BSD 3 clause
%
%FlowJoTree.GetData is the primary module for integrating MATLAB 
%  functionality with FlowJo TM v10.8 software (BD Life Sciences)

    properties(Constant)
        PROP_EXPORT_FLDR='FlowJoTree.Export.Folder';
        PROP_SYNC_KLD='FlowJoTree.Mirror';
        PROP_OPEN='FlowJoTree.NewOrReuse';
        PROPS_MATCH='FlowJoTree.QFMatch';
        COLOR_YELLOW_LIGHT=java.awt.Color(1, 1, .88);
        MAX_WORKSPACES=35;
    end

    properties
        title='FlowJoExplorer';
    end
    
    properties(SetAccess=private)    
        hPnl;
        fig;
        jw;
        figs={};%dependent windows
        tb;
        gml;
        multiProps;
        bullsEye;
        imgSamples;
        imgSample;
        imgFolder;
        imgGate; % tree branch
        hiD; % tree root
        app;
        gaters;%1 per gml.sampleNodes
        gatersAllData; %1 no data limits
        cbMirror;
        btnSave;
        suhTree;
        umapVersion=UMAP.VERSION;
        selectedKey;
        parameterExplorer;
        figNamePrefix;
        isSyncingKld=false;
        initializing=true;
        pipelineCallback; %SUH pipeline callback @(data, names, labelPropsFile)
        pipelineAllowsLabel;
        pipelineFcsParameters;
        pipelineArgs={};
        btnFlashlight;
        btnColorWheel;
        btnMatch;
        umapVarArgIn;
        phateVarArgIn;
        phateVarArgInStruct;
        fitcnetVarArgIn;
        umapArgsDone=false;
        phateArgsDone=false;
        fitcnetArgsDone=false;
        eppModalVarArgIn;
        eppDbmVarArgIn;
        eppArgsDone=false;
        jdWsp;
        jlWsp;
        alwaysUnmix;
    end
    
    properties
        hearingChange=false;
        lastPlotFig;
        searchAc;
        chbSearchType;
    end
    
    methods
        function setPipelineArgs(this, args)
            if iscell(args) && mod( length(args), 2)==1
                this.pipelineArgs=args(2:end);
            else
                this.pipelineArgs=args;
            end
        end
        
        function this=FlowJoTree(fjw)
            if ischar(fjw) % must be URI
                fjw=FlowJoWsp(fjw);
                if isempty(fjw.doc) 
                    this.gml=[];
                    return;
                end
            end
            this.gml=fjw;
            this.gaters=Map;
            this.gatersAllData=Map;
            this.app=BasicMap.Global;
            pp=this.app.contentFolder;
            this.multiProps=MultiProps(this.app, this.gml.propsGui);
            this.imgSamples=fullfile(pp, 'tube rack.png');
            this.imgSample=fullfile(pp, 'tube2.png');
            this.imgFolder=fullfile(pp, 'foldericon.png');
            this.bullsEye=fullfile(pp, 'bullseye.png');
            this.hiD=fullfile(pp, 'tSNE.png');
            this.imgGate=fullfile(pp, 'polygonGate.png');
            fjw.registerChangeListener(...
                @(gml,id, eventClue)hearChange(this,id, eventClue), this);
        end
        
        function save(this)
            Gui.ShowBusy(this.fig, ...
                [this.app.h2Start 'Saving workspace' ...
                this.app.h2End '<hr><br><br><br><br><br><br>'], ...
                'save16.gif', 4);
            clr='F9EEEE';
            try
                saved=this.gml.save; % if not cancelled
                quiet;
                if saved
                    word='';
                    this.btnSave.setEnabled(false);
                    icon='tick_green.png';
                    iconSz=3;
                    clr='EEF5F1';
                else
                    word='<font color="red">NOT ';
                    icon='warning.png';
                    iconSz=1.38;
                end
                if saved
                    Gui.CashRegister;
                else
                    Gui.Splat;
                end
            catch ex
                Gui.MsgException(ex);
                return;
            end
            [~,wspF, wspE]=fileparts(this.gml.file);
            Gui.ShowBusy(this.fig, ['<table border=1 cellpadding=4><tr>' ...
                '<td bgcolor="#' clr '">' this.app.h2Start ...
                'Workspace ' word 'saved: <font color="blue">' ...
                wspF wspE '</font>!' ...
                this.app.h2End '</td></tr></table>' ...
                '<br><br><br><br><br><br>'], ...
                icon, iconSz);
            this.jw.setEnabled(true);
            edu.stanford.facs.swing.Basics.Shake(this.jlWsp, 3);
            this.app.showToolTip(this.jlWsp);
            MatBasics.RunLater(@(h,e)quiet(), 2.8);

            function quiet
                Gui.HideBusy(this.fig);
            end
        end        
        
        function yes=isVisible(this, id)
            uiNode=this.suhTree.uiNodes.get(id);
            yes=~isempty(uiNode);
        end
            
        function hearChange(this, id, eventClue)
            if strcmp(eventClue, FlowJoWsp.CHANGE_EVENT_START)
                this.hearingChange=true;
                this.rememberExpanded(id);
            elseif strcmp(eventClue, FlowJoWsp.CHANGE_EVENT_END)
                this.restoreExpanded;
                drawnow;
                this.hearingChange=false;
            else
                this.btnSave.setEnabled(true);
                if isequal(id, this.selectedKey) ...
                        && ~isempty(this.parameterExplorer) ...
                        && this.parameterExplorer.isValid
                    [~, gate]=this.getGate(this.selectedKey);
                    if isempty(gate)
                        warning('Gate for key=%s is not found', key);
                        return;
                    end
                    data=gate.getDataForAutoGating;
                    this.parameterExplorer.refresh(data, gate.name);
                    drawnow;
                end
                uiNode=this.suhTree.uiNodes.get(id);
                if ~isempty(uiNode)
                    node=this.gml.getNodeById(id);
                    if ~isempty(node)
                        [~, gate]=this.getGate(node);
                        if isempty(gate.count)
                            gate.getMlSummary;
                            gate.refreshSampleRows;
                        end
                        this.suhTree.refreshNode(uiNode, ...
                            this.getNodeHtml(gate.name, gate.count));
                        this.gml.addStaleCountChildIds(gate.id);
                    end
                end
            end
        end
        
        function obj=initFig(this, locate_fig)    
            [this.fig, this.tb, personalized] =...
                Gui.Figure(true, 'FlowJoTree.fig', this.gml.propsGui);
            this.fig.UserData=this;
            [~,f,e]=fileparts(this.gml.file);
            set(this.fig, 'name', [ 'FlowJoBridge ' f e])
            if ~personalized
                pos=get(this.fig, 'pos');
                set(this.fig, 'pos', [pos(1) pos(2) pos(3)*.66 pos(4)]);
            end
            if ~isempty(locate_fig)
                Gui.FollowWindow(this.fig, locate_fig);
                drawnow;
                Gui.FitFigToScreen(this.fig);
                SuhWindow.SetFigVisible(this.fig);
            else
                Gui.FitFigToScreen(this.fig);
                Gui.SetFigVisible(this.fig);
                drawnow;
            end
            this.setWindowClosure;
            [obj.busy, ~, obj.busyLbl]=Gui.ShowBusy(this.fig, ...
                Gui.YellowH3('Initializing hierarchy'),...
                'CytoGenius.png', .66, false);            
            this.jw=Gui.WindowAncestor(this.fig);
        end
        
        function show(this, locateFig, fncNodeSelected)
            if nargin<3
                fncNodeSelected=@(h,e)nodeSelectedCallback(this, e);
                if nargin<2
                    %locateFig={gcf, 'east', true};
                    locateFig=[];
                end    
            end
            sm1=this.app.smallStart;
            sm2=this.app.smallEnd;
            b1='<b><font color="blue">';
            b2='</font></b>';
            this.initializing=true;
            busy=this.initFig(locateFig);
            app_=this.app;
            pp=app_.contentFolder;
            startNode=uitreenode('v0', FlowJoWsp.ROOT_ID, ['<html>'...
                'All samples ' app_.supStart ...
                app_.supEnd '</html>'],...
                this.imgSamples, false);
            ToolBarMethods.addButton(this.tb, 'flowJo10small.png',...
                'Open a different FlowJo workspace', ...           
                @(h,e)openTree());
            this.btnSave=ToolBarMethods.addButton(this.tb, 'save16.gif', ...
                'Save changes to gating', ...
                @(h,e)save(this), ...
                Html.WrapSmall('Save'));
            this.btnSave.setEnabled(false);
            this.btnFlashlight=ToolBarMethods.addButton(this.tb, ...
                fullfile(pp, 'pinFlashlightTransparent.png'),...
                'Highlight selected subset''s events in plots',...
                @(h,e)flashlight(this));
            this.btnColorWheel=...
                ToolBarMethods.addButton(this.tb, 'colorWheel16.png', ...
                ['<html><center>Edit highlight colors for leaf <br>'...
                'subsets of selected subset<center></html>'], ...
                @(h,e)flashlights(this));
            
            this.btnMatch=ToolBarMethods.addButton( ...
                this.tb, 'heatMapHot.png', ...
                ['<html>HiD subset views for selections:<ul>'...
                '<li><u>HeatMap</u> ' this.app.supStart ...
                '(fast earth-mover''s distance).' this.app.supEnd ...
                '<li><u>Phenograms/QF-tree</u>' this.app.supStart...
                '(fast earth-mover''s distance).' this.app.supEnd ...
                '<li><u>MDS</u>' this.app.supStart ...
                '(multi-dimensional scaling)' this.app.supEnd '</html>'], ...
                @(h,e)viewMenu(this, h));
            ToolBarMethods.addButton(this.tb, ...
                'eye.gif', ['<html>Open PlotEditor for '...
                'all selections.</html>'], ...
                @(h,e)openPlots(this))
            this.tb.jToolbar.addSeparator;
            img=Html.ImgXy('pseudoBarHi.png', pp, .819);
            this.cbMirror=Gui.CheckBox(...
                Html.WrapSmallBold(['Sync ' img]), ...
                false,...%this.app.is(FlowJoTree.PROP_SYNC_KLD, false), ...
                [], '', ...
                @(h,e)mirror(), ...
                ['<html>Select to synchronize this tree''s 1st '...
                '<br>selection with the ' img ...
                ' Subset ParameterExplorer<hr></html>']);
            ToolBarMethods.addComponent(this.tb, ...
                Gui.FlowLeftPanelBorder(this.cbMirror));        
            if ~isempty(this.gml.resources.keys)
                ToolBarMethods.addButton(this.tb, 'help2.png', ...
                    'See resources associated with Gating-ML', ...
                    @(h,e)seeResources(h));
            end
            if ~isempty(this.gml.file)
                fileHtml=Html.FileTree(this.gml.file);
                this.tb.jToolbar.addSeparator
                [~,jl]=Gui.ImageLabel(...
                    Html.WrapSm('wsp'),...
                    'foldericon.png',...
                    ['<html>Click <b>' Html.Img('foldericon.png') ...
                    ' wsp</b> to see:<br>' ...
                    fileHtml '</html>'], @(h,e)showFile());
                jl.setForeground(java.awt.Color.BLACK);
                ToolBarMethods.addComponent(this.tb,jl);
                this.jlWsp=jl;
            end
            ToolBarMethods.addButton(this.tb, 'find16.gif', ...
                'Find gate(s)', @(h,e)find(this), ...
                Html.WrapSm('Find'));
            ToolBarMethods.addButton(this.tb, 'garbage.png', ...
                    'Delete selected gate(s)', ...
                    @(h,e)deleteGate(this));
            hPanLeft = uipanel('Parent',this.fig, ...
                'Units','normalized','Position',...
                [0.02 0.08 0.98 0.92]);
            drawnow;
            this.suhTree=SuhTree.New(startNode, fncNodeSelected,...
                @(key)getParentIds(this,key), @(key)nodeExists(this, key), ...
                @(key)newUiNodes(this, key), @(key)getChildren(this, key), false);
            set(this.suhTree.container,'Parent',hPanLeft, ...
                'Units','normalized', 'Position',[0 0 1 1]);
            this.suhTree.stylize;
            this.suhTree.jtree.setToolTipText(['<html><table cellspacing=''5''>'...
                '<tr><td>Click on any node to see:<ul>'...
                '<li>' Html.ImgXy('pseudoBarHi.png', pp, .9) ...
                '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Measurement <i>distributions</i> '...
                 '</ul><hr></td><tr></table></html>']);
            uit=this.suhTree.tree;
            this.suhTree.setDefaultExpandedCallback;
            paramExp=[];
            sep=javax.swing.JLabel('  ');
            pnl=Gui.FlowLeftPanel(4, 1, umapUstBtn, ...
                eppBtn, mlpBtn, phateBtn, qfMatchBtn, ...
                sep, csvBtn);
            Gui.SetFlowLeftHeightBackground(...
                pnl, FlowJoTree.COLOR_YELLOW_LIGHT);
            sep.setBackground(pnl.getBackground);
            H=Gui.PutJavaInFig(pnl, this.fig, 1, 1);
            uit.expand(startNode);
            drawnow;
            d=pnl.getPreferredSize;
            if this.app.highDef
                set(H, 'Position', [1 1 d.width ...
                    9+d.height*(1/this.app.toolBarFactor)]);
            end
            this.hPnl=H;
            set(this.suhTree.jtree, 'KeyPressedCallback', ...
                @(src, evd)keyPressedFcn(this, evd));
            set(this.suhTree.jtree, 'MousePressedCallback', ...  
                @(hTree, eventData)doubleClickFcn(this, eventData));
            set(this.suhTree.jtree, 'MouseMovedCallback', ...  
                @(hTree, eventData)mouseMoveFcn(this, eventData));
            try
            this.restoreExpanded;
            catch
            end
            MatBasics.RunLater(@(h,e)notBusy, .81);
            this.suhTree.tree.setVisible(true)
            this.restoreLastVisibleRect;
            this.restoreWindows;
            this.initializing=false;
            Gui.Chime;
            
            function openTree()
                FlowJoTree.Open(this.fig);
            end

            function notBusy
                Gui.HideBusy(this.fig, busy.busy, true);
            end
            
            function mirror
                if this.cbMirror.isSelected
                    this.app.set(FlowJoTree.PROP_SYNC_KLD, 'true');
                    if ~isempty(paramExp) && ~paramExp.isValid
                        paramExp=[];
                    end
                    if ~this.syncParameterExplorer(this.selectedKey)
                        FlowJoTree.MsgSelect;
                    end
                else
                    this.app.set(FlowJoTree.PROP_SYNC_KLD, 'false');
                end
            end
            
            function showFile
                if ~isempty(this.jdWsp)
                    this.jdWsp.setVisible(true);
                    this.jdWsp.toFront;
                    return;
                end
                btnWsp=Gui.NewBtn(Html.WrapSmall('Open<br><i><b>wsp</b></i>'),...
                    @(h,e)openWsp(), ['<html>Click "Open ' ...
                    'this workspace in FlowJo!</html>'], ...
                    'flowJo10small.png');
                if ispc
                    word='Microsoft File Explorer';
                else
                    word='MAC Finder';
                end
                btn=Gui.NewBtn(Html.WrapSmall('Open<br><i><b>folder</b></i>'),...
                    @(h,e)openFolder(), ['<html>Click "Open '...
                    '<b><i>folder</i></b>" to open a ' word  ...
                    ' window<br>on the folder containing '...
                    'this workspace file!</html>'], ...
                    'foldericon.png');
                if this.gml.isCloudUri
                    demoQuestion=Html.WrapHr(['Overwrite this workspace ' ...
                        'with the <i>original demo</i>?<br>' ...
                        Html.WrapBoldSmall(['(You will lose ' ...
                        '<font color=''red''>ALL</font>' ...
                        ' changes made to the demo </i>)']) ...
                        '<br><br>' ...
                        '<b><font color="red">Reset <i>demo</i> now??</font></b>']);
                    cmp=Gui.FlowLeftPanelBorder(btnWsp, btn, ...
                        Gui.NewBtn(Html.WrapSmall( 'Reset<br><i>demo</i>'), ...
                        @(h,e)resetDemo(), demoQuestion, 'cancel.gif'));
                else
                    cmp=Gui.FlowLeftPanelBorder(btnWsp, btn);
                end
                this.jdWsp=msg(struct('javaWindow', this.jw, ...
                    'component', cmp, 'msg', ...
                    ['<html>The workspace file and associated <br>'...
                    'files are here: <br>' fileHtml '<hr></html>']), ...
                    10, 'east+', 'WSP file location');
                edu.stanford.facs.swing.Basics.Shake(btnWsp, 5);
                this.app.showToolTip(btnWsp, char(btn.getToolTipText), ...
                    -15, 35);

                function openWsp
                    [yes, cancelled]=askYesOrNo(struct('javaWindow', ...
                        this.jdWsp, 'msg', Html.WrapHr(['Close ' ...
                        'workspace in <u>FlowJoBridge</u><br>' ...
                        'to avoid conflicts with <u>FlowJo</u>?']), ...
                        'where', 'north+'));
                    if cancelled
                        return;
                    end
                    if yes
                        close(this.fig);
                        if Gui.IsVisible(this.fig)
                            return;
                        end
                    end
                    if this.gml.unsavedChanges>0
                        this.btnSave.doClick;
                    end
                    if ismac
                        system(['open ' String.ToSystem(this.gml.file)]);
                    else
                        system(['cmd /c ' String.ToSystem(this.gml.file) '&']);
                    end
                                        
                end

                function openFolder
                    File.OpenFolderWindow(this.gml.file, 'openFolder', false);
                end

                function resetDemo
                    if askYesOrNo(struct('javaWindow', this.jw, ...
                            'msg', demoQuestion), 'Confirm', ...
                            'north east', false)
                        if ~this.gml.save
                            this.gml.doBackUp;
                        end
                        close(this.fig);
                        if exist(this.gml.file, 'file')
                            delete(this.gml.file);
                        end
                        if exist(this.gml.props.fileName, 'file')
                            delete(this.gml.props.fileName);
                        end
                        if exist(this.gml.propsGui.fileName, 'file')
                            delete(this.gml.propsGui.fileName);
                        end
                        FlowJoTree.NewOrReuse(this.gml.uri, ...
                            this.gml.resources);
                    end
                end
            end

            function J=eppBtn() 
                prefix=['<html><center>' ...
                    'Run <i>unsupervised</i> gating '...
                    'with EPP<br>' sm1 '(' b1 'E' b2 ...
                    'xhaustive ' b1 'P' b2 'rojection ' ...
                    b1 'P' b2 'ursuit)' sm2 '<hr>'];
                suffix=['<hr>' sm1 'Weighing more with' sm2 ...
                    '<br>Wayne Moore and David Parks' ...
                    '</center></html>'];
                if this.app.highDef
                    img=[Html.ImgXy('wayneMoore1.png', [], .9) ...
                        ' ' Html.ImgXy('parks.png', [], .68)];
                else
                    img=[Html.ImgXy('wayneMoore1.png', [], .6) ...
                        ' ' Html.ImgXy('parks.png', [], .42)];
                end
                tip=[prefix img suffix];
                [~,J]=Gui.ImageLabel(['<html>&nbsp;' ...
                    Html.ImgXy('epp.png',[],...
                    this.app.adjustHighDef(1.2, .4)) ...
                    '&nbsp;&nbsp;</html>'],  [], ...
                    tip, @(h,e)eppOptions(h));
                emptyBorder=javax.swing.BorderFactory.createEmptyBorder(0,44,0,0);
                J.setBorder(emptyBorder);
                J.setBackground(FlowJoTree.COLOR_YELLOW_LIGHT)
                border=javax.swing.BorderFactory.createLineBorder(...
                    java.awt.Color.blue);
                J.setBorder(border);
            
                function eppOptions(h)
                    v=SuhJsonSplitter.GetVersionText;
                    jm=PopUp.Menu;
                    Gui.NewMenuLabel(jm, 'Using modal clustering ');
                    Gui.NewMenuItem(jm, 'Run on selected gate', ...
                        @(h,e)runEpp(this, 'explore_hierarchy', false));
                    Gui.NewMenuItem(jm, ...
                        'Run with explore/compare windows', ...
                        @(h,e)runEpp(this, 'explore_hierarchy', true));
                    Gui.NewMenuItem(jm, ['Check for updates to ' v], ...
                        @(h,e)checkForUpdates());
                    Gui.NewMenuItem(jm, ...
                        'Alter EPP modal settings', ...
                        @(h,e)alterEppModalSettings(this));
                    
                    jm.addSeparator;
                    Gui.NewMenuLabel(jm, 'Using DBM clustering');
                    Gui.NewMenuItem(jm, ...
                        'Run on selected gate', ...
                        @(h,e)runEpp(this, 'create_splitter', ...
                        'dbm', 'explore_hierarchy', false));
                    Gui.NewMenuItem(jm, ...
                        'Run with explore/compare windows', ...
                        @(h,e)runEpp(this, 'create_splitter', ...
                        'dbm', 'explore_hierarchy', true));                    
                    Gui.NewMenuItem(jm, ...
                        'Alter EPP DBM settings', ...
                        @(h,e)alterEppDbmSettings(this));        
                    jm.addSeparator;
                    Gui.NewMenuItem(jm, 'Slide presentation', @(h,e)web( ...
                        ['https://1drv.ms/b/' ...
                        's!AkbNI8Wap-7_jOIovIYSl7wCo_awxA?e=DngGRy'],...
                        '-browser'));
                    Gui.NewMenuItem(jm, 'BD Symphony Tutorial (OMIP 044)', @(h,e)web( ...
                        ['https://docs.google.com/document/d/' ...
                        '1vZU-D_V8H_6eH2k8WdDLg1FVjMTHNUTzDIvq-yjvs0s/' ...
                        'edit?usp=sharing'], '-browser'));
                    Gui.NewMenuItem(jm, 'CyTOF Tutorial (Genentech)', @(h,e)web( ...
                        ['https://docs.google.com/document/d/' ...
                        '1Py-SNo32f6Js_MuMNsSndd2xzsSSZGW_gCeRVp0p5z0/' ...
                        'edit?usp=sharing'], '-browser'));
                    jm.show(h, 35, 35);
                end

                function checkForUpdates
                    Gui.Modem;
                    SuhJsonSplitter.GetUpdate([],true,this.jw);
                end
            end
            
            function J=mlpBtn()
                prefix=['<html><center>' ...
                    'Run <i>supervised</i> gating with MLP<br>' ...
                    sm1 '(' b1 'M' b2 'ulti-' b1 'L' b2 'ayer ' b1...
                    'P' b2 'erceptron neural networks' ')' sm2 '<hr>'];
                if this.app.highDef
                    img=Html.ImgXy('ebrahimian.png', [], .9);
                    factor=this.app.adjustHighDef(1.2, .4);
                else
                    img=Html.ImgXy('ebrahimian.png', [], .6);...
                    factor=.8;
                end
                tip=[prefix img '<hr>Jonathan Ebrahimian' ...
                    '</center></html>'];
                [~, J]=Gui.ImageLabel(['<html>&nbsp;' ...
                    Html.ImgXy('mlp.png', [], factor) ...
                    Html.WrapBoldSmall(' MLP')...
                    '&nbsp;&nbsp;</html>'],  [], ...
                    tip, @(h,e)mlpOptions(h));
                J.setBackground(FlowJoTree.COLOR_YELLOW_LIGHT)
                border=javax.swing.BorderFactory.createLineBorder(...
                    java.awt.Color.blue);
                J.setBorder(border);
                
                function mlpOptions(h)
                    jm=PopUp.Menu;
                    Gui.NewMenuItem(jm, ['Train a multi-layer ' ...
                        'perceptron neural network (MLP)'], ...
                        @(h,e)mlpTrain(this));
                    Gui.NewMenuItem(jm, ...
                        'Predict/classify gates using a trained MLP', ...
                        @(h,e)mlpPredict(this));
                    jm.addSeparator;
                    Gui.NewMenuItem(jm, ...
                        'Alter MLP settings for MATLAB''s fitcnet', ...
                        @(h,e)alterFitcnetSettings(this));

                    jm.addSeparator;
                    Gui.NewMenuItem(jm, 'Tutorial', ...
                        @(h,e)web(['https://docs.google.com/document' ...
                        '/d/1ICQuUkpFTVd-2k2kWvTgLlWBfUOhLAImzOBViIaeRPI' ...
                        '/edit?usp=sharing'], '-browser'));
                    
                    jm.show(h, 35, 35);
                end
            end

            function J=phateBtn()
               prefix=['<html><center>' ...
                   'Visualize data with PHATE'...
                    '<br>' sm1 ...
                    '(' b1 'P' b2 'otential of ' b1 'H' b2 ...
                    'eat-diffusion for ' b1 'A' b2 ...
                    'ffinity-<br>based ' b1 'T' b2 ...
                    'ransition ' b1 'E' b2 'mbedding)' ...
                    sm2 '<hr>'];
               suffix=['<hr>Smita Krishnaswamy<br>' ...
                   'Yale University</center></html>'];
                if this.app.highDef
                    smita=Html.ImgXy('krishnaswamy.png', [], .77);
                else
                    smita=Html.ImgXy('krishnaswamy.png', [], .45);
                end
                img='demoIcon.gif';
                [~, J]=Gui.ImageLabel(['<html>' ...
                    Html.WrapSm('PHATE&nbsp;')...
                    '</html>'],  img, ...
                    [prefix smita suffix], @(h,e)phateOptions(h));
                J.setBackground(FlowJoTree.COLOR_YELLOW_LIGHT)
                border=javax.swing.BorderFactory.createLineBorder(...
                    java.awt.Color.blue);
                J.setBorder(border);
                
                function phateOptions(h)
                    jm=PopUp.Menu;
                    Gui.NewMenuItem(jm, ...
                        'Reduce data', ...
                        @(h,e)phate(this, 1));
                    Gui.NewMenuItem(jm, ...
                        'Reduce with fast approximation', ...
                        @(h,e)phate(this, 2));
                    jm.addSeparator;
                    Gui.NewMenuItem(jm, ...
                        ['Reduce & compare to ' ...
                        'selected manual gates'],...
                        @(h,e)phate(this, 3));
                    Gui.NewMenuItem(jm, ...
                        ['Reduce & compare ' ...
                        'with fast approximation'],...
                        @(h,e)phate(this, 4));                    
                    jm.addSeparator;
                    Gui.NewMenuItem(jm, ...
                        'Alter PHATE settings', ...
                        @(h,e)alterPhateSettings(this));
                    jm.addSeparator;
                    Gui.NewMenuItem(jm, ...
                        'Read about PHATE',...
                        @(h,e)web(...
                        ['https://www.krishnaswamylab.org/' ...
                        'projects/phate'], '-browser'));
                    
                    jm.show(h, 35, 35);
                end
            end            
            
            function J=csvBtn()
               prefix=['<html><center>' ...
                   'Export/import both data and<br>' ...
                   'gate labels to a CSV file'...
                    '<br>' sm1 ...
                    '(CSV=' b1 'C' b2 'omma-' b1 'S' b2 ...
                    'eparated ' b1 'V' b2 ...
                    'alue file)' ...
                    sm2 '<hr>'];
               suffix='<hr></center></html>';
                if this.app.highDef
                    factor=1.72;
                else
                    factor=1.05;
                end
                [~, J]=Gui.ImageLabel(['<html>&nbsp;' ...
                    Html.ImgXy('foldericon.png', [], factor)  ...
                    Html.WrapSm('&nbsp;CSV&nbsp;')...
                    '</html>'],  [], ...
                    [prefix suffix], @(h,e)csvOptions(h));
                J.setBackground(FlowJoTree.COLOR_YELLOW_LIGHT)
                border=javax.swing.BorderFactory.createLineBorder(...
                    java.awt.Color.blue);
                J.setBorder(border);
                
                function csvOptions(h)
                    jm=PopUp.Menu;
                    Gui.NewMenuItem(jm, ...
                        'Export first selection to CSV file', ...
                        @(h,e)csv(this, true));
                    Gui.NewMenuItem(jm, ...
                        'Export selection''s gate labels for sample', ...
                        @(h,e)csv(this, 'sample labels'));
                    Gui.NewMenuItem(jm, ...
                        'Import a CSV file as label gates', ...
                        @(h,e)csv(this));
                    jm.show(h, 25, 25);
                end
            end    

            function J=qfMatchBtn()
                prefix=['<html><center>Match leaf gates under 2<br>' ...
                    'tree selections <br>with QFMatch<hr>'];
                if this.app.highDef
                    img=Html.ImgXy('darya.png', [], .39);
                    factor=.86;%2/this.app.toolBarFactor;
                else
                    img=Html.ImgXy('darya.png', [], .26);
                    factor=.84;
                end
                tip=[prefix img '<hr>Darya Orlova' ...
                    '</center></html>'];
                 [~, J]=Gui.ImageLabel(['<html>&nbsp;' ...
                    Html.WrapSm('QF<br>Match  ')...
                    '&nbsp;&nbsp;</html>'], ...
                    Gui.GetResizedImageFile('match.png', factor), ...
                    tip, @(h,e)matchOptions(h));
                J.setBackground(FlowJoTree.COLOR_YELLOW_LIGHT)
                border=javax.swing.BorderFactory.createLineBorder(...
                    java.awt.Color.blue);
                J.setBorder(border);
                function matchOptions(h)
                    jm=PopUp.Menu;
                    Gui.NewMenuItem(jm, ...
                        'QFMatch leaf gates under 2 gate selections',...
                        @(h,e)match(this));
                    Gui.NewMenuItem(jm, ...
                        ['<html>QFMatch ALL gates with same X/Y &amp; name<br>' ...
                        '&nbsp;&nbsp;(<i>find drag & drop issues</i>)</html>'],...
                        @(h,e)matchDimNameLevel(this), [], [], true,...
                        ['<html>Measure EMD similarity '...
                        ' between subsets with <br>same name, '...
                        'X/Y & hierarchy <i>position<</i> under '...
                        '<br>the 2 selections.... this serves as a copy'...
                        ' quality check.</html>'], this.app);
                    jm.addSeparator;
                    Gui.NewMenuItem(jm, 'QFMatch publication', ...
                        @(h,e)web( ...
                        'https://www.nature.com/articles/s41598-018-21444-4', ...
                        '-browser'));
                    Gui.NewMenuItem(jm, 'Tutorial on leaf gates', ...
                        @(h,e)web(['https://docs.google.com/document/d/'...
                        '18eWiChLsd45-5KgD0k9h1g0pEkmm933v9sRJopDyVIo/'...
                        'edit?usp=sharing'], '-browser'));
                    Gui.NewMenuItem(jm, 'Tutorial on ALL gates', @(h,e)web( ...
                        ['https://docs.google.com/document/d/' ...
                        '1uupMd9HR-1i9VQObWH-JW00ela2HrTfUVCk8oXgATWU/' ...
                        'edit?usp=sharing'], '-browser'));
                    
                    jm.show(h, 25, 25);
                end
            end

            function J=umapUstBtn()
                prefix=['<html><center>Visualize data ' ...
                    'with UMAP and UST<br>' sm1 ...
                    '(' b1 'U' b2 'niform ' b1 'M' b2 'anifold ' ...
                    b1 'A' b2 'pproximation &amp; ' b1 'P' b2 'rojection'...
                    '<br>and ' b1 'U' b2 'MAP ' ...
                    b1 'S' b2 'upervised ' b1 'T' b2 'emplates)'...
                    sm2 '<hr>' ];
                suffix=['<hr>Connor Meehan, MATLAB implementor<br>' ...
                    this.app.smallStart...
                    '(Invented by Leland McInnes)</center></html>'];
                if this.app.highDef
                    connor=Html.ImgXy('connor.png', [], .47);
                else
                    connor=Html.ImgXy('connor.png', [], .25);
                end
                img=Gui.GetResizedImageFile('umap.png', 1.5);
                [~, J]=Gui.ImageLabel(['<html>' ...
                    Html.WrapSm('UMAP/&nbsp;<br>UST')...
                    '</html>'],  img, ...
                    [prefix connor suffix], @(h,e)umapOptions(h));
                J.setBackground(FlowJoTree.COLOR_YELLOW_LIGHT)
                border=javax.swing.BorderFactory.createLineBorder(...
                    java.awt.Color.blue);
                J.setBorder(border);
                
                function umapOptions(h)
                    jm=PopUp.Menu;
                    Gui.NewMenuItem(jm, ...
                        'Reduce data', @(h,e)umap(this, 1));
                    Gui.NewMenuItem(jm, ...
                        'Reduce with fast approximation', ...
                        @(h,e)umap(this, 2));
                    jm.addSeparator;
                    Gui.NewMenuItem(jm, ...
                        'Supervise with manual gates', @(h,e)umap(this, 3));
                    Gui.NewMenuItem(jm, ...
                        'Supervise with fast approximation', ...
                        @(h,e)umap(this, 4));
                    jm.addSeparator;
                    Gui.NewMenuItem(jm, ...
                        'Reduce & compare to selected manual gates',...
                        @(h,e)umap(this, 5));
                    Gui.NewMenuItem(jm, ...
                        'Reduce & compare with fast approximation',...
                        @(h,e)umap(this, 6));
                    jm.addSeparator;
                    Gui.NewMenuItem(jm, ...
                        'Alter UMAP/UST settings', ...
                        @(h,e)alterUmapSettings(this));
                    Gui.NewMenuItem(jm, ...
                        'Tutorial', ...
                        @(h,e)tutorial());
                    jm.show(h, 25, 25);
                end
                 
                function tutorial()
                    web('https://storage.googleapis.com/cytogenie.org/FlowJoBridge/Docs/UMAP%20Demo%20in%20FlowJoBridge.pdf', '-browser');
                end

            end
           
            function seeResources(btn)
                keys=this.gml.resources.keys;
                N=length(keys);
                
                mnu=PopUp.Menu;
                if N>0
                    Gui.NewMenuLabel(mnu, 'Help resources');
                else
                    Gui.NewMenuLabel(mnu, 'No help resoures');
                end
                mnu.addSeparator;
                
                for ii=1:N
                    Gui.NewMenuItem(mnu, keys{ii}, ...
                        @(h,e)goto(keys{ii}));
                end
                mnu.show(btn, 25, 25)
            end

            function goto(key)
                uri=this.gml.resources.get(key);
                web(uri, '-browser');
            end
        end
        
        function [gates, nGates]=getSelectedGates(this)
            ids=this.getSelectedIds;
            nIds=length(ids);
            gates={};
            for i=1:nIds
                if this.gml.IsGateId(ids{i})
                    gates{end+1}=ids{i};
                end
            end
            nGates=length(gates);
        end

        function mlpTrain(this)
            ids=this.getSelectedIds;
            if isempty(ids)
                msgWarning('Select gates first..', 5, 'north east');
                return;
            end
            [python, holdout, limitArgName,limitArgValue]=...
                MlpGui.GetTrainSettings(...
                String.Pluralize2('gate selection', length(ids)), ...
                this.fig, this.app, this.multiProps);
            if isempty(python)
                return;
            end
            forPython=python==1;
            [data, names, labelPropsFile, gates, ~]...
                =this.packageSubsets(false);
            if isempty(data)
                msgWarning('No data for MLP!', 8, 'south east');
                return;
            end
            names{end}='label';
            busy=Gui.ShowBusy(this.fig, Gui.YellowSmall(...
                'MLP training is in session'), 'mlpBig.png', .46);
            try
                fldr=this.gml.getResourceFolder('MLP');
                fileName=gates{1}.getFileName(false);
                if length(gates)>1
                    fileName=[fileName '(' num2str(length(gates)) ')'];
                end
                model=fullfile(fldr, fileName);
                if ~forPython
                    if isnan(limitArgValue)
                        limitArgValue=1000;
                    end
                    if isnan(holdout)
                        validate=false;
                        holdout=0;% 2% for luck
                    else
                        validate=holdout>0;
                        holdout=holdout/100;
                    end
                    model=Mlp.Train(data, ...
                        'props', this.multiProps,...
                        'model_file', model, ...
                        'column_names', names, ...
                        'confirm', true,...
                        'hold', holdout, ...
                        'validate', validate, ...
                        'verbose', 1, ....
                        'VerboseFrequency', 50,...
                        limitArgName, limitArgValue);
                else
                    if isnan(limitArgValue)
                        limitArgValue=50;
                    end
                    model=MlpPython.Train(...
                        data, ...
                        'column_names', names, ...
                        'model_file', model, ...
                        'props', this.multiProps,...
                        'confirm', true, ...
                        'wait', false,...
                        limitArgName, limitArgValue);
                end
                saveLabelProperties(model);
            catch ex
                ex.getReport
            end
            Gui.HideBusy(this.fig, busy, true);

            function fileName...
                    =saveLabelProperties(model)
                if isempty(model)
                    fileName=[];
                    return;
                end
                [p,f]=fileparts(model);
                fileName=fullfile(p, [f '.properties']);
                copyfile(labelPropsFile, fileName);
            end
        end

        function mlpPredict(this)
            ids=this.getSelectedIds;
            if isempty(ids)
                msgWarning('Select gates first..', 5, 'north east');
                return;
            end
            fldr=this.gml.getResourceFolder('MLP');
            doingFitcnet=~verLessThan('matLab', '9.10');
            if doingFitcnet
                [choice, cancelled]=...
                    Gui.Ask(['<html>Predict using which ' ...
                    '<i>type</i><br>of MLP model?</html>'], ...
                    {'Python''s TensorFlow', ...
                    'MATLAB''s fitcnet'},...
                    'FlowJoBridge.WhichMlp', 'MLP predicting/classifying...', 1);
                if cancelled
                    return;
                end
                forPython=choice==1;
            else
                forPython=true;
            end
            if forPython
                mlpFile=uiGetFile({'*.h5'}, fldr, ...
                    Html.WrapHr(['Select a <u>Tensorflow</u> '...
                    'MLP file <br>' Html.WrapBoldSmall(...
                    ['(this uses the extension ' ...
                    '<font color="blue">*.h5</font>)'])]));
                if ~isempty(mlpFile) && endsWith(mlpFile, '.h5')
                    model=mlpFile(1:end-3);
                end
            else
                mlpFile=uiGetFile({'*.mlp.mat'}, fldr, ...
                    Html.WrapHr(['Select a <u>fitcnet</u> '...
                    'MLP file <br>' Html.WrapBoldSmall(...
                    ['(this uses the extension ' ...
                    '<font color="blue">*.mlp.mat</font>)'])]));
                if ~isempty(mlpFile) && endsWith(mlpFile, '.mlp.mat')
                    model=mlpFile(1:end-8);
                end
            end
            if isempty(mlpFile)
                return;
            end
            args.mlp_supervise=true;
            args.flowjo_ask=true;
            [data, columnNames, ~, gates, args.sample_offsets]...
                =this.packageSubsets(true, false);
            if isempty(data)
                msgWarning('No data for UMAP!', 8, 'south east');
                return;
            end
            busy=Gui.ShowBusy(this.fig, Gui.YellowSmall(...
                'MLP is classifying/predicting gates'), 'mlpBig.png', .46);
            this.tb.setEnabled(false);
            try
                if ~forPython
                    labels=Mlp.Predict(...
                        data, ...
                        'has_label', false, ...
                        'column_names', columnNames,...
                        "model_file", model, ...
                        "confirm", false);
                else
                    labels=MlpPython.Predict(...
                        data, ...
                        'has_label', false, ...
                        'column_names', columnNames,...
                        "model_file", model, ...
                        "confirm", false);
                end
                jp=JavaProperties([model '.properties']);
                FlowJoTree.CreateLabelGates('MLP',...
                    'mlp.png',data, labels, jp, columnNames, gates, args);
            catch ex
                ex.getReport
            end
            Gui.HideBusy(this.fig, busy, true);
            this.tb.setEnabled(true);
            this.btnSave.setEnabled(this.gml.unsavedChanges>0);
        end

        function yes=isTreeVisible(this)
            yes=~isempty(this.fig) && ishandle(this.fig) ...
                && strcmpi('on', get(this.fig, 'Visible'));
        end
        
        function parentIds=getParentIds(this, key)
            parentIds=this.gml.getParentIds(this.gml.getNodeById(key));
        end

        function pid=getParentId(this, key)
            pid=this.gml.getParentId(key);
        end

        function [axOrKld, ax]=showParameterExplorer(this, gate, axOrKld)
            if ~FlowJoWsp.IsGateId(gate)
                ax=[];
                if nargin<3
                    axOrKld=[];
                end
                warning('%s is not at gate key', key);
                return;
            end
            key=gate;
            [gater, gate]=this.getGate(gate);
            if isempty(gate)
                ax=[];
                if nargin<3
                    axOrKld=[];
                end
                warning('Gate for key=%s is not found', key);
                return;
            end
            [data, columnNames]=gate.getDataForAutoGating;
            createdKld=nargin<3;
            if createdKld
                if isempty(data)
                    ax=[];
                    if nargin<3
                        axOrKld=[];
                    end
                    return;
                end
                createdKld=true;
                axOrKld=Kld.Table(data, columnNames, ...
                    [],... % no normalizing scale
                    gcf, gate.name,'south++','Parameter', 'Subset', ...
                    false, [], {this.fig, 'east++', true}, false,...
                    [],'subsetKld',@(tb, init)exportFromParameterExplorer(this, init));
                fldr=this.gml.props.get(FlowJoTree.PROP_EXPORT_FLDR,...
                    this.gml.getResourceFolder('exported'));
                axOrKld.table.setFldr(fldr);
                this.figNamePrefix=axOrKld.getFigure.Name;
            end
            if isa(axOrKld, 'Kld')
                jw2=Gui.JWindow(  axOrKld.getFigure );
                jw2.setAlwaysOnTop(true);
                this.jw.setAlwaysOnTop(true);
                drawnow;
                [~,sampleName, sampleCount]=...
                    gater.gml.getSampleIdByGate(gate.population);
                sn=[sampleName ' '  String.encodeK(sampleCount)];                
                axOrKld.getFigure.Name=[this.figNamePrefix ', sample=' sn];
                parentGate=gate.getParent;
                axOrKld.table.setObjectName(String.ToFile(gate.getName));
                hasParent= ~isempty(parentGate) && ~isempty(parentGate.id);
                if ~hasParent                    
                    axOrKld.initPlots(1, 2);
                    ax=axOrKld.getAxes;
                    sp=SuhPlot(gater, gate, false, ax, false);
                    if isempty(sp.ax)
                        msgError('<html>Cannot show: gate <hr></html>');
                        return;
                    end
                else
                    axOrKld.initPlots(1, 3);
                    ax=axOrKld.getAxes;
                    sp=SuhPlot(gater, parentGate, ...
                        false, ax, false);
                    if isempty(sp.ax)
                        msgError('<html>Cannot show gate <hr></html>');
                    else
                        ax=axOrKld.getAxes(2);
                        sp=SuhPlot(gater, gate, false, ax, false);
                        if isempty(sp.ax)
                            msgError('<html>Cannot show gate <hr></html>');
                            return;
                        end
                    end
                end
                if ~createdKld
                    axOrKld.refresh(data, gate.name);
                end
                jw2.setAlwaysOnTop(false);
                this.jw.setAlwaysOnTop(false)
            else
                if strcmpi('figure', get(axOrKld, 'type'))
                    ax=Gui.Axes(axOrKld);
                else
                    ax=axOrKld;
                end
                sp=SuhPlot(gate.gater, gate, false, ax, false);
                if isempty(sp.ax)
                    msgError('<html>Cannot show gate <hr></html>');
                    return;
                end
            end
        end     
        
        function runEpp(this, varargin)
            nSelected=length(this.getSelectedIds);
            if nSelected==0
                msgWarning(Html.WrapHr('Select a gate first...'), ...
                    5, 'north east');
                return;
            end
            if nSelected>1
                msgWarning(Html.WrapHr(['Select only <b>ONE</b> ' ...
                    'gate for EPP ...']), ...
                    5, 'north east');
                return;
            end
            exploring=isequal(true, ...
                Args.Get('explore_hierarchy', varargin{:}));
            [data, names, labelPropsFile, ~, gate, leaves, ~, columns]...
                =this.packageSubset(this.selectedKey, true, ...
                this.pipelineFcsParameters, false, ~exploring);
            if isempty(data)
                msgWarning('No data for EPP!', 8, 'south east');
                return;
            end
            if gate.fcs.hdr.isCytof
                cytometer='cytof';
            elseif gate.fcs.isSpectral
                cytometer='spectral';
            else
                cytometer='conventional';
            end
            gate.transferPickColumnsToMatch;
            varArgs=[this.getPipelineArgs(gate) varargin];
            isDbm=strcmpi('dbm', Args.Get('create_splitter', varargin{:}));
            if isDbm
                if ~isempty(this.eppDbmVarArgIn)
                    varArgs=[varArgs this.eppDbmVarArgIn];
                end
            else
                if ~isempty(this.eppModalVarArgIn)
                    varArgs=[varArgs this.eppModalVarArgIn];
                end
            end
            args=Args.NewKeepUnmatched(SuhEpp.DefineArgs, varArgs{:});
            if args.ignore_off_scale
                %remove off scale
                r=gate.getSampleRows;
                on=gate.fcs.getOnScale(args.max_stain/100, ...
                    args.max_scatter/100);
                l=on(r);
                if size(data,1)>sum(l)
                    warning('%d off scale events removed ...', size(data,1)-sum(l));
                end
                data=data(l, :);
            end
            if args.explore_hierarchy && length(leaves)>5
                [yes, cancelled]=askYesOrNo( ...
                    struct('msg', Html.WrapHr(sprintf(...
                    ['<b>Compare EPP to prior gating?</b><br><br>' ...
                    Html.WrapSm(['(When <b><i>finished</i></b> QFMatch ' ...
                    'compares the EPP hierarchy''s leaves' ...
                    '<br>with the %d leaves of your currently ' ...
                    'selected hierarchy)'])], ...
                    length(leaves))), ...
                    'javaWindow', this.jw),...
                    'Run QFMatch ?', 'center', true, [], ...
                    'FlowJoTree.EppLeaves');
                if cancelled
                    return;
                end
                supervised=yes;
            else
                supervised=false;
            end
            varArgs{end+1}='locate_fig';
            varArgs{end+1}={this.fig, 'south east+', true};
            varArgs{end+1}='store';
            varArgs{end+1}=gate.getEppGateCreatorFunction(columns, false);
            eppFolder=this.gml.getResourceFolder(...
                'epp', [gate.getFileName '.' num2str(supervised)]);
            busy=Gui.ShowBusy(this.fig, ...
                Gui.YellowH3('Weighing more gates<br>with EPP'),...
                'moore.png', .66, false);
            try            
                if supervised
                    SuhEpp.New(data, ...
                        'column_names', names, ...
                        'label_column', 'end', ...
                        'label_file', labelPropsFile, ...
                        'cytometer', cytometer,...
                        'folder', eppFolder, ...
                        varArgs{:});
                else
                    if exploring
                        data=data(:,1:end-1);
                        names(end)=[];
                        varArgs=Args.RemoveArg(varArgs, 'label_column');
                    end
                    SuhEpp.New(data, ...
                        'column_names', names, ...
                        'cytometer', cytometer, ...
                        'folder', eppFolder, ...
                        'never_reuse', true, ...
                        varArgs{:});
                end
                this.setSaveBtn('Click here to save EPP results...');
            catch ex
                ex.getReport
            end
            Gui.HideBusy(this.fig, busy, true);
        end
        
        
        function [data, columnNames, labelPropsFile, csvFile, ...
                gate, leaves, props, columns]=packageSubset(...
                this, key, askUser, columns, writeCsv, justData,...
                fullNameMap, fig)
            if nargin<8
                fig=this.fig;
                if nargin<7
                    fullNameMap=[];
                    if nargin<6
                        justData=false;
                        if nargin<5
                            writeCsv=false;
                            if nargin<4
                                columns=[];
                                if nargin<3
                                    askUser=true;
                                    if nargin<2
                                        key=this.selectedKey;
                                    end
                                end
                            end
                        end
                    end
                end
            end
            csvFile='';
            gate=[];   
            if isempty(key)
                reject
                return;
            end            
            [gater, gate]=this.getGate(key);
            if isempty(gater)
                reject
                return;
            end
            if gater.isLimitedForDisplay
                [gater, gate]=this.getGate(key, this.gatersAllData, 0);
            end
            [data, columnNames, labelPropsFile, csvFile, gate, ...
                leaves, props, columns]=gater.packageSubset(...
                gate, askUser, columns, writeCsv, justData, ...
                fig, fullNameMap);

            function reject
                msgWarning(Html.WrapHr(['First select a '...
                    '<br>subset or sample...']), 7,...
                    'south west')
                data=[];
                columnNames={};
                labelPropsFile='';
                leaves={};
                props=[];
            end
        end

        function disable(this, ttl, fig)
            if nargin<3
                fig=this.fig;
                if nargin<2
                    ttl='One moment ...';
                end
            end
            if ~isempty(fig)
                Gui.ShowFacs(fig, ttl);
            end
            if ~isempty(this.tb)
                this.tb.setEnabled(false);
            end
        end

        function enable(this, fig)
            if nargin<2
                fig=this.fig;
            end
            if ~isempty(fig)
                Gui.HideBusy(fig);
            end
            if ~isempty(this.tb)
                this.tb.setEnabled(true);
                this.btnSave.setEnabled(this.gml.unsavedChanges>0);
            end
        end

        function setSaveBtn(this, tip)
            btn=this.btnSave;
            if ~isempty(btn)
                yes=this.gml.unsavedChanges>0;
                btn.setEnabled(yes);
                if yes
                    edu.stanford.facs.swing.Basics.Shake(btn, 7);
                    if nargin<2
                        tip=char(btn.getToolTipText);
                    end
                    this.app.showToolTip(btn, ...
                        tip, -15, 35);
                end
            end
        end
    end
    
    methods(Access=private)
        function [data, names]=exportFromParameterExplorer(this, initializing)
            data=[];
            names={};
            if nargin>1 && initializing
                return;
            end
            pu=PopUp('Classifying leaf gates', 'north');
            paramExp=this.parameterExplorer;
            try
                [~, mrs]=paramExp.table.getSelectedRows;
                if ~isempty(mrs)
                    [yes, cancelled]=askYesOrNo(struct('javaWindow', ...
                        this.jw, 'msg', [...
                        '<html><center>Restrict data export to the <br>' ...
                        num2str(length(mrs)) ' selected columns?'...
                        '<hr></center></html>']));
                    if cancelled
                        pu.close;
                        return;
                    end
                    if ~yes
                        mrs=[];
                    end
                end
                [gater, gate]=this.getGate(this.curParameterExplorerKey);
                if gater.isLimitedForDisplay
                    [data, names]=this.packageSubset(...
                        this.curParameterExplorerKey);
                    pu.close;
                    return;
                end
                props=JavaProperties;
                classifier=gater.classifyLeaves(gate, props);
                [labelColumn, cancelled]=classifier.choose(true, this.fig);
                if cancelled
                    pu.close;
                    return;
                end
                rows=gate.getSampleRows;
                labelColumn=labelColumn(rows);
                if isempty(mrs)
                    names=[paramExp.columnNames 'classification label'];
                    try
                        data=[paramExp.recentData labelColumn'];
                    catch
                        data=[paramExp.recentData labelColumn];
                    end
                else
                    names=[paramExp.columnNames(mrs) 'classification label'];
                    try
                        data=[paramExp.recentData(:, mrs) labelColumn'];
                    catch
                        data=[paramExp.recentData(:, mrs) labelColumn];
                    end
                end
                this.gml.props.get(FlowJoTree.PROP_EXPORT_FLDR,...
                    fileparts(paramExp.table.lastCsvFile));
                props.save(File.SwitchExtension2( paramExp.table.lastCsvFile, '.properties'));
            catch ex
                ex.getReport
            end
            pu.close;
        end
        
        function ok=nodeExists(this, key)
            ok=~isempty(this.gml.getNodeById(key));
        end
        
    end
    
    properties(SetAccess=private)
        oneClick=false;
        nextKldSync;
        curParameterExplorerKey;
    end
    
    methods(Access=private)
        function nodeSelectedCallback(this, evd)
            if ~this.hearingChange
                uiNode=evd.getCurrentNode;
                [ids, nSelected]=this.getSelectedIds;
                this.selectedKey=char(uiNode.getValue);
                if nSelected>0 && ...
                    ~StringArray.Contains(ids, this.selectedKey)
                    this.selectedKey=ids{1};
                end
                this.oneClick=true;
                this.nextKldSync=this.selectedKey;
                if ~this.initializing
                    MatBasics.RunLater(@(h,e)syncIfOneClick(this), 1);
                end
                this.toggleFlashlightButton;
                if nSelected==2
                    edu.stanford.facs.swing.Basics.Shake(...
                        this.btnMatch, 2);
                    this.app.showToolTip(this.btnMatch,Html.WrapSmall(...
                        ['Click <b>here</b> to match<br>'...
                        'the 2 groups of subsets']), ...
                        12, 23, 0, [], true, .31);
                end
            end
        end

        function phenogram(this)
            ids=this.getSelectedIds;
            nIds=length(ids);
            if nIds==0
                msgWarning('Select gates first..', 5, 'north east');
                return;
            end
            Gui.ShowFacs(this.fig, 'Computing phenogram...');
            for i=1:nIds
                [data, ~, lblFile, ~, gate, ~]...
                    =this.packageSubset(ids{i});
                if isempty(data)
                    break;
                end
                lbls=data(:,end);
                idMap=JavaProperties(lblFile);
                [names, clrs]=LabelBasics.NamesAndColors(lbls, idMap);
                if i==1
                    fig_=this.fig;
                else
                    fig_=nextFig;
                end
                ttl=Html.Remove(gate.describe);
                [~, ~, nextFig]=run_QfTree(data(:,1:end-1), lbls, {ttl},...
                    'trainingNames', names, 'log10', true, 'colors', clrs, ...
                    'locate_fig', {fig_, 'east', true});
            end
            Gui.HideBusy(this.fig, [], true);
        end

        function mds(this)
            ids=this.getSelectedIds;
            nIds=length(ids);
            if nIds==0
                msgWarning('Select gates first..', 5, 'north east');
                return;
            end
            Gui.ShowFacs(this.fig, 'Scaling multi-dimensions..');
            for i=1:nIds
                [data, columnNames, lblFile, ~, gate, ~]...
                    =this.packageSubset(ids{i});
                if isempty(data)
                    break;
                end
                lbls=data(:,end);
                idMap=JavaProperties(lblFile);
                [mdns, sizes]=LabelBasics.Median(data(:,1:end-1), lbls);
                [names, clrs]=LabelBasics.NamesAndColors(lbls, idMap);
                if i==1
                    fig_=this.fig;
                else
                    fig_=nextFig;
                end
                [~, nextFig]=MDS.New(names, columnNames(1:end-1), ...
                    clrs, mdns, sizes, ['MDS: ' ...
                    Html.Remove(gate.describe)], ...
                    {fig_, 'east', true});
            end
            Gui.HideBusy(this.fig, [], true);
        end

        function exportCsv(this)
            ids=this.getSelectedIds;
            nIds=length(ids);
            if nIds==0
                msgWarning('Select gates first..', 5, 'north east');
                return;
            end
            for i=1:nIds
                packageSubset(this, ids{i}, true, [], true);
            end
        end
        function viewMenu(this, h)
            ids=this.getSelectedIds;
            nIds=length(ids);
            if nIds==0
                msg('Requires gate selections..', 5, 'north east');
            end
            jMenu=PopUp.Menu;
            Gui.NewMenuItem(jMenu, '<html>Heat map</html>',...
                @(h,e)showHeatMap(this), 'heatMapHot.png');
            Gui.NewMenuItem(jMenu, ['<html>Phenogram ' this.app.supStart...
                '(QF-tree</i>)' this.app.supEnd '</html>'],...
                @(h,e)phenogram(this), 'phenogram.png');
            Gui.NewMenuItem(jMenu, ['<html>MDS ' this.app.supStart...
                '(multi-dimensional scaling)' this.app.supEnd ...names
                '</html>'], @(h,e)mds(this), 'mds.png');
            Gui.NewMenuItem(jMenu, 'Phenogram & MDS publication', ...
                @(h,e)web('https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6586874/', '-browser'),...
                'help2.png')
            jMenu.addSeparator;
            Gui.NewMenuItem(jMenu, 'Export CSV files with classification labels', ...
                @(h,e)exportCsv(this),'save16.gif')
            jMenu.show(h, 15, 25);
        end

        function match(this)
            if this.getSelectionCount~=2
                msgWarning(Html.WrapHr([...
                    'Select 2 gates with <br>'...
                    '3+ leaf gates.']));
                return;
            end
            ids=this.getSelectedIds;
            fcsNames=this.getCommonColumnNames(ids, true, {}, ...
                FlowJoTree.PROPS_MATCH);
            if isempty(fcsNames)
                return;
            end
            [trainData, columnNames, trainLabelFile, ~, trainGate, trainLeaves]...
                =this.packageSubset(ids{1}, [false true], fcsNames);
            if isempty(trainData)
                return;
            end
            if length(trainLeaves)<=3
                msgWarning(Html.WrapHr([...
                    'Select 2 gates with <br>'...
                    '3+ leaf gates.']));
                return;
            end
            [testData, ~, testLabelFile, ~, testGate, testLeaves]...
                =this.packageSubset(ids{2}, [false true], ...
                fcsNames);%eliminate classifier label            
            if isempty(testData)
                return;
            end
            if length(testLeaves)<=3
                msgWarning('Select two subsets with 3+ leaves.');
                return;
            end            
            trainSampleId=trainGate.getSampleId;
            testSampleId=testGate.getSampleId;
            if ~isequal(trainSampleId, testSampleId)
                matchStrategy=1;
            else
                matchStrategy=2;
                trainRows=trainGate.getSampleRows;
                R=length(trainRows);
                data=zeros(R, length(columnNames)-1);
                data(trainRows,:)=trainData(:,1:end-1);%no label column 
                trainLabels=zeros(R, 1);
                trainLabels(trainRows)=trainData(:,end);
                testRows=testGate.getSampleRows;
                data(testRows,:)=testData(:,1:end-1);
                testLabels=zeros(R, 1);
                testLabels(testRows)=testData(:,end);
                trainData=[data trainLabels];
                testData=[data testLabels];
            end
            [rb, cancelled]=askYesOrNo( ...
                struct('javaWindow', this.jw, 'property', ...
                'QfHiDM.ROBUST_CONCORDANCE', 'msg', Html.WrapHr( ...
                ['Do robust concordance?<br><br>' ...
                Html.WrapSm('(costs more time)')])), ...
                'Confirm....', 'center', true, []);
            if ~cancelled
                run_match(...
                    'javaWindow', this.jw,...
                    'training_set', trainData,  ...
                    'training_label_file', trainLabelFile, ...
                    'test_set', testData,  ...
                    'test_label_file', testLabelFile,...
                    'column_names', columnNames, ...
                    'matchStrategy', matchStrategy, ...
                    'locate_fig', {this.fig, 'north east+', true},...
                    'select_callback', @hearSelections, ...
                    'robustConcordance', rb);
            end
            function hearSelections(listener)
                N=length(listener.lastLbls);
                for i=1:N
                    this.ensureVisible([FlowJoWsp.TYPE_GATE ':ID'  ...
                        num2str(listener.lastLbls(i))], 1);
                end
            end
        end
        
        function matchDimNameLevel(this)
            if this.getSelectionCount~=2
                msgWarning(Html.WrapHr([...
                    'Select 2 gates with <br>'...
                    '3+ leaf gates.']));
                
                return;
            end
            ids=this.getSelectedIds;
            [~, tGate]=this.getGate(ids{1});
            [~, sGate]=this.getGate(ids{2});
            if tGate.isSample || sGate.isSample
                msgError('Select gates, not samples!')
                return;
            end
            this.disable([...
                'Matching 2 gate hierarchies for gates'...
                '<br>with same name and X/Y']);
            
            tDims=tGate.getAncestorDimsAndData;
            [tMap, tDims2]=tGate.getDescendants;
            tDims.addAll(tDims2);
            [tMarkers, tFcsIdxs]=tGate.fcs.findMarkers(tDims);
            sDims=sGate.getAncestorDimsAndData;
            [sMap, sDims2]=sGate.getDescendants;
            sDims.addAll(sDims2);
            [sMarkers, sFcsIdxs]=sGate.fcs.findMarkers(sDims);
            if tMarkers.equals(sMarkers)
                fcsIdxs=sFcsIdxs;
            elseif sMarkers.containsAll(tMarkers)
                fcsIdxs=tFcsIdxs;
            elseif tMarkers.containsAll(sMarkers)
                fcsIdxs=sFcsIdxs;
            else
                fcsIdxs=[];
                if sMarkers.size>tMarkers.size
                    me=tMarkers;
                    meIdxs=tFcsIdxs;
                    you=sMarkers;
                else
                    me=sMarkers;
                    meIdxs=sFcsIdxs;
                    you=tMarkers;
                end
                nMe=me.size;
                for i=1:nMe
                    if you.contains(me.get(i-1))
                        fcsIdxs(end+1)=meIdxs(i);
                    end
                end
                if length(fcsIdxs)<3
                    msgError('< 3 common parameters');
                    this.enable;
                    return;
                end
            end            
            if tMap.size<1
                msgError(Html.WrapHr(sprintf(['"<b>%s</b>" needs'...
                    '<br>1 or more sub gates.'], tGate.name)));
                this.enable;
                return;
            end
            if sMap.size<=1
                msgError(Html.WrapHr(sprintf(['"<b>%s</b>" needs'...
                    '<br>1 or more sub gates.'], sGate.name)));
                this.enable;
                return;
            end
            tData=tGate.fcs.transformColumns(...
                [], fcsIdxs, false, true);
            sData=sGate.fcs.transformColumns(...
                [], fcsIdxs, false, true);
            ab=SuhProbabilityBins.Bins(tData, sData);
            data={};
            names=tMap.keys;
            N=length(names);
            for i=1:N
                name=names{i};
                tGate2=tMap.get(name);
                sGate2=sMap.get(name);
                if ~isempty(sGate2)
                    if tGate2.hasSameDims(sGate2)
                        ds=ab.distance(tGate2.getSampleRows, ...
                            sGate2.getSampleRows, false);
                        data(end+1,:)={1-ds, tGate2.name, ...
                            name, tGate2, sGate2};
                    else
                        fprintf(...
                            '%s has different dims %sx%s & %sx%s\n',...
                            tGate2.name, tGate2.dims{1}, tGate2.dims{2},...
                            sGate2.dims{1}, sGate2.dims{2});
                    end
                end
            end
            this.enable;
            if ~isempty(data)
                SuhSimilarityTable(this, data);
            else
                msg('No matches found!', 5, 'north east');
            end
        end
        
        function cnt=getSelectionCount(this)
            cnt=this.suhTree.jtree.getSelectionCount;
        end
        
        function syncIfOneClick(this)
            if this.oneClick ...
                    && isequal(this.selectedKey, this.nextKldSync)...
                    && ~isequal(this.selectedKey, this.curParameterExplorerKey)...
                    && this.cbMirror.isSelected
                this.syncParameterExplorer(this.selectedKey)
            end
        end

        function ok=syncParameterExplorer(this, key)
            ok=false;
            busyJw=[];
            wasEnabled=[];
            if ~isempty(key) && ~this.isSyncingKld
                try
                    this.isSyncingKld=true;
                    disp('Syncing KLD')
                    paramExp=this.parameterExplorer;
                    if FlowJoWsp.IsGateId(key)
                        edu.stanford.facs.swing.Basics.Shake(...
                            this.cbMirror, 2);
                        img=Html.ImgXy('pseudoBarHi.png', [], .92);
                        this.app.showToolTip(this.cbMirror,...
                            Html.WrapSmall(...
                            ['De-select <b>Sync ' img '</b> to STOP <br>'...
                            'synchronizing every selection.<hr>']), ...
                            12, 23, 0, [], true);
                        html=[this.app.smallStart ...
                            'Synchronizing ' img '<b>' ...
                            this.app.supStart ' Subset ParameterExplorer'...
                            this.app.supEnd '</b><br>with selection in ' ...
                            Html.ImgXy('tree.png', [], 1.2)...
                            this.app.supStart ' ' this.fig.Name ...
                            this.app.supEnd '' this.app.smallEnd];
                        if isempty(paramExp) || ~paramExp.isValid
                            busyJw=this.jw;
                            [~, wasEnabled]=Gui.ShowFacs(busyJw, html);
                            paramExp=this.showParameterExplorer(key);
                            ok=true;
                        elseif paramExp.isValid
                            busyJw=Gui.JWindow(  paramExp.getFigure);
                            [~, wasEnabled]=Gui.ShowFacs(busyJw, html);
                            paramExp=this.showParameterExplorer(key, paramExp);
                            ok=true;
                        end
                        this.curParameterExplorerKey=key;
                    else
                        edu.stanford.facs.swing.Basics.Shake(...
                            this.cbMirror, 2);
                        this.app.showToolTip(this.cbMirror, ...
                            Html.WrapSmall(...
                            ['Click <b>here</b> to keep the<br>'...
                            'Subset ParameterExplorer in sync']), ...
                            12, 23, 0, [], true, .31);
                    end
                    this.parameterExplorer=paramExp;
                catch ex
                    ex.getReport
                end
                close;
            end
            
            function close
                if ~isempty(busyJw)
                    Gui.HideBusy(busyJw, [], wasEnabled);
                end
                MatBasics.RunLater(@(h,e)off, .2);
            end
            function off
                this.isSyncingKld=false;
            end
        end
        
        function keyPressedFcn(this, eventData)
            this.suhTree.trackStateKeys(eventData);
        end

        function mouseMoveFcn(this, eventData)
            %disp(MatBasics.SourceLocation('STILL not implemented'));
        end
        
        function contextMenu(this, popup, eventData, forAutoComplete)
            MatBasics.SourceLocation('STILL not implemented')
        end
        
        function renameNode(this, id)
            MatBasics.SourceLocation('STILL not implemented')
        end
        
        function unexpanded=getUnexpanded(this, uiNode, unexpanded)
            if nargin>2
                unexpanded=SuhTree.GetUnexpanded(this.suhTree.jtree, ...
                    this.suhTree.root, uiNode, unexpanded);
            else
                unexpanded=SuhTree.GetUnexpanded(this.suhTree.jtree, ...
                    this.suhTree.root, uiNode);
            end
        end
        
        function [ids, N]=getUnexpandedIds(this, start)
            if nargin<2
                start=this.suhTree.root;
            else
                try
                    start=start(1);
                catch
                end
            end
            if isempty(start)
                ids={};
                N=0;
                return;
            end
            unexpanded=this.getUnexpanded(start);
            N=unexpanded.size;
            ids=java.util.ArrayList;
            for i=0:N-1
                ids.add(java.lang.String(unexpanded.get(i).getValue));
            end
            [~,ids]=this.gml.getExpandableIds(ids);
        end
    end
    
    methods
         function rememberOpenPlots(this)
             ids=this.getOpenPlots;
             if ~isempty(ids)
                 this.gml.propsGui.set('lastOpenPlots', ...
                     FlowJoWsp.Ids2Str(this.getOpenPlots));
             else
                 this.gml.propsGui.remove('lastOpenPlots');
             end
         end
         
         function ids=getOpenPlots(this)
             ids={};
            N=length(this.figs);
            for i=1:N
                if ishandle(this.figs{i})
                    if isa(this.figs{i}.UserData, 'SuhPlot')
                        ids{end+1}=this.figs{i}.UserData.gate.id;
                    end
                end
            end
         end

         function find(this)
             FlowJoSearch(this);
         end

         function deleteGate(this)
             ids=this.getSelectedGates;
             nIds=length(ids);
             if nIds<1
                 msg(struct('javaWindow', this.jw, ...
                     'msg', 'First select 1 or more gates.'));
                 return;
             end
             if askYesOrNo(struct('msg', Html.SprintfHr('Remove "<b>%s</b>"?', ...
                     String.Pluralize2('selected gate', nIds)), ...
                     'javaWindow', this.jw))
                 saveEnabled=false;
                 for i=1:nIds
                     id=ids{i};
                     [gater, g]=this.getGate(id);
                     if ~isempty(g)
                         P=g.getParent;
                         if ~isempty(P)
                             pid=P.id;
                             gater.gml.delete(g.population);
                             gater.gml.resyncChildren(pid);
                             this.suhTree.ensureChildUiNodesExist(pid, true);
                             this.closeDescendentPlots(id);
                         end
                         if ~saveEnabled
                             g.enableSave;
                             saveEnabled=true;
                         end
                     end
                 end
                 this.suhTree.ensureVisible(pid,true);
                 Gui.Thunk;
                 %this.syncParameterExplorer(pid);
             end
         end

         function ids=closeDescendentPlots(this, possibleAncestor)
             ids={};
            N=length(this.figs);
            for i=1:N
                f=this.figs{i};
                if ishandle(f)
                    if isa(f.UserData, 'SuhPlot')
                        u=f.UserData;
                        g=u.gate;
                        possibleDescendent=g.id;
                        if this.gml.isDescendent(...
                                possibleDescendent, possibleAncestor)
                            close(f);
                        elseif this.gml.isDescendent(...
                                possibleAncestor, u.parentGate.id)
                            f.UserData.removeGateById(possibleAncestor)
                        end
                    end
                end
            end
         end

        function rememberExpanded(this, id)
            if isempty(this.suhTree)
                return;
            end
            if nargin>1 && ischar(id)
                uiNode=this.suhTree.uiNodes.get(id);
            else
                uiNode=[];
            end
            if isempty(uiNode)
                uiNode=this.suhTree.root;
            end
            p=this.gml.propsGui;
            vp=javaObjectEDT(this.suhTree.jtree.getParent);            
            rect=javaObjectEDT(vp.getViewRect);
            p.set('lastVisibleRect', num2str([rect.x, rect.y ...
                rect.width rect.height]));
            [unexpanded, nUnexpanded]=this.getUnexpandedIds(uiNode);
            p.set('nUnexpanded', num2str(nUnexpanded));            
            p.set('unexpanded', unexpanded);
            p.set('lastSelectedIds', ...
                FlowJoWsp.Ids2Str(this.getSelectedIds));
            
        end
        
        function restoreWindows(this)
            ids=FlowJoWsp.Str2Ids(...
                this.gml.propsGui.get('lastOpenPlots'));
            N=length(ids);
            openKld=this.app.is(FlowJoTree.PROP_SYNC_KLD, false);
            if ~openKld && N==0
                return;
            end
            choices={};
            dflts=[];
            if N>0
                choices{1}=String.Pluralize2('Plot window', N);
                dflts(1)=1;
            end
            dimExp=['<html>' Html.ImgXy('pseudoBarHi.png', [], 1.2) ...
                ' Subset ParameterExplorer</html>'];
            if openKld
                choices{end+1}=dimExp;
                dflts(end+1)=length(choices);
            end
            
            [~,~,~,jd]=Gui.Ask(struct('msg', ...
                '<html><br><i>Open previous windows?</i><hr></html>', ...
                'where', 'south east++', ...
                'pauseSecs', 8,...
                'checkFnc', @(idxs, cancelled, jd)answer(idxs),...
                'modal', false), choices, [], 'Confirm (in 8 seconds)...', dflts, ...
                [], false);
            first=false;
            figure(this.fig);
            this.suhTree.jtree.requestFocus;
            MatBasics.RunLater(@(h,e)dispose, 4);
            
            function dispose
                if ~first
                    jd.setTitle('CLOSING in 4 seconds...');
                    MatBasics.RunLater(@(h,e)dispose, 5);
                    first=true;
                else
                    jd.dispose;
                end
            end
            function ok=answer(idxs)
                MatBasics.RunLater(@(h,e)open(idxs), .1);
                ok=true;
            end      
            
            function open(idxs)
                nIdxs=length(idxs);
                for i=1:nIdxs
                    choice=choices{idxs(i)};
                    if isequal(dimExp, choice)
                        this.cbMirror.setSelected(true);
                        this.syncIfOneClick;
                    else
                        this.restoreOpenPlots(false);
                    end
                end
            end
        end
        
        function ok=restoreOpenPlots(this, askUser)
            if nargin<2
                askUser=false;
            end
            ok=false;                
            ids=FlowJoWsp.Str2Ids(...
                this.gml.propsGui.get('lastOpenPlots'));
            N=length(ids);
            if N>0 && askUser ...
                    && ~askYesOrNo(struct('javaWindow', this.jw, 'msg', ...
                    Html.WrapHr(['Re-open previous<br>'...
                    String.Pluralize2('Plot window?', N)])),...
                    'Confirm...', 'north+')
                return;
            end
            if N>0
                ok=true;
                this.openPlots( ids );
            end
        end
        
        function restoreExpanded(this)
            p=this.gml.propsGui;
            ids=FlowJoWsp.Str2Ids(p.get('unexpanded') );
            N=length(ids);
            if ~isempty(ids)
                num=str2double(p.get('nUnexpanded'));
                if isnan(num) || num==0
                    num=length(ids);
                    factor=1;
                else
                    factor=num/N;
                end
            end
            pu=[];
            if N==0
                sample1=this.gml.getSampleIdByNum(1);
                this.suhTree.ensureVisible(sample1,false);
            else
                if N>20
                  pu=PopUp.New(['<html><center>Re-opening ' ...
                      String.Pluralize2('gate node', num) '<br><br>' ...
                      this.app.smallStart '(click <b>Cancel' ...
                      '</b> to start faster)' this.app.smallEnd ...
                      '<hr></html>'], 'north', 'Note....', false, ...
                      @(h,e) setappdata(this.fig, 'canceling', 1),...
                      Gui.Icon('facs.gif'));
                end
                setappdata(this.fig, 'canceling', 0);
                for i=1:N
                    id=ids{i};
                    drawnow;
                    if getappdata(this.fig,'canceling')
                         break;
                    end                    
                    this.suhTree.ensureVisible(id, false);
                    if ~isempty(pu) && mod(i, 5)==0
                        f=floor((N-i)*factor);
                        pu.setText(['Re-opening ' String.Pluralize2(...
                            'prior tree node', f)]);
                    end
                end
                setappdata(this.fig, 'canceling', 0);
            end
            this.suhTree.ensureSelected(...
                FlowJoWsp.Str2Ids(p.get('lastSelectedIds')));
            if ~isempty(pu)
               pu.close; 
            end
        end
    end
    
    methods(Access=private)    
        function restoreLastVisibleRect(this)
            r=this.gml.propsGui.get('lastVisibleRect');
            if ~isempty(r)
                r=str2num(r); %#ok<ST2NM> 
                if ~isempty(r)
                    rect=javaObjectEDT('java.awt.Rectangle');
                    rect.x=r(1);
                    rect.y=r(2);
                    rect.width=r(3);
                    rect.height=r(4);
                    javaMethodEDT('scrollRectToVisible', ...
                        this.suhTree.jtree, rect);
                end
            end
        end
        
        function [ids, N, uiNodes]=getSelectedIds(this)
            uiNodes=this.suhTree.tree.getSelectedNodes();
            N=length(uiNodes);
            ids=cell(1,N);
            for i=1:N
                ids{i}=uiNodes(i).getValue;
            end
        end
        
        function setWindowClosure(this)
            if Gui.IsFigure(this.fig)
                priorCloseer=get(this.fig, 'CloseRequestFcn');
                set(this.fig, 'CloseRequestFcn', @hush);
            end
            
            function hush(h,e)
                try
                    [~,cancelled]=this.gml.save(false, true);
                    if cancelled
                        MatBasics.RunLater(@(h,e)refresh(), .3);
                        return;
                    end
                    if isa(priorCloseer, 'function_handle')
                        feval(priorCloseer, h,e);
                    elseif ischar(priorCloseer)
                        feval(priorCloseer);
                    end
                    try
                        this.gml.closeWindows;
                        drawnow;
                        this.rememberOpenPlots;
                        N=length(this.figs);
                        for i=1:N
                            try
                                close(this.figs{i});
                            catch ex
                                MatBasics.SourceLocation('Problem', ex.message)
                            end
                        end
                        this.rememberExpanded
                        this.gml.propsGui.save;
                        prop=['FlowJoTree.' this.gml.uri];
                        FlowJoTrees(prop, []);
                        this.gml.lock.release;
                        try
                            fjbFig=ArgumentClinic.FlowJoBridgeFig(true);
                            Gui.Shake(Gui.JWindow(fjbFig).getContentPane, 5);
                        catch
                        end
                    catch ex
                        MatBasics.SourceLocation(ex)
                    end
                catch ex
                    ex.getReport
                end
            end

            function refresh
                figure(this.fig);
            end
        end
    end
    
    methods
        function [gate, gater, sampleNum]=findGate(this, names, ensureVisibility, gaters)
            if nargin<4
                gaters=this.gaters;
                if nargin<3
                    ensureVisibility=2;%select
                end
            end
            if ischar(names)
                if contains(names, '/')
                    names=strsplit(names, '/');
                else
                    names={names};
                end
            end
            sampleNum=this.gml.getSampleNumByName(names{1});
            if sampleNum==0
                sampleNum=this.gml.getSampleNumById(names{1});
                if sampleNum==0
                    sampleNum=1;
                    sampleId=this.gml.getSampleIdByNum(sampleNum);
                else
                    sampleId=names{1};
                end
            else
                sampleId=this.gml.getSampleIdByNum(sampleNum);
            end
            if ~isempty(sampleId)
                names=names(2:end);
                gater=gaters.get(sampleId);
                if isempty(gater)
                    fcs=this.gml.getFcs(sampleId);
                    if isempty(fcs)
                        return;
                    end
                    this.checkMarkerStainMix(fcs, sampleId);
                    gater=SuhGater(fcs, this.gml);
                    gaters.set(sampleId, gater);
                end
                gate=gater.findGate(names);
                if ~isempty(gate) 
                    if isempty(gate.gater)
                        gate.setFcs(gater);
                    end
                    if ensureVisibility>0
                        this.suhTree.ensureVisible(...
                            gate.id, ensureVisibility==2);
                    end
                end
            else
                gater=[];
                gate=[];
            end
        end
        
        function ensureVisible(this, id, ...
                selectIf1MutliIf2, scroll)
            if nargin<4
                scroll=true;
                if nargin<3
                    selectIf1MutliIf2=1;
                end
            end
            this.suhTree.ensureVisible(...
                id, selectIf1MutliIf2, scroll);
        end
        
        function [gater, gate]=getGate(this, population, gaters, limit)
            if nargin<3
                gaters=this.gaters;
                if nargin<2
                    if this.getSelectionCount==0
                        gater=[];
                        gate=[];
                        return;
                    end
                    population=this.selectedKey;
                end
            end
            if ischar(population)
                population=this.gml.getNodeById(population);
            end
            sampleId=this.gml.getSampleIdByGate(population);
            if ~isempty(sampleId)
                gater=gaters.get(sampleId);
                if isempty(gater)
                    fcs=this.gml.getFcs(sampleId);
                    if isempty(fcs) || isempty(fcs.hdr)
                        gater=[];
                        gate=[];
                        return;
                    end
                    this.checkMarkerStainMix(fcs, sampleId);
                    if nargin<4
                        gater=SuhGater(fcs, this.gml);
                    else
                        gater=SuhGater(fcs, this.gml, limit);
                    end
                    gater.setTree(this)
                    gaters.set(sampleId, gater);
                end
                gate=gater.getGate(population);
                if isempty(gate.gater)
                    gate.setFcs(gater);
                end
            else
                gater=[];
                gate=[];
            end
        end
        
        function checkMarkerStainMix(this, fcs, sampleId)
            if ~isempty(this.suhTree)
                [asked, unmix]=fcs.handleMarkerStainMix(this.gml.propsGui, ...
                    this.alwaysUnmix, ...
                    this.jw);
                if asked
                    this.alwaysUnmix=unmix;
                end
            else
                % no tree showing do NOT ask about mix
                fcs.handleMarkerStainMix(this.gml.propsGui, ...
                    false, this.jw)
            end
        end
        
        function showHeatMaps(this)
            if this.getSelectionCount==0
                msgWarning(Html.WrapHr(['Select a gate (preferably'...
                    '<br>with 2+ leaves.']));
                return;
            end  
            ids=this.getSelectedIds;
            N=length(ids);
            for i=1:N
                this.showHeatMap(ids{i});
            end
        end
        
        function showHeatMap(this, id)
            if nargin<2
                id=this.selectedKey;
            end
            [data, columnNames, ~, ~, gate, leaves, props]...
                =this.packageSubset(id);
            if isempty(data)
                return;
            end
            if isempty(leaves)
                msg(struct('javaWindow', this.jw, 'msg', ...
                    Html.WrapHr(['Select a gate with<br>'...
                    '2 or more leaf gates'])));
                return;
            end
            this.disable('Building HeatMap');
            columns=gate.fcs.resolveColumns(columnNames(1:end-1));
            nColumns=length(columnNames);
            for i=1:nColumns-1
                name=columnNames{i};
                idx=String.IndexOf(name, ':');
                if idx>0
                    columnNames{i}=name(1:idx-1);
                end
            end            
            columnNames(end)=[];
            nLeaves=length(leaves);%may differ from # of labels
            labels=data(:,end);
            u=unique(labels);
            data(:,end)=[];
            C=size(data,2);
            rawData=gate.fcs.data(gate.getSampleRows,columns);
            R=gate.fcs.getRowCount;
            nLabels=length(u);
            mdns1=zeros(nLabels, C);
            mdns2=zeros(nLabels, C);
            freqs=zeros(1, nLabels);
            names=cell(1, nLabels);
            syms=zeros(nLabels, 3);
            ids=cell(1, nLabels);
            leafGates=cell(1, nLabels);
            for i=1:nLabels
                label=u(i);
                ids{i}=num2str(label);
                cnt=sum(labels==label);
                freqs(i)=cnt/R;
                D1=data(labels==label,:);
                D2=rawData(labels==label,:);
                mdns1(i,:)=median(D1);
                mdns2(i,:)=median(D2);
                if label==0
                    names{i}='ungated';
                else
                    names{i}=props.get(ids{i});
                    for j=1:nLeaves
                        if endsWith(leaves{j}.id, ids{i})
                            leafGates{i}=leaves{j};
                            break;
                        end
                    end
                end
                clr=props.get(LabelBasics.ColorKey(ids{i}));
                if isempty(clr)
                    syms(i,:)=Gui.HslColor(i,nLabels);
                else
                    syms(i,:)=str2num(clr); %#ok<ST2NM> 
                end
            end            
            jdHeatMap=SuhHeatMap.New(...
                'measurements', mdns1, 'rawMeasurements', mdns2,...
                'measurementNames', columnNames, ...
                'subsetName', 'Leaf gate/subset', ...
                'subsetSymbol', syms, ...
                'names', names, 'freqs', freqs, ...
                'cellClickedCallback', @rowClicked,...
                'rowClickedCallback', @rowClicked,...
                'parentFig', this.fig, ...
                'ignoreScatter', false,...
                'rowClickAdvice', '(<i>click to select in tree</i>)',...
                'windowTitleSuffix', ' for leaf gates');
            SuhWindow.Follow(jdHeatMap, this.fig, 'west++');
            this.enable;
            function rowClicked(~, row, ~)
                if ~isempty(leafGates{row})
                    this.ensureVisible(leafGates{row}.id, true);
                else
                    msg(struct('javaWindow', this.jw, 'msg', ...
                        Html.WrapHr(['No tree selection'...
                        ' for<br>"<b>' names{row} '</b>"!'])));
                end
            end
        end
        
        function plots=openPlots(this, ids, metaDown, uiNodes)
            if nargin<2
                ids=this.getSelectedIds();
                if isempty(ids)
                    msg('First select 1 or more gates.');
                    return;
                end
            end
            N=length(ids);
            plots={};
            txt=sprintf('Opening %s', String.Pluralize2('plot',N));
            [~, wasEnabled]=Gui.ShowFacs(this.jw, txt);
            for i=1:N
                id=ids{i};
                population=this.gml.getNodeById(id);
                [gater, gate]=this.getGate(population);
                if ~isempty(gater)
                    [~, plot]=SuhPlot.New(gater, gate);
                    plots{end+1}=plot;
                end
            end
            Gui.HideBusy(this.jw, [], wasEnabled);
        end
        
        function addFigure(this, fig)
            this.figs{end+1}=fig;
        end
        function doubleClickFcn(this, eventData) %,additionalVar)
            if eventData.getClickCount==2 
                this.oneClick=false;
                [ids, N, uiNodes]=this.getSelectedIds();
                if N==1
                    if this.gml.IsFolderId(ids{1})
                        this.renameNode(ids{1});
                        return;
                    end
                end
                if ismac
                    on=get(eventData, 'MetaDown');
                else
                    on=get(eventData, 'ControlDown');
                end
                this.openPlots(ids,on,uiNodes);                
            elseif eventData.isPopupTrigger ||  (ispc...
                    &&  get(eventData, 'MetaDown' ))
                this.contextMenu(false, eventData);
            else
                uiNode=SuhTree.GetClickedNode(eventData);
                if ~isempty(uiNode)
                    uiNode=SuhTree.ClickedBottomRight(eventData);
                    if ~isempty(uiNode) && ~uiNode.isLeafNode
                        if ~SuhTree.IsExpanded(this.suhTree.jtree, uiNode)
                            this.suhTree.tree.expand(uiNode);
                        else
                            this.suhTree.tree.collapse(uiNode);
                        end
                    end
                end
            end
        end
        
        function keys=getChildren(this, parentKey)
            keys=this.gml.getChildren(parentKey);
        end
        
        function nodes=newUiNodes(this, parentKey)
            [keys, N, names, counts, leaves, ...
                ~, haveGates, icons]...
                =this.gml.getChildren(parentKey);
            if this.gml.staleCountIds.contains(parentKey)
                this.gml.staleCountIds.remove(parentKey);
                for i=1:N
                    [~, g2]=this.getGate(keys{i});
                    if size(g2.fcs.data,1)<g2.fcs.hdr.TotalEvents
                        counts(i)=g2.getTrueCount(sum(g2.getSampleRows));
                    else
                        counts(i)=sum(g2.getSampleRows);
                    end
                    g2.population.setAttribute('count', ...
                        num2str(counts(i)));
                    this.gml.addStaleCountChildIds(keys{i});
                end
            end
            if ~haveGates
                for i=1:N
                    if this.gml.IsSampleId(keys{i})
                        img=this.imgSample;
                    else
                        img=this.imgFolder;
                    end
                    nodes(i)=uitreenode('v0', keys{i}, ...
                        this.getNodeHtml(names{i}, counts(i)), ...
                        img, leaves(i));
                end
            else
                for i=1:N
                    nodes(i)=uitreenode('v0', keys{i}, ...
                        this.getNodeHtml(names{i}, counts(i)), ...
                        icons(i), leaves(i));
                end
            end
            if ~exist('nodes', 'var')
                nodes={};
            end
        end
        
        function html=getNodeHtml(this, name, count)
            name=char(edu.stanford.facs.swing.Basics.RemoveXml( ...
                name));            
            html=['<html>' name ', ' this.app.supStart ...
                String.encodeK(count) ...
                this.app.supEnd '</html>'];
        end
        
    end
    
    
    methods
        function addPipelineBtn(this, args, ...
                pipelineCallback, ... %@(data, names, labelPropsFile)
                allowLabel, lbl, width, tip, fcsParameters)
            if nargin<8
                fcsParameters=[];
                if nargin<7
                    tip=[];
                    if nargin<6
                        width=.2;
                        if nargin<5
                            lbl='Run UMAP';
                            if nargin<4
                                allowLabel=true;
                                if nargin<3
                                    warning(['No pipeline given ... '...
                                        'assuming UMAP with matching']);
                                    pipelineCallback=...
                                        @(data, names, labelPropsFile, varArgs)...
                                        FlowJoTree.RunUmap(data, names, labelPropsFile, this.fig, varArgs{:});
                                end
                            end
                        end
                    end
                end
            end
            this.setPipelineArgs(args);
            this.pipelineCallback=pipelineCallback;
            this.pipelineAllowsLabel=allowLabel;
            this.pipelineFcsParameters=fcsParameters;
            if isempty(tip)
                tip=Html.WrapHr([lbl ' on the selected subset']);
            end
            if this.app.highDef
                width=width*1.1;
                extraChars=8;
            else
                extraChars=4;
            end
            hPanLeft = uipanel('Parent',this.fig, ...
                'Units','normalized',...
                'BorderType', 'none','Position',...
                [1-(width), .004, width-.01, .061]);
            uicontrol(hPanLeft, 'style', 'pushbutton',...
                'String', ['  ' lbl '  '],...
                'FontWeight', 'bold', ...
                'ForegroundColor', 'blue',...
                'BackgroundColor', [1 1 .80],...
                'ToolTipString', tip,...
                'Units', 'Characters', ...
                'Position',[0 0 length(lbl)+extraChars 2],...
                'Callback', @(btn,event) runPipeline(this));
        end
            
        function runPipeline(this)
            [data, names, labelPropsFile, ~,gate]=this.packageSubset(...
                this.selectedKey, true, this.pipelineFcsParameters,...
                false, ~this.pipelineAllowsLabel);
            if isempty(data)
                msgWarning('No data for pipeline!', 8, 'south east');
            else
                args=this.getPipelineArgs(gate);
                feval(this.pipelineCallback, data, names, ...
                    labelPropsFile, args);
            end
        end
        
        function runUmap(this, supervised, matchIfUnsupervised, ...
                canUseTemplate, varargin) 
            doingPhate=length(varargin)>1 ...
                && strcmpi(varargin{1}, 'reduction_algorithm')...
                && strcmpi(varargin{2}, 'phate');
            if doingPhate
                purpose='PHATE';
            else
                purpose='UMAP';
            end
            dataOnly=~supervised && ~matchIfUnsupervised;
            [data, names, labelPropsFile, gates, sampleOffsets, leaves]...
                =this.packageSubsets(dataOnly, true, purpose);
            if isempty(data)
                msgWarning(['No data for ' purpose '!'], 8, 'south east');
                return;
            end
            if ~dataOnly
                if length(leaves)<3
                    msgError(Html.WrapHr(['For comparing and supervising ' ...
                        '<br>at least 3 leaf gates are needed']), ...
                        6, 'south')
                    return;
                end
            end
            nToDo=length(this.getSelectedIds);
            if nToDo>1
                ttl=sprintf('%s for %d/%d selections ', ...
                    purpose, length(gates), nToDo);
            else
                ttl=[purpose ' for 1 selection'];
            end
            umapFldr=this.gml.getResourceFolder(purpose);
            if ~doingPhate
                prop='FlowJo.UMAP.template.folder';
                if ~canUseTemplate
                    choices={...
                            'No template'...
                            'Yes, normal template'};
                    if length(leaves)>2
                        if ~verLessThan('matLab', '9.10')
                            choices=[choices ...
                                'Yes, with neural network (TensorFlow)', ...
                                'Yes, with neural network (fitcnet)'];
                        else
                            choices=[choices ...
                                'Yes, with neural network (TensorFlow)'];
                        end
                    end
                    ustChoice=Gui.Ask('Train a UMAP template?', choices, ...
                        'FlowJo.UST', ttl, 1);
                    if isempty(ustChoice)
                        return;
                    end
                    if ustChoice>1
                        file=String.ToFile([gates{1}.getName '.umap.mat']);
                        [umapFldr, file]=uiPutFile(umapFldr, file, ...
                            this.multiProps, prop,...
                            'Save UMAP as training template');
                        if isempty(umapFldr)
                            return
                        end
                        Gui.Train;
                        varargin{end+1}='save_template';
                        varargin{end+1}=fullfile(umapFldr, file);
                        if ustChoice>2
                            varargin{end+1}='mlp_train';
                            if ustChoice==3
                                varargin{end+1}='TensorFlow';
                            else
                                varargin{end+1}='fitcnet';
                            end
                        end
                    end
                else
                    cb=Gui.CheckBox(Html.WrapSmallBold(...
                        'No UMAP<br>if MLP?'), false, ...
                        this.gml.propsGui, 'FlowJoTree.MlpOnlyUMAP', [], ...
                        ['<html>If template has MLP model<br>'...
                        'then exit before UMAP reduction</html>']);
                    [yes, cancelled]=askYesOrNo(struct(...
                        'javaWindow', this.jw, ...
                        'component', cb,...
                        'msg', Html.WrapHr(['Guide UMAP with a <br>' ...
                        'previously trained template?']), 'property', ...
                        'FlowJoTree.UseTemplate'), ttl, 'south', false, []);
                    if cancelled
                        return;
                    end
                    if yes && cb.isSelected
                        varargin{end+1}='mlp_only';
                        varargin{end+1}=true;
                    end
                    if yes
                        umapFile=uiGetFile('*.mat', umapFldr, ...
                            'Select trained UMAP template', ...
                            this.multiProps,  prop);
                        if isempty(umapFile)
                            return;
                        end
                        Gui.Train;
                        varargin{end+1}='template_file';
                        varargin{end+1}=umapFile;
                        varargin{end+1}='see_training';
                        varargin{end+1}=true;
                    end
                end
            end
            args=[this.getPipelineArgs(gates, sampleOffsets) varargin];
            if ~doingPhate
                if ~isempty(this.umapVarArgIn)
                    args=[args this.umapVarArgIn];
                end
            else
                if isempty(this.phateVarArgInStruct)
                    phateArgs=Args.NewKeepUnmatched( ...
                        PhateUtil.DefineArgs, {'k', 15, ...
                        'n_landmarks', 500});
                    args=[args 'args_phate', phateArgs];
                else
                    args=[args 'args_phate', this.phateVarArgInStruct];
                end
            end
            if supervised
                this.RunUmap(data, names, labelPropsFile, ...
                    this.fig, args{:});
            elseif matchIfUnsupervised
                this.RunUmap(data, names, labelPropsFile, ...
                    this.fig, 'match_scenarios', 3, args{:});
            else
                args=Args.RemoveArg(args, 'label_column');
                args=Args.RemoveArg(args, 'match_scenarios');
                this.RunUmap(data, names, [], this.fig, args{:});
            end
        end
        
        function [data, names, labelPropsFile, gates, sampleOffsets,...
                leaves]=packageSubsets(this, ...
                justData, askUser, purpose, ids, fig)
            if nargin<6
                fig=this.fig;
                if nargin<5
                    ids=this.getSelectedIds;
                    if nargin<4
                        purpose='UMAP';
                        if nargin<3
                            askUser=true;
                        end
                    end
                end
            end
            data=[];names={};labelPropsFile='';
            gates={};leaves={}; sampleOffsets=[];
            nIds=length(ids);
            if nIds==0
                msg(struct('javaWindow', this.jw, 'msg', ...
                    Html.WrapHr(['First select a sample or gate<br>'...
                    'upon which to run ' purpose ])));
                return;
            end
            fullNameMap=[];
            if nIds>1 && askUser
                options=cell(1, nIds);
                for i=1:nIds
                    [~, gate]=this.getGate(ids{i});
                    options{i}=['<html>' gate.describe(true) '</html'];
                end
                [choices, cancelled]=Gui.Ask(struct( ...
                    'javaWindow', this.jw, 'msg', ...
                    Html.WrapHr(['Which of your ' ...
                    String.Pluralize2('selection', nIds) ...
                    ' do you<br>want to run ' purpose ' on?']), ...
                    'property', 'FlowJoTree.SampleMerge', ...
                    'properties', this.gml.props), ...
                    options, '', 'Confirm...', 1, [], false);
                if cancelled
                    return;
                end
                ids=ids(choices);
                nIds=length(ids);
                if nIds>1
                    fullNameMap=Map;
                end
            end
            gates={};
            if nIds==1
                [data, names, labelPropsFile, ~, gates{1}, leaves]...
                    =this.packageSubset(ids{1}, askUser, ...
                    this.pipelineFcsParameters, false, ...
                    justData, fullNameMap, fig);
                sampleOffsets=[];
                return;
            end
            fullNameMap=Map;
            fcsNames=this.getCommonColumnNames(ids, ...
                askUser, this.pipelineFcsParameters);
            if isempty(fcsNames)
                return;
            end
            % 2 askUser values ... first if for fcsNames (NO) and 2nd is
            % for overlap
            askUserOverlapOnly=[false, askUser];%don't ask about fcsNames
            [data, names, labelPropsFile, ~, gates{1}, leaves, props]...
                =this.packageSubset(ids{1}, askUserOverlapOnly, ...
                fcsNames, false, justData, fullNameMap, fig);
            if isempty(data)
                return;
            end
            resave=false;
            for i=2:nIds
                [data2, ~, ~, ~, gate2, leaves2, props2]...
                    =this.packageSubset(ids{i}, askUserOverlapOnly, ...
                    fcsNames, false, justData, fullNameMap, fig);
                if ~isempty(data2)
                    gates{end+1}=gate2;
                    data=[data;data2];
                    leaves=[leaves leaves2];
                    if ~justData
                        keys=props.keys;
                        nKeys=length(keys);
                        for j=1:nKeys
                            if ~props.containsKey(keys{j})
                                resave=true;
                                props.set(key, props2.get(keys{j}))
                            end
                        end
                    end
                end
            end
            if resave
                props.save;
            end
            sampleOffsets=Map;
            sampleOffset=1;
            gateOffset=1;
            nIds=length(gates);
            for i=1:nIds
                gate=gates{i};
                sampleOffsets.set(gate.id, struct( ...
                    'sampleOffset', sampleOffset, ...
                    'gateOffset', gateOffset, ...
                    'sampleSize', gate.sampleSize, ...
                    'gateSize', gate.count));
                sampleOffset=sampleOffset+gate.sampleSize;
                gateOffset=gateOffset+gate.count;
            end
        end
            
        function [choices, common]=getCommonColumnNames( ...
                this, ids, ask, starters, property )
            if nargin<5
                property='FlowJoTree.Ask';
                if nargin<4
                    starters={};
                    if nargin<3
                        ask=true;
                        if nargin<2
                            ids=this.getSelectedIds;
                        end
                    end
                end
            end
            nSelected=length(ids);
            names=edu.stanford.facs.swing.Counter(java.util.LinkedHashMap);
            for i=1:nSelected
                [~, gate]=this.getGate(ids{i});
                [~,g]=gate.fcs.getAutoGateColumns;
                    N2=length(g);
                    for j=1:N2
                        names.count(g{j});
                    end
            end
            common={};
            it=names.keySet.iterator;
            while it.hasNext
                name=it.next;
                if names.getCount(name)==nSelected
                    common{end+1}=name;
                else
                    fprintf('%s count is %d\n', name, names.getCount(name));
                end
            end
            if ~isempty(starters)
                removeIdxs=[];
                nStarters=length(starters);
                for i=1:nStarters
                    if ~StringArray.Contains(common, starters{i})
                        removeIdxs(end+1)=i;
                    end
                end
                if ~isempty(removeIdxs)
                    starters(removeIdxs)=[];
                end
                common=starters;
            end
            N=length(common);
            if ~ask
                choices=common;
                return;
            end
            options=cell(1,N);
            for i=1:N
                mrk=common{i};
                if isempty(mrk)
                    mrk=stains{fcsIdx};
                end
                try
                    mrk=char(...
                        edu.stanford.facs.swing.MarkerSorter.encodeKey(mrk));
                catch
                end
                htm1=Html.EncodeSort('marker', lower(mrk));
                options{i}=['<html>' common{i} htm1 '</html>'];
            end
            props=this.app;
            if N<20
                scroll=N;
            else
                scroll=20;
            end            
            idxs=mnuMultiDlg(struct('msg', ['<html>Choose FCS '...
                'parameter(s) from <b>' ...
                String.Pluralize2('selection',nSelected) '</b>'], ...
                'where', 'east+', 'property', property,...
                'properties', this.gml.propsGui,...
                'sortProps', props, 'sortProp', property, ...
                'javaWindow', this.jw, SortGui.PROP_SEARCH2, true), ...
                'Confirm...', ...
                options, 0:N-1, false, true, [],[],[],[],scroll);
            choices=common(idxs);
        end
        
        function args=getPipelineArgs(this, gates, sampleOffsets)
            if nargin<3
                sampleOffsets=[];
            end
            if isa(gates, 'SuhGate')
                temp=gates;
                gates={temp};
            end
            nGates=length(gates);
            if nGates==1
                args=[this.pipelineArgs ...
                    {'flowjo_wsp' this.gml ...
                    'flowjo_tree' this ...
                    'gates' gates ...
                    'std_outliers' 3 ...
                    'sample_rows' gates{1}.getSampleRows ...
                    'highlighter_registry' @highlightRegistry}];
            else
                args=[this.pipelineArgs ...
                    {'flowjo_wsp' this.gml ...
                    'flowjo_tree' this ...
                    'gates' gates ...
                    'std_outliers' 3 ...
                    'highlighter_registry' @highlightRegistry}];
                if ~isempty(sampleOffsets)
                    sampleRows=gates{1}.getSampleRows;
                    for i=2:nGates
                        sampleRows=[sampleRows gates{i}.getSampleRows];
                    end
                    args{end+1}='sample_rows';
                    args{end+1}=sampleRows;
                    if ~isempty(sampleOffsets)
                        args{end+1}='sample_offsets';
                        args{end+1}=sampleOffsets;
                    end
                else
                    args{end+1}='sample_rows';
                    args{end+1}=gates.getSampleRows;
                    warning('%d gates has no sampleOffsets??', ...
                        length(gates));
                end
            end

            function highlightRegistry(listener)
                nGates2=length(gates);
                for i=1:nGates2
                    gates{i}.gater.registerHighlightListener(listener);
                end
            end
        end

        function umap(this, op)
            switch op
                case 1
                    this.runUmap(false, false, true);
                case 2 
                    this.runUmap(false, false, true, 'fast', true);
                case 3
                    this.runUmap(true, false, false);
                case 4
                    this.runUmap(true, false, false, 'fast', true);
                case 5
                    this.runUmap(false, true, true);
                case 6
                    this.runUmap(false, true, true, 'fast', true);
            end
        end
        
        function csv(this, export, ask)
            if nargin<3
                ask=true;
                if nargin<2
                    export=[];
                end
            end
            ids=this.getSelectedIds;
            nIds=length(ids);
            if nIds~=1
                msgWarning('Select 1 gate/sample (only)');
                return;
            end
            if ~isempty(export)
                if ischar(export) && contains(export, 'sample')
                    [~,~,lFile,csv]=this.packageSubset(...
                        ids{1}, ask, {'Time'}, export);
                else
                    [~,~,lFile,csv]=this.packageSubset(...
                        ids{1}, ask, [], export);
                end
               if isempty(csv)
                   return;
               end
               [~,fLabel, eLabel]=fileparts(lFile);
               [~,fCsv, eCsv]=fileparts(csv);
               msg(struct('javaWindow', this.jw, ...
                   'msg', Html.Sprintf( ...
                   ['Two files exported...', ...
                   '<br>Open folder containing:' ...
                   '<ul><li>%s<li>%s</ul>'], ...
                   [fLabel eLabel], ...
                   [fCsv eCsv])));     
            else
                [~,gate]=this.getGate(ids{1});
                nEvents=gate.fcs.hdr.TotalEvents;
                prop='FlowJoTree.ImportCsv';
                fldr=this.gml.props.get(FlowJoTree.PROP_EXPORT_FLDR,...
                        this.gml.getResourceFolder('exported'));
                    
                csvFile=uiGetFile('*.csv', fldr, ...
                    sprintf(['<html>Select prior ' ...
                    'CSV file<br> with labels for ' ...
                    'this<br> sample''s %s events</html>'], ...
                    String.encodeInteger(nEvents)),...
                    this.multiProps,  prop);
                if isempty(csvFile)
                    return;
                end
                if ~gate.isSample
                    msgWarning(struct('javaWindow', this.jw, ...
                        'msg', Html.WrapHr(['Gates must be imported ' ...
                        '<br>at the sample level'])), 8, 'south east+');
                    gate=gate.getSampleGate;
                end
                Gui.ShowFacs(this.fig, 'Reading the csv file');
                [m,columnNames2]=File.ReadCsv2(csvFile);
                Gui.HideBusy(this.fig);
                [data, columnNames]=this.packageSubset( ...
                    gate.id, false, [], false, true);
                if isempty(data)
                    return;
                end
                columnNames2(end)=[];
                if length(columnNames2)==1 && ...
                        isequal('Time', columnNames2{1})
                    allFound=true;
                else
                    allFound=StringArray.Find(...
                        columnNames2, columnNames, true);
                end
                if ~allFound
                    if ~askYesOrNo(struct('javaWindow', this.jw, 'msg', ...
                            Html.Wrap(['<b><font color="red">'...
                            'Some</font> column names not found</b>:'  ...
                            Html.To2Lists(columnNames, columnNames2, ...
                            'ol', 'FCS file', 'CSV file', ...
                            true) '<br><br><center><b>Continue?' ...
                            '</b></center>'])))
                        return;
                    end
                end
                R=size(m, 1);
                labels=m(:,end);
                if nEvents ~= R
                    msgError(Html.SprintfHr(['This sample ' ...
                        'has %s events but the<br>csv file ' ...
                        'has %s rows'], String.encodeInteger(nEvents), ...
                        String.encodeInteger(R)));
                else
                    u=unique(labels);
                    if length(u)>25
                        if ~askYesOrNo(struct('javaWindow', this.jw, ...
                                'msg', Html.SprintfHr(...
                                ['%d distinct class labels found!<br>' ...
                                'It will be hard to read ' ...
                                'the plots in FlowJo ... ' ...
                                '<b>Continue<b>?'], length(u))))
                            return;
                        end
                    end
                    propFile=File.SwitchExtension2(csvFile, '.properties');
                    if ~exist(propFile, 'file')
                        [~, propFile, e]=fileparts(propFile);
                        msgWarning(Html.SprintfHr(['Default names will ' ...
                            'be made.<br><br>If <b>%s%s</b> were found ' ...
                            'in the <br>same folder then it would ' ...
                            'provide label=name translations'], ...
                            propFile, e))
                        props=[];
                    else
                        props=JavaProperties(propFile);
                    end
                    FlowJoTree.CreateLabelGates('CSV', ...
                        'foldericon.png', data, labels, ...
                        props, columnNames, {gate})
                end                
            end
        end

        function phate(this, op)
            switch op
                case 1
                    this.runUmap(false, false, true, ...
                        'reduction_algorithm', 'PHATE');
                case 2 
                    this.runUmap(false, false, true, ...
                        'reduction_algorithm', 'PHATE', 'fast', true);
                case 3
                    this.runUmap(false, true, true, ...
                        'reduction_algorithm', 'PHATE');
                case 4
                    this.runUmap(false, true, true, ...
                        'reduction_algorithm', 'PHATE', 'fast', true);
            end
        end
        
        function args=alterUmapSettings(this)
            Gui.ShowFacs(this.fig, 'Gathering UMAP settings');
            try
                this.initUmapArgs;
                varArgIn=['fake.csv', this.umapVarArgIn];
                argsObj=UmapUtil.GetArgsWithMetaInfo(varArgIn{:});
                argsObj.popUpEditor(this.jw, ...
                    'Alter UMAP/UST settings', 'center', 1, 2, 3, ...
                    'cluster_detail', 'maxDeviantParameters', ...
                    'robustConcordance');
                varArgIn=argsObj.getVarArgIn;
                this.umapVarArgIn=varArgIn(2:end);
                args=Args.NewKeepUnmatched(UmapUtil.DefineArgs, varArgIn{:});
            catch ex
                ex.getReport
            end
            Gui.HideBusy(this.fig);
            figure(this.fig);
        end

        function args=alterPhateSettings(this)
            try
                Gui.ShowFacs(this.fig, 'Gathering PHATE settings');
                this.initUmapArgs;
                if ~isempty(this.phateVarArgInStruct)
                    varArgIn=this.phateVarArgIn;
                else
                    varArgIn={'fake.csv', 'k', 15, 'n_landmarks', 600};
                end
                argsObj=PhateUtil.GetArgsWithMetaInfo(varArgIn{:});
                argsObj.popUpEditor(this.jw, ...
                    'Alter PHATE settings', 'center', 1);
                varArgIn=argsObj.getVarArgIn;
                args=Args.NewKeepUnmatched(PhateUtil.DefineArgs, varArgIn{:});
                this.phateVarArgInStruct=args;
                this.phateVarArgIn=varArgIn;
            catch ex
                ex.getReport
            end
            Gui.HideBusy(this.fig);
            figure(this.fig);
        end

        function args=alterFitcnetSettings(this)
            Gui.ShowFacs(this.fig, 'Gathering fitcnet settings');
            try
                this.initFitcnetArgs;
                varArgIn=['fake.csv', this.fitcnetVarArgIn];
                argsObj=FitcnetUtil.GetArgsWithMetaInfo(varArgIn{:});
                argsObj.popUpEditor(this.jw, ...
                    'Alter MLP settings for MATLAB''s fitcnet', 'center', 1);
                varArgIn=argsObj.getVarArgIn;
                this.fitcnetVarArgIn=varArgIn(2:end);
                args=Args.NewKeepUnmatched(FitcnetUtil.DefineArgs, varArgIn{:});
            catch ex
                ex.getReport
            end
            Gui.HideBusy(this.fig);
            figure(this.fig);
        end

        function args=alterEppModalSettings(this)
            try
                Gui.ShowFacs(this.fig, ['Gathering EPP settings<br>' ...
                    'used for <b>modal</b> clustering...']);
                this.initEppArgs;
                if ~isempty(this.eppModalVarArgIn)
                    varArgIn=this.eppModalVarArgIn;
                else
                    varArgIn={};
                end
                argsObj=SuhEpp.GetArgsWithMetaInfo([], varArgIn{:});
                kldGroup=3; %CyTOF and non CyTOF settings
                if SuhJsonSplitter.CYTOMETER_SPECIFIC_DEFAULTS
                    if isempty(this.selectedKey) ...
                            || FlowJoWsp.IsSampleId(this.selectedKey)
                        msgError(Html.WrapHr([ ...
                            'First pick a gate ... modal clustering...' ...
                            '<br>uses <i>cytometer-<b>specific<b?</i> ' ...
                            'settings ']), 8, 'north');
                        args=[];
                        Gui.HideBusy(this.fig);
                        return;
                    end
                end
                [~, gate]=this.getGate;
                if ~isempty(gate)
                    if gate.fcs.hdr.isCytof
                        cytometer='cytof';
                    elseif gate.fcs.isSpectral
                        cytometer='spectral';
                    else
                        cytometer='conventional';
                    end
                end
                if SuhJsonSplitter.CYTOMETER_SPECIFIC_DEFAULTS
                    [yes, cancelled]=askYesOrNo(struct('javaWindow', ...
                        this.jw, 'msg', Html.SprintfHr(['Reset the ' ...
                        'defaults that modal clustering<br>' ...
                        'uses for <b><i>%s</i></b> ' ...
                        'flow cytometers?'], cytometer)));
                    if cancelled
                        args=[];
                        Gui.HideBusy(this.fig);
                        return;
                    end
                    if yes
                        SuhEpp.HandleCytometerArgsForModal2(...
                            cytometer, argsObj);
                    end
                end
                argsObj.popUpEditor(this.jw, ...
                    'Alter EPP settings for modal clustering...', ...
                    'center', 4, kldGroup, 5);
                varArgIn=argsObj.getVarArgIn;
                varArgIn=varArgIn(2:end);
                args=Args.NewKeepUnmatched(SuhEpp.DefineArgs, varArgIn{:});
                this.eppModalVarArgIn=varArgIn;
            catch ex
                ex.getReport
            end
            Gui.HideBusy(this.fig);
            figure(this.fig);
        end

        function initPhateArgs(this)
            if ~this.phateArgsDone
                argsObj=Args(PhateUtil.DefineArgs);
                this.phateVarArgIn=this.pipelineArgs;%argsObj.extractFromThat(this.unmatched);
                this.phateArgsDone=true;
                this.phateVarArgIn=argsObj.parseStr2NumOrLogical(...
                    this.phateVarArgIn);
            end
        end

        function initFitcnetArgs(this)
            if ~this.fitcnetArgsDone
                argsObj=Args(FitcnetUtil.DefineArgs);
                this.fitcnetVarArgIn=this.pipelineArgs;%argsObj.extractFromThat(this.unmatched);
                this.fitcnetArgsDone=true;
                this.fitcnetVarArgIn=argsObj.parseStr2NumOrLogical(...
                    this.fitcnetVarArgIn);
            end
        end
        
        
        function args=alterEppDbmSettings(this)
            try
                Gui.ShowFacs(this.fig, ['Gathering EPP settings<br>' ...
                    'used for <b>DBM</b> clustering...']);
                this.initEppArgs;
                if ~isempty(this.eppDbmVarArgIn)
                    varArgIn=this.eppDbmVarArgIn;
                else
                    varArgIn={};
                end
                argsObj=SuhEpp.GetArgsWithMetaInfo([], varArgIn{:});
                argsObj.popUpEditor(this.jw, ...
                    'Alter EPP settings for DBM clustering...', ...
                    'center', 2, 7, 5);
                varArgIn=argsObj.getVarArgIn;
                varArgIn=varArgIn(2:end);
                args=Args.NewKeepUnmatched(SuhEpp.DefineArgs, varArgIn{:});
                this.eppDbmVarArgIn=varArgIn;
            catch ex
                ex.getReport
            end
            Gui.HideBusy(this.fig);
            figure(this.fig);
        end
        
        function initUmapArgs(this)
            if ~this.umapArgsDone
                argsObj=Args(UmapUtil.DefineArgs);
                this.umapVarArgIn=this.pipelineArgs;%argsObj.extractFromThat(this.unmatched);
                this.umapArgsDone=true;
                this.umapVarArgIn=argsObj.parseStr2NumOrLogical(...
                    this.umapVarArgIn);
            end
        end
        
        function initEppArgs(this)
            if ~this.eppArgsDone
                argsObj=Args(SuhEpp.DefineArgs);
                this.eppModalVarArgIn=this.pipelineArgs;%argsObj.extractFromThat(this.unmatched);
                this.eppArgsDone=true;
                this.eppModalVarArgIn=argsObj.parseStr2NumOrLogical(...
                    this.umapVarArgIn);
                this.eppDbmVarArgIn=this.pipelineArgs;%argsObj.extractFromThat(this.unmatched);
                this.eppDbmVarArgIn=argsObj.parseStr2NumOrLogical(...
                    this.umapVarArgIn);
            end
        end
        
        function toggleFlashlightButton(this, gate)
            if nargin<2
                [gater, gate]=this.getGate;
            else
                gater=gate.gater;
            end
            if ~isempty(gater) && gater.isHighlighted(gate)
                this.btnFlashlight.setIcon(Gui.Icon(...
                    'pinFlashlightTransparentOff.png'));
            else
                this.btnFlashlight.setIcon(Gui.Icon(...
                    'pinFlashlightTransparent.png'));
            end
        end

        function flashlight(this, key)
            if nargin<2
                [gater, gate]=this.getGate;
                if isempty(gate)
                    msg('First select a gate/sample!', 8, 'east+');
                    return;
                end
            else
                [gater, gate]=this.getGate(key);
            end
            gate.getColor;
            gater.setHighlighted(gate);
            this.toggleFlashlightButton(gate);
        end
        
        function flashlights(this, mnu)
            if nargin<2
                mnu=PopUp.Menu;
            end
            gater=this.getGate;
            if isempty(gater)
                msg('First select a gate/sample!', 8, 'east+');
                return;
            end
            N=gater.getHighlightedCount;
            Gui.NewMenuItem(mnu, 'Edit leaf gate colors',...
                @(h,e)editLeafColors(this), 'table.gif');
            Gui.NewMenuLabel(mnu, String.Pluralize2(...
                'highlighted gate', N), true);
            mi=Gui.NewMenuItem(mnu, 'Re-color highlighting', ...
                @(h,e)recolorFlashLight(this), 'colorWheel16.png');
            mi.setEnabled(N>0);
            mi=Gui.NewMenuItem(mnu, 'Remove highlighting', ...
                @(h,e)removeFlashLight(this), 'cancel.gif');
            mi.setEnabled(N>0);
            mnu.show(this.btnColorWheel, 25, 25)
        end
        
        function removeFlashLight(this)
            gater=this.getGate;
            if isempty(gater)
                msg('First select a gate/sample!', 8, 'east+');
                return;
            end
            chosenGates=gater.chooseHighlightedGate(...
                'Re-color which gate?',...
                'SuhGater.Recolor', false);
            N=length(chosenGates);
            for i=1:N
                gater.setHighlighted(chosenGates{i});
            end
        end
        
        function recolorFlashLight(this)
            gater=this.getGate;
            if isempty(gater)
                msg('First select a gate/sample!', 8, 'east+');
                return;
            end
            [gate, ~, ch]=gater.chooseHighlightedGate(...
                'Re-color which gate?',...
                'SuhGater.Recolor', true);
            if ~isempty(gate)
                clr=Gui.SetColor (Gui.JWindow(this.fig), ...
                    ['<html>Highight ' ch(7:end)],...
                    gate.highlightColor);
                if ~isempty(clr)
                    gate.setColor(clr);
                    gater.fireHighlighting(gate, true);
                end
            end
        end
        
        function editLeafColors(this, key)
            if nargin<2
                if isempty(this.selectedKey)
                    msg('First select a gate/sample!', 8, 'east+');
                    return;
                end
                key=this.selectedKey;
            end
            if ~isempty(key)
                pu=PopUp('Raking up leaves of gating tree');
                this.gml.editColors(key);
                pu.close;
            end
        end
    end
    
    methods(Static)
        function fjt=NewOrReuse(uri, resources, visibleTree)
            if nargin<3
                visibleTree=true;
                if nargin<2
                    resources={};
                end
            end
            prop=['FlowJoTree.' uri];
            was=FlowJoTrees(prop);
            if ~isempty(was)
                fjt=was;
                if ~fjt.gml.tryLock
                    fjt=[];
                    return;
                end
                if ~isempty(was.fig) && ishandle(was.fig)
                   figure(fjt.fig);
                elseif visibleTree
                    setResources(fjt.gml);
                    fjt.show;
                end
            else
                fjt=FlowJoTree(uri);
                fjw=fjt.gml;
                if isempty(fjw)
                    fjt=[];
                    return;
                end
                if ~isempty(fjw) && ~isempty(fjw.resources)
                    setResources(fjw);
                    if visibleTree
                        fjt.show;
                    end
                    FlowJoTrees(prop, fjt);
                    BasicMap.Global.insert( ...
                        FlowJoTree.PROP_OPEN, uri, ...
                        FlowJoTree.MAX_WORKSPACES, true);
                end
            end
            
            function setResources(gml)
                prev=File.SwitchExtension(gml.file, '.resources.mat');
                if exist(prev, 'file')
                    load(prev, 'resourceMap');
                    gml.setResourceMap(resourceMap);
                end
                if ~isempty(resources)
                    if iscell(resources)
                        N=length(resources);
                        for i=1:2:N
                            gml.addResource( ...
                                resources{i}, resources{i+1});
                        end
                    elseif isa(resources, 'Map')
                        gml.setResourceMap(resources);
                    end
                    resourceMap=gml.resources;
                    save(prev, 'resourceMap');
                end
            end
        end

        function fjt=Open(jw)
            if nargin<1
                jw=Gui.JWindow(get(0, 'CurrentFigure'));
            end
            settingsCount=FlowJoTrees;            
            app=BasicMap.Global;
            uris=app.getAll(FlowJoTree.PROP_OPEN);
            N=length(uris);
            if N<FlowJoTree.MAX_WORKSPACES
                uris={};
                try
                    if ~isa(app, 'CytoGate') %not running AutoGate
                        uris=readFlowJoWorkspaces; %get saved in AutoGate
                    else
                        % get saved in suh_pipelines
                        m=Map(File.Home('.run_umaps', BasicMap.FILE));
                        uris=m.getAll(FlowJoTree.PROP_OPEN);
                    end
                catch
                    disp('No additional URIs');
                end
                N2=length(uris);
                for i=1:N2
                    if app.addIfMissing(FlowJoTree.PROP_OPEN, uris{i})
                        N=N+1;
                        if N==FlowJoTree.MAX_WORKSPACES
                            break;
                        end
                    end
                end
                uris=app.getAll(FlowJoTree.PROP_OPEN);
            end
            N=length(uris);
            fjt=[];
            isDemo=false;
            btnDemo=SuhDemo.GetButton(@demoCallback);
            btnAbout=Gui.NewBtn('About', @(h,e)about(h), ...
                    'Read overview of the bridge', ...
                    'help2.png');
            closedByPipelines=false;
            if N>0
                items={};
                good={};
                set=java.util.HashSet;
                nMissing=0;
                for i=1:N
                    file=strtrim(uris{i});
                    if ~startsWith(lower(file), 'https://')...
                            && ~startsWith(lower(file), 'http://')...
                            && ~exist(file, 'file')
                        warning('File does not exist %s', file);
                        nMissing=nMissing+1;
                        continue;
                    end
                    if ~set.contains(file)
                        good{end+1}=file;
                        set.add(file);
                    else
                        continue;
                    end
                    [p, f, e]=fileparts(file);
                    items{end+1}=['<html>' f e ' ' app.smallStart '(<b>' ...
                        p '</b>)' app.smallEnd '</html>'];
                end
                uris=good;
                if nMissing>0
                    ttl=String.Pluralize2('missing workspace', nMissing);
                    try
                        app.setAll(FlowJoTree.PROP_OPEN, uris);
                    catch ex
                        warning('Missing not removed');
                    end
                end
                N=length(items);
                btn1=Gui.NewBtn('Find', @(h,e)browse(h), ...
                    'Find a WSP file in your local file system', ...
                    'search.gif');
                btnPipelines=Gui.NewBtn('Pipelines', ...
                    @(h,e)pipelines(h), ...
                    'Open up Herzenberg pipelines window', ...
                    'smallGenie.png');
                visibleRows=N+2;
                if visibleRows>15
                    visibleRows=15;
                elseif N<6
                    visibleRows=5;
                end
                items{end+1}='Browse/find in file system';
                choice=Gui.AutoCompleteDlg(items, ...
                    'Type a file name', 1, ...
                    'Enter a FlowJo workspace name', ...
                    ['<html><b>Enter workspace</b>:</html>'], ...
                    false, visibleRows, 45, ...
                    'east+', Gui.Panel(btn1, btnDemo, btnPipelines, btnAbout), ...
                    true, 'Bridge to FlowJo...', jw, ...
                    'flowJo10big.png');
                if closedByPipelines
                    return;
                end
                if ~isempty(choice)
                    choice=items{choice};
                end
                if isempty(choice)
                    return;
                end
                if settingsCount<FlowJoTrees
                    return;
                end
                if isDemo
                    return;
                end
                if strcmp(choice, items{end})
                    browse;
                else
                    idx=StringArray.IndexOf(items, choice);
                    fjt=FlowJoTree.NewOrReuse(uris{idx});
                end
            else
                [choice, cancelled]=Gui.Ask( struct('msg', ...
                    ['<html>Bridge MATLAB with <i>which</i> ' ...
                    'FlowJo workspace?</html>'], 'where', 'east++', ...
                    'javaWindow', jw),...
                    {'A workspace in my file system', ...
                    'One of the demo workspaces'}, 'FlowJoWsp.Open', ...
                    'FlowJoBridge', 1, btnAbout);
                if cancelled 
                    return;
                elseif choice==2
                    btnDemo.doClick;
                elseif choice==1
                    browse();
                end
            end

            function demoCallback(idx,demo)
                fprintf('Called demo #%d "%s"\n', idx, demo);
                isDemo=true;
            end

            function about(h)
                jw=Gui.WindowAncestor(h);
                app=BasicMap.Global;
                sm1=app.smallStart;
                sm2=app.smallEnd;
                b1='<b><font color="blue">';
                b2='</font></b>';
                g1='<b><font color="green">';
                msgBox( struct('javaWindow', jw,...
                    'icon', 'none', 'msg',...
                    ['<html><table cellpadding="0"' ...
                    ' cellspacing="0"><tr><td align="center">' ...
                    '&nbsp;&nbsp;The Herzenberg Lab develops '...
                    '<b>FlowJoBridge</b> ' app.supStart '(V2 beta)'...
                    app.supEnd ' for use&nbsp;&nbsp;<br>'...
                    'with ' b1 'FlowJo</font>' app.supStart b1 'TM ' ...
                    '10.8.1</font> (from BD Life Sciences)' ...
                    app.supEnd ' so that <b><i>you</i></b> can:' ...
                    '</td></tr><tr><td>' Html.Wrap(['<ul>' ...
                    '<li><u>Open</u> up your FlowJo analyses to '...
                    ' MATLAB!' sm1 ...
                    ' <br>Bridge the best flow analysis software ' ...
                    ' with the best platform for <b><i>rapid</i></b>' ...
                    '<br>development of '...
                    ' statistics, mathematics and bioinformatics ' ...
                    'pipelines.<br>MATLAB is low/no cost for ' ...
                    'academia and more stable than R.' sm2 ...
                    '<li><u>Visualize</u> high dimensional patterns '...
                    'with our faster<br><b>UMAP</b>  ' ...
                    'implementation or with <b>PHATE</b> from Yale' ...
                    '<br>University''s Krishnaswamy Lab.'...
                    '<li><u>Run</u> AutoGate''s novel <i>unsupervised</i> '...
                    'automatic gating<br>method on ' g1 'ANY' b2  ...
                    ' population you define in FlowJo.<br>' sm1...
                    'This method is ' b1 'E' ...
                    b2 'xhaustive '  b1 'P' b2 'rojection ' b1 'P' b2 ...
                    'ursuit (<b>EPP</b>).' sm2...                    '
                    '<li><u>Guide</u> AutoGate''s <i>supervised' ...
                    '</i> gating methods with<br>populations you ' ...
                    'define in FlowJo. <br>' sm1 'These methods are '...
                    b1 'U' b2 'MAP ' b1 'S' b2 'upervised ' b1 'T' ...
                    b2 'emplates <br>(<b>UST</b>) and ' b1 'M' b2 ...
                    'ulti-' b1 'L' b2 'ayer ' b1 'P' b2 ['erceptron ' ...
                    'neural networks (<b>MLP</b>).'] ...
                    '<li><u>Save</u> gates to ' ...
                    'your workspace for further use in FlowJo.<br>' ...
                    sm1 'Gates from <b>UST</b>, <b>MLP</b> or ' ...
                    '<b>EPP</b> <i>plus</i> manual gates on'...
                    ' visual data <br>derived from <b>UMAP</b> or ' ...
                    '<b>PHATE</b> <i>as well as</i> ' g1 'ANY other' b2 ...
                    ' gates stored<br>as a numeric '...
                    'matrix with a final ID column in ' ...
                    'a CSV file!' sm2 ...
                    '<li><u>Compare</u> FlowJo defined populations ' ...
                    'with each other,<br>or AutoGate''s, ' ...
                    'or ' g1 'ANY other ' b2 ' using ' ...
                    'AutoGate''s tools.<br>' sm1  'Tools are: ' ...
                    'QFMatch, QF-tree, multidimensional scaling ' ...
                    '(<b>MDS</b>),<br>parameter explorer, gate ' ...
                    'highlighting</b> etc.' sm2...
                    '<li><u>Refine</u> existing FlowJo manual gate ' ...
                    'hierarchies.<br>' sm1 'Creating <b>new</b> ' ...
                    'hierarchies requires the <u>ongoing use</u> ' ...
                    'of FlowJo.<br><br>' ...
                    '<u>Supports</u>: ellipse, polygon, quadrant '...
                    'rectangle and NOT gates scaled<br>'...
                    'by Linear, Logarithmic, Biex, ArcSinh, Hyperlog '...
                    'or Logicle.<br><u>Under development</u>: boolean ' ...
                    'gates + Miltenyi scale.' sm2 ...
                    '</ul>']) '</td></tr>'...
                    '</table></html>'], 'where', 'west+'),...
                    'Welcome to FlowJoBridge!!');
            end

            function browse(h)
                uri=uiGetFile('myWorkspace.wsp', File.Documents,...
                    'Open a FlowJo workspace', BasicMap.Global, ...
                    'FlowJoBridge.Folder');
                if ~isempty(uri)
                    fjt=FlowJoTree.NewOrReuse(uri);
                    if nargin>0
                        w=Gui.Wnd(h);
                        w.dispose;
                    end
                end
            end

            function pipelines(h)
                closedByPipelines=true;
                w=Gui.Wnd(h);
                w.dispose;
                ArgumentClinic();
            end
        end

        
        function RunEpp(data, names, labelPropsFile, args)
            gate=Args.Get('Gate', args{:});
            if gate.fcs.hdr.isCytof
                cytometer='cytof';
            elseif gate.fcs.isSpectral
                cytometer='spectral';
            else
                cytometer='conventional';
            end
            supervised=~isempty(labelPropsFile) && startsWith(names{end}, 'classification');
            eppFolder=gate.gml.getResourceFolder(...
                'epp', [gate.getFileName '.' num2str(supervised)]);
            args=Args.Set('column_names', names, args{:});
            args=Args.Set('label_file', labelPropsFile, args{:});
            args=Args.Set('label_column', 'end', args{:});
            args=Args.Set('cytometer', cytometer, args{:});
            args=Args.Set('folder', eppFolder, args{:});
            SuhEpp.New(data, args{:});
        end
        
        function [reduction, umap, clusterIdentifiers, extras]...
                =RunUmap(data, names, labelPropsFile, fig, varargin)
            args=varargin;
            gates=Args.Get('gates', varargin{:});
            nGates=length(gates);
            gate=gates{1};
            umapTopGates={};
            umapSubGates={};
            umapBaseName=[];
            umapDims=cell(nGates, 2);
            fldr=Args.GetStartsWith('output_folder', [], args);
            if isempty(fldr)
                fldr=gate.gml.getResourceFolder('umap', gate.getFileName);
                args{end+1}='output_folder';
                args{end+1}=fldr;
            end
            stdOutliers=Args.GetStartsWith('std_outliers', nan, args);
            if isnan(stdOutliers)
                args{end+1}='std_outliers';
                args{end+1}=3;
            end
            args=Args.RemoveArg(args, 'label_file');
            args=Args.RemoveArg(args, 'label_column');
            args=Args.RemoveArg(args, 'parameter_names');            
            args=Args.Set('save_output', true, args{:});
            args{end+1}='locate_fig';
            args{end+1}={fig, 'south east+', true};
            args{end+1}='conclude';
            args{end+1}=@conclude;
            args{end+1}='save_roi';
            args{end+1}=@saveRoi;
            args{end+1}='cluster_detail';
            args{end+1}='medium';
            args{end+1}='mlp_supervise';
            args{end+1}=true;
            args{end+1}='locate_fig';
            args{end+1}={fig, 'east++', true};
            args{end+1}='ignoreScatter';
            args{end+1}=false;
            args{end+1}='rescale';
            args{end+1}=100;
            %args{end+1}=1;
            args{end+1}='rescale_nudge';
            args{end+1}=100;
            
            if ~isempty(labelPropsFile)
                [reduction, umap, clusterIdentifiers, extras]=...
                    run_umap(data, ...
                    'parameter_names', names, ...
                    'label_file', labelPropsFile, ...
                    'label_column', 'end',...
                    args{:});
            else
                args=Args.RemoveArg(args, 'match_scenarios');
                [reduction, umap, clusterIdentifiers, extras]=...
                    run_umap(data, 'parameter_names', names, args{:});
            end

            function saveRoi(key, roi, name, reduction, args, enableSave)
                if nargin<6
                    enableSave=true;
                end
                if ~RoiUtil.IsHandle(roi)
                    return;
                end
                if args.phate
                    gateType='PHATE';
                else
                    gateType='UMAP';
                end
                if isempty(umapBaseName)
                    conclude(reduction, args);
                    if isempty(umapBaseName)
                        msgWarning(Basics.HtmlHr(['No gate will be ' ...
                            'saved if<br>' gateType ...
                            'is not saved first.']));
                        return;
                    end
                end
                if size(reduction, 2)~=2
                    msgWarning('Only 2D reductions supported!');
                    return;
                end
                html=['Saving ' gateType ' gate'];
                busy1=Gui.ShowBusy(gates{1}.getTreeFig, Gui.YellowSmall(...
                    html), 'umap.png', 3);
                try
                    [umapTopGates, umapSubGates]...
                        =SuhGate.SaveRoiUnderClonedGates(...
                        roi, name, gateType, reduction, umapDims, gates,...
                        true, args, umapTopGates,{}, umapSubGates, key);
                    if enableSave
                        gates{1}.enableSave;
                    end
                catch ex
                    ex.getReport
                end
                Gui.HideBusy(gates{1}.getTreeFig, busy1, true);
            end

            function conclude(reduction, supervisor, args, fig)
                if ~isempty(supervisor) 
                    if args.mlp_only
                        saveMlp(supervisor, args);
                    end
                end                    
                if isempty(reduction)
                    return;
                end
                if args.phate
                    purpose='PHATE';
                else
                    purpose='UMAP';
                end
                html=['Writing ' purpose ' to FlowJo ' ...
                    'workspace<br>' Html.WrapBoldSmall( ...
                    '<br>(save later when/IF satisfied)')];
                busy1=Gui.ShowBusy(gates{1}.getTreeFig, Gui.YellowSmall(...
                    html), 'umap.png', 3);
                busy2=Gui.ShowBusy(fig, Gui.YellowSmall(...
                    html), 'umap.png', 3);
                [umapBaseName, umapDims]=SuhGate.SaveUmap( ...
                    reduction, gates, args);
                Gui.HideBusy(gates{1}.getTreeFig, busy1, true);
                Gui.HideBusy(fig, busy2, true);
            end
            
            function saveMlp(supervisors, args)
                FlowJoTree.CreateLabelGates('MLP', 'mlp.png', data, ...
                    supervisors.mlp_labels, supervisors.labelMap, ...
                    names, gates, args)
            end
        end

        function ok=CreateLabelGates(gateType, img, data, labels, ...
                labelMap, columnNames, gates, args)
            if nargin<8
                args=struct('flowjo_ask', false);
            end
            GAP=100;
            ok=false;
            if isempty(labels)
                return;
            end
            if isfield(args, 'mlp_supervise') && ~args.mlp_supervise
                return;
            end
            if isempty(labelMap)
                labelMap=LabelBasics.EmptyMap(labels);
            end
            [R, C]=size(labels);
            if C > R
                labels=labels';
            end
            if isinteger(labels)
                labels=double(labels);
            end
            dflt=StringArray.ArrayItemStartsWith(columnNames, 'FSC-', true, 1);
            prop=['FlowJo.LabelGate.' gateType];
            props=MultiProps(BasicMap.Global, gates{1}.gml.propsGui);
            if ~args.flowjo_ask
                priorDflt=BasicMap.Global.get(prop);
                if ~isempty(priorDflt)
                    priorDflt=StringArray.IndexOf(columnNames, priorDflt);
                    if priorDflt>0
                        dflt=priorDflt;
                    end
                end
                if isempty(dflt) || dflt<1
                    dflt=1;
                end
                xIdx=dflt;
            else
                [xIdx, cancelled]=Gui.Ask(struct('msg', Html.WrapHr([...
                    'Pick "X parameter" for X/Y display <br>of <b>' ...
                    gateType ' gates</b>...']),'properties', ...
                    gates{1}.gml.propsGui), columnNames,...
                    [], ['FlowJo ' gateType], dflt);
                if cancelled || isempty(xIdx) || xIdx<1
                    return;
                end
                props.set(prop, columnNames{xIdx});
            end
            figTree=gates{1}.getTreeFig;
            tempFigTree=isempty(figTree);
            if tempFigTree
                figTree=Gui.Figure(true);
                set(figTree, 'Name', 'Opening FlowJo workspace');
                op=get(figTree, 'OuterPosition');
                set(figTree, 'OuterPosition', [op(1) op(2) op(3)*.7 op(4)/2]);
                Gui.SetFigVisible(figTree, true);
                drawnow;
            end
            busy1=Gui.ShowBusy(figTree, Gui.YellowSmall(...
                ['Creating ' gateType ' gates for use in FlowJo ']), img, 3);
            pu=[];
            [scalerX, dimX]=gates{1}.fcs.getScalerByName(columnNames{xIdx});
            xData=data(:, xIdx);
            try
                u=unique(labels);
                yData=labels;
                nU=length(u);
                for i=1:nU
                    label=u(i);
                    yData(labels==label)=i*GAP;
                end
                [dimYs, baseName, pu]=SuhGate.NewDerivedParameters(...
                    gateType, yData, gates, args, 0, (nU+1)*GAP, false);
                if isempty(baseName)
                    Gui.HideBusy(figTree, busy1, true);
                    if tempFigTree
                        close(figTree);
                    end
                    if ~isempty(pu)
                        pu.close;
                    end
                    return;
                end
                nGates=length(gates);
                mlpDims=cell(nGates, 2);
                for i=1:nGates
                    mlpDims(i,:)={dimX, dimYs{i,1}};
                end
                scalerY=gates{1}.fcs.scalers.get(dimYs{1,1});
                mlpData=[xData scalerY.scale(yData)];
                scalers={scalerX, scalerY};
                ax_=[];
                fig_=[];
                height=scalerY.scale(floor(GAP/3));
                mlpTopGates={};
                for i=1:nU
                    label=u(i);
                    if label==0
                        name='Background';
                    else
                        name=labelMap.get(...
                            java.lang.String(num2str(label)));
                        if isempty(name)
                            name=[gateType ' ID=' num2str(label)];
                        end
                    end
                    mn=min(xData(labels==label));
                    mx=max(xData(labels==label));
                    X=mn-.01;
                    width=(mx-mn)+.02;
                    Y=scalerY.scale((i*GAP)-floor(GAP/6));
                    [roi, ax_, tempFig]=RoiUtil.NewRect(...
                        [X Y width height], ax_);
                    if ~isempty(tempFig)
                        fig_=tempFig;
                    end
                    mlpTopGates=SuhGate.SaveRoiUnderClonedGates(...
                        roi, name, gateType, mlpData, mlpDims, ...
                        gates, true, args, mlpTopGates, scalers);
                end
                if ~isempty(fig_)
                    delete(fig_);
                end
            catch ex
                ex.getReport
            end            
            Gui.HideBusy(gates{1}.getTreeFig, busy1, true);
            if tempFigTree
                close(figTree);
            end
            if ~isempty(pu)
                pu.close;
            end
            gates{1}.enableSave(false, gateType);
            ok=true;
        end

        function MsgSelect
            msg(Html.WrapHr(['First select a gate <br>'...
                'in this tree of gates...']), 8, 'north east+', ...
                'Selection required...');
        end
        
        function [type, id]=Parse(key)
            idx=find(key==':');
            type=key(1:idx-1);
            id=key(idx+1:end);
        end
        
        function [csvFileOrData, columnNames, labelPropsFile, gt, ...
                sampleOffsets, fncSave, fncSaveRoi, fjb, gates, ...
                gaters]=GetData(flowJoURI, columns, ...
                visibleTree, justDataNoLabels, getCsvFile, fig, ...
                priorFncSave, purpose, ask)
            if nargin<9
                ask=true;
                if nargin<8
                    purpose='explore';
                    if nargin<7
                        priorFncSave=[];
                        if nargin<6
                            fig=[];
                            if nargin<5
                                getCsvFile=false;
                                if nargin<4
                                    justDataNoLabels=false;
                                    if nargin<3
                                        visibleTree=false;
                                        if nargin<2
                                            columns=[];
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            sampleOffsets=[];
            fncSave=priorFncSave;
            if iscell(flowJoURI)
                first=flowJoURI{1};
                nSubsets=length(flowJoURI);
            else
                first=flowJoURI;
                nSubsets=1;
            end
            toks=strsplit(first, '@');
            nToks=length(toks);
            if nToks==1
                uriFjb=toks{1};
                subset='';
            elseif nToks==2
                uriFjb=toks{2};
                subset=toks{1};
            else
                error('Format error subset@flowJo.wsp (%s)!',...
                    first);
            end
            gt=FlowJoTree.NewOrReuse(uriFjb, [], visibleTree);
            if isempty(gt)
                csvFileOrData=[];
                columnNames={};
                labelPropsFile=[];
                fncSaveRoi=[];
                ids={};
                gates={};
                gaters={};
                return;
            end
            fjb=gt.gml;
            if isempty(fig)
                if ~isempty(gt.fig) && ishandle(gt.fig)
                    fig=gt.fig;
                else
                    figTree=Gui.Figure(true);
                    op=get(figTree, 'OuterPosition');
                    set(figTree, 'OuterPosition', [op(1) op(2) op(3)*.7 op(4)/2]);
                    set(figTree, 'Name', 'Opening FlowJo workspace');
                    Gui.SetFigVisible(figTree, true);
                    drawnow;
                    fig=figTree;
                end
            end
            ids={};
            gates={};
            gaters={};
            addGate(subset);
            if nSubsets>1
                for i=2:nSubsets
                    s=flowJoURI{i};
                    if contains(s, '/')
                        subset=s;
                    else
                        idx=String.IndexOf(subset,'/');
                        if idx>0
                            subset=[s subset(idx:end)];
                        else
                            subset=s;
                        end
                    end
                    addGate(subset);
                end
            end
            if isempty(gates)
                csvFileOrData=[];
                columnNames={};
                labelPropsFile=[];
                msgError('No gates found!')
            elseif visibleTree
                if ~gt.isTreeVisible
                    gt.show;
                end
                gt.suhTree.ensureVisible(ids{1}, 1);
                for j=2:nSubsets
                    gt.suhTree.ensureVisible(ids{j}, 2);
                end
                csvFileOrData=[];
                columnNames={};
                labelPropsFile=[];
                fncSaveRoi=[];
            else
                if nSubsets>1
                    if nargout>10
                        msgWarning(Html.WrapHr(['No csvFile returned '...
                            'if arg #1<br>(<i>subsetAndUri</i>)' ...
                            ' denotes multiple hierarchies.']));
                        csvFile='';
                    end
                    [csvFileOrData, columnNames, labelPropsFile, ~, sampleOffsets]...
                        =gt.packageSubsets(justDataNoLabels, ask, purpose, ids, fig);
                    gt=[];
                else
                    gt=[];
                    [csvFileOrData, columnNames, labelPropsFile, csvFile,~,~,~,columns]=...
                        gates{1}.gater.packageSubset(gates{1}, ask, ...
                        columns, getCsvFile, justDataNoLabels, fig);
                end
                if nargout>5
                    if strcmpi(purpose, 'EPP')
                        fncSave=gates{1}.getEppGateCreatorFunction(columns);
                    elseif strcmpi(purpose, 'MLP')
                        fncSave=@(data, columnNames, mlpLabels, ...
                            labelMap, args)saveMlp(gates{1}, data, gates, ...
                            columnNames, mlpLabels, labelMap, args);
                    elseif strcmpi(purpose, 'UMAP')
                        umapBaseName={};                
                        umapDims={};
                        fncSave=@(reduction, supervisors, args, fig)...
                            saveUmap(reduction, gates, args);
                    end
                    if nargout>6
                        umapTopGates={};                
                        umapSubGates={};                        
                        fncSaveRoi=@(key, roi, name, reduction, ...
                            args, enableSave)...
                            saveUmapRoi(key, roi, name, reduction, ...
                            gates, args, enableSave);
                    end
                end
                if exist('figTree', 'var')
                    close(figTree);
                end
                if getCsvFile
                    csvFileOrData=csvFile;
                end 
            end 

            function saveUmapRoi(key, roi, name, reduction, gates, args, enableSave)
                [umapTopGates, umapSubGates]=SuhGate.SaveUmapRoi(key, roi, name, ...
                    reduction, gates, args, umapBaseName, umapDims, ...
                    umapTopGates, umapSubGates, enableSave);
            end
            
            function saveUmap(reduction, gates, args)
                [umapBaseName, umapDims]=...
                    SuhGate.SaveUmap(reduction, gates, args);
            end
            
            function addGate(subset)
                [gate, gater]=gt.findGate(subset, 0);
                gater.setTree(gt);
                if ~isempty(gate)
                    ids{end+1}=gate.id;
                    gates{end+1}=gate;
                    gaters{end+1}=gater;
                end
            end
        end    
    end
end