
%% Interactive CT Concentration Visualization
%
% This script provides an interactive visualization environment for
% exploring processed CT concentration datasets generated from porous media
% flow experiments.
%
% The workflow loads processed experiment data, breakthrough information,
% and concentration image stacks stored in HDF5 files. Users can interact
% with a breakthrough curve to display the corresponding CT image and
% associated concentration statistics.
%
% Workflow
% --------
% 1. Import experiment configuration and metadata.
% 2. Load processed experiment results (.mat files).
% 3. Load concentration images stored in HDF5 format.
% 4. Construct breakthrough-curve data from all scans.
% 5. Display an interactive breakthrough plot.
% 6. Select any breakthrough point to visualize:
%       - Axial concentration profile
%       - Radial/end-point concentration profile
%       - 2-D concentration map
%       - Concentration histogram
%       - Experimental metadata
%
% Interactive Features
% --------------------
% Clicking a point on the breakthrough curve automatically:
%
%   - Identifies the corresponding experiment, run, and scan number.
%   - Loads the associated concentration image from HDF5 storage.
%   - Displays concentration distributions within the core.
%   - Updates concentration profiles and histograms.
%   - Updates figure titles and annotations.
%
% Figure Layout
% -------------
% ax1 : Axial concentration profile
% ax2 : Concentration histogram
% ax3 : 2-D concentration image
% ax4 : Outlet/radial concentration profile
% ax5 : Breakthrough curve
% ax5b: Dimensionless time (t_D) axis
%
% Inputs
% ------
% inputCTExpConfig.xlsx
%     Configuration file containing:
%         - Input metadata file
%         - Import path
%         - Export path
%
% Generated HDF5 files:
%     <ExperimentKey>.h5
%
% Generated MAT files:
%     <ExperimentKey>.mat
%
% Outputs
% -------
% Interactive MATLAB figure for exploring CT concentration data.
%
% Optional Output
% ---------------
% The script contains a commented section allowing generation of
% time-resolved MP4 movies showing the evolution of concentration fields
% during experiments.
%
% Dependencies
% ------------
% Required custom functions:
%
%     import_inputCTExp
%     onClickCallback
%
% Required MATLAB functionality:
%
%     HDF5 support
%     Image Processing Toolbox
%
% Notes
% -----
% - Concentration images are expected to be stored in:
%
%       /exp/run_xx/conc
%
%   within each HDF5 file.
%
% - Dimensionless breakthrough time is computed using:
%
%       t_D = v * t / L
%
%   where:
%       v = front velocity
%       t = elapsed time
%       L = core length
%
% - The callback function ONCLICKCALLBACK controls all interactive updates.

%% IMPORT input

addpath('functions/');

% Introduce name of input and desired output folder name

inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

filenameExp = inputFileConfig.inputFileName{:};

pathImportAll = inputFileConfig.importPath{:}; % Path for OUTPUT
pathExportAll = inputFileConfig.exportPath{:}; % Path for OUTPUT
mkdir(pathExportAll); % Create directory for output

%% Import params and data

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

