
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

figHandles = gobjects(length(filedataExp.Key),1);

for i = 1:length(filedataExp.Key)
    
    fig = figure('Position', [50, 50, 800, 1000]); % [left, bottom, width, height];
    figHandles(i) = fig;

    % figure config
    imgPos  = [0.1 0.1  0.8 0.8]; % xleft ybottom W H
    hGap = 0.07;
    vGap = 0.07;   
    % colorbar reservation — only needed for ax2's column
    cbGap      = 0.012;
    cbWidth    = 0.018;
    cbLabelPad = 0.03;              % room for "C_1 [-]" label text
    cbReserve  = cbGap + cbWidth + cbLabelPad;
    % plotting window — 3 equal plot-box widths; extra cbReserve inserted after ax2 only
    colsW = (imgPos(3) - 2*hGap - cbReserve)/3;
    row1H = imgPos(4)*3/4 - vGap;
    row2H = imgPos(4)/4;
    ax1Pos  = [imgPos(1) imgPos(2)+row2H+vGap colsW row1H];
    ax2Pos  = [imgPos(1)+colsW+hGap ax1Pos(2) colsW ax1Pos(4)];
    ax3Pos  = [imgPos(1)+2*colsW+hGap+cbReserve+hGap ax1Pos(2) colsW ax1Pos(4)];
    ax4Pos  = [imgPos(1) imgPos(2) imgPos(3) row2H];
    % axes
    ax1 = axes('Position',ax1Pos);
    ax2 = axes('Position',ax2Pos);
    ax3 = axes('Position',ax3Pos);
    ax4 = axes('Position',ax4Pos);

    % hTitle
    hTitle = annotation('textbox', [0 0.9 1 0.05], ...
        'String', '', ...
        'EdgeColor','none', ...
        'HorizontalAlignment','center', ...
        'FontSize', 12,'FontWeight','bold', ...
        'Interpreter','none');

    HDF5filename = fullfile(pathExportAll, filedataExp.Key(i) + ".h5");
    expCTDataname = fullfile(pathExportAll, filedataExp.Key(i) + ".mat");
    expCTDataTemp = load(expCTDataname);
    expCTData.(filedataExp.Key(i)) = expCTDataTemp.expCTDataSave;

    cmap = flipud(winter(256));
    varsAll = expCTData.(filedataExp.Key(i)).concVarsAll;
    varsAll = varsAll(varsAll.tDtotal < 1,:);

    tDAll = varsAll.tDtotal;
    tDmin = 0;
    tDmax = 1;
    levels = [0.5 0.5];   % contour level, reused for both ax1 and ax2
    levelsFull = 0:0.1:1;  

    % struct array holding one entry per plotted frame
    frames = struct('tD',{},'run_name',{},'k',{},'rotPos',{}, ...
        'color',{},'xD',{},'zD',{},'C',{}, ...
        'xD2',{},'rhoNormVert',{},'hContour',{},'hScatter',{});

    for j = 1:length(expFolderName) % number of runs
        run_name = "run_" + sprintf('%02d', j);
        HDF5dataPath = ['/exp/' char(run_name) '/conc'];
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nx = dims(1);
        ny = dims(2);
        nz = dims(3);

        varsRun = expCTData.(filedataExp.Key(i)).exp.(run_name).concVars;
        tDRun = [varsRun.tDtotal];
        varsRun = varsRun(tDRun < 1);
        tDstep = 0.1;
        tDtargets = min([varsRun.tDtotal]):tDstep:max([varsRun.tDtotal]);
        kPlot = zeros(length(tDtargets),1);
        
        for m = 1:length(tDtargets)
            [~,kPlot(m)] = min(abs([varsRun.tDtotal] - tDtargets(m)));
        end

        kPlot = unique(kPlot,'stable');

        for ii = 1:length(kPlot)
            k = kPlot(ii);
            vars = expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k);
            tD = vars.tDtotal;

            % ax1
            concCTimages = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            imgSmooth = imgaussfilt(concCTimages, 20);
            resXmm = expCTData.(filedataExp.Key(i)).exp.(run_name).pca.Geometry.VoxelSizeX;
            resYmm = expCTData.(filedataExp.Key(i)).exp.(run_name).pca.Geometry.VoxelSizeY;
            xcm = (1:ny)*resXmm/10;
            zcm = (1:nx)*resYmm/10;
            xD = xcm/max(xcm);
            zD = zcm/max(zcm);
            % cidx = round(1 + 255*(tD-tDmin)/(tDmax-tDmin));
            % cidx = max(1,min(256,cidx));
            hold(ax1,'on')
            [C, h] = contour(ax1,xD,zD,imgSmooth,levels, ...
                'LineColor','k',...
                'LineWidth',2.2);
            set(h,'HitTest','off','PickableParts','none');

            % ax3
            x2 = vars.C1Profile.zVertcm;
            xD2 = x2/max(x2);
            y2 = vars.C1Profile.rhoNormVert;
            s = scatter(ax3,xD2,y2,3,'filled','MarkerFaceColor','k');
            set(s,'HitTest','off','PickableParts','none');
            hold(ax3,'on')

            % store this frame (image + BT point NOT plotted yet)
            frames(end+1) = struct( ...
                'tD',tD,'run_name',run_name,'k',k,'rotPos',vars.rotPos, ...
                'color','k','xD',xD,'zD',zD,'C',C, ...
                'xD2',xD2,'rhoNormVert',y2, ...
                'hContour',h,'hScatter',s);

            if isempty(C)
                continue
            end
            npts = C(2,1);
            if npts > 5
                mid = round(npts/2);
                xLab = C(1,mid+1);
                zLab = C(2,mid+1)+0.06;
                % ax1
                text(ax1,xLab,zLab,sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,vars.rotPos),'Color','k',...
                    'FontSize',8,'FontWeight','bold',...
                    'HorizontalAlignment','center',...
                    'BackgroundColor','none','Margin',1,...
                    'HitTest','off','PickableParts','none');
                % ax3
                text(ax3,zLab,0.3, ...
                sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,vars.rotPos),'Color','k', ...
                'FontSize',8,'FontWeight','bold', ...
                'BackgroundColor','w','Margin',1,...
                'HitTest','off','PickableParts','none');

            end        
            
        end
    end
    
    % ax1
    set(ax1,'YDir','reverse','FontSize',8)
    grid(ax1,'on')
    xlabel(ax1,'x_D [-]','FontSize',8)
    ylabel(ax1,'z_D [-]','FontSize',8)
    colormap(ax1,cmap)
    clim(ax1,[tDmin tDmax])
    xlim(ax1,[0 1])            
    ylim(ax1,[0 1])
    title(ax1,'Front advance @ C_D = 0.5','FontSize',9)

    % ax2 - format only, NO image plotted yet (created on first selection)
    axis(ax2,'xy')
    set(ax2,'YDir','reverse')
    xlabel(ax2,'x_D [-]')
    set(ax2,'YTickLabel',[])
    colormap(ax2,turbo)
    clim(ax2,[0 1])
    xlim(ax2,[0 1])           
    ylim(ax2,[0 1])           
    cb2 = colorbar(ax2);
    cb2.Label.String = 'C_1 [-]';
    drawnow
    alignAxesColorbar(ax2, cb2, ax2Pos, cbGap, cbWidth, 'right');
    
    % ax3
    camroll(ax3,270)
    set(ax3,'XTickLabel',[])
    ylabel(ax3,'C_{ave,1} [-]')
    colormap(ax3,cmap)
    clim(ax3,[tDmin tDmax])
    grid(ax3,'on')
    ylim(ax3,[-0.02 1])
    ax3.YAxisLocation = 'right';
    title(ax3,'Vert. conc. profile @ t_D','FontSize',9)

    % ax4 Breakthrough curve (base black data only; red current point deferred)
    BT = expCTData.(filedataExp.Key(i)).BTcore;
    scatter(ax4, BT.tDtotal, BT.rhoNorm,5,'filled',...
        'MarkerFaceColor','k','HitTest','off','PickableParts','none')
    hold(ax4,'on')
    grid(ax4,'on')
    xlabel(ax4,'t_D_{total} [-]')
    ylabel(ax4,'C_{ave,1} [-]')
    ylim(ax4,[-0.02 1])
    xlim(ax4,[BT.tDtotal(1),BT.tDtotal(end)])
    title(ax4,'Breakthrough curve @ z_D = 1','FontSize',9)

    % wire up interactivity
    setappdata(fig,'frames',frames);
    setappdata(fig,'HDF5filename',HDF5filename);
    setappdata(fig,'ax2',ax2);
    setappdata(fig,'ax4',ax4);
    setappdata(fig,'levels',levels);
    setappdata(fig,'levelsFull',levelsFull);
    setappdata(fig,'hImgAx2',gobjects(0));
    setappdata(fig,'hContourAx2',gobjects(0));   
    setappdata(fig,'hCurrentAx4',gobjects(0));  
    setappdata(fig,'hTitle',hTitle);
    setappdata(fig,'keyName',filedataExp.Key(i));
    setappdata(fig,'pathExportAll',pathExportAll);
    setappdata(fig,'selectedIdx',[]);

    ax1.ButtonDownFcn = @(src,evt) axesClickCallback(fig, ax1, 'ax1');
    ax4.ButtonDownFcn = @(src,evt) axesClickCallback(fig, ax4, 'ax4');
