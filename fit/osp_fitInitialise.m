function [MRSCont] = osp_fitInitialise(MRSCont)
%% [MRSCont] = osp_fitInitialise(MRSCont)
%   This function initialises default basis sets and decides which
%   metabolites to include in the modeling process carried out by OspreyFit.
%
%   USAGE:
%       [MRSCont] = osp_fitInitialise(MRSCont);
%
%   INPUTS:
%       MRSCont     = Osprey MRS data container.
%
%   OUTPUTS:
%       MRSCont     = Osprey MRS data container.
%
%   AUTHOR:
%       Dr. Georg Oeltzschner (Johns Hopkins University, 2019-02-24)
%       goeltzs1@jhmi.edu
%
%   HISTORY:
%       2019-02-24: First version of the code.


% The workflow will differ depending on whether we fit entirely within
% Osprey, or whether we are wrapping the LCModel binaries.
switch MRSCont.opts.fit.method
    
    % ------ OPTION OSPREY -----
    case 'Osprey'
        
        
        % Find the right basis set (provided as *.mat file in Osprey basis set
        % format)
        if ~(isfield(MRSCont.opts.fit,'basisSetFile') && ~isempty(MRSCont.opts.fit.basisSetFile))
            
            % Extract TE, B0, and sequence from first dataset
            te = num2str(MRSCont.raw{1}.te);
            Bo = MRSCont.raw{1}.Bo;
            if (Bo >= 2.8 && Bo < 3.1)
                Bo = '3T';
            else
                Bo = '7T';
            end
            seq = lower(MRSCont.raw{1}.seq);
            seq = seq(~ismember(seq, char([10 13]))); % remove return or carriage return
            
            ext = 0; % Set external flag to zero
            
            if strcmp(MRSCont.vendor,'GE') % Still need to find a way to destinguish GE sequences
                seq = 'press';
            end
            if contains(seq,'gaba_par') || contains(seq,'gaba par')
                seq = 'press';
            end
            if contains(seq,'press')
                seq = 'press';
            end
            if contains(seq,'slaser')
                seq = 'slaser';
            end
            
            if ~strcmp(seq,'press') && ~strcmp(seq,'slaser') %Unable to find the localization type we will assume it is PRESS
                seq = 'press';
            end
            
            if MRSCont.flags.isUnEdited
                switch MRSCont.vendor
                    case 'Philips'
                        MRSCont.opts.fit.basisSetFile        = which(['fit/basissets/' Bo '/philips/unedited/' seq '/' te '/basis_philips_' seq te '.mat']);
                    case 'GE'
                        MRSCont.opts.fit.basisSetFile        = which(['fit/basissets/' Bo '/ge/unedited/' seq '/' te '/basis_ge_' seq te '.mat']);
                    case 'Siemens'
                        MRSCont.opts.fit.basisSetFile        = which(['fit/basissets/' Bo '/siemens/unedited/' seq '/' te '/basis_siemens_' seq te '.mat']);
                end
            elseif MRSCont.flags.isMEGA
                editTarget = lower(MRSCont.opts.editTarget{1});
                switch MRSCont.vendor
                    case 'Philips'
                        MRSCont.opts.fit.basisSetFile        = which(['fit/basissets/' Bo '/philips/mega/' seq '/' editTarget te '/basis_philips_megapress_' editTarget te '.mat']);
                    case 'GE'
                        MRSCont.opts.fit.basisSetFile        = which(['fit/basissets/' Bo '/ge/mega/' seq '/' editTarget te '/basis_ge_megapress_' editTarget te '.mat']);
                    case 'Siemens'
                        MRSCont.opts.fit.basisSetFile        = which(['fit/basissets/' Bo '/siemens/mega/' seq '/' editTarget te '/basis_siemens_megapress_' editTarget te '.mat']);
                end
            elseif MRSCont.flags.isHERMES
                editTarget1 = lower(MRSCont.opts.editTarget{1});
                editTarget2 = lower(MRSCont.opts.editTarget{2});
                switch MRSCont.vendor
                    case 'Philips'
                        MRSCont.opts.fit.basisSetFile        = which(['fit/basissets/' Bo '/siemens/hermes/' editTarget1 editTarget2 '/basis_siemens_hermes.mat']);
                    case 'GE'
                        MRSCont.opts.fit.basisSetFile        = which(['fit/basissets/' Bo '/siemens/hermes/' editTarget1 editTarget2 '/basis_siemens_hermes.mat']);
                    case 'Siemens'
                        MRSCont.opts.fit.basisSetFile        = which(['fit/basissets/' Bo '/siemens/hermes/' editTarget1 editTarget2 '/basis_siemens_hermes.mat']);
                end
            elseif MRSCont.flags.isHERCULES
                switch MRSCont.vendor
                    case 'Philips'
                        MRSCont.opts.fit.basisSetFile        = which(['fit/basissets/' Bo '/philips/hercules-press/basis_philips_hercules-press.mat']);
                    case 'GE'
                        MRSCont.opts.fit.basisSetFile        = which(['fit/basissets/' Bo '/philips/hercules-press/basis_philips_hercules-press.mat']);
                    case 'Siemens'
                        MRSCont.opts.fit.basisSetFile        = which(['fit/basissets/' Bo '/siemens/hercules-press/basis_siemens_hercules-press.mat']);
                end
            end
        else
            ext = 1;
        end
        % Clear existing basis set
        MRSCont.fit.basisSet = [];
        
        % Check if automated basis set pick worked, otherwise the basis set from
        % the user folder is loaded.
        if isempty(MRSCont.opts.fit.basisSetFile)
            addpath( which('fit/basissets'));
            MRSCont.opts.fit.basisSetFile = which('fit/basissets/user/BASIS_noMM.mat');
            if isempty(MRSCont.opts.fit.basisSetFile)
                error('There is no appropriate basis set to model your data. Please supply a sufficient basis set in Osprey .mat format in the fit/basissets/user/BASIS_MM.mat file! ');
            else
                ext = 1;
            end
        end
        
        % Load the specified basis set or the user basis set file
        basisSet = load(MRSCont.opts.fit.basisSetFile);
        basisSet = basisSet.BASIS;
        
        % Generate the list of basis functions that are supposed to be included in
        % the basis set
        if ext
            % Sort basis set file according to Osprey conventions
            basisSet = fit_sortBasisSet(basisSet);
            
            % To do: Interface with interactive user input
            metabList = fit_createMetabList(MRSCont.opts.fit.includeMetabs);
            % Collect MMfit flag from the options determined in the job file
            fitMM = MRSCont.opts.fit.fitMM;
            if fitMM == 1 && metabList.MMexp == 1
                fitMM = 2;
            end
            % Create the modified basis set
            basisSet = fit_selectMetabs(basisSet, metabList, fitMM);
        else
            % To do: Interface with interactive user input
            basisSet = fit_sortBasisSet(basisSet);
            metabList = fit_createMetabList(MRSCont.opts.fit.includeMetabs);
            % Collect MMfit flag from the options determined in the job file
            fitMM = MRSCont.opts.fit.fitMM;
            if fitMM == 1 && metabList.MMexp == 1
                fitMM = 2;
            end
            % Create the modified basis set
            basisSet = fit_selectMetabs(basisSet, metabList, fitMM);
        end
        
        % Determine the scaling factor between data and basis set for each dataset
        for kk = 1:MRSCont.nDatasets
            if ~MRSCont.flags.isMRSI  && ~MRSCont.flags.isPRIAM
                MRSCont.fit.scale{kk} = max(real(MRSCont.processed.A{kk}.specs)) / max(max(max(real(basisSet.specs))));
            else
                MRSCont.fit.scale{kk} = max(max(max(real(MRSCont.processed.A{kk}.specs)))) / max(max(max(real(basisSet.specs))));
            end
        end
        
        
        % Save the modified basis set
        MRSCont.fit.basisSet = basisSet;
        
        
        
    % ------ OPTION LCMODEL -----    
    case 'LCModel'
        
        % For now, the user needs to EXPLICITLY specify a basis set. We
        % will weave in the automatic selection as we convert more and more
        % basis sets to LCModel format.
        % (GO 07/08/2021)
        if ~(isfield(MRSCont.opts.fit,'basisSetFile') && ~isempty(MRSCont.opts.fit.basisSetFile))
            error('For LCModel fitting, please explicitly specify a .BASIS file in the job file (opts.fit.basisSetFile = ''FILE'').');
        end
        
        % Read in the user-supplied control file (if there is one)
        if isfield(MRSCont.opts.fit,'controlFile') 
            if ~isempty(MRSCont.opts.fit.controlFile)
                % Load all control parameters
                LCMparam = osp_readlcm_control(MRSCont.opts.fit.controlFile);
                
                % Make some changes to the control file that will apply to
                % ALL control files
                LCMparam = osp_editControlParameters(LCMparam, 'filraw', '');
                LCMparam = osp_editControlParameters(LCMparam, 'filtab', '');
                LCMparam = osp_editControlParameters(LCMparam, 'filps', '');
                LCMparam = osp_editControlParameters(LCMparam, 'filcsv', '');
                LCMparam = osp_editControlParameters(LCMparam, 'filcoo', '');
                LCMparam = osp_editControlParameters(LCMparam, 'filbas', ['''' MRSCont.opts.fit.basisSetFile '''']);
                LCMparam = osp_editControlParameters(LCMparam, 'savdir', '');
                LCMparam = osp_editControlParameters(LCMparam, 'lcsi_sav_1', '');
                LCMparam = osp_editControlParameters(LCMparam, 'lcsi_sav_2', '');
                LCMparam = osp_editControlParameters(LCMparam, 'filcsi_sav_1', '');
                LCMparam = osp_editControlParameters(LCMparam, 'filcsi_sav_2', '');
                LCMparam = osp_editControlParameters(LCMparam, 'ndslic', '');
                LCMparam = osp_editControlParameters(LCMparam, 'ndrows', '');
                LCMparam = osp_editControlParameters(LCMparam, 'ndcols', '');
                LCMparam = osp_editControlParameters(LCMparam, 'islice', '');
                LCMparam = osp_editControlParameters(LCMparam, 'irowst', '');
                LCMparam = osp_editControlParameters(LCMparam, 'irowen', '');
                LCMparam = osp_editControlParameters(LCMparam, 'icolst', '');
                LCMparam = osp_editControlParameters(LCMparam, 'icolen', '');
                
                % The LPS parameter appears to break the postscript file
                % production for some weird reason, remove it here.
                LCMparam = osp_editControlParameters(LCMparam, 'lps', '');
                
                
                % Now loop over all datasets
                for kk = 1:MRSCont.nDatasets
                    LCMparam = osp_editControlParameters(LCMparam, 'srcraw', ['''' MRSCont.files{kk} '''']);
                    
                    % Loop over number of diffusion-weighted spectra and
                    % create a control file for each spectrum that needs to
                    % be fit
                    nDW = length(MRSCont.opts.fit.lcmodel.outfileA{kk});
                    for dd = 1:nDW
                        
                        % Write control file
                        MRSCont = osp_writelcm_control(MRSCont, kk, dd, 'A', LCMparam);
                    end
                    
                end
                
            else
                error('The field ''opts.fit.controlFile'' in the job file is specified, but empty.')
            end
            
        else
            % If the field does not exist, write default control parameters
            for kk = 1:MRSCont.nDatasets
                LCMparam = osp_lcmcontrol_params(MRSCont.flags.isMEGA);
                MRSCont       = osp_writelcm_control(MRSCont, kk, 'A', LCMparam);
            end
        end
        

        
end

end