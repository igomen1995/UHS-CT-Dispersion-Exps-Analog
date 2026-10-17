
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
% 1. Read experiment configuration (one row per experiment) from
%    inputCTExpConfig.xlsx.
% 2. For each experiment: read metadata and locate reference and
%    experimental scan folders.
% 3. (Optional section) Plot the crop profile for j = 1, k = 1 of each
%    experiment, without touching the HDF5 files.
% 4. For each experiment and run:
%       - import scanner metadata and acquisition logs (.pca, .pcp, .pcj)
%       - normalize raw CT images to [0,1]
%       - detect a fixed-width crop window per projection, centered on
%         the core
%       - compute normalized concentration images:
%
%           C = (Iexp - Iref_init) ./ (Iref_final - Iref_init)
%
%       - save concentration image stacks to HDF5.
%
% Input Files
% -----------
% inputCTExpConfig.xlsx
%     One row per experiment, containing:
%       - inputFileName : experiment input spreadsheet
%       - importPath    : import directory
%       - exportPath    : export directory
%
% Experiment input spreadsheet (read by IMPORT_INPUTCTEXP)
%       - Experiment identifier (Key)
%       - Scan paths, reference scan and run locations
%
% CT scan folders
%       - *.tif : projection images
%       - *.pca : scanner/reconstruction settings
%       - *.pcp : acquisition log data
%       - *.pcj : reconstruction output data
%
% Outputs (per experiment, in its exportPath)
% -------
%     <ExperimentKey>.h5            /exp/run_xx/conc, [Nx Ny Nimages]
%     cropCoords_<ExperimentKey>.txt  j, k, xmin, xmax for every image
%     cropProfile_<Key>_run_01_k001.(png|pdf|fig)  crop profile figure
%     conc_<Key>_run_xx.mp4         (optional) movie of concentration maps
%
% Dependencies
% ------------
%     import_inputCTExp, importPCA, importPCP, importPCJ, importImages,
%     normImage, cropImage, satImage, findcropCore_xAxis,
%     findCropWindow_xAxis, plotCropProfile
%     Image Processing Toolbox, Curve Fitting Toolbox (smooth)
%
% Notes
% -----
% - Reference and experimental scans must contain the same number of
%   projections/images.
% - Crop window is detected per projection on the initial (Xe) reference
%   image and applied to refInit, refFinal and the experiment image.
% - Existing HDF5 output files are overwritten when writeH5 = true.
% - Concentration values may exceed [0,1] due to noise or
%   reference-image uncertainty.


%% IMPORT input

CT_setupPaths;

% Introduce name of input and desired output folder name

inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

% Crop parameters (shared by the plot and processing sections)
pixDist      = 70;
partsScanned = 5;      % air, core holder, water, sleeve, core
cropWidth    = 1400;

nExp = height(inputFileConfig);

cropMethod = 'layers';     % 'layers' (kink) or 'peaks' (old)
layerOpts  = struct();     % options of findLayerBoundaries_xAxis, e.g. struct('cornerPx',15)

%% IMPORT, NORM and CROP data

