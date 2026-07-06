%% End-to-End CT Concentration Processing Workflow
%
% This script performs the complete processing workflow for CT-based
% concentration analysis of core-flood experiments.
%
% Raw CT images, reference scans, experimental scans, and scanner metadata
% are imported, processed, analyzed, and visualized within a single script.
%
% The workflow converts reconstructed CT images into concentration maps,
% extracts concentration profiles and breakthrough curves, and generates
% both video animations and interactive visualizations.
%
% Workflow
% --------
% 1. Import experiment metadata and configuration.
% 2. Load initial and final reference scans.
% 3. Load experimental scan runs.
% 4. Import scanner metadata files:
%       - PCA (scanner/reconstruction parameters)
%       - PCP (acquisition timestamps)
%       - PCJ (reconstruction information)
% 5. Normalize all CT images.
% 6. Crop images to the core region of interest.
% 7. Calculate concentration maps using:
%
%       C = (Iexp - Iref_init)
%           ------------------
%       (Iref_final - Iref_init)
%
% 8. Extract quantitative transport variables:
%       - Axial concentration profiles
%       - Vertical concentration profiles
%       - Concentration histograms
%       - Breakthrough curves
%       - Injected volumes and dimensionless time
%
% 9. Save reduced experimental datasets.
% 10. Generate MP4 animations.
% 11. Launch an interactive breakthrough visualization interface.
%
% Outputs
% -------
% expCTlight_<ExperimentKey>.mat
%     Lightweight dataset containing processed concentration statistics.
%
% crop_xCoords.mat
%     Cropping coordinates used for image processing.
%
% movie_<ExperimentKey>.mp4
%     Time-resolved visualization of concentration evolution.
%
% Interactive GUI
%     Linked breakthrough and image visualization interface.
%
% Dependencies
% ------------
%     import_inputCTExp
%     importPCA
%     importPCJ
%     importPCP
%     importImages
%     cropImage
%     findcropCore_xAxis
%     normImage
%     satImage
%     onClickCallback
%
% Notes
% -----
% This script stores complete image datasets in memory. For large
% experiments, the newer HDF5-based workflow is recommended because it
% significantly reduces memory usage and improves scalability.

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
            % crop_xCoords = findcropCore_xAxis(imageRefCrop,pixDist,partsScanned-1);
            % crop_xCoords = [crop_xCoords(1)+60;crop_xCoords(2)-60];
            load(pathImportAll+ "crop_xCoords.mat");
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
    concVarsAll = table();
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
            zVertcm = pixelVert*resYmm/10; %cm
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
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).histImage = [counts', edges(1:end-1)',edges(2:end)']; % hist
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).C1Profile = [zVertcm',concVert']; % y vars
            expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k).C1Axial = [xHorzcm',concHorz']; % x vars
            % BT
            BTlinesBefore_temp = table( timeStamp, timeElapsed, secondsElapsed, volInjected, tDtotal, concVert(1),...
                'VariableNames',{'timeStamp','timeElapsed','secondsElapsed','volInjected','tDtotal','C1'});
            BTcore_temp = table( timeStamp, timeElapsed, secondsElapsed, volInjected, tDtotal, concVert(end),...
                'VariableNames',{'timeStamp','timeElapsed','secondsElapsed','volInjected','tDtotal','C1'});
            BTlinesBefore = [BTlinesBefore;BTlinesBefore_temp];
            BTcore = [BTcore;BTcore_temp];
        end
        concVars_temp =  expCTData.(filedataExp.Key(i)).exp.(run_name).concVars;
        concVars_tempTable = struct2table(concVars_temp);
        concVarsAll = [concVarsAll;concVars_tempTable];
    end
    expCTData.(filedataExp.Key(i)).BTlinesBefore = BTlinesBefore;
    expCTData.(filedataExp.Key(i)).BTcore = BTcore;
    expCTData.(filedataExp.Key(i)).concVarsAll = concVarsAll;
end


%% save
for i = 1:length(filedataExp.Key)
    expCT_name = pathExportAll + "expCTlight_"+filedataExp.Key(i);
    expCTDataLight = rmfield(expCTData.(filedataExp.Key(i)), {'refInit','refFinal','exp'});
    save(expCT_name + '.mat','expCTDataLight')
end
save(pathExportAll + "crop_xCoords.mat",'crop_xCoords')
%% Imaging movie

