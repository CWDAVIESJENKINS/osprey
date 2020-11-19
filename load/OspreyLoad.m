function [MRSCont] = OspreyLoad(MRSCont)
%% [MRSCont] = OspreyLoad(MRSCont)
%   This function loads the raw MRS data from all major vendors.
%   Data is read from the provided input filenames. It is shaped according 
%   to the type of sequence (un-edited data, MEGA-edited (ON/OFF), 
%   HERMES/HERCULES (A/B/C/D), etc.).
%
%   USAGE:
%       MRSCont = OspreyLoad(MRSCont);
%
%   INPUTS:
%       MRSCont     = Osprey MRS data container.
%
%   OUTPUTS:
%       MRSCont     = Osprey MRS data container.
%
%   AUTHOR:
%       Dr. Georg Oeltzschner (Johns Hopkins University, 2019-02-19)
%       goeltzs1@jhmi.edu
%   
%   CREDITS:    
%       This code is based on numerous functions from the FID-A toolbox by
%       Dr. Jamie Near (McGill University)
%       https://github.com/CIC-methods/FID-A
%       Simpson et al., Magn Reson Med 77:23-33 (2017)
%
%   HISTORY:
%       2019-02-19: First version of the code.

% Set flags
if ~isempty(MRSCont.files)
    MRSCont.flags.hasFiles = 1;
end
if ~isempty(MRSCont.files_mm)       %re_mm adding functionality to load MM data
    MRSCont.flags.hasMM = 1;        %re_mm 
end                                 %re_mm
if ~isempty(MRSCont.files_ref)
    MRSCont.flags.hasRef = 1;
end
if ~isempty(MRSCont.files_w)
    MRSCont.flags.hasWater = 1;
end

% Version check and updating log file
MRSCont.ver.CheckLoad        = '1.0.0 Load';
outputFolder = MRSCont.outputFolder;
fileID = fopen(fullfile(outputFolder, 'LogFile.txt'),'a+');
fprintf(fileID,['Timestamp %s ' MRSCont.ver.Osp '  ' MRSCont.ver.CheckLoad '\n'], datestr(now,'mmmm dd, yyyy HH:MM:SS'));
fclose(fileID);

% Determine data types
[MRSCont, retMsg] = osp_detDataType(MRSCont);

% Determine number of datasets
MRSCont.nDatasets = length(MRSCont.files);

% Load raw data (call loaders depending on file type)
switch MRSCont.vendor
    case 'Siemens'
        switch MRSCont.datatype
            case 'TWIX'
                [MRSCont] = osp_LoadTwix(MRSCont);
            case 'RDA'
                [MRSCont] = osp_LoadRDA(MRSCont);
            case 'DICOM'
                [MRSCont] = osp_LoadDICOM(MRSCont);
            otherwise
                msg = 'Data type not supported. Please contact the Osprey team (gabamrs@gmail.com).';
                fprintf(fileID,msg);
                error(msg);
        end
    case 'Philips'
        switch MRSCont.datatype
            case 'SDAT'
                [MRSCont] = osp_LoadSDAT(MRSCont);
            case 'DATA'
                [MRSCont] = osp_LoadDATA(MRSCont);
            case 'RAW'
                error('Support for Philips RAW/LAB/SIN files coming soon!');
                %[MRSCont] = osp_LoadRAW(MRSCont);
            otherwise
                msg = 'Data type not supported. Please contact the Osprey team (gabamrs@gmail.com).';
                fprintf(fileID,msg);
                error(msg);
        end
    case 'GE'
        switch MRSCont.datatype
            case 'P'
                [MRSCont] = osp_LoadP(MRSCont);
            otherwise
                msg = 'Data type not supported. Please contact the Osprey team (gabamrs@gmail.com).';
                fprintf(fileID,msg);
                error(msg);
        end
    otherwise
        msg = 'Vendor not supported. Please contact the Osprey team (gabamrs@gmail.com).';
        fprintf(fileID,msg);
        error(msg);
end

% Perform coil combination (SENSE-based reconstruction if PRIAM flag set)
if ~MRSCont.flags.isPRIAM
    if sum(strcmp(MRSCont.datatype, {'DATA', 'RAW', 'P'})) == 1
        [MRSCont] = osp_combineCoils(MRSCont);
    else
        if ~strcmp(MRSCont.datatype, 'TWIX')
            fprintf('Data type %s %s is already coil-combined.\n', MRSCont.vendor, MRSCont.datatype);
        end
    end
elseif MRSCont.flags.isPRIAM
    [MRSCont] = osp_senseRecon(MRSCont);
end

%% Clean up and save
% Set exit flags and version
MRSCont.flags.didLoadData           = 1;
MRSCont.ver.Load             = '1.0.0 Load';


% Save the output structure to the output folder
% Determine output folder
outputFolder    = MRSCont.outputFolder;
outputFile      = MRSCont.outputFile;
if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end


% Optional: Create all pdf figures
if MRSCont.opts.savePDF
    for kk = 1 : MRSCont.nDatasets
        osp_plotModule(MRSCont, 'OspreyLoad', kk, 'mets');
        if MRSCont.flags.hasRef
            osp_plotModule(MRSCont, 'OspreyLoad', kk, 'ref');
        end
        if MRSCont.flags.hasWater
            osp_plotModule(MRSCont, 'OspreyLoad', kk, 'w');
        end
        if MRSCont.flags.hasMM
            osp_plotModule(MRSCont, 'OspreyLoad', kk, 'mm');
        end
    end
end

% Gather some more information from the processed data;
if  MRSCont.flags.isGUI
    MRSCont.flags.isGUI = 0;
    save(fullfile(outputFolder, outputFile), 'MRSCont','-v7.3');
    MRSCont.flags.isGUI = 1;
else
   save(fullfile(outputFolder, outputFile), 'MRSCont','-v7.3');
end

end