for i = 1%:nExp

    filenameExp = inputFileConfig.inputFileName{i};
    pathExportAll = inputFileConfig.exportPath{i}; % Path for OUTPUT
    % Create directory for output
    if ~isfolder(pathExportAll)
        mkdir(pathExportAll);
    end
    
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

    % CT init ref
    refInitFolderPathCT = fullfile(refInitFolderContent.folder, refInitFolderName);
        % pca
        refInitpcaFiles = dir(fullfile(refInitFolderPathCT, '*.pca'));
        expCTData.(filedataExp.Key).refInit.pca = importPCA(refInitpcaFiles);
        % pcp
        refInitpcpFiles = dir(fullfile(refInitFolderPathCT, '*.pcp'));
        expCTData.(filedataExp.Key).refInit.pcp = importPCP(refInitpcpFiles);
        % CTimages folder 
        refInitimgFiles = dir(fullfile(refInitFolderPathCT, '*.tif'));
        
    nn_refInit = height(expCTData.(filedataExp.Key).refInit.pcp);

    % CT final ref
    refFinalFolderPathCT = fullfile(refFinalFolderContent.folder, refFinalFolderName);
        % pcp
        refFinalpcpFiles = dir(fullfile(refFinalFolderPathCT, '*.pcp'));
        expCTData.(filedataExp.Key).refFinal.pcp = importPCP(refFinalpcpFiles);
        refFinalimgFiles = dir(fullfile(refFinalFolderPathCT, '*.tif'));

    nn_refFinal = height(expCTData.(filedataExp.Key).refFinal.pcp);

    % % HDF5 file
    % HDF5filename = fullfile(pathExportAll, filedataExp.Key + ".h5");
    % if isfile(HDF5filename)
    %     delete(HDF5filename);
    % end

    cropLogFile = fullfile(pathExportAll, "cropCoords_" + filedataExp.Key + ".txt");
    fidCrop = fopen(cropLogFile, 'w');
    fprintf(fidCrop, '%s\t%s\t%s\t%s\n', 'j', 'k', 'xmin', 'xmax');

    for j = 1%:length(expFolderName)
        expFolderPathCT = fullfile(expFolderPath{j}, expFolderName{j});
        run_name = "run_" + sprintf('%02d', j);
            % pca
            exppcaFiles = dir(fullfile(expFolderPathCT, '*.pca'));
            expCTData.(filedataExp.Key).exp.(run_name).pca = importPCA(exppcaFiles);
            % pcj 
            exppcjFiles = dir(fullfile(expFolderPathCT, '*.pcj'));
            expCTData.(filedataExp.Key).exp.(run_name).pcj = importPCJ(exppcjFiles);
            % pcp
            exppcpFiles = dir(fullfile(expFolderPathCT, '*.pcp'));
            expCTData.(filedataExp.Key).exp.(run_name).pcp = importPCP(exppcpFiles);
            expimgFiles = dir(fullfile(expFolderPathCT, '*.tif'));

        nn_exp = height(expCTData.(filedataExp.Key).exp.(run_name).pcp); % per run

        % Check number of imaging in reference and exp are same
        if nn_refInit ~= nn_refFinal
            error("Mismatch: initial reference (%d) vs final references (%d) projections", nn_refInit, nn_refFinal);
        elseif nn_refInit ~= nn_exp
            error("Mismatch: initial reference (%d) vs experiment run_%02d (%d) projections", nn_refInit, j, nn_exp);
        end

        % Crop params: fixed width, but the window is re-centered on the
        % core for every projection, since the rotation axis is not
        % centered in the frame and the core's x-position shifts as it
        % rotates.
        DimY = expCTData.(filedataExp.Key).refInit.pca.Image.DimY;  
        crop_yCoords = [1;DimY]; 

        % HDF5created = false; % flag
        % HDF5dataPath = ['/exp/' char(run_name) '/conc'];  % structured path
        
        % % Uncomment to see intanstaneous movie
        % fig = figure('Color','w','Position',[50 50 700 800]);
        % ax  = axes(fig);
        % v = VideoWriter(fullfile(pathExportAll, "conc_" + filedataExp.Key(i) + "_" + run_name), 'MPEG-4');
        % v.FrameRate = 20;
        % open(v);

        Iair_refInit  = findIair(importImages(refInitimgFiles,  1));
        Iair_refFinal = findIair(importImages(refFinalimgFiles, 1));
        Iair_exp = findIair(importImages(expimgFiles, 1));     % I0 of THIS run
        
        fprintf('%s %s  I0: refInit %.4g | refFinal %.4g | exp %.4g\n', ...
            filedataExp.Key, run_name, Iair_refInit, Iair_refFinal, Iair_exp);

        for k = 1:nn_exp
            % Collect each image and save it in HDF5 one by one

            % refInit
            % Raw, normalized and cropped CT images
            refInitrawImage = importImages(refInitimgFiles,k);  % expCTData.(filedataExp.Key(i)).refInit.RawCT = importImages(imgFiles);
            refInitrawImage = normImage(refInitrawImage,Iair_refInit);
            
            % Per-projection crop window, centered on the core as it
            % appears at THIS rotation angle; refInit/refFinal share the
            % same angle index k, so the same window applies to all three
            if strcmp(cropMethod, 'layers')
                [crop_xCoords_k, ~, coreTrans_k] = findCropWindow_layers(refInitrawImage, cropWidth, layerOpts);
            else
                [crop_xCoords_k, pv_sort_parts_k] = findCropWindow_xAxis(refInitrawImage, pixDist, partsScanned-1, cropWidth);
            end
            fprintf('  k=%d: crop_xCoords_k = [%d %d]\n', k, crop_xCoords_k(1), crop_xCoords_k(2));
            fprintf(fidCrop, '%d\t%d\t%d\t%d\n', j, k, crop_xCoords_k(1), crop_xCoords_k(2));

            refInitcroppedImage = cropImage(refInitrawImage,crop_xCoords_k, crop_yCoords); % minImage
            
            % refFinal
            % Raw, normalized and cropped CT images
            refFinalrawImage = importImages(refFinalimgFiles,k);  % expCTData.(filedataExp.Key(i)).refInit.RawCT = importImages(imgFiles);
            refFinalrawImage = normImage(refFinalrawImage,Iair_refFinal);
            refFinalcroppedImage = cropImage(refFinalrawImage,crop_xCoords_k, crop_yCoords); % maxImage

            % exp run k
            % Raw, normalized and cropped CT images
            exprawImage = importImages(expimgFiles,k);  % expCTData.(filedataExp.Key(i)).exp.(run_name).RawCT = importImages(imgFiles);
            exprawImage = normImage(exprawImage,Iair_exp);
            expcroppedImage = cropImage(exprawImage,crop_xCoords_k, crop_yCoords);
            concImage = satImage(expcroppedImage,refInitcroppedImage,refFinalcroppedImage); % arguments (exp, min,max)
            
            % % Uncomment to see intanstaneous movie
            % cla(ax)
            % imagesc(ax, concImage)            % columns -> x pixel, rows -> y pixel
            % axis(ax, 'image')
            % colormap(ax, turbo)
            % clim(ax, [0 1])
            % colorbar(ax)
            % xlabel(ax, 'x (pixel)')
            % ylabel(ax, 'y (pixel)')
            % title(ax, sprintf('%s %s  image %03d', filedataExp.Key(i), run_name, k), 'Interpreter','none')
            % drawnow
            % writeVideo(v, getframe(fig));

            % % HDF5 params
            % [nx, ny] = size(concImage);
            % 
            % if ~HDF5created 
            %     h5create(HDF5filename, HDF5dataPath, [nx ny nn_exp], ...
            %         'Datatype', 'single', ...
            %         'ChunkSize', [nx ny 1], ...
            %         'Deflate', 5);
            %     HDF5created = true;
            % end
            % 
            % h5write(HDF5filename, HDF5dataPath, single(concImage), [1 1 k], [nx ny 1]);       
        end
        % close(v)
    end
    fclose(fidCrop);
