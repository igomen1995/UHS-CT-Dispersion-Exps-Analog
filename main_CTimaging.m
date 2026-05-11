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

%% Imaging movie

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
    HDF5filename = fullfile(pathExportAll, filedataExp.Key(i) + ".h5");
    expCTDataname = fullfile(pathExportAll, filedataExp.Key(i) + ".mat");
    expCTDataTemp = load(expCTDataname);
    expCTData.(filedataExp.Key(i)) = expCTDataTemp.expCTDataSave;

    fig = figure('Position', [50, 50, 600, 1000]); % [left, bottom, width, height];
    frame = getframe(fig);
    v = VideoWriter(pathExportAll + "movie_" + filedataExp.Key(i), 'MPEG-4');
    v.FrameRate = 100;   % frames per second
    open(v);
    writeVideo(v, frame);
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
        run_name = "run_" + sprintf('%02d', j);
        HDF5dataPath = ['/exp/' char(run_name) '/conc'];
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nx = dims(1);
        ny = dims(2);
        nz = dims(3);

        for k = 1:nz
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
            concCTimages = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            cla(ax3)
            imagesc(ax3, concCTimages)
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
    HDF5filename = fullfile(pathExportAll, filedataExp.Key(i) + ".h5");
    expCTDataname = fullfile(pathExportAll, filedataExp.Key(i) + ".mat");
    expCTDataTemp = load(expCTDataname);
    expCTData.(filedataExp.Key(i)) = expCTDataTemp.expCTDataSave;

    for j = 1:length(expFolderName)

        run_name = "run_" + sprintf('%02d', j);
        HDF5dataPath = ['/exp/' char(run_name) '/conc'];
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nx = dims(1);
        ny = dims(2);
        nz = dims(3);

        concCTimages = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);

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
