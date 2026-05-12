% Code description
% 
%
% Workflow
% Loop over one single full scan
% 1 - extract data, take time and angle, and all fileDataExp
% 2 - crop
% 3 - normalize Measured - Xe / He - Xe or run estimated density based on
% calibration, different gray image average or distribution correspond to a
% certain density
% 4 - save data

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

%% Extract data from images

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

% BT extract
BTlinesBefore = table(); 
BTcore = table();
expCTData = struct();

for i = 1:length(filedataExp.Key)

    % Image
    HDF5filename = fullfile(pathExportAll, filedataExp.Key(i) + ".h5");

    % CF params
    expCTData.(filedataExp.Key(i)).CFparams = filedataExp(i,:);

    % CT init ref
    refInitFolderPathCT = fullfile(refInitFolderContent.folder, refInitFolderName);
        % pca
        refInitpcaFiles = dir(fullfile(refInitFolderPathCT, '*.pca'));
        expCTData.(filedataExp.Key(i)).refInit.pca = importPCA(refInitpcaFiles);
        % pcj 
        refInitpcjFiles = dir(fullfile(refInitFolderPathCT, '*.pcj'));
        expCTData.(filedataExp.Key(i)).refInit.pcj = importPCJ(refInitpcjFiles);
        % pcp
        refInitpcpFiles = dir(fullfile(refInitFolderPathCT, '*.pcp'));
        expCTData.(filedataExp.Key(i)).refInit.pcp = importPCP(refInitpcpFiles);
        % CTimages folder 
        
    nn_refInit = height(expCTData.(filedataExp.Key(i)).refInit.pcp);

    % CT final ref
    refFinalFolderPathCT = fullfile(refFinalFolderContent.folder, refFinalFolderName);
        % pca
        refFinalpcaFiles = dir(fullfile(refFinalFolderPathCT, '*.pca'));
        expCTData.(filedataExp.Key(i)).refFinal.pca = importPCA(refFinalpcaFiles);
        % pcj 
        refFinalpcjFiles = dir(fullfile(refFinalFolderPathCT, '*.pcj'));
        expCTData.(filedataExp.Key(i)).refFinal.pcj = importPCJ(refFinalpcjFiles);
        % pcp
        refFinalpcpFiles = dir(fullfile(refFinalFolderPathCT, '*.pcp'));
        expCTData.(filedataExp.Key(i)).refFinal.pcp = importPCP(refFinalpcpFiles);

    % BT concvarsAll
    concVarsAll = table();

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

        nn_exp = height(expCTData.(filedataExp.Key(i)).exp.(run_name).pcp); % per run

        HDF5dataPath = ['/exp/' char(run_name) '/conc'];  % structured path
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nx = dims(1);
        ny = dims(2);
        nz = dims(3);

        for k = 1:nn_exp
            concImage = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);

            % Concentration profiles and histograms of normalized images
            imgNr = expCTData.(filedataExp.Key(i)).exp.(run_name).pcp.ImgNr(k);
            rotPos = expCTData.(filedataExp.Key(i)).exp.(run_name).pcp.RotPos(k);
            timeStamp = expCTData.(filedataExp.Key(i)).exp.(run_name).pcp.Time(k);
            timeStart = filedataExp.st(i);
            timeElapsed = timeStamp - timeStart;
            secondsElapsed = seconds(timeElapsed);
            volInjected = secondsElapsed*filedataExp.Q(i)/60;
            tDtotal = volInjected/filedataExp.Vtotal(i);
            % ct prop
            resXmm = expCTData.(filedataExp.Key(i)).exp.(run_name).pca.Geometry.VoxelSizeX; % mm
            resYmm = expCTData.(filedataExp.Key(i)).exp.(run_name).pca.Geometry.VoxelSizeY; % mm
            % histogram 
            numBins = 100;
            [counts, edges] = histcounts(concImage, numBins);
            % y vars
            concVert = mean(concImage');
            pixelVert = 1:1:length(concVert);
            zVertcm = pixelVert*resYmm/10; %cm
            % x vars
            concHorz = mean(concImage);
            pixelHorz = 1:1:length(concHorz);
            xHorzcm = pixelHorz*resXmm/10; %cm
            % store in struct
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).imgNr = imgNr;
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).rotPos = rotPos;
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).timeStamp = timeStamp;
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).timeElapsed = timeElapsed;     
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).secondsElapsed = secondsElapsed; 
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).volInjected = volInjected;
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).tDtotal = tDtotal;
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).histImage = [counts', edges(1:end-1)',edges(2:end)']; % hist
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).C1Profile = [zVertcm',concVert']; % y vars
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).C1Axial = [xHorzcm',concHorz']; % x vars
            % front velocity
            
            idx = (concImage>=0.05 & concImage <= 0.15);
            [rows, ~] = find(idx);   % rows = Z positions (pixel indices)
            if ~isempty(rows)
                z01front = mean(rows) * resYmm / 10;
            else
                z01front = NaN;
            end
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).zFront = z01front; % x front

            % BT
            BTlinesBefore_temp = table( timeStamp, timeElapsed, secondsElapsed, volInjected, tDtotal, concVert(1),...
                'VariableNames',{'timeStamp','timeElapsed','secondsElapsed','volInjected','tDtotal','C1'});
            BTcore_temp = table( timeStamp, timeElapsed, secondsElapsed, volInjected, tDtotal, concVert(end),z01front,...
                'VariableNames',{'timeStamp','timeElapsed','secondsElapsed','volInjected','tDtotal','C1','zfront'});
            BTlinesBefore = [BTlinesBefore;BTlinesBefore_temp];
            BTcore = [BTcore;BTcore_temp];
        
        end
        concVars_temp =  expCTData.(filedataExp.Key(i)).exp.(run_name).concVars;
        concVars_tempTable = struct2table(concVars_temp,'AsArray',true);
        concVarsAll = [concVarsAll;concVars_tempTable];
    end
    expCTData.(filedataExp.Key(i)).BTlinesBefore = BTlinesBefore;
    expCTData.(filedataExp.Key(i)).BTcore = BTcore;
    expCTData.(filedataExp.Key(i)).concVarsAll = concVarsAll;

    velFront_cms = mean(gradient(expCTData.(filedataExp.Key(i)).concVarsAll.zFront, ...
        expCTData.(filedataExp.Key(i)).concVarsAll.secondsElapsed),'omitnan');
    velFront_cmmin = velFront_cms*60;
    expCTData.(filedataExp.Key(i)).CFparams.velFront_cmmin = velFront_cmmin;
    expCTData.(filedataExp.Key(i)).concVarsAll.tDcorr = ...
        velFront_cms*expCTData.(filedataExp.Key(i)).concVarsAll.secondsElapsed/zVertcm(end);
    for j = 1:length(expFolderName)
        for k = 1:nn_exp
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).tDcorr = ...
                velFront_cms*expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).secondsElapsed/zVertcm(end);
        end
    end

    % save expCTData
    expCT_name = pathExportAll + filedataExp.Key(i);
    expCTDataSave = expCTData.(filedataExp.Key(i));
    save(expCT_name + '.mat','expCTDataSave')
end