end

% local functions

function alignAxesColorbar(ax, cb, axPos, cbGap, cbWidth, side)
    if nargin < 6
        side = 'right';
    end
    ax.Units = 'normalized';
    cb.Units = 'normalized';
    ax.Position = axPos;

    switch side
        case 'right'
            cbLeft = axPos(1) + axPos(3) + cbGap;
        case 'left'
            cbLeft = axPos(1) - cbGap - cbWidth;
        otherwise
            error('side must be ''left'' or ''right''');
    end

    cb.Position = [cbLeft, axPos(2), cbWidth, axPos(4)];
end

function [xs, ys] = contourMatrixPoints(C)
    xs = [];
    ys = [];
    idx = 1;
    n = size(C,2);
    while idx <= n
        npts = C(2,idx);
        segX = C(1, idx+1 : idx+npts);
        segY = C(2, idx+1 : idx+npts);
        xs = [xs, segX]; 
        ys = [ys, segY]; 
        idx = idx + npts + 1;
    end
end

function axesClickCallback(fig, ax, axName)
    cp = get(ax,'CurrentPoint');
    xClick = cp(1,1);
    zClick = cp(1,2);

    frames = getappdata(fig,'frames');
    if isempty(frames)
        return
    end

    bestIdx = [];
    switch axName
        case 'ax1'
            bestDist = Inf;
            for idx = 1:numel(frames)
                [xs, ys] = contourMatrixPoints(frames(idx).C);
                if isempty(xs)
                    continue
                end
                d = (xs - xClick).^2 + (ys - zClick).^2;
                dm = min(d);
                if dm < bestDist
                    bestDist = dm;
                    bestIdx = idx;
                end
            end
        case 'ax4'
            allTD = [frames.tD];
            [~,bestIdx] = min(abs(allTD - xClick));
    end

    if ~isempty(bestIdx)
        updateSelection(fig, bestIdx);
    end
