
%% CT Image Processing and Concentration Map Generation
%
% This script processes raw CT scan data from tracer/core-flooding
% experiments and generates normalized concentration maps for each scan.
%
% The workflow imports reference scans and experimental scans, applies
% image normalization and cropping, computes concentration fields using
% reference states, and stores the resulting image stacks in HDF5 format
% for efficient downstream analysis.
%
% Workflow
% --------
% 1. Read experiment configuration and metadata from Excel files.
% 2. Load initial and final reference CT scans.
% 3. Load experimental CT scan runs.
% 4. Import scanner metadata and acquisition logs (.pca, .pcp, .pcj).
% 5. Normalize raw CT images to the range [0,1].
% 6. Crop images to the region containing the core sample.
% 7. Compute normalized concentration images using:
%
%        C = (Iexp - Iref_init) ./ (Iref_final - Iref_init)
%
% 8. Save concentration image stacks to HDF5 files.
%
% Input Files
% -----------
% inputCTExpConfig.xlsx
%     Repository configuration file containing:
%       - Input metadata filename
%       - Import directory
%       - Export directory
%
% Experiment input spreadsheet
%     Imported through IMPORT_INPUTCTEXP and contains:
%       - Experiment identifiers
%       - Scan paths
%       - Reference scan locations
%       - Experimental run locations
%
% CT scan folders
%     Each folder may contain:
%       - *.tif : Projection or reconstructed images
%       - *.pca : Scanner/reconstruction settings
%       - *.pcp : Acquisition log data
%       - *.pcj : Reconstruction output data
%
% Outputs
% -------
% One HDF5 file is generated for each experiment:
%
%     <ExperimentKey>.h5
%
% containing:
%
%     /exp/run_xx/conc
%
% where run_xx is the experimental run number and conc is a 3-D image
% stack with dimensions:
%
%     [Nx Ny Nimages]
%
% corresponding to normalized concentration maps.
%
% Dependencies
% ------------
% Required custom functions:
%
%     import_inputCTExp
%     importPCA
%     importPCP
%     importPCJ
%     importImages
%     normImage
%     cropImage
%     satImage
%
% Required MATLAB Toolboxes:
%
%     Image Processing Toolbox
%
% Notes
% -----
% - Reference and experimental scans must contain the same number of
%   projections/images.
% - Crop coordinates are imported from:
%
%       crop_xCoords.mat
%
% - Existing HDF5 output files are automatically overwritten.
% - Concentration values may exceed the physical range [0,1] due to image
%   noise or reference-image uncertainty.


%% IMPORT input

addpath('functions/');

% Introduce name of input and desired output folder name

inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

filenameExp = inputFileConfig.inputFileName{:};

pathImportAll = inputFileConfig.importPath{:}; % Path for OUTPUT
pathExportAll = inputFileConfig.exportPath{:}; % Path for OUTPUT
mkdir(pathExportAll); % Create directory for output

%% IMPORT, NORM and CROP data

filedataExp = import_inputCTExp(filenameExp); % import input to a local variable

% Capture init ref data folder
refInitFolderContent = dir(filedataExp.path+filedataExp.CT_data_ref_init); % Xe
refInitFolderContent = refInitFolderContent([refInitFolderContent.isdir] & ~startsWith({refInitFolderContent.name},'.'));
refInitFolderName = refInitFolderContent.name;

% Capture final ref data folder
refFinalFolderContent = dir(filedataExp.path+filedataExp.CT_data_ref_final); % He
refFinalFolderContent = refFinalFolderContent([refFinalFolderContent.isdir] & ~startsWith({refFinalFolderContent.name},'.'));
refFinalFolderName = refFinalFolderContent.name;

% Capture exp data folder
expFolderContent = dir(filedataExp.path+filedataExp.CT_data_exp); % exp
expFolderContent = expFolderContent([expFolderContent.isdir] & ~startsWith({expFolderContent.name},'.'));
expFolderName = {expFolderContent.name}';
expFolderPath = {expFolderContent.folder};