end

%% PLOT crop profile (j = 1, k = 1) for each experiment - no HDF5
% Run the "IMPORT input" section first, then run this section on its own.
% The crop window does not depend on the run: it is detected on the Xe reference
% (refInit) at projection kPlot. jPlot only goes into the file name.
% Layers at k = 1 (outside -> in): air (thin, left) | carbon fibre | aluminium liner |
% confining fluid | sleeve | (heat-shrink, not resolved) | core
%
% Figure 1: plotTransitionStages - EVERY peak/valley findcropCore_xAxis finds and
%           what happens to it (removed by spacing, merged, outer part removed
%           by partsNoCore, core). Numbers = rows of pv_sort_parts.
% Figure 2: plotCropProfile - layers shaded and crop window of cropMethod.
% Try several pixDistTol values in pixDistTest to see which transitions survive.
% cropMethod = 'layers' : core edge from findCropWindow_layers (Al-liner minimum ->
%              fluid maximum -> sharpest corner = sleeve/core; no peak counting)
% cropMethod = 'peaks'  : core edge from findCropWindow_xAxis (peaks/valleys + partsNoCore)
% Both are computed and printed for every k in kPlot, so you can compare them.

% Self-contained: if the IMPORT input section was not run, do it here
if ~exist('nExp','var') || ~exist('inputFileConfig','var')
    CT_setupPaths;
    inputFileConfig = readtable('inputCTExpConfig.xlsx');
    nExp = height(inputFileConfig);
end
if ~exist('pixDist','var'),      pixDist      = 70;   end
if ~exist('partsScanned','var'), partsScanned = 5;    end   % air, core holder, water, sleeve, core
if ~exist('cropWidth','var'),    cropWidth    = 1400; end

jPlot = 1;                 % run used in the file name
kPlot = 1;                 % projection(s) to test, e.g. [1 100 200 300 400]
showStages  = true;        % plotTransitionStages figures (peaks method)
pixDistTest = pixDist;     % e.g. [pixDist, 20, 50, 100] to compare spacing filters
partsTest   = partsScanned-1;   % partsNoCore passed to findCropWindow_xAxis
if ~exist('cropMethod','var'), cropMethod = 'layers';  end
if ~exist('layerOpts','var'),  layerOpts  = struct();  end