for i = 1:length(filedataExp.Key)
    v = VideoWriter(pathExportAll + "movie_" + filedataExp.Key(i), 'MPEG-4');
    v.FrameRate = 100;   % frames per second
    open(v);
    fig = figure('Position', [50, 50, 600, 1000]); % [left, bottom, width, height];
    % Shared geometry
    imgPos  = [0.12 0.2  0.3 0.5];   % image axes
    cbPos  = [0.45 0.2 0.02 0.5];
    ax1Pos  = [imgPos(1) 0.78 imgPos(3) 0.14]; % same WIDTH as image
    ax4Pos  = [0.62 0.2  0.27 imgPos(4)];      % same HEIGHT as image  
    ax2Pos  = [ax4Pos(1) ax1Pos(2) ax4Pos(3) ax1Pos(4)];
    ax5Pos = [ax1Pos(1) 0.05 0.77 ax1Pos(1)];  
    ax1 = axes('Position',ax1Pos);
    ax2 = axes('Position',ax2Pos);
    ax3 = axes('Position',imgPos);
    ax4 = axes('Position',ax4Pos);
    ax5 = axes('Position',ax5Pos);

    for j = 1:length(expFolderName) % number of runs
        run_name = "run_" + string(j);

        for k = 1:length(concCTImage)
            vars = expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k);

            % plot concentration in x ax1
            xy1 = vars.C1Axial;
            x1 = xy1(:,1);
            y1 = xy1(:,2);
            cla(ax1)
            plot(ax1, x1, y1)
            xlim(ax1,[min(x1) max(x1)])
            ylim(ax1,[0 1])
            xlabel(ax1,'X Distance [cm]')
            ylabel(ax1,'Average concentration')
            title(ax1,"timeElapsed: " + vars.secondsElapsed + ...
                      " s, volInjected: " + vars.volInjected + " mL")
            grid(ax1,'on')
    
            % plot concentration in z ax4
            xy2 = vars.C1Profile;
            x2 = xy2(:,1);
            y2 = xy2(:,2);
            cla(ax4)
            plot(ax4, x2, y2)
            xlabel(ax4,'Z Distance [cm]')
            ylabel(ax4,'Average concentration')
            grid(ax4,'on')          
            axis(ax4,'tight')
            axis(ax4,'manual')
            camroll(ax4,270)
            ylim(ax4,[0 1])

            % plot image ax3
            concCTimages = expCTData.(filedataExp.Key(i)).exp.(run_name).concCT;
            cla(ax3)
            imagesc(ax3, concCTimages{k})
            axis(ax3,'xy','fill')
            set(ax3,'YDir','reverse')
            colormap(ax3,turbo)
            clim(ax3,[0 1]);
            
            cb = colorbar(ax3,'Position',cbPos);
            cb.Label.String = 'Concentration';

            % plot histogram ax3
            histData = vars.histImage;
            freq = histData(:,1);
            binCenters = (histData(:,2)+histData(:,3))/2;
            binWidth = abs(histData(:,3)-histData(:,2));
            cla(ax2)
            bar(ax2,binCenters,freq,1)
            xlim(ax2,[0,1])
            ylim(ax2,[0,length(x1)*length(x2)])
            xlabel(ax2,'Concentration')
            ylabel(ax2,'Counts')
            title(ax2,"run: " +string(j)+" , angle: " + vars.rotPos + "°")
            grid(ax2, 'on')

            % plot BTcore ax5
            t = vars.secondsElapsed;
            C = y2(end);
            tmin = expCTData.(filedataExp.Key(i)).BTcore.secondsElapsed(1);
            tmax = expCTData.(filedataExp.Key(i)).BTcore.secondsElapsed(end);
            scatter(ax5,t,C,15,'filled','MarkerFaceColor',[0, 0.4470, 0.7410],'MarkerEdgeColor','none')
            hold(ax5,'on')
            ylim(ax5,[0,1])
            xlim(ax5,[tmin,tmax])
            xlabel(ax5,'secondsElapsed')
            ylabel(ax5,'Concentration')
            grid(ax5, 'on')

            drawnow;
            frame = getframe(fig);  % capture frame
            writeVideo(v, frame); % write to movie
        end
    end
    close(v)
end

%% Interactive imaging

figure('Position',[50 50 600 1000])
imgPos  = [0.12 0.2  0.3 0.5];
cbPos   = [0.45 0.2 0.02 0.5];
ax1Pos  = [imgPos(1) 0.78 imgPos(3) 0.14];
ax4Pos  = [0.62 0.2  0.27 imgPos(4)];
ax2Pos  = [ax4Pos(1) ax1Pos(2) ax4Pos(3) ax1Pos(4)];
ax5Pos  = [ax1Pos(1) 0.05 0.77 0.12];
ax1 = axes('Position',ax1Pos);
ax2 = axes('Position',ax2Pos);
ax3 = axes('Position',imgPos);
ax4 = axes('Position',ax4Pos);
ax5 = axes('Position',ax5Pos);
hold(ax5,'on')
grid(ax5,'on')
xlabel(ax5,'secondsElapsed')
ylabel(ax5,'Concentration')

% store BT
BT.t = [];
BT.C = [];
BT.i = [];
BT.j = [];
BT.k = [];

% build data to plot
for i = 1:length(filedataExp.Key)

    for j = 1:length(expFolderName)

        run_name = "run_" + string(j);
        concCTimages = expCTData.(filedataExp.Key(i)).exp.(run_name).concCT;

        for k = 1:length(concCTimages)

            vars = expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k);

            % breakthrough point
            t = vars.secondsElapsed;
            xy2 = vars.C1Profile;
            y2 = xy2(:,2);
            C = y2(end);

            % store
            BT.t(end+1) = t;
            BT.C(end+1) = C;
            BT.i(end+1) = i;
            BT.j(end+1) = j;
            BT.k(end+1) = k;

        end
    end
end

% plot BT
hScatter = scatter(ax5, BT.t, BT.C, 20, ...
    'filled', ...
    'MarkerFaceColor',[0 0.4470 0.7410], ...
    'MarkerEdgeColor','none');
tmin = min(BT.t);
tmax = max(BT.t);
xlim(ax5,[tmin tmax])
ylim(ax5,[0 1])

% callback part
hScatter.ButtonDownFcn = @(src,event) ...
    onClickCallback(src,event,BT, ...
    expCTData,filedataExp, ...
    ax1,ax2,ax3,ax4,cbPos);

% mark point with a red dot in the BT curve