for i = 1:length(filedataExp.Key)

    % CT init ref
    refInitFolderPathCT = fullfile(refInitFolderContent.folder, refInitFolderName);
        % pca
        refInitpcaFiles = dir(fullfile(refInitFolderPathCT, '*.pca'));
        expCTData.(filedataExp.Key(i)).refInit.pca = importPCA(refInitpcaFiles);
        % pcp
        refInitpcpFiles = dir(fullfile(refInitFolderPathCT, '*.pcp'));
        expCTData.(filedataExp.Key(i)).refInit.pcp = importPCP(refInitpcpFiles);
        % CTimages folder 
        refInitimgFiles = dir(fullfile(refInitFolderPathCT, '*.tif'));
        
    nn_refInit = height(expCTData.(filedataExp.Key(i)).refInit.pcp);

    % CT final ref
    refFinalFolderPathCT = fullfile(refFinalFolderContent.folder, refFinalFolderName);
        % pcp
        refFinalpcpFiles = dir(fullfile(refFinalFolderPathCT, '*.pcp'));
        expCTData.(filedataExp.Key(i)).refFinal.pcp = importPCP(refFinalpcpFiles);
        refFinalimgFiles = dir(fullfile(refFinalFolderPathCT, '*.tif'));

    nn_refFinal = height(expCTData.(filedataExp.Key(i)).refFinal.pcp);

    % HDF5 file
    HDF5filename = fullfile(pathExportAll, filedataExp.Key(i) + ".h5");
    if isfile(HDF5filename)
        delete(HDF5filename);
    end

    for j = 1:length(expFolderName)
        expFolderPathCT = fullfile(expFolderPath{j}, expFolderName{j});
        run_name = "run_" + sprintf('%02d', j);
            % pca
            exppcaFiles = dir(fullfile(expFolderPathCT, '*.pca'));
            expCTData.(filedataExp.Key(i)).exp.(run_name).pca = importPCA(exppcaFiles);
            % pcj 
            exppcjFiles = dir(fullfile(expFolderPathCT, '*.pcj'));
            expCTData.(filedataExp.Key(i)).exp.(run_name).pcj = importPCJ(exppcjFiles);
            % pcp
            exppcpFiles = dir(fullfile(expFolderPathCT, '*.pcp'));
            expCTData.(filedataExp.Key(i)).exp.(run_name).pcp = importPCP(exppcpFiles);
            expimgFiles = dir(fullfile(expFolderPathCT, '*.tif'));

        nn_exp = height(expCTData.(filedataExp.Key(i)).exp.(run_name).pcp); % per run

        % Check number of imaging in reference and exp are same
        if nn_refInit ~= nn_refFinal
            error("Mismatch: initial reference (%d) vs final references (%d) projections", nn_refInit, nn_refFinal);
        elseif nn_refInit ~= nn_exp
            error("Mismatch: initial reference (%d) vs experiment run_%02d (%d) projections", nn_refInit, j, nn_exp);
        end

        % Create function to take parameters to crop!!!
        % rawImage = importImages(imgFiles);  % expCTData.(filedataExp.Key(i)).refInit.RawCT = importImages(imgFiles);
        % croppedImage = cell(size(rawImage));
        % % Crop params
        % imageRefCrop = rawImage{1};
        % pixDist = 70;
        % partsScanned = 5; % Parts scanned: from left to middle: air, CH. water,sleeve, core
        % % crop_xCoords = findcropCore_xAxis(imageRefCrop,pixDist,partsScanned-1);
        % % crop_xCoords = [crop_xCoords(1)+60;crop_xCoords(2)-60];
        % load(pathImportAll+ "crop_xCoords.mat");
        % crop_yCoords = [1;length(imageRefCrop)];    
        load(pathImportAll+ "crop_xCoords.mat");
        DimY = expCTData.(filedataExp.Key(i)).refInit.pca.Image.DimY;  
        crop_yCoords = [1;DimY]; 

        HDF5created = false; % flag
        HDF5dataPath = ['/exp/' char(run_name) '/conc'];  % structured path

        for k = 1:nn_exp
            % Collect each image and save it in HDF5 one by one

            % refInit
            % Raw, normalized and cropped CT images
            refInitrawImage = importImages(refInitimgFiles,k);  % expCTData.(filedataExp.Key(i)).refInit.RawCT = importImages(imgFiles);
            refInitrawImage = normImage(refInitrawImage);
            refInitcroppedImage = cropImage(refInitrawImage,crop_xCoords, crop_yCoords); % minImage

            % refFinal
            % Raw, normalized and cropped CT images
            refFinalrawImage = importImages(refFinalimgFiles,k);  % expCTData.(filedataExp.Key(i)).refInit.RawCT = importImages(imgFiles);
            refFinalrawImage = normImage(refFinalrawImage);
            refFinalcroppedImage = cropImage(refFinalrawImage,crop_xCoords, crop_yCoords); % maxImage

            % exp run k
            % Raw, normalized and cropped CT images
            exprawImage = importImages(expimgFiles,k);  % expCTData.(filedataExp.Key(i)).exp.(run_name).RawCT = importImages(imgFiles);
            exprawImage = normImage(exprawImage);
            expcroppedImage = cropImage(exprawImage,crop_xCoords, crop_yCoords);
            concImage = satImage(expcroppedImage,refInitcroppedImage,refFinalcroppedImage); % arguments (exp, min,max)

            % HDF5 params
            [nx, ny] = size(concImage);

            if ~HDF5created 
                h5create(HDF5filename, HDF5dataPath, [nx ny nn_exp], ...
                    'Datatype', 'single', ...
                    'ChunkSize', [nx ny 1], ...
                    'Deflate', 5);
                HDF5created = true;
            end
          
            h5write(HDF5filename, HDF5dataPath, single(concImage), [1 1 k], [nx ny 1]);       
        end
    end
end