for i = 1:nExp
    filenameExp   = inputFileConfig.inputFileName{i};
    pathExportAll = inputFileConfig.exportPath{i};            % path for OUTPUT
    if ~isfolder(pathExportAll)
        mkdir(pathExportAll);
    end

    filedataExp = import_inputCTExp(filenameExp);             % input of THIS experiment
    key = char(filedataExp.Key);

    % Xe reference folder for THIS experiment
    refInitFolderContent = dir(filedataExp.path + filedataExp.CT_data_ref_init);
    refInitFolderContent = refInitFolderContent([refInitFolderContent.isdir] & ...
        ~startsWith({refInitFolderContent.name}, '.'));
    if isempty(refInitFolderContent)
        warning('%s: no Xe reference folder found, skipped.', key);
        continue
    elseif numel(refInitFolderContent) > 1
        warning('%s: %d Xe reference folders found, using "%s".', key, ...
            numel(refInitFolderContent), refInitFolderContent(1).name);
    end
    refInitimgFiles = dir(fullfile(refInitFolderContent(1).folder, refInitFolderContent(1).name, '*.tif'));

    % I0 = max of frame k = 1 (air at the left edge)
    Iair_k1 = findIair(importImages(refInitimgFiles, 1));

    fprintf('\n%s   core edges [left right] and crop, peaks vs layers\n', key);
    fprintf('   k  | peaks core   | layers core  | diff L  R | crop peaks  | crop layers\n');
    for kk = kPlot
        if kk > numel(refInitimgFiles)
            warning('%s: k = %d but only %d projections, skipped.', key, kk, numel(refInitimgFiles));
            continue
        end
        refInitImage = normImage(importImages(refInitimgFiles, kk), Iair_k1);

        % --- old: peaks/valleys + partsNoCore (stage plots for each pixDistTol)
        for pd = pixDistTest
            [cropP, ~, coreP, dbg_k] = findCropWindow_xAxis(refInitImage, pd, partsTest, cropWidth);
            if showStages
                ttl = sprintf('%s  k = %d  pixDistTol = %g  partsNoCore = %d', key, kk, pd, partsTest);
                [figStages, T] = plotTransitionStages(refInitImage, dbg_k, cropP, ttl);
                disp(T(T.part > 0, :));
                baseName = fullfile(pathExportAll, sprintf('cropStages_%s_run_%02d_k%03d_pd%03d', ...
                    key, jPlot, kk, round(pd)));
                exportgraphics(figStages, baseName + ".png", 'Resolution', 300);
                % savefig(figStages, baseName + ".fig");
            end
        end

        % --- new: layer / kink detection
        [cropL, B, coreL] = findCropWindow_layers(refInitImage, cropWidth, layerOpts);

        fprintf('%5d | [%4d %4d]  | [%4d %4d]  | %4d %4d | [%4d %4d] | [%4d %4d]\n', kk, ...
            coreP(1,1), coreP(end,1), coreL(1,1), coreL(end,1), ...
            coreL(1,1) - coreP(1,1), coreL(end,1) - coreP(end,1), ...
            cropP(1), cropP(2), cropL(1), cropL(2));

        % --- Figure 2: layers and crop window of the selected method
        if strcmp(cropMethod, 'layers')
            cropSel = cropL;
            Bsel    = B;                                                  % boundaries used for the crop
        else
            cropSel = cropP;
            Bsel    = findLayerBoundaries_xAxis(refInitImage, coreP, layerOpts);   % layers around the peaks core
        end
        [figProfile, B] = plotCropProfile(refInitImage, cropSel, Bsel, ...
            sprintf('%s  k = %d  crop: %s', key, kk, cropMethod));

        fprintf('        left  edges (air|CF|Al|fluid|sleeve|core): %s\n', mat2str(round(B.edgesL)));
        fprintf('        right edges (air|CF|Al|fluid|sleeve|core): %s\n', mat2str(round(B.edgesR)));

        baseName = fullfile(pathExportAll, sprintf('cropProfile_%s_run_%02d_k%03d_%s', ...
            key, jPlot, kk, cropMethod));
        exportgraphics(figProfile, baseName + ".png", 'Resolution', 600);
        % savefig(figProfile, baseName + ".fig");
    end
end