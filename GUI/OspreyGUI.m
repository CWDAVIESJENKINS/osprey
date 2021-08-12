classdef OspreyGUI < handle
    %% OspreyGUI
    %   This class creates a one-in-all figure with visualizations of the
    %   processed data (spectra in the frequency domain), voxel coregistration
    %   and segmentation, quantification tables, and results.
    %
    %   The figure contains several tabs, not all of which may be available at
    %   all times:
    %       - Data
    %       - Processed
    %       - Coregistration and segmentation
    %       - Fit
    %       - Quantification
    %       - Overview
    %
    %   As an example, if coregistration and segmentation have not been
    %   performed, the respective tab will be grayed out.
    %
    %   USAGE:
    %       OspreyGUIapp;
    %
    %
    %   AUTHORS:
    %       Dr. Helge Zoellner (Johns Hopkins University, 2019-11-07)
    %       hzoelln2@jhmi.edu
    %
    %   CREDITS:
    %       This code is based on numerous functions from the FID-A toolbox by
    %       Dr. Jamie Near (McGill University)
    %       https://github.com/CIC-methods/FID-A
    %       Simpson et al., Magn Reson Med 77:23-33 (2017)
    %
    %   HISTORY:
    %       2020-01-13: First version of the code.
    
    %% Properties
    % Here the properties for the gui class are defined
    properties
        MRSCont     % MRS container with data
        folder      % all folders
        colormap    % colormaps for gui
        controls    % gui control handles
        waitbar     % waitbar values
        load        % OspreyLoad infos
        process     % OspreyProcess infos
        fit         % OspreyFit infos
        coreg       % OspreyCoreg infos
        quant       % OspreyQuant infos
        overview    % OspreyOverview infos
        figure      % figure handle
        layout      % Layout infos
        upperBox    % contains upper part of gui
        Plot        % plot struct
        InfoText    % info text struct (left side of fit plot)
        Results     % result struct (fit results)
    end
    
    methods
        
        function gui = OspreyGUI(MRSCont)
            % This is the "constructor" for the OspreyGUI class
            % It runs when an object of this class is created (i.e. when
            % the GUI is started up, either from the Osprey start menu, or 
            % with OspreyGUI(MRSCont) from an existing MRS data container.
            
            
            %% %%% 1. INITIALIZE VARIABLES, START-UP CHECK-UPS %%%
            
            % Catch empty call
            if nargin == 0
                error('No MRS container supplied. Please call OspreyGUI with a MRS container as argument.')
            end
            
            % Close any remaining open figures & add folders
            close all;
            % Determine the folder Osprey is being run from
            [settingsFolder,~,~]    = fileparts(which('OspreySettings.m'));
            gui.folder.allFolders   = strsplit(settingsFolder, filesep);
            gui.folder.ospFolder    = strjoin(gui.folder.allFolders(1:end-1), filesep); % parent folder (= Osprey folder)
            
            % Toolbox check to determine whether and which MATLAB toolboxes
            % (and SPM) are available
            if isfield(MRSCont.flags,'isToolChecked')
                MRSCont.flags.hasSPM = osp_Toolbox_Check('OspreyGUI',MRSCont.flags.isToolChecked);
            else
                MRSCont.flags.hasSPM = osp_Toolbox_Check('OspreyGUI',0);
                MRSCont.flags.isToolChecked = 1;
            end
            if MRSCont.flags.hasSPM
                load(fullfile(gui.folder.ospFolder,'GUI','SPMpath.mat'),'SPMpath')
                gui.folder.spmversion = SPMpath;
            end
            
            % Load selected colormap
            gui.colormap = MRSCont.colormap;
            
            % Set GM plot to on
            gui.controls.GM = 1;
            
            % Setting up initial values for the gui control variables
            % Global controls
            gui.controls.Selected       = 1;
            gui.controls.Number         = 1;
            gui.controls.NumberImages   = 1;
            gui.controls.KeyPress       = 0;
            % File selections for each sub function
            gui.load.Selected           = 1;
            gui.process.Selected        = 1;
            gui.fit.Selected            = 1;
            gui.coreg.Selected          = 1;
            gui.quant.Selected.Model    = 1;
            gui.quant.Selected.Quant    = 1;
            gui.overview.Selected.Metab = 1;
            % Names for each selection
            gui.load.Names.Spec         = {'metabolites'};
            gui.load.Names.Images       = {'structural'};
            % Initial number of datasets
            if isfield(MRSCont, 'nDatasets')
                gui.controls.nDatasets  = MRSCont.nDatasets;
            else
                gui.controls.nDatasets  = 0;
            end
            
            % Setting up remaining values in dependence of the conducted processing steps
            if MRSCont.flags.didLoadData % Get variables regarding the loading
                if ~isempty(MRSCont.raw{1,gui.controls.Selected}.seq)
                    if strcmp(sprintf('\n'), MRSCont.raw{1,gui.controls.Selected}.seq(end)) % Clean up Sequence Name if needed
                        gui.load.Names.Seq = MRSCont.raw{1,gui.controls.Selected}.seq(1:end-1);
                    else
                        gui.load.Names.Seq = MRSCont.raw{1,gui.controls.Selected}.seq;
                    end
                else
                    if MRSCont.flags.isUnEdited
                        gui.load.Names.Seq =['Unedited ' MRSCont.vendor];
                    end
                    if MRSCont.flags.isMEGA
                        gui.load.Names.Seq =['MEGA ' MRSCont.vendor];
                    end
                    if MRSCont.flags.isHERMES
                        gui.load.Names.Seq =['HERMES ' MRSCont.vendor];
                    end
                    if MRSCont.flags.isHERCULES
                        gui.load.Names.Seq =['HERCULES ' MRSCont.vendor];
                    end
                    if MRSCont.flags.isPRIAM
                        gui.load.Names.Seq =['PRIAM ' MRSCont.vendor];
                    end
                end
                gui.load.Names.Geom = fieldnames(MRSCont.raw{1,1}.geometry.size); %Get variables regarding voxel geometry
            end
            
            if MRSCont.flags.didProcess % Get variables regarding the processing
                gui.process.Number  = length(fieldnames(MRSCont.processed));
                gui.process.Names   = fieldnames(MRSCont.processed);
            end
            
            if MRSCont.flags.didFit % Get variables regarding the fitting
                if strcmp(MRSCont.opts.fit.style, 'Concatenated')
                    temp = fieldnames(MRSCont.fit.results);
                    if MRSCont.flags.isUnEdited
                        gui.fit.Names = fieldnames(MRSCont.fit.results);
                    end
                    if MRSCont.flags.isMEGA
                        gui.fit.Names = {'diff1','sum'};
                        if length(temp) == 2
                            gui.fit.Names{3} = temp{2};
                        else if length(temp) == 3
                                gui.fit.Names{3} = temp{2};
                                gui.fit.Names{4} = temp{3};
                            end
                        end
                    end
                    if (MRSCont.flags.isHERMES || MRSCont.flags.isHERCULES)
                        gui.fit.Names = {'diff1','diff2','sum'};
                        if length(temp) == 2
                            gui.fit.Names{4} = temp{2};
                        else if length(temp) == 3
                                gui.fit.Names{4} = temp{2};
                                gui.fit.Names{5} = temp{3};
                            end
                        end
                    end
                    gui.fit.Number  = length(gui.fit.Names);
                else
                    gui.fit.Names   = fieldnames(MRSCont.fit.results);
                    gui.fit.Number  = length(fieldnames(MRSCont.fit.results));
                end
            end
            
            if MRSCont.flags.didCoreg % Get variables regarding the coregistration
            end
            
            if MRSCont.flags.didSeg % Get variables regarding the segmentation
            end
            
            if MRSCont.flags.didQuantify % Get variables regarding the quantification
                gui.quant.Number.Model      = length(fieldnames(MRSCont.quantify.tables));
                gui.quant.Names.Model       = fieldnames(MRSCont.quantify.tables);
                gui.quant.Number.Quants     = length(fieldnames(MRSCont.quantify.tables.(gui.quant.Names.Model{1})));
                gui.quant.Names.Quants      = fieldnames(MRSCont.quantify.tables.(gui.quant.Names.Model{1}));
                gui.quant.Number.Metabs     = length(MRSCont.quantify.metabs);
                gui.quant.Selected.Metab    = find(strcmp(MRSCont.quantify.metabs, 'tNAA'));
                gui.quant.Selected.Model    = 1;
                gui.quant.idx.GABA          = find(strcmp(MRSCont.quantify.metabs, 'GABA'));
            end
            
            if MRSCont.flags.didOverview % Get variables for the overview tab
                gui.overview.NAAnormed      = 1;
                gui.overview.Number.Groups  = MRSCont.overview.NoGroups;
                [gui.colormap.cb]           = cbrewer('qual', 'Dark2', 12, 'pchip');
                temp                        = gui.colormap.cb(3,:);
                gui.colormap.cb(3,:)        = gui.colormap.cb(4,:);
                gui.colormap.cb(4,:)        = temp;
                % Set up names and correlation measures for the correlation
                % tab
                if isfield(MRSCont.overview, 'corr')
                    gui.overview.Names.Corr = MRSCont.overview.corr.Names;
                    gui.overview.CorrMeas = MRSCont.overview.corr.Meas;
                end
                gui.overview.Selected.Corr          = 1;
                gui.overview.Selected.CorrChoice    = 3;
                gui.overview.Names.QM = {'SNR', 'FWHM (ppm)'};
            end
            
            % Create the waitbar
            gui.waitbar.overall = MRSCont.flags.didLoadData+MRSCont.flags.didProcess+MRSCont.flags.didFit+MRSCont.flags.didCoreg+MRSCont.flags.didSeg+MRSCont.flags.didQuantify+MRSCont.flags.didOverview;
            gui.waitbar.step    = 1/ gui.waitbar.overall;
            
            % Version check and update log file
            MRSCont.flags.isGUI     = 1;
            MRSCont.ver.GUI         = '1.0.0 GUI';
            outputFolder            = MRSCont.outputFolder;
            fileID                  = fopen(fullfile(outputFolder, 'LogFile.txt'),'a+');
            fprintf(fileID,['Timestamp %s ' MRSCont.ver.Osp '  ' MRSCont.ver.GUI '\n'], datestr(now,'mmmm dd, yyyy HH:MM:SS'));
            fclose(fileID);
            
            
            %% %%% 2. CREATE THE OSPREYGUI PARENT FIGURE %%%
            
            % Create the figure handle and assign the MRSCont data container
            gui.figure = figure('Name', 'Osprey', 'NumberTitle', 'off', 'Visible', 'on','Menu', 'none',...
                'ToolBar', 'none', 'HandleVisibility', 'off', 'Renderer', 'painters', 'Color', gui.colormap.Background);
            setappdata(gui.figure, 'MRSCont', MRSCont);
            
            % Resize such that width is 1.2941 * height (1.2941 is the ratio
            % between width and height of standard US letter size (11x8.5 in).
            screenSize      = get(0,'ScreenSize');
            canvasSize      = screenSize;
            canvasSize(4)   = screenSize(4) * 0.9;
            canvasSize(3)   = canvasSize(4) * (11/8.5);
            canvasSize(2)   = (screenSize(4) - canvasSize(4))/2;
            canvasSize(1)   = (screenSize(3) - canvasSize(3))/2;
            set(gui.figure, 'Position', canvasSize);
            
            % Create the main horizontal box division between menu (left) and display
            % panel tabs (right)
            gui.layout.mainLayout   = uix.HBox('Parent', gui.figure, 'BackgroundColor', gui.colormap.Background);
            % Create the left-side menu
            gui.layout.leftMenu     = uix.VBox('Parent', gui.layout.mainLayout, 'Padding', 4, 'Spacing', 2, 'BackgroundColor', gui.colormap.Background);
            gui.layout.Buttonbox    = uix.HBox('Parent', gui.layout.leftMenu, 'BackgroundColor', gui.colormap.Background);
            gui.layout.b_about      = uicontrol(gui.layout.Buttonbox, 'Style', 'PushButton');
            [img, ~, ~] = imread('osprey.png', 'BackgroundColor', gui.colormap.Background);
            [img2]      = imresize(img, 0.08);
            set(gui.layout.b_about, 'CData', img2, 'TooltipString', 'Contact developers via mail');
            set(gui.layout.b_about, 'Callback', {@osp_onOsp});
            
            % Create the upper left info button box
            gui.layout.Infobuttons = uix.VButtonBox('Parent', gui.layout.Buttonbox, 'BackgroundColor', gui.colormap.Background);
            % PubMed link button
            gui.layout.b_pub        = uicontrol(gui.layout.Infobuttons, 'Style', 'PushButton');
            [img, ~, ~] = imread('PubMed.png', 'BackgroundColor', gui.colormap.Background);
            [img2]      = imresize(img, 0.06);
            set(gui.layout.b_pub, 'CData', img2, 'TooltipString', 'Please cite these publications when using Osprey');
            set(gui.layout.b_pub, 'Callback', {@osp_onPub});
            % GitHub button
            gui.layout.b_git        = uicontrol(gui.layout.Infobuttons, 'Style', 'PushButton');
            [img, ~, ~] = imread('GitHubB.png', 'BackgroundColor', gui.colormap.Background);
            [img2]      = imresize(img, 0.07);
            set(gui.layout.b_git, 'CData', img2, 'TooltipString', 'Keep yourself updated and request/develop new features on GitHub');
            set(gui.layout.b_git, 'Callback', {@osp_onGit});
            % Set info button sizes
            set(gui.layout.Infobuttons, 'ButtonSize', [150 100]);
            set(gui.layout.Buttonbox, 'Width', [-0.5 -0.5]);
            
            
            %% %%% 3. CREATE MAIN MENU (LEFT-HAND SIDE) %%%
            % Here, the left hand side box is filled with the main menu
            % buttons and a listbox to switch between datasets included in
            % the Osprey job file.
            
            % Create the main menu button column
            gui.layout.p2 = uix.VButtonBox('Parent', gui.layout.leftMenu, 'Spacing', 3, ...
                'BackgroundColor',gui.colormap.Background);
            set(gui.layout.leftMenu, 'Heights', [-0.2 -0.8]);
            set(gui.layout.p2, 'ButtonSize', [300 60]);
            
            % Load button
            gui.layout.b_load = uicontrol('Parent', gui.layout.p2, 'Style', 'PushButton', 'String', 'Load data', 'Enable', 'on', 'ForegroundColor', gui.colormap.Foreground);
            set(gui.layout.b_load,'Units', 'Normalized', 'Position', [0.1 0.75 0.8 0.08], 'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'Bold');
            % Activate only if data loading has not been completed yet
            if (MRSCont.flags.didLoadData == 1 && isfield(MRSCont, 'raw') && (gui.controls.nDatasets >= length(MRSCont.raw)) && isfield(MRSCont.ver, 'Load') && strcmp(MRSCont.ver.Load, MRSCont.ver.CheckLoad))
                gui.layout.b_load.Enable = 'off';
            end
            % Set callback function
            set(gui.layout.b_load, 'Callback', {@osp_onLoad,gui}, 'TooltipString', 'Call OspreyLoad');
            set(gui.layout.b_load, 'Tag', 'Load');
            
            % Process button
            gui.layout.b_proc = uicontrol('Parent', gui.layout.p2, 'Style', 'PushButton', 'String', 'Process data', 'Enable', 'on', 'ForegroundColor', gui.colormap.Foreground);
            set(gui.layout.b_proc, 'Units', 'Normalized', 'Position', [0.1 0.75 0.8 0.08], 'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'Bold');
            % Activate only if data processing has not been completed yet
            if (MRSCont.flags.didProcess == 1  && isfield(MRSCont, 'raw') && (gui.controls.nDatasets >= length(MRSCont.processed.A)) && isfield(MRSCont.ver, 'Pro') && strcmp(MRSCont.ver.Pro,MRSCont.ver.CheckPro))
                gui.layout.b_proc.Enable = 'off';
            else if ~(MRSCont.flags.didLoadData == 1  && isfield(MRSCont, 'raw') && (gui.controls.nDatasets >= length(MRSCont.raw)) && isfield(MRSCont.ver, 'Load') && strcmp(MRSCont.ver.Load,MRSCont.ver.CheckLoad))
                    gui.layout.b_proc.Enable = 'off';
                end
            end
            % Set callback function
            set(gui.layout.b_proc, 'Callback',{@osp_onProc,gui}, 'TooltipString', 'Call OspreyProcess');
            
            % Fit button
            gui.layout.b_fit = uicontrol('Parent', gui.layout.p2, 'Style', 'PushButton', 'String', 'Model data', 'Enable', 'on', 'ForegroundColor', gui.colormap.Foreground);
            set(gui.layout.b_fit, 'Units', 'Normalized', 'Position', [0.1 0.67 0.8 0.08], 'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'Bold');
            % Activate only if data fitting has not been completed yet
            if (MRSCont.flags.didFit == 1  && isfield(MRSCont, 'fit') && (gui.controls.nDatasets >= length(MRSCont.fit.scale)) && isfield(MRSCont.ver, 'Fit') && strcmp(MRSCont.ver.Fit,MRSCont.ver.CheckFit))
                gui.layout.b_fit.Enable = 'off';
            else if ~(MRSCont.flags.didProcess == 1  && isfield(MRSCont, 'raw') && (gui.controls.nDatasets >= length(MRSCont.processed.A)) && isfield(MRSCont.ver, 'Pro') && strcmp(MRSCont.ver.Pro,MRSCont.ver.CheckPro))
                    gui.layout.b_fit.Enable = 'off';
                end
            end
            % Set callback function
            set(gui.layout.b_fit, 'Callback', {@osp_onFit,gui}, 'TooltipString', 'Call OspreyFit');
            
            % Coregister button
            gui.layout.b_coreg = uicontrol('Parent', gui.layout.p2, 'Style', 'PushButton', 'String', 'CoRegister', 'Enable', 'off', 'ForegroundColor', gui.colormap.Foreground);
            set(gui.layout.b_coreg, 'Units', 'Normalized', 'Position', [0.1 0.59 0.8 0.08], 'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'Bold');
            % Activate only if structurals are available AND coreg has not
            % been completed yet
            if MRSCont.flags.hasSPM == 1 && ~isempty(MRSCont.files_nii) && ~(MRSCont.flags.didCoreg == 1  && isfield(MRSCont, 'coreg') && (gui.controls.nDatasets >= length(MRSCont.coreg.vol_image)) && isfield(MRSCont.ver, 'Coreg') && strcmp(MRSCont.ver.Coreg,MRSCont.ver.CheckCoreg)) && (MRSCont.flags.didLoadData == 1  && isfield(MRSCont, 'raw') && (gui.controls.nDatasets >= length(MRSCont.raw)) && isfield(MRSCont.ver, 'Load') && strcmp(MRSCont.ver.Load,MRSCont.ver.CheckLoad))
                gui.layout.b_coreg.Enable = 'on';
            end
            % Set callback function
            set(gui.layout.b_coreg, 'Callback', {@osp_onCoreg,gui}, 'TooltipString', 'Call OspreyCoreg');
            % If SPM is not available, change caption of the button
            if MRSCont.flags.hasSPM == 0
                set(gui.layout.b_coreg, 'String', 'Install SPM12 to CoRegister', 'FontSize', 12);
            end
            
            % Segment button
            gui.layout.b_segm = uicontrol('Parent', gui.layout.p2, 'Style', 'PushButton', 'String', 'Segment', 'Enable', 'off', 'ForegroundColor', gui.colormap.Foreground);
            set(gui.layout.b_segm, 'Units', 'Normalized', 'Position', [0.1 0.51 0.8 0.08], 'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'Bold');
            % Activate only if structurals are available AND seg has not
            % been completed yet
            if MRSCont.flags.hasSPM == 1 && ~isempty(MRSCont.files_nii) && ~(MRSCont.flags.didSeg == 1  && isfield(MRSCont, 'seg') && (gui.controls.nDatasets >= length(MRSCont.seg.tissue.fGM)) && isfield(MRSCont.ver, 'Seg') && strcmp(MRSCont.ver.Seg,MRSCont.ver.CheckSeg)) && (MRSCont.flags.didCoreg == 1  && isfield(MRSCont, 'coreg') && (gui.controls.nDatasets >= length(MRSCont.coreg.vol_image)) && isfield(MRSCont.ver, 'Coreg') && strcmp(MRSCont.ver.Coreg,MRSCont.ver.CheckCoreg))
                gui.layout.b_segm.Enable = 'on';
            end
            % Set callback function
            set(gui.layout.b_segm,'Callback',{@osp_onSeg,gui}, 'TooltipString', 'Call OspreySeg');
            % If SPM is not available, change caption of the button
            if MRSCont.flags.hasSPM == 0
                set(gui.layout.b_segm, 'String', 'Install SPM12 to Segment', 'FontSize', 12);
            end
            
            % Quantify button
            gui.layout.b_quant = uicontrol('Parent', gui.layout.p2, 'Style', 'PushButton', 'String', 'Quantify', 'Enable', 'on', 'ForegroundColor', gui.colormap.Foreground);
            set(gui.layout.b_quant, 'Units', 'Normalized', 'Position', [0.1 0.43 0.8 0.08], 'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'Bold');
            % Activate only if quantify has not been completed yet
            if MRSCont.flags.didQuantify
                gui.layout.b_quant.Enable = 'off';
            else if ~(MRSCont.flags.didFit == 1  && isfield(MRSCont, 'fit') && (gui.controls.nDatasets >= length(MRSCont.fit.scale)) && isfield(MRSCont.ver, 'Fit') && strcmp(MRSCont.ver.Fit,MRSCont.ver.CheckFit))
                    gui.layout.b_quant.Enable = 'off';
                end
            end
            % Set callback function
            set(gui.layout.b_quant, 'Callback', {@osp_onQuant,gui}, 'TooltipString', 'Call OspreyQuantify');
            
            % DeIdentify button
            gui.layout.b_deid = uicontrol('Parent', gui.layout.p2, 'Style', 'PushButton', 'String', 'DeIdentify', 'Enable', 'off', 'ForegroundColor', gui.colormap.Foreground);
            set(gui.layout.b_deid, 'Units', 'Normalized', 'Position', [0.1 0.2 0.8 0.08], 'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'Bold');
            % Set callback function
            set(gui.layout.b_deid, 'Callback', {@gui_deid,gui,MRSCont}, 'TooltipString', 'DeIndentify');
            
            % Save button
            gui.layout.b_save = uicontrol('Parent', gui.layout.p2, 'Style', 'PushButton', 'String', 'Save MRSCont', 'ForegroundColor', gui.colormap.Foreground);
            set(gui.layout.b_save, 'Units', 'Normalized', 'Position', [0.1 0 0.8 0.08], 'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'Bold');
            % Set callback function
            set(gui.layout.b_save,'Callback', {@osp_onSave,gui}, 'TooltipString', 'Save MRSCont as .mat-file');
            
            % Exit button
            gui.layout.b_exit = uicontrol('Parent', gui.layout.p2, 'Style', 'PushButton', 'String', 'Exit', 'ForegroundColor', gui.colormap.Foreground);
            set(gui.layout.b_exit, 'Units', 'Normalized', 'Position', [0.1 0 0.8 0.08], 'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'Bold');
            % Set callback function
            set(gui.layout.b_exit, 'Callback', {@osp_onExit,gui}, 'TooltipString', 'See you next time!');
            
            % Create list of files for the dataset Listbox
            gui.layout.controlPanel     = uix.Panel('Parent', gui.layout.leftMenu, 'Title', 'MRS Container','BackgroundColor',gui.colormap.Background);
            set(gui.layout.controlPanel, 'Units', 'Normalized', 'Position', [0.5 0 0.66 0.1], 'FontSize', 16, 'FontName', 'Arial', 'FontWeight', 'Bold', 'ForegroundColor', gui.colormap.Foreground, 'HighlightColor', gui.colormap.Foreground, 'ShadowColor', gui.colormap.Foreground);
            gui.layout.fileList         = MRSCont.files;
            SepFileList                 = cell(1,length(MRSCont.files));
            gui.layout.RedFileList      = cell(1,length(MRSCont.files));
            gui.layout.OnlyFileList     = cell(1,length(MRSCont.files));
            for i = 1 : length(MRSCont.files) %find last two subfolders and file names
                SepFileList{i} =  split(gui.layout.fileList(i), filesep);
                if length(SepFileList{i}) == 1
                    SepFileList{i} =  split(gui.layout.fileList(i), '\');
                end
                gui.layout.RedFileList{i}   = [filesep SepFileList{i}{end-2} filesep SepFileList{i}{end-1} filesep SepFileList{i}{end}];
                gui.layout.OnlyFileList{i}  = [SepFileList{i}{end}];
            end
            clear SepFileList
            gui.layout.ListBox = uicontrol('Style', 'list', 'BackgroundColor', 'w', 'FontName', 'Arial', 'BackgroundColor', gui.colormap.Background, ...
                'Parent', gui.layout.controlPanel, 'String', gui.layout.RedFileList(:), ...
                'Value', gui.controls.Selected, 'Interruptible', 'on', 'BusyAction', 'cancel', ...
                'ForegroundColor', gui.colormap.Foreground, 'TooltipString', 'Select a file you want to inspect.');
            
            
            %% %%% 4. CREATE DISPLAY PANEL TOP TAB ROW %%%
            % Here, we define the parent tab row for each
            % analysis step.
            gui.layout.tabs = uix.TabPanel('Parent', gui.layout.mainLayout, 'Padding', 3, 'FontName', 'Arial','Visible','off',...
                'FontSize', 16,'BackgroundColor', gui.colormap.Background,...
                'ForegroundColor', gui.colormap.Foreground, 'HighlightColor', gui.colormap.Foreground, 'ShadowColor', gui.colormap.Foreground);
            gui.layout.rawTab      = uix.TabPanel('Parent', gui.layout.tabs, 'BackgroundColor', gui.colormap.Background,...
                'ForegroundColor', gui.colormap.Foreground, 'HighlightColor', gui.colormap.Foreground, 'ShadowColor', gui.colormap.Foreground,...
                'FontName', 'Arial', 'TabLocation','bottom','FontSize', 10);
            gui.layout.proTab      = uix.TabPanel('Parent', gui.layout.tabs, 'BackgroundColor', gui.colormap.Background,...
                'ForegroundColor', gui.colormap.Foreground, 'HighlightColor', gui.colormap.Foreground, 'ShadowColor', gui.colormap.Foreground,...
                'FontName', 'Arial', 'TabLocation','bottom','FontSize', 10);
            gui.layout.fitTab      = uix.TabPanel('Parent', gui.layout.tabs, 'BackgroundColor', gui.colormap.Background,...
                'ForegroundColor', gui.colormap.Foreground, 'HighlightColor', gui.colormap.Foreground, 'ShadowColor', gui.colormap.Foreground,...
                'FontName', 'Arial', 'TabLocation','bottom','FontSize', 10);
            gui.layout.coregTab    = uix.TabPanel('Parent', gui.layout.tabs, 'BackgroundColor', gui.colormap.Background,...
                'ForegroundColor', gui.colormap.Foreground, 'HighlightColor', gui.colormap.Foreground, 'ShadowColor', gui.colormap.Foreground,...
                'FontName', 'Arial', 'TabLocation','bottom','FontSize', 10);
            gui.layout.quantifyTab = uix.TabPanel('Parent', gui.layout.tabs, 'BackgroundColor', gui.colormap.Background,...
                'ForegroundColor', gui.colormap.Foreground, 'HighlightColor', gui.colormap.Foreground, 'ShadowColor', gui.colormap.Foreground,...
                'FontName', 'Arial', 'TabLocation','bottom','FontSize', 10);
            gui.layout.overviewTab = uix.TabPanel('Parent', gui.layout.tabs, 'BackgroundColor', gui.colormap.Background,...
                'ForegroundColor', gui.colormap.Foreground, 'HighlightColor', gui.colormap.Foreground, 'ShadowColor', gui.colormap.Foreground,...
                'FontName', 'Arial', 'TabLocation','bottom','FontSize', 10);
            
            % Set tab titles, default activation, and tab widths
            gui.layout.tabs.TabTitles  = {'Raw', 'Processed', 'LC model', 'Cor/Seg', 'Quantified','Overview'};
            gui.layout.tabs.TabWidth   = 115;
            gui.layout.tabs.Selection  = 1;
            gui.layout.tabs.TabEnables = {'off', 'off', 'off', 'off', 'off', 'off'};
            set(gui.layout.mainLayout, 'Widths', [-0.2  -0.8] );
            gui.layout.EmptydataPlot = 0;
            
            
            %% %%% 5. ACTIVATE AVAILABLE TABS %%%
            % Now enable the display tabs depending on which processing steps have
            % been completed. For each step, a waitbar is included.
            
            % Load tab
            gui.controls.waitbar = waitbar(0, 'Start', 'Name', 'Loading your MRS Container');
            waitbar(0,gui.controls.waitbar, 'Loading your raw spectra')
            if (MRSCont.flags.didLoadData == 1 && isfield(MRSCont, 'raw') && (gui.controls.nDatasets >= length(MRSCont.raw)) && isfield(MRSCont.ver, 'Load') && strcmp(MRSCont.ver.Load, MRSCont.ver.CheckLoad)) 
                osp_iniLoadWindow(gui);
                set(gui.controls.b_save_RawTab, 'Callback', {@osp_onPrint,gui});
            end
            
            % Process tab
            waitbar(gui.waitbar.step,gui.controls.waitbar, 'Loading your processed spectra');
            if (MRSCont.flags.didProcess == 1 && isfield(MRSCont, 'raw') && (gui.controls.nDatasets >= length(MRSCont.processed.A)) && isfield(MRSCont.ver, 'Pro') && strcmp(MRSCont.ver.Pro, MRSCont.ver.CheckPro)) % Has data been processed?
                set(gui.layout.tabs, 'Visible', 'on');
                osp_iniProcessWindow(gui);
                set(gui.controls.b_save_proTab, 'Callback', {@osp_onPrint,gui});
                set(gui.layout.tabs, 'Visible', 'off');
            end
            
            % Fit tab
            waitbar(gui.waitbar.step*2, gui.controls.waitbar, 'Loading your fits');
            if (MRSCont.flags.didFit == 1 && isfield(MRSCont, 'fit') && (gui.controls.nDatasets >= length(MRSCont.fit.scale)) && isfield(MRSCont.ver, 'Fit') && strcmp(MRSCont.ver.Fit, MRSCont.ver.CheckFit)) % Has data fitting been run?
                osp_iniFitWindow(gui);
                set(gui.controls.b_save_fitTab, 'Callback', {@osp_onPrint,gui});
            end
            
            % Coreg/Seg tab
            waitbar(gui.waitbar.step*3, gui.controls.waitbar, 'Loading your image operations');
            if (MRSCont.flags.didCoreg == 1 && isfield(MRSCont, 'coreg') && (gui.controls.nDatasets >= length(MRSCont.coreg.vol_image)) && isfield(MRSCont.ver, 'Coreg') && strcmp(MRSCont.ver.Coreg, MRSCont.ver.CheckCoreg)) % Have coreg/segment masks been created?
                osp_iniCoregWindow(gui);
                set(gui.controls.b_save_coregTab, 'Callback', {@osp_onPrint,gui});
            end
            
            % Quantify tab
            waitbar(gui.waitbar.step*5, gui.controls.waitbar, 'Loading your quantification results');
            if MRSCont.flags.didQuantify
                osp_iniQuantifyWindow(gui);
            end
            
            % Overview tab
            waitbar(gui.waitbar.step*7, gui.controls.waitbar, 'Loading your overview');
            if MRSCont.flags.didOverview && (MRSCont.flags.didFit == 1 && isfield(MRSCont, 'fit') && (gui.controls.nDatasets >= length(MRSCont.fit.scale)) && isfield(MRSCont.ver, 'Fit') && strcmp(MRSCont.ver.Fit, MRSCont.ver.CheckFit)) % Has data fitting been run?
                osp_iniOverviewWindow(gui);
                set(gui.layout.overviewTab, 'SelectionChangedFcn', {@osp_OverviewTabChangedFcn,gui});
                set(gui.controls.pop_specsOvPlot, 'callback', {@osp_pop_specsOvPlot_Call,gui});
                set(gui.controls.pop_meanOvPlot, 'callback', {@osp_pop_meanOvPlot_Call,gui});
                set(gui.controls.pop_quantOvPlot, 'callback', {@osp_pop_quantOvPlot_Call,gui});
                set(gui.controls.pop_distrOvQuant, 'callback', {@osp_pop_distrOvQuant_Call,gui});
                set(gui.controls.pop_distrOvMetab, 'callback', {@osp_pop_distrOvMetab_Call,gui});
                set(gui.controls.pop_corrOvQuant, 'callback', {@osp_pop_corrOvQuant_Call,gui});
                set(gui.controls.pop_corrOvMetab, 'callback', {@osp_pop_corrOvMetab_Call,gui});
                set(gui.controls.pop_corrOvCorr, 'callback', {@osp_pop_corrOvCorr_Call,gui});
                set(gui.controls.pop_whichcorrOvCorr, 'callback', {@osp_pop_whichcorrOvCorr_Call,gui});
                set(gui.controls.check_specsOvPlot, 'callback', {@osp_check_specsOvPlot_Call,gui});
                set(gui.controls.check_meanOvPlot, 'callback', {@osp_check_meanOvPlot_Call,gui});
                set(gui.controls.check_distrOv, 'callback', {@osp_check_distrOv_Call,gui});
                set(gui.controls.b_save_specOvTab, 'Callback', {@osp_onPrint,gui});
                set(gui.controls.b_save_meanOvTab, 'Callback', {@osp_onPrint,gui});
                set(gui.controls.b_save_distrOvTab, 'Callback', {@osp_onPrint,gui});
                set(gui.controls.b_save_corrOvTab, 'Callback', {@osp_onPrint,gui}); 
            end
            
            % Activate first tab
            gui.layout.tabs.Selection  = 1;
            % Turn off Listbox if data has not been loaded
            if ~MRSCont.flags.didLoadData
                gui.layout.ListBox.Enable = 'off';
            end
            % Make the activated tabs visible
            set(gui.layout.tabs, 'Visible', 'on');
            % Close waitbar
            waitbar(1, gui.controls.waitbar, 'Finished');
            pause(1);
            close(gui.controls.waitbar);
            
            
            %% %%% 6. ADD CALLBACK LISTENERS TRIGGERED ON SELECTION CHANGES %%%
            % Whenever a selection is changed, the GUI will react according
            % to the functions defined below.
           
            set(gui.layout.tabs, 'SelectionChangedFcn', {@osp_SelectionChangedFcn,gui});
            set(gui.layout.rawTab, 'SelectionChangedFcn', {@osp_RawTabChangeFcn,gui});
            set(gui.layout.proTab, 'SelectionChangedFcn', {@osp_ProTabChangeFcn,gui});
            set(gui.layout.fitTab, 'SelectionChangedFcn', {@osp_FitTabChangeFcn,gui});
            set(gui.layout.coregTab, 'SelectionChangedFcn', {@osp_CoregTabChangeFcn,gui});
            set(gui.layout.quantifyTab, 'SelectionChangedFcn', {@osp_QuantTabChangeFcn,gui});
            % The listbox reacts to key presses as well to enable scrolling
            % through the datasets with the arrow buttons
            set(gui.layout.ListBox, 'Callback', {@osp_onListSelection,gui}, 'KeyPressFcn', {@osp_WindowKeyDown,gui}, 'KeyReleaseFcn', {@osp_WindowKeyUp,gui});
            
        end
        
    end
    
end % End of OspreyGUI class definition