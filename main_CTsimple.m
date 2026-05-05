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

    % CF params
    expCTData.(filedataExp.Key(i)).CFparams = filedataExp(i,:);

    % CT init ref
    refInitFolderPathCT = fullfile(refInitFolderContent.folder, refInitFolderName);
        % pca
        pcaFiles = dir(fullfile(refInitFolderPathCT, '*.pca'));
        expCTData.(filedataExp.Key(i)).refInit.pca = importPCA(pcaFiles);
        % pcj 
        pcjFiles = dir(fullfile(refInitFolderPathCT, '*.pcj'));
        expCTData.(filedataExp.Key(i)).refInit.pcj = importPCJ(pcjFiles);
        % pcp
        pcpFiles = dir(fullfile(refInitFolderPathCT, '*.pcp'));
        expCTData.(filedataExp.Key(i)).refInit.pcp = importPCP(pcpFiles);

        % CT images
        imgFiles = dir(fullfile(refInitFolderPathCT, '*.tif'));
            % Raw and cropped CT
            rawImage = importImages(imgFiles);  % expCTData.(filedataExp.Key(i)).refInit.RawCT = importImages(imgFiles);
            croppedImage = cell(size(rawImage));
            % Crop params
            imageRefCrop = rawImage{1};
            pixDist = 70;
            partsScanned = 5; % Parts scanned: from left to middle: air, CH. water,sleeve, core
            crop_xCoords = findcropCore_xAxis(imageRefCrop,pixDist,partsScanned-1);
            crop_xCoords = [crop_xCoords(1)+60;crop_xCoords(2)-60];
            crop_yCoords = [1;length(imageRefCrop)];          
            % Norm and cropp CT
            for k = 1:length(rawImage)
                rawImage{k} = normImage(rawImage{k});
                croppedImage{k} = cropImage(rawImage{k},crop_xCoords, crop_yCoords);
            end
            expCTData.(filedataExp.Key(i)).refInit.croppedCT = croppedImage;
   
    % CT final ref
    refFinalFolderPathCT = fullfile(refFinalFolderContent.folder, refFinalFolderName);
        % pca
        pcaFiles = dir(fullfile(refFinalFolderPathCT, '*.pca'));
        expCTData.(filedataExp.Key(i)).refFinal.pca = importPCA(pcaFiles);
        % pcj 
        pcjFiles = dir(fullfile(refFinalFolderPathCT, '*.pcj'));
        expCTData.(filedataExp.Key(i)).refFinal.pcj = importPCJ(pcjFiles);
        % pcp
        pcpFiles = dir(fullfile(refFinalFolderPathCT, '*.pcp'));
        expCTData.(filedataExp.Key(i)).refFinal.pcp = importPCP(pcpFiles);

        % CT images
        imgFiles = dir(fullfile(refFinalFolderPathCT, '*.tif'));
            % Raw and cropped CT
            rawImage = importImages(imgFiles);  % expCTData.(filedataExp.Key(i)).refFinal.RawCT = importImages(imgFiles);
            croppedImage = cell(size(rawImage));
            % Norm and cropp CT
            for k = 1:length(rawImage)
                rawImage{k} = normImage(rawImage{k});
                croppedImage{k} = cropImage(rawImage{k},crop_xCoords, crop_yCoords);
            end
            expCTData.(filedataExp.Key(i)).refFinal.croppedCT = croppedImage;

    % CT exps
    for j = 1:length(expFolderName)
        expFolderPathCT = fullfile(expFolderPath{j}, expFolderName{j});
        run_name = "run_" + string(j);
            % pca
            pcaFiles = dir(fullfile(expFolderPathCT, '*.pca'));
            expCTData.(filedataExp.Key(i)).exp.(run_name).pca = importPCA(pcaFiles);
            % pcj 
            pcjFiles = dir(fullfile(expFolderPathCT, '*.pcj'));
            expCTData.(filedataExp.Key(i)).exp.(run_name).pcj = importPCJ(pcjFiles);
            % pcp
            pcpFiles = dir(fullfile(expFolderPathCT, '*.pcp'));
            expCTData.(filedataExp.Key(i)).exp.(run_name).pcp = importPCP(pcpFiles);

            % CT images
            imgFiles = dir(fullfile(expFolderPathCT, '*.tif'));
            % Raw and cropped CT
            rawImage = importImages(imgFiles);  % expCTData.(filedataExp.Key(i)).exp.(run_name).RawCT = importImages(imgFiles);
            concImage = cell(size(rawImage));
            % Norm and cropp CT
            for k = 1:length(rawImage)
                rawImage{k} = normImage(rawImage{k});
                croppedImage = cropImage(rawImage{k},crop_xCoords, crop_yCoords);
                minImage = expCTData.(filedataExp.Key(i)).refInit.croppedCT{k};
                maxImage = expCTData.(filedataExp.Key(i)).refFinal.croppedCT{k};
                concImage{k} = satImage(croppedImage,minImage,maxImage);
            end
            % expCTData.(filedataExp.Key(i)).exp.(run_name).croppedCT = croppedImage;
            expCTData.(filedataExp.Key(i)).exp.(run_name).concCT = concImage;
    end
end

%% Concentration profiles and histograms of normalized images
BTlinesBefore = table(); 
BTcore = table();
for i = 1:length(filedataExp.Key)
    for j = 1:length(expFolderName) % number of runs
        run_name = "run_" + string(j);
        concCTImage = expCTData.(filedataExp.Key(i)).exp.(run_name).concCT;
        concVars = cell(size(concCTImage));
        for k = 1:length(concCTImage) % numbers of images per run
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
            [counts, edges] = histcounts(concCTImage{k}, numBins);
            % y vars
            concVert = mean(concCTImage{k}');
            pixelVert = 1:1:length(concVert);
            zVertcm = pixelVert*resYmm/100; %cm
            % x vars
            concHorz = mean(concCTImage{k});
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
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).histImage = {[counts', edges(1:end-1)',edges(2:end)']}; % hist
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).C1Profile = {[zVertcm',concVert']}; % y vars
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).C1Axial = {[xHorzcm',concHorz']}; % x vars
            % BT
            BTlinesBefore_temp = table( timeStamp, timeElapsed, secondsElapsed, volInjected, tDtotal, concVert(1),...
                'VariableNames',{'timeStamp','timeElapsed','secondsElapsed','volInjected','tDtotal','C1'});
            BTcore_temp = table( timeStamp, timeElapsed, secondsElapsed, volInjected, tDtotal, concVert(end),...
                'VariableNames',{'timeStamp','timeElapsed','secondsElapsed','volInjected','tDtotal','C1'});
            BTlinesBefore = [BTlinesBefore;BTlinesBefore_temp];
            BTcore = [BTcore;BTcore_temp];
        end
    end
end
expCTData.(filedataExp.Key(i)).BTlinesBefore = BTlinesBefore;
expCTData.(filedataExp.Key(i)).BTcore = BTcore;

%% Imaging
% Plot as movies with angle and profiles in x and y
% plot histogram per figure or for movie, allow movie to stop, or
% interactive with angl or time
% plot breakthrough curve


    % have final results in a full array with angle and time
    % create breakthrough curve in the end point with time


