function osp_onFit( ~, ~ ,gui)
%% osp_onFit
%   Callback function on fit button click.
%
%
%   USAGE:
%       osp_onFit( ~, ~ ,gui);
%
%   INPUT:      gui      = gui class containing all handles and the MRSCont 
%
%   OUTPUT:     Changes in gui parameters and MRSCont are written into the
%               gui class
%
%
%   AUTHORS:
%       Dr. Helge Zoellner (Johns Hopkins University, 2020-01-16)
%       hzoelln2@jhmi.edu
%
%   CREDITS:
%       This code is based on numerous functions from the FID-A toolbox by
%       Dr. Jamie Near (McGill University)
%       https://github.com/CIC-methods/FID-A
%       Simpson et al., Magn Reson Med 77:23-33 (2017)
%
%   HISTORY:
%       2020-01-16: First version of the code.
%%% 1. DELETE OLD PLOTS %%%
    MRSCont = getappdata(gui.figure,'MRSCont'); % Get MRSCont from hidden container in gui class  
    set(gui.figure,'HandleVisibility','off');
    set(gui.layout.tabs,'SelectionChangedFcn','');
    set(gui.layout.fitTab, 'SelectionChangedFcn','');
    gui.layout.b_fit.Enable = 'off';
    gui.layout.tabs.Selection  = 3;
    if gui.process.ManualManipulation
        % Optional: write edited files to LCModel .RAW files
        if MRSCont.opts.saveLCM && ~MRSCont.flags.isPRIAM && ~MRSCont.flags.isMRSI
            [MRSCont] = osp_saveLCM(MRSCont);
        end
        
        % Optional: write edited files to jMRUI .txt files
        if MRSCont.opts.savejMRUI && ~MRSCont.flags.isPRIAM && ~MRSCont.flags.isMRSI
            [MRSCont] = osp_saveJMRUI(MRSCont);
        end
        
        % Optional: write edited files to vendor specific format files readable to
        % LCModel and jMRUI
        % SPAR/SDAT if Philips
        % RDA if Siemens
        if MRSCont.opts.saveVendor && ~MRSCont.flags.isPRIAM && ~MRSCont.flags.isMRSI
            [MRSCont] = osp_saveVendor(MRSCont);
        end
        
        % Optional: write edited files to NIfTI-MRS format
        if MRSCont.opts.saveNII && ~MRSCont.flags.isPRIAM && ~MRSCont.flags.isMRSI
            [MRSCont] = osp_saveNII(MRSCont);
        end
    end
    [gui,MRSCont] = osp_processingWindow(gui,MRSCont);
%%% 2. CALL OSPREYFIT %%%
    MRSCont = OspreyFit(MRSCont);
    delete(gui.layout.dummy);   
    if ~(isfield(MRSCont.flags,'isPRIAM') || isfield(MRSCont.flags,'isMRSI')) || ~(MRSCont.flags.isPRIAM || MRSCont.flags.isMRSI)
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
            gui.fit.Number = length(gui.fit.Names); 
        else
            gui.fit.Names = fieldnames(MRSCont.fit.results);
            gui.fit.Number = length(fieldnames(MRSCont.fit.results));   
        end
    else
        if strcmp(MRSCont.opts.fit.style, 'Concatenated')
            temp = fieldnames(MRSCont.fit.results{1,gui.controls.act_x});
            if MRSCont.flags.isUnEdited
                gui.fit.Names = fieldnames(MRSCont.fit.results{1,gui.controls.act_x});
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
            gui.fit.Number = length(gui.fit.Names); 
        else
            gui.fit.Names = fieldnames(MRSCont.fit.results{1,gui.controls.act_x});
            gui.fit.Number = length(fieldnames(MRSCont.fit.results{1,gui.controls.act_x}));   
        end        
    end
    setappdata(gui.figure,'MRSCont',MRSCont); % Write MRSCont into hidden container in gui class
    set(gui.figure,'HandleVisibility','on');
%%% 3. INITIALIZE OUTPUT WINDOW %%%    
    osp_iniFitWindow(gui);
    gui.layout.b_quant.Enable = 'on';
    set(gui.layout.tabs,'SelectionChangedFcn',{@osp_SelectionChangedFcn,gui});
    set(gui.layout.fitTab, 'SelectionChangedFcn',{@osp_FitTabChangeFcn,gui});
end % onFit