% %% Imaging movie
% 
% for i = 1:length(filedataExp.Key)
%     HDF5filename = fullfile(pathExportAll, filedataExp.Key(i) + ".h5");
%     expCTDataname = fullfile(pathExportAll, filedataExp.Key(i) + ".mat");
%     expCTDataTemp = load(expCTDataname);
%     expCTData.(filedataExp.Key(i)) = expCTDataTemp.expCTDataSave;
% 
%     fig = figure('Position', [50, 50, 600, 1000]); % [left, bottom, width, height];
%     frame = getframe(fig);
%     v = VideoWriter(pathExportAll + "movie_" + filedataExp.Key(i), 'MPEG-4');
%     v.FrameRate = 100;   % frames per second
%     open(v);
%     writeVideo(v, frame);
%     % Shared geometry
%     imgPos  = [0.12 0.24  0.3 0.5]; % image axes
%     cbPos   = [0.45 imgPos(2) 0.02 0.5];
%     ax1Pos  = [imgPos(1) 0.79 imgPos(3) 0.14];  % same WIDTH as image
%     ax4Pos  = [0.62 imgPos(2)  0.27 imgPos(4)];  % same HEIGHT as image  
%     ax2Pos  = [ax4Pos(1) ax1Pos(2) ax4Pos(3) ax1Pos(4)];
%     ax5Pos  = [ax1Pos(1) 0.05 0.77 0.12]; 
%     ax1 = axes('Position',ax1Pos);
%     ax2 = axes('Position',ax2Pos);
%     ax3 = axes('Position',imgPos);
%     ax4 = axes('Position',ax4Pos);
%     ax5 = axes('Position',ax5Pos);
%     ax5b = axes('Position', ax5.Position, ...
%         'XAxisLocation','top', ...
%         'YAxisLocation','right', ...
%         'Color','none', ...
%         'YColor','none');   % hide Y axis
%     linkaxes([ax5 ax5b],'x')
% 
%     % hTitle
%     hTitle = annotation('textbox', [0 0.93 1 0.05], ...
%         'String', '', ...
%         'EdgeColor','none', ...
%         'HorizontalAlignment','center', ...
%         'FontWeight','bold', ...
%         'Interpreter','none');
% 
%     for j = 1:length(expFolderName) % number of runs
%         run_name = "run_" + sprintf('%02d', j);
%         HDF5dataPath = ['/exp/' char(run_name) '/conc'];
%         info = h5info(HDF5filename, HDF5dataPath);
%         dims = info.Dataspace.Size;
%         nx = dims(1);
%         ny = dims(2);
%         nz = dims(3);
% 
%         for k = 1:nz
%             vars = expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k);
% 
%             % hTitle
%             set(hTitle, 'String', ...
%                 filedataExp.Key(i) + ": CT " + run_name + ...
%                 " ImgNumber_" + sprintf('%03d', k));
% 
%             % plot concentration in x ax1
%             x1 = vars.C1Axial.xHorzcm;
%             y1 = vars.C1Axial.rhoNormHorz;
%             cla(ax1)
%             plot(ax1, x1, y1,'LineWidth',2)
%             xlim(ax1,[min(x1) max(x1)])
%             ylim(ax1,[-0.02 1])
%             xlabel(ax1,'X [cm]')
%             ylabel(ax1,'C_{ave}_1 [-]')
%             title(ax1,"timeElapsed: " + vars.secondsElapsed + ...
%                       " s, volInjected: " + sprintf('%.2f', vars.volInjected) + ...
%                       " mL, tD: " + sprintf('%.3f', vars.tDtotal))
%             grid(ax1,'on')
% 
%             % plot concentration in z ax4
%             x2 = vars.C1Profile.zVertcm;
%             y2 = vars.C1Profile.rhoNormVert;
%             cla(ax4)
%             plot(ax4, x2, y2,'LineWidth',2)
%             xlabel(ax4,'Z [cm]')
%             ylabel(ax4,'C_{ave}_1 [-]')
%             grid(ax4,'on')          
%             axis(ax4,'tight')
%             axis(ax4,'manual')
%             camroll(ax4,270)
%             ylim(ax4,[-0.02 1])
%             ax4.YAxisLocation = 'right';
% 
%             % plot image ax3
%             concCTimages = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
%             % imgSmooth = imgaussfilt(concCTimages, 20);
%             cla(ax3)
%             imagesc(ax3, concCTimages)
%             axis(ax3,'xy','fill')
%             set(ax3,'YDir','reverse')
%             xlabel(ax3,'Pixel Number')
%             ylabel(ax3,'Pixel Number')
%             % nLevels = 10;
%             % cmap = turbo(nLevels);
%             % colormap(ax3,cmap)
%             colormap(ax3,turbo)
%             clim(ax3,[0 1]);
%             cb = colorbar(ax3,'Position',cbPos);
%             cb.Label.String = 'C_1 [-]';
%             % levels = 0:0.1:1;
%             % hold(ax3,'on')
%             % contour(ax3, imgSmooth, levels, ...
%             %     'LineColor','k', ...
%             %     'LineWidth',1,'ShowText',true,'LabelFormat',"%0.1f")
%             % hold(ax3,'off')
% 
%             % plot histogram ax2
%             freq = vars.histImage.counts;
%             binCenters = (vars.histImage.minEdge + vars.histImage.maxEdge)/2;
%             binWidth = abs(vars.histImage.maxEdge-vars.histImage.minEdge);
%             cla(ax2)
%             bar(ax2,binCenters,freq,1)
%             xlim(ax2,[-0.02,1])
%             ylim(ax2,[0,length(x1)*length(x2)])
%             xlabel(ax2,'C_1 [-]')
%             ylabel(ax2,'Counts')
%             title(ax2,"run: " +string(j)+" , angle: " + vars.rotPos + "°")
%             grid(ax2, 'on')
% 
%             % plot BTcore ax5
%             t = vars.secondsElapsed;
%             C = y2(end);
%             tmin = expCTData.(filedataExp.Key(i)).BTcore.secondsElapsed(1);
%             tmax = expCTData.(filedataExp.Key(i)).BTcore.secondsElapsed(end);
%             scatter(ax5,t,C,15,'filled','MarkerFaceColor',[0, 0.4470, 0.7410],'MarkerEdgeColor','none')
%             hold(ax5,'on')
%             ylim(ax5,[-0.02 1])
%             xlim(ax5,[tmin,tmax])
%             xlabel(ax5,'secondsElapsed')
%             ylabel(ax5,'C_{ave}_1 [-]')
%             xlabel(ax5b,'t_D [-]')
%             grid(ax5, 'on')
% 
%             drawnow;
%             frame = getframe(fig);  % capture frame
%             writeVideo(v, frame); % write to movie
%         end
%     end
%     close(v)
% end

%% Interactive imaging

figure('Position',[50 50 600 1000])
imgPos  = [0.12 0.24  0.3 0.5];
cbPos   = [0.45 imgPos(2) 0.02 0.5];
ax1Pos  = [imgPos(1) 0.79 imgPos(3) 0.14];
ax4Pos  = [0.62 imgPos(2)  0.27 imgPos(4)];
ax2Pos  = [ax4Pos(1) ax1Pos(2) ax4Pos(3) ax1Pos(4)];
ax5Pos  = [ax1Pos(1) 0.05 0.77 0.12];
ax1 = axes('Position',ax1Pos);
ax2 = axes('Position',ax2Pos);
ax3 = axes('Position',imgPos);
ax4 = axes('Position',ax4Pos);
ax5 = axes('Position',ax5Pos);
ax5b = axes('Position', ax5.Position, ...
    'XAxisLocation','top', ...
    'YAxisLocation','right', ...
    'Color','none', ...
    'YColor','none');   % hide Y axis
linkaxes([ax5 ax5b],'x')
ax5b.HitTest = 'off';
ax5b.PickableParts = 'none';
hold(ax5,'on')

% store BT
BT.t = [];
BT.tD = [];
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
        % nx = dims(1);
        % ny = dims(2);
        nz = dims(3);

        for k = 1:nz

            % concCTimages = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            vars = expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(:,k);

            % breakthrough point
            t = vars.secondsElapsed;
            tD = vars.tDtotal;
            y2 = vars.C1Profile.rhoNormVert;
            C = y2(end);

            % store
            BT.t(end+1) = t;
            BT.tD(end+1) = tD;
            BT.C(end+1) = C;
            BT.i(end+1) = i;
            BT.j(end+1) = j;
            BT.k(end+1) = k;

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
    ylim(ax5,[-0.02 1])
    xlabel(ax5,'secondsElapsed')
    ylabel(ax5,'C_{ave}_1 [-]')
    xt = ax5.XTick;
    tDtick = xt*(max(BT.tD)/max(BT.t));
    ax5b.XTick = xt;
    ax5b.XTickLabel = compose('%.2f',tDtick);
    xlabel(ax5b,'t_D [-]')
    grid(ax5,'on')
    
    % Selected point marker
    hSelected = scatter(ax5, NaN, NaN, 40, ...
        'filled', ...
        'MarkerFaceColor','r', ...
        'MarkerEdgeColor','k');
    
    hTitle = annotation('textbox', [0 0.93 1 0.05], ...
        'String', '', ...
        'EdgeColor','none', ...
        'HorizontalAlignment','center', ...
        'FontWeight','bold', ...
        'Interpreter','none');
    
    
    % callback part
    hScatter.ButtonDownFcn = @(src,event) ...
        onClickCallback(src,event,pathExportAll,hSelected, ...
        BT, expCTData,filedataExp, ...
        ax1,ax2,ax3,ax4,cbPos,hTitle);
end

%% Countour map

for i = 1:length(filedataExp.Key)
    HDF5filename = fullfile(pathExportAll, filedataExp.Key(i) + ".h5");
    expCTDataname = fullfile(pathExportAll, filedataExp.Key(i) + ".mat");
    expCTDataTemp = load(expCTDataname);
    expCTData.(filedataExp.Key(i)) = expCTDataTemp.expCTDataSave;

    fig = figure('Position', [50, 50, 600, 1000]); % [left, bottom, width, height];
    % Shared geometry
    imgPos  = [0.12 0.24  0.3 0.5]; % image axes
    cbPos   = [0.45 imgPos(2) 0.02 0.5];
    ax1Pos  = [imgPos(1) 0.79 imgPos(3) 0.14];  % same WIDTH as image
    ax4Pos  = [0.62 imgPos(2)  0.27 imgPos(4)];  % same HEIGHT as image  
    ax2Pos  = [ax4Pos(1) ax1Pos(2) ax4Pos(3) ax1Pos(4)];
    ax5Pos  = [ax1Pos(1) 0.05 0.77 0.12]; 
    ax1 = axes('Position',ax1Pos);
    ax2 = axes('Position',ax2Pos);
    ax3 = axes('Position',imgPos);
    ax4 = axes('Position',ax4Pos);
    ax5 = axes('Position',ax5Pos);
    ax5b = axes('Position', ax5.Position, ...
        'XAxisLocation','top', ...
        'YAxisLocation','right', ...
        'Color','none', ...
        'YColor','none');   % hide Y axis
    linkaxes([ax5 ax5b],'x')
    ax5b.HitTest = 'off';
    ax5b.PickableParts = 'none';
    hold(ax5,'on')

    % hTitle
    hTitle = annotation('textbox', [0 0.93 1 0.05], ...
        'String', '', ...
        'EdgeColor','none', ...
        'HorizontalAlignment','center', ...
        'FontWeight','bold', ...
        'Interpreter','none');

    for j = 1:length(expFolderName) % number of runs
        run_name = "run_" + sprintf('%02d', j);
        HDF5dataPath = ['/exp/' char(run_name) '/conc'];
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nx = dims(1);
        ny = dims(2);
        nz = dims(3);

        for k = 10%1:nz
            vars = expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k);

            % hTitle
            set(hTitle, 'String', ...
                filedataExp.Key(i) + ": CT " + run_name + ...
                " ImgNumber_" + sprintf('%03d', k));

            % plot concentration in x ax1
            x1 = vars.C1Axial.xHorzcm;
            y1 = vars.C1Axial.rhoNormHorz;
            cla(ax1)
            plot(ax1, x1, y1,'LineWidth',2)
            xlim(ax1,[min(x1) max(x1)])
            ylim(ax1,[-0.02 1])
            xlabel(ax1,'X [cm]')
            ylabel(ax1,'C_{ave}_1 [-]')
            title(ax1,"timeElapsed: " + vars.secondsElapsed + ...
                      " s, volInjected: " + sprintf('%.2f', vars.volInjected) + ...
                      " mL, tD: " + sprintf('%.3f', vars.tDtotal))
            grid(ax1,'on')

            % plot concentration in z ax4
            x2 = vars.C1Profile.zVertcm;
            y2 = vars.C1Profile.rhoNormVert;
            cla(ax4)
            plot(ax4, x2, y2,'LineWidth',2)
            xlabel(ax4,'Z [cm]')
            ylabel(ax4,'C_{ave}_1 [-]')
            grid(ax4,'on')          
            axis(ax4,'tight')
            axis(ax4,'manual')
            camroll(ax4,270)
            ylim(ax4,[-0.02 1])
            ax4.YAxisLocation = 'right';

            % plot image ax3
            concCTimages = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            imgSmooth = imgaussfilt(concCTimages, 20);
            cla(ax3)
            imagesc(ax3, concCTimages)
            axis(ax3,'xy','fill')
            set(ax3,'YDir','reverse')
            xlabel(ax3,'Pixel Number')
            ylabel(ax3,'Pixel Number')
            % nLevels = 10;
            % cmap = turbo(nLevels);
            % colormap(ax3,cmap)
            colormap(ax3,turbo)
            clim(ax3,[0 1]);
            cb = colorbar(ax3,'Position',cbPos);
            cb.Label.String = 'C_1 [-]';
            levels = 0:0.1:1;
            hold(ax3,'on')
            contour(ax3, imgSmooth, levels, ...
                'LineColor','k', ...
                'LineWidth',1,'ShowText',true,'LabelFormat',"%0.1f")
            hold(ax3,'off')

            % plot histogram ax2
            freq = vars.histImage.counts;
            binCenters = (vars.histImage.minEdge + vars.histImage.maxEdge)/2;
            binWidth = abs(vars.histImage.maxEdge-vars.histImage.minEdge);
            cla(ax2)
            bar(ax2,binCenters,freq,1)
            xlim(ax2,[-0.02,1])
            ylim(ax2,[0,length(x1)*length(x2)])
            xlabel(ax2,'C_1 [-]')
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
            ylim(ax5,[-0.02 1])
            xlim(ax5,[tmin,tmax])
            xlabel(ax5,'secondsElapsed')
            ylabel(ax5,'C_{ave}_1 [-]')
            xlabel(ax5b,'t_D [-]')
            grid(ax5, 'on')
        end
    end
end


