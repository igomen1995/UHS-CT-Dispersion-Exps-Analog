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
            % C = 0.1
            idx = (concImage>=0.05 & concImage <= 0.15);
            [rows, ~] = find(idx);   % rows = Z positions (pixel indices)
            if ~isempty(rows)
                zFront_10 = mean(rows) * resYmm / 10;
            else
                zFront_10 = NaN;
            end
                        % C = 0.1
            idx = (concImage>=0.85 & concImage <= 0.95);
            [rows, ~] = find(idx);   % rows = Z positions (pixel indices)
            if ~isempty(rows)
                zFront_90 = mean(rows) * resYmm / 10;
            else
                zFront_90 = NaN;
            end
            zWidth = zFront_10 - zFront_90;

            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).zFront10 = zFront_10; % Z C = 0.1 front
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).zFront90 = zFront_90; % Z C = 0.9 front
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).zWidth = zWidth; % Z width front from 0.9 to 0.1

            % BT
            BTlinesBefore_temp = table( timeStamp, timeElapsed, secondsElapsed, volInjected, tDtotal, concVert(1),...
                'VariableNames',{'timeStamp','timeElapsed','secondsElapsed','volInjected','tDtotal','C1'});
            BTcore_temp = table( timeStamp, timeElapsed, secondsElapsed, volInjected, tDtotal, concVert(end),zFront_10,zFront_90,zWidth,...
                'VariableNames',{'timeStamp','timeElapsed','secondsElapsed','volInjected','tDtotal','C1','zFront10','zFront90','zWidth'});
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

    velFront_cms = mean(gradient(expCTData.(filedataExp.Key(i)).concVarsAll.zFront10, ...
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