end

function updateSelection(fig, idx)
    frames        = getappdata(fig,'frames');
    prevIdx       = getappdata(fig,'selectedIdx');
    HDF5filename  = getappdata(fig,'HDF5filename');
    ax2           = getappdata(fig,'ax2');
    ax4           = getappdata(fig,'ax4');
    levels        = getappdata(fig,'levels');
    levelsFull    = getappdata(fig,'levelsFull');
    hImgAx2       = getappdata(fig,'hImgAx2');
    hContourAx2   = getappdata(fig,'hContourAx2');
    hContourAx2Hi = getappdata(fig,'hContourAx2Hi');
    hCurrentAx4   = getappdata(fig,'hCurrentAx4');
    hTitle        = getappdata(fig,'hTitle');
    keyName       = getappdata(fig,'keyName');
    pathExportAll = getappdata(fig,'pathExportAll');

    % restore previous highlight
    if ~isempty(prevIdx) && prevIdx <= numel(frames)
        set(frames(prevIdx).hContour,'LineColor',frames(prevIdx).color,'LineWidth',3);
        set(frames(prevIdx).hScatter,'MarkerFaceColor',frames(prevIdx).color,'SizeData',8);
    end

    % apply new highlight
    set(frames(idx).hContour,'LineColor','r','LineWidth',3);
    set(frames(idx).hScatter,'MarkerFaceColor','r','SizeData',8);

    % re-read raw frame and recompute the smoothed field (cheap, done once per click)
    HDF5dataPath = ['/exp/' char(frames(idx).run_name) '/conc'];
    info = h5info(HDF5filename, HDF5dataPath);
    dims = info.Dataspace.Size;
    nx = dims(1); ny = dims(2);
    concCTimages = h5read(HDF5filename, HDF5dataPath, [1 1 frames(idx).k], [nx ny 1]);
    imgSmooth = imgaussfilt(concCTimages, 20);

    % ax2 image: create on first use, otherwise just update it
    if isempty(hImgAx2) || ~isvalid(hImgAx2)
        hold(ax2,'on')
        hImgAx2 = imagesc(ax2, frames(idx).xD, frames(idx).zD, concCTimages);
        uistack(hImgAx2,'bottom');   % keep it under the contours
    else
        set(hImgAx2,'CData',concCTimages,'XData',frames(idx).xD,'YData',frames(idx).zD);
    end
    setappdata(fig,'hImgAx2',hImgAx2);

    % ax2 highlighted C = 0.5 contour (thicker, drawn on top)
    if ~isempty(hContourAx2Hi) && isvalid(hContourAx2Hi)
        delete(hContourAx2Hi);
    end
    [~, hContourAx2Hi] = contour(ax2, frames(idx).xD, frames(idx).zD, imgSmooth, levels, ...
        'LineColor','k','LineWidth',3, 'ShowText',true);
    set(hContourAx2Hi,'HitTest','off','PickableParts','none');
    uistack(hContourAx2Hi,'top');
    setappdata(fig,'hContourAx2Hi',hContourAx2Hi);

    % ax2 full contour set 0:0.1:1 (thin, white, labeled)
    if ~isempty(hContourAx2) && isvalid(hContourAx2)
        delete(hContourAx2);
    end
    [~, hContourAx2] = contour(ax2, frames(idx).xD, frames(idx).zD, imgSmooth, levelsFull, ...
        'LineColor','k','LineWidth',1,'ShowText',true,'LabelFormat',"%0.1f");
    set(hContourAx2,'HitTest','off','PickableParts','none');
    setappdata(fig,'hContourAx2',hContourAx2);

    % keep ax2's box pinned regardless of what imagesc/contour touched
    xlim(ax2,[0 1]);
    ylim(ax2,[0 1]);

    % ax4: create the red current-point marker on first use
    if isempty(hCurrentAx4) || ~isvalid(hCurrentAx4)
        hCurrentAx4 = scatter(ax4, frames(idx).tD, frames(idx).rhoNormVert(end), ...
            80, 'r', 'filled');
    else
        set(hCurrentAx4,'XData',frames(idx).tD,'YData',frames(idx).rhoNormVert(end));
    end
    setappdata(fig,'hCurrentAx4',hCurrentAx4);

    % update title
    if ~isempty(hTitle) && isvalid(hTitle)
        hTitle.String = sprintf('%s - CT %s, tD = %.1f, theta = %.0f°', ...
                char(keyName), frames(idx).run_name, frames(idx).tD, frames(idx).rotPos);
        title(ax2, sprintf('Concentration map @ t_D = %.1f', frames(idx).tD), 'FontSize', 9)
    end

    setappdata(fig,'selectedIdx',idx);

    % save the completed figure for this selection
    tDStr = strrep(sprintf('%.1f', frames(idx).tD), '.', 'p');  % e.g. 0.50 -> 0p50
    fname = sprintf('%s_tD%s_%s', char(keyName), tDStr, frames(idx).run_name);
    saveas(fig, fullfile(pathExportAll, fname), 'png');
    saveas(fig, fullfile(pathExportAll, fname), 'fig');
end

function selectFrameByTD(fig, tDQuery)
    frames = getappdata(fig,'frames');
    if isempty(frames)
        warning('No frame data available for this figure.');
        return
    end
    allTD = [frames.tD];
    [~,idx] = min(abs(allTD - tDQuery));
    updateSelection(fig, idx);
end