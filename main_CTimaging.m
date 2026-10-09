
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

% One exp at a time
Root = CT_setupPaths;   % absolute path to the BTC repo, from your existing setup

% Introduce name of input and desired output folder name

inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

%% Import params and load data

nExp = height(inputFileConfig);
filedataExpAll   = cell(nExp,1);
expCTDataAll     = cell(nExp,1);
MFM_CT_DataAll   = cell(nExp,1);
MFM_UHS_DataAll  = cell(nExp,1);
HDF5filenameAll  = cell(nExp,1);
interpFcnAll     = cell(nExp,1);
expFolderNameAll = cell(nExp,1);
pathExportAllVec = cell(nExp,1);
dataSourceAll    = cell(nExp,1);

for i = 1:nExp

    filenameExp = inputFileConfig.inputFileName{i};

    pathExportAll = inputFileConfig.exportPath{i}; % Path for OUTPUT
    mkdir(pathExportAll); % Create directory for output
    dataSource = inputFileConfig.dataSource{i};   % "rhoNorm" or "conc"
    if ~ismember(dataSource, {'rhoNorm','conc'})
        error('dataSource must be "rhoNorm" or "conc", got "%s"', dataSource);
    end

    filedataExp = import_inputCTExp(filenameExp); % import input to a local variable
        
    % Capture exp data folder (for run numbers)
    expFolderContent = dir(filedataExp.path+filedataExp.CT_data_exp); % exp
    expFolderContent = expFolderContent([expFolderContent.isdir] & ~startsWith({expFolderContent.name},'.'));
    expFolderName = {expFolderContent.name}';

    HDF5filename = fullfile(pathExportAll, filedataExp.Key + ".h5");
    expCTDataname = fullfile(pathExportAll, filedataExp.Key + ".mat");
    expCTDataTemp = load(expCTDataname);

    % interpolant for composition form array 0 to 1 (binary mixture)
    interpFcn = buildInterpolant(filedataExp.Fluid1, ...
        filedataExp.Fluid2, filedataExp.T, filedataExp.P);

    pathImport_MFM_CT = inputFileConfig.MFM_BTC_CT_Path{i};   % "../results/exp_He-Xe-T20-V_REFPROP/"
    pathImport_MFM_UHS = inputFileConfig.MFM_BTC_UHS_Path{i};   % "../results/exp_H2-CG-T40-P1160-V_REFPROP/"
    MFM_CT_name = inputFileConfig.MFM_BTC_CT_Key{i};
    MFM_UHS_name = inputFileConfig.MFM_BTC_UHS_Key{i};
    % main_Processing in other should have been executed first
    MFM_CT_file = fullfile(Root, pathImport_MFM_CT, 'expProcFullData.mat');
    MFM_UHS_file = fullfile(Root, pathImport_MFM_UHS, 'expProcFullData.mat');
    % load processed MFM data
    MFM_CT_Data = load(MFM_CT_file);
    MFM_UHS_Data = load(MFM_UHS_file);

    filedataExpAll{i}   = filedataExp;
    expCTDataAll{i}     = expCTDataTemp.expCTDataSave;
    MFM_CT_DataAll{i}   = MFM_CT_Data.expProcFullData.(MFM_CT_name);
    MFM_UHS_DataAll{i}  = MFM_UHS_Data.expProcFullData.(MFM_UHS_name);
    HDF5filenameAll{i}  = HDF5filename;
    interpFcnAll{i}     = interpFcn;
    expFolderNameAll{i} = expFolderName;
    pathExportAllVec{i} = pathExportAll;
    dataSourceAll{i}    = dataSource;

end   

% set tDmax
tDmax = 2.0;

%% Imaging movie

for i = 1:nExp

    filedataExp   = filedataExpAll{i};
    pathExportAll = pathExportAllVec{i};
    dataSource    = dataSourceAll{i};
    HDF5filename  = HDF5filenameAll{i};
    interpFcn     = interpFcnAll{i};
    expFolderName = expFolderNameAll{i};
    expProcFullData_MFM_CT  = MFM_CT_DataAll{i};   % only used in Interactive imaging & Countour map
    expProcFullData_MFM_UHS = MFM_UHS_DataAll{i};

    expCTData = struct();
    expCTData.(filedataExp.Key) = expCTDataAll{i};

    fprintf('Running imaging movie %s\n',filedataExp.Key)
    
    fig = figure('Position', [50, 50, 600, 1000]); % [left, bottom, width, height];
    frame = getframe(fig);
    v = VideoWriter(pathExportAll + "movie_" + filedataExp.Key + "_" + dataSource, 'MPEG-4');
    v.FrameRate = 100;   % frames per second
    open(v);
    writeVideo(v, frame);
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
    
        for k = 1:nz
            vars = expCTData.(filedataExp.Key).exp.(run_name).vars.(dataSource)(k);
    
            % hTitle
            set(hTitle, 'String', ...
                filedataExp.Key + ": CT " + dataSource + " " + run_name + ...
                " ImgNumber_" + sprintf('%03d', k));
    
            % plot concentration in x ax1
            x1 = vars.C1Axial.xHorzcm;
            xD1 = x1 / max(x1);
            y1 = vars.C1Axial.CHorz;
            cla(ax1)
            plot(ax1, xD1, y1,'LineWidth',2)
            xlim(ax1,[0 1])
            ylim(ax1,[-0.02 1])
            xlabel(ax1,'x_D [-]')
            ylabel(ax1,'C_{ave}_1 [-]')
            title(ax1,"timeElapsed: " + vars.secondsElapsed + ...
                      " s, volInjected: " + sprintf('%.2f', vars.volInjected) + ...
                      " mL, tD: " + sprintf('%.3f', vars.tDtotal))
            grid(ax1,'on')
    
            % plot concentration in z ax4
            x2 = vars.C1Profile.zVertcm;
            zD2 = x2 / max(x2);
            y2 = vars.C1Profile.CVert;
            cla(ax4)
            plot(ax4, zD2, y2,'LineWidth',2)
            xlabel(ax4,'z_D [-]')
            ylabel(ax4,'C_{ave}_1 [-]')
            grid(ax4,'on')          
            axis(ax4,'tight')
            axis(ax4,'manual')
            camroll(ax4,270)
            ylim(ax4,[-0.02 1])
            ax4.YAxisLocation = 'right';
    
            % plot image ax3
            rhoNormImage = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            if strcmp(dataSource,'conc')
                plotImage = interpFcn(rhoNormImage);
            else
                plotImage = rhoNormImage;
            end
            imgSmooth = imgaussfilt(plotImage, 20);
            resXmm = expCTData.(filedataExp.Key).exp.(run_name).pca.Geometry.VoxelSizeX;
            resYmm = expCTData.(filedataExp.Key).exp.(run_name).pca.Geometry.VoxelSizeY;
            xcm = (1:ny)*resXmm/10;
            zcm = (1:nx)*resYmm/10;
            xD = xcm/max(xcm);
            zD = zcm/max(zcm);
    
            cla(ax3)
            imagesc(ax3, xD, zD, plotImage)
            axis(ax3,'xy','fill')
            set(ax3,'YDir','reverse')
            xlabel(ax3,'x_D [-]')
            ylabel(ax3,'z_D [-]')
            % nLevels = 10;
            % cmap = turbo(nLevels);
            % colormap(ax3,cmap)
            colormap(ax3,turbo)
            clim(ax3,[0 1]);
            cb = colorbar(ax3,'Position',cbPos);
            cb.Label.String = 'C_1 [-]';
            % levels = 0:0.1:1;
            % hold(ax3,'on')
            % contour(ax3, imgSmooth, levels, ...
            %     'LineColor','k', ...
            %     'LineWidth',1,'ShowText',true,'LabelFormat',"%0.1f")
            % hold(ax3,'off')
    
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
            BTdata = expCTData.(filedataExp.Key).varsAll.(dataSource); 
            tmax = interp1(BTdata.tDtotal, BTdata.secondsElapsed, tDmax, 'linear','extrap');
            scatter(ax5,t,C,15,'filled','MarkerFaceColor',[0, 0.4470, 0.7410],'MarkerEdgeColor','none')
            hold(ax5,'on')
            ylim(ax5,[-0.02 1])
            xlim(ax5,[0,tmax])
            xlabel(ax5,'secondsElapsed')
            ylabel(ax5,'C_{ave}_1 [-]')
            grid(ax5, 'on')
    
            % sync ax5b's ticks to show tD instead of raw seconds
            xt = ax5.XTick;
            tDtick = xt * (tDmax / tmax);
            ax5b.XTick = xt;
            ax5b.XTickLabel = compose('%.2f', tDtick);
            xlabel(ax5b,'t_D [-]')
    
            drawnow;
            frame = getframe(fig);  % capture frame
            writeVideo(v, frame); % write to movie
        end
    end
    close(v)

end

%% Interactive imaging

for i = 1:nExp

    filedataExp   = filedataExpAll{i};
    pathExportAll = pathExportAllVec{i};
    dataSource    = dataSourceAll{i};
    HDF5filename  = HDF5filenameAll{i};
    interpFcn     = interpFcnAll{i};
    expFolderName = expFolderNameAll{i};
    expProcFullData_MFM_CT  = MFM_CT_DataAll{i};   % only used in Interactive imaging & Countour map
    expProcFullData_MFM_UHS = MFM_UHS_DataAll{i};

    expCTData = struct();
    expCTData.(filedataExp.Key) = expCTDataAll{i};

    fprintf('Running interactive imaging %s\n',filedataExp.Key)

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
    hold(ax5,'on')
    
    % store BT
    BT.t = [];
    BT.tD = [];
    BT.C = [];
    BT.Cmid = [];
    BT.Cinlet = [];
    BT.j = [];
    BT.k = [];
    
    for j = 1:length(expFolderName)
    
        run_name = "run_" + sprintf('%02d', j);
        HDF5dataPath = ['/exp/' char(run_name) '/conc'];
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nz = dims(3);
    
        for k = 1:nz
    
            vars = expCTData.(filedataExp.Key).exp.(run_name).vars.(dataSource)(k);
    
            % breakthrough point
            t = vars.secondsElapsed;
            tD = vars.tDtotal;
            C = vars.CD1_zD1p0;
            Cmid = vars.CD1_zD0p5;
            Cinlet = vars.CD1_zD0p0;
    
            % store
            BT.t(end+1) = t;
            BT.tD(end+1) = tD;
            BT.C(end+1) = C;
            BT.Cmid(end+1) = Cmid;
            BT.Cinlet(end+1) = Cinlet;
            BT.j(end+1) = j;
            BT.k(end+1) = k;
    
        end
    end
        
    % plot BT
    colors = get(groot,'defaultAxesColorOrder');
    scatter(ax5, BT.tD, BT.Cinlet, 8, ...
        'filled', 'MarkerFaceColor',[0.75 0.75 0.75], 'MarkerEdgeColor','none', ...
        'HitTest','off','PickableParts','none', ...
        'DisplayName','CT analog BTC (zD=0.0, inlet)');
    scatter(ax5, BT.tD, BT.Cmid, 8, ...
        'filled', 'MarkerFaceColor',[0.5 0.5 0.5], 'MarkerEdgeColor','none', ...
        'HitTest','off','PickableParts','none', ...
        'DisplayName','CT analog BTC (zD=0.5, mid-core)');
    hold(ax5,'on')
    hScatter = scatter(ax5, BT.tD, BT.C, 8, ...
        'filled', ...
        'MarkerFaceColor','k', ...
        'MarkerEdgeColor','none','DisplayName','CT analog BTC (zD=1.0, outlet)');
    scatter(ax5, expProcFullData_MFM_CT.BT.tDtotal, expProcFullData_MFM_CT.BT.CDi, 8, ...
        'filled', ...
        'MarkerFaceColor',colors(1,:), ...
        'MarkerEdgeColor','none','DisplayName','MFM_analog_BTC');
    scatter(ax5, expProcFullData_MFM_UHS.BT.tDtotal, expProcFullData_MFM_UHS.BT.CDi, 8, ...
        'filled', ...
        'MarkerFaceColor',colors(3,:), ...
        'MarkerEdgeColor','none','DisplayName','MFM_UHS_BTC');
    xlim(ax5,[0 tDmax])
    ylim(ax5,[-0.02 1])
    xlabel(ax5,'t_D [-]')
    ylabel(ax5,'C_{ave}_1 [-]')
    legend(ax5, 'Location','southeast','Interpreter','none')
    grid(ax5,'on')
    
    % Selected point marker
    hSelected = scatter(ax5, NaN, NaN, 40, ...
        'filled', 'MarkerFaceColor','r', 'MarkerEdgeColor','k', ...
        'Visible','off','HandleVisibility','off');
    
    hSelectedLine = xline(ax5, NaN, '--r', 'LineWidth', 2, 'DisplayName','');
    
    hTitle = annotation('textbox', [0 0.93 1 0.05], ...
        'String', '', ...
        'EdgeColor','none', ...
        'HorizontalAlignment','center', ...
        'FontWeight','bold', ...
        'Interpreter','none');
    
    % callback part
    hScatter.ButtonDownFcn = @(src,event) ...
        onClickCallback(src,event,pathExportAll,hSelected, hSelectedLine, ...
        BT, expCTData,filedataExp,interpFcn,dataSource, ...
        ax1,ax2,ax3,ax4,cbPos,hTitle);

end

%% 3D front reconstruction across rotation angles (ghosted, no time correction)

for i = 1:nExp

    filedataExp   = filedataExpAll{i};
    pathExportAll = pathExportAllVec{i};
    dataSource    = dataSourceAll{i};
    HDF5filename  = HDF5filenameAll{i};
    interpFcn     = interpFcnAll{i};
    expFolderName = expFolderNameAll{i};
    expProcFullData_MFM_CT  = MFM_CT_DataAll{i};   % only used in Interactive imaging & Countour map
    expProcFullData_MFM_UHS = MFM_UHS_DataAll{i};

    expCTData = struct();
    expCTData.(filedataExp.Key) = expCTDataAll{i};

    fprintf('3D contours imaging %s\n',filedataExp.Key)

    fig3D = figure('Position',[100 100 900 800]);
    hold on
    
    % transparent reference cylinder, shifted to [0,1] range
    [Xc, Yc, Zc] = cylinder(0.5, 60);
    Xc = Xc + 0.5;
    Yc = Yc + 0.5;
    surf(Xc, Yc, Zc, 'FaceAlpha',0.08, 'EdgeColor','none', 'FaceColor',[0.6 0.6 0.9])
    
    cmap = winter(256);
    level = [0.5 0.5];
    
    thetaFull = linspace(0, 2*pi, 200);
    xBase = 0.5 + 0.5*sin(thetaFull);
    yBase = 0.5 - 0.5*cos(thetaFull);
    plot3(xBase, yBase, ones(size(thetaFull)), 'k-', 'LineWidth',1)   % z=1, was z=0
    
    angleTicks = 0:30:330;
    rTick = 0.58;
    rTickLine = [0.5 0.56];
    for a = angleTicks
        theta = deg2rad(a);
        xTick = 0.5 + rTickLine*sin(theta);
        yTick = 0.5 - rTickLine*cos(theta);
        plot3(xTick, yTick, [1 1], 'k-', 'LineWidth',1)   % z=1, was z=0
    
        xLab = 0.5 + rTick*sin(theta);
        yLab = 0.5 - rTick*cos(theta);
        text(xLab, yLab, 1, sprintf('%d°', a), ...   % z=1, was z=0
            'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
            'FontSize',8, 'Color',[0.3 0.3 0.3])
    end
    
    for j = 1:length(expFolderName)
        run_name = "run_" + sprintf('%02d', j);
        HDF5dataPath = ['/exp/' char(run_name) '/conc'];
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nx = dims(1); ny = dims(2); nz = dims(3);
    
        varsRun = expCTData.(filedataExp.Key).exp.(run_name).vars.(dataSource);
        tDRun = [varsRun.tDtotal];
    
        % --- fixed tD grid, same for every experiment regardless of flow rate ---
        tDtargets = 0.05:0.05:1.0;
        plotIdx = nan(size(tDtargets));
        for m = 1:length(tDtargets)
            [minDist, idx] = min(abs(tDRun - tDtargets(m)));
            if minDist > 0.025   % half the grid spacing; flag if nothing close enough
                warning('run %s: no scan close to tD=%.2f (nearest %.3f, off by %.3f)', ...
                    run_name, tDtargets(m), tDRun(idx), minDist);
                continue
            end
            plotIdx(m) = idx;
        end
        plotIdx = plotIdx(~isnan(plotIdx));
        plotIdx = unique(plotIdx, 'stable');
    
        for ii = 1:length(plotIdx)
            k = plotIdx(ii);
            vars = varsRun(k);
            tD = vars.tDtotal;
            theta = deg2rad(vars.rotPos);
    
            rhoNormImage = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            if strcmp(dataSource,'conc')
                plotImage = interpFcn(rhoNormImage);
            else
                plotImage = rhoNormImage;
            end
            imgSmooth = imgaussfilt(double(plotImage), 20);
            C = contourc(imgSmooth, level);
            if isempty(C), continue; end
            [xpx, zpx] = contourMatrixPoints(C);
            xD = xpx / size(imgSmooth,2);
            zD = zpx / size(imgSmooth,1);
    
            X = (xD - 0.5) * cos(theta) + 0.5;
            Y = (xD - 0.5) * sin(theta) + 0.5;
            Z = zD;
    
            cidx = round(1 + 255*tD);
            cidx = max(1,min(256,cidx));
    
            scatter3(X, Y, Z, 8, cmap(cidx,:), 'filled')
        end
    end
    
    xlabel('X_D [-]'); ylabel('Y_D [-]'); zlabel('Z_D [-]')
    xlim([0 1]); ylim([0 1]); zlim([0 1])
    axis equal
    set(gca,'ZDir','reverse')   % zD=0 at top
    view(45,20)
    colormap(cmap)
    clim([0 1])
    cb = colorbar;
    cb.Label.String = 't_D [-]';
    cb.Direction = 'reverse';   % tD=0 at top of colorbar, matching zD=0 at top of plot
    title({sprintf('%s: 3D front (C=0.5), no time correction (%s)', char(filedataExp.Key), dataSource), ...
        'Ghosting/blur reflects true front advance during each rotation cycle'}, ...
        'Interpreter','none','FontSize',9)
    grid on
    box on
    
    fname3D = sprintf('front3D_%s_%s', char(filedataExp.Key), dataSource);
    if ~isfolder(pathExportAll), mkdir(pathExportAll); end
    saveas(fig3D, fullfile(pathExportAll, fname3D), 'png');
    saveas(fig3D, fullfile(pathExportAll, fname3D), 'fig');

end

%% Countour map (batch save, all contours)

for i = 1:nExp

    filedataExp   = filedataExpAll{i};
    pathExportAll = pathExportAllVec{i};
    dataSource    = dataSourceAll{i};
    HDF5filename  = HDF5filenameAll{i};
    interpFcn     = interpFcnAll{i};
    expFolderName = expFolderNameAll{i};
    expProcFullData_MFM_CT  = MFM_CT_DataAll{i};
    expProcFullData_MFM_UHS = MFM_UHS_DataAll{i};

    expCTData = struct();
    expCTData.(filedataExp.Key) = expCTDataAll{i};

    fprintf('Contour map batch save %s\n',filedataExp.Key)

    fig = figure('Position', [50, 50, 800, 1000]);

    % figure config
    imgPos  = [0.1 0.1  0.8 0.8];
    hGap = 0.07;
    vGap = 0.07;
    cbGap      = 0.012;
    cbWidth    = 0.018;
    cbLabelPad = 0.03;
    cbReserve  = cbGap + cbWidth + cbLabelPad;
    colsW = (imgPos(3) - 2*hGap - cbReserve)/3;
    row1H = imgPos(4)*3/4 - vGap;
    row2H = imgPos(4)/4;
    ax1Pos  = [imgPos(1) imgPos(2)+row2H+vGap colsW row1H];
    ax2Pos  = [imgPos(1)+colsW+hGap ax1Pos(2) colsW ax1Pos(4)];
    ax3Pos  = [imgPos(1)+2*colsW+hGap+cbReserve+hGap ax1Pos(2) colsW ax1Pos(4)];
    ax4Pos  = [imgPos(1) imgPos(2) imgPos(3) row2H];
    ax1 = axes('Position',ax1Pos);
    ax2 = axes('Position',ax2Pos);
    ax3 = axes('Position',ax3Pos);
    ax4 = axes('Position',ax4Pos);

    hTitle = annotation('textbox', [0 0.9 1 0.05], ...
        'String', '', 'EdgeColor','none', ...
        'HorizontalAlignment','center', ...
        'FontSize', 12,'FontWeight','bold', 'Interpreter','none');

    cmap = flipud(winter(256));
    varsAll = expCTData.(filedataExp.Key).varsAll.(dataSource);
    varsAll = varsAll(varsAll.tDtotal < 1,:);

    tDAll = varsAll.tDtotal;
    tDminContours = 0;
    tDmaxContours = 1;
    levels = [0.5 0.5];
    levelsFull = 0:0.1:1;

    frames = struct('tD',{},'run_name',{},'k',{},'rotPos',{}, ...
        'color',{},'xD',{},'zD',{},'C',{}, ...
        'xD2',{},'CVert',{},'hContour',{},'hScatter',{});

    for j = 1:length(expFolderName)
        run_name = "run_" + sprintf('%02d', j);
        HDF5dataPath = ['/exp/' char(run_name) '/conc'];
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nx = dims(1);
        ny = dims(2);
        nz = dims(3);

        varsRun = expCTData.(filedataExp.Key).exp.(run_name).vars.(dataSource);
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
            vars = expCTData.(filedataExp.Key).exp.(run_name).vars.(dataSource)(k);
            tD = vars.tDtotal;

            rhoNormImage = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            if strcmp(dataSource,'conc')
                plotImage = interpFcn(rhoNormImage);
            else
                plotImage = rhoNormImage;
            end
            imgSmooth = imgaussfilt(plotImage, 20);
            resXmm = expCTData.(filedataExp.Key).exp.(run_name).pca.Geometry.VoxelSizeX;
            resYmm = expCTData.(filedataExp.Key).exp.(run_name).pca.Geometry.VoxelSizeY;
            xcm = (1:ny)*resXmm/10;
            zcm = (1:nx)*resYmm/10;
            xD = xcm/max(xcm);
            zD = zcm/max(zcm);
            hold(ax1,'on')
            [C, h] = contour(ax1,xD,zD,imgSmooth,levels, ...
                'LineColor','k','LineWidth',2.2);
            set(h,'HitTest','off','PickableParts','none');

            x2 = vars.C1Profile.zVertcm;
            xD2 = x2/max(x2);
            y2 = vars.C1Profile.CVert;
            s = scatter(ax3,xD2,y2,3,'filled','MarkerFaceColor','k');
            set(s,'HitTest','off','PickableParts','none');
            hold(ax3,'on')

            frames(end+1) = struct( ...
                'tD',tD,'run_name',run_name,'k',k,'rotPos',vars.rotPos, ...
                'color','k','xD',xD,'zD',zD,'C',C, ...
                'xD2',xD2,'CVert',y2, ...
                'hContour',h,'hScatter',s);

            if isempty(C)
                continue
            end
            npts = C(2,1);
            if npts > 5
                mid = round(npts/2);
                xLab = C(1,mid+1);
                zLab = C(2,mid+1)+0.06;
                text(ax1,xLab,zLab,sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,vars.rotPos),'Color','k', ...
                    'FontSize',8,'FontWeight','bold', ...
                    'HorizontalAlignment','center', ...
                    'BackgroundColor','none','Margin',1, ...
                    'HitTest','off','PickableParts','none');
                text(ax3,zLab,0.3, ...
                    sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,vars.rotPos),'Color','k', ...
                    'FontSize',8,'FontWeight','bold', ...
                    'BackgroundColor','w','Margin',1, ...
                    'HitTest','off','PickableParts','none');
            end
        end
    end

    set(ax1,'YDir','reverse','FontSize',8)
    grid(ax1,'on')
    xlabel(ax1,'x_D [-]','FontSize',8)
    ylabel(ax1,'z_D [-]','FontSize',8)
    colormap(ax1,cmap)
    clim(ax1,[tDminContours tDmaxContours])
    xlim(ax1,[0 1])
    ylim(ax1,[0 1])
    title(ax1,'Front advance @ C_D = 0.5','FontSize',9)

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

    camroll(ax3,270)
    set(ax3,'XTickLabel',[])
    ylabel(ax3,'C_{ave,1} [-]')
    colormap(ax3,cmap)
    clim(ax3,[tDminContours tDmaxContours])
    grid(ax3,'on')
    ylim(ax3,[-0.02 1])
    ax3.YAxisLocation = 'right';
    title(ax3,'Vert. conc. profile @ t_D','FontSize',9)

    BTdata = expCTData.(filedataExp.Key).varsAll.(dataSource);
    colors = get(groot,'defaultAxesColorOrder');

    zDoutlet = 'CD1_zD1p0';
    zDmid    = 'CD1_zD0p5';
    zDinlet  = 'CD1_zD0p0';

    scatter(ax4, BTdata.tDtotal, BTdata.(zDinlet), 8, 'filled', ...
        'MarkerFaceColor',[0.75 0.75 0.75], ...
        'HitTest','off','PickableParts','none', ...
        'DisplayName','CT analog BTC (zD=0.0, inlet)');
    hold(ax4,'on')
    scatter(ax4, BTdata.tDtotal, BTdata.(zDmid), 8, 'filled', ...
        'MarkerFaceColor',[0.5 0.5 0.5], ...
        'HitTest','off','PickableParts','none', ...
        'DisplayName','CT analog BTC (zD=0.5, mid-core)');
    scatter(ax4, BTdata.tDtotal, BTdata.(zDoutlet), 8, 'filled', ...
        'MarkerFaceColor','k', ...
        'HitTest','off','PickableParts','none', ...
        'DisplayName','CT analog BTC (zD=1.0, outlet)');
    scatter(ax4, expProcFullData_MFM_CT.BT.tDtotal, expProcFullData_MFM_CT.BT.CDi, ...
        8, 'filled', 'MarkerFaceColor',colors(1,:), ...
        'HitTest','off','PickableParts','none', 'DisplayName','MFM analog BTC');
    scatter(ax4, expProcFullData_MFM_UHS.BT.tDtotal, expProcFullData_MFM_UHS.BT.CDi, ...
        8, 'filled', 'MarkerFaceColor',colors(3,:), ...
        'HitTest','off','PickableParts','none', 'DisplayName','MFM UHS BTC');
    grid(ax4,'on')
    xlabel(ax4,'t_D_{total} [-]')
    ylabel(ax4,'C_{ave,1} [-]')
    ylim(ax4,[-0.02 1])
    xlim(ax4,[0,tDmax])
    legend(ax4, 'Location','southeast','Interpreter','none')
    title(ax4,'Breakthrough curve @ zD = 0.0, 0.5 and 1.0','FontSize',9)

    setappdata(fig,'frames',frames);
    setappdata(fig,'HDF5filename',HDF5filename);
    setappdata(fig,'interpFcn',interpFcn);
    setappdata(fig,'ax2',ax2);
    setappdata(fig,'ax4',ax4);
    setappdata(fig,'levels',levels);
    setappdata(fig,'levelsFull',levelsFull);
    setappdata(fig,'hImgAx2',gobjects(0));
    setappdata(fig,'hContourAx2',gobjects(0));
    setappdata(fig,'hCurrentAx4',gobjects(0));
    setappdata(fig,'hTitle',hTitle);
    setappdata(fig,'keyName',filedataExp.Key);
    setappdata(fig,'pathExportAll',pathExportAll);
    setappdata(fig,'selectedIdx',[]);
    setappdata(fig,'dataSource',dataSource);

    for idx = 1:numel(frames)
        saveFrame(fig, idx);
    end

    close(fig)
end

%% Countour map (batch save, multi-level overlay C=0.16/0.5/0.84)

for i = 1:nExp

    filedataExp   = filedataExpAll{i};
    pathExportAll = pathExportAllVec{i};
    dataSource    = dataSourceAll{i};
    HDF5filename  = HDF5filenameAll{i};
    interpFcn     = interpFcnAll{i};
    expFolderName = expFolderNameAll{i};
    expProcFullData_MFM_CT  = MFM_CT_DataAll{i};
    expProcFullData_MFM_UHS = MFM_UHS_DataAll{i};

    expCTData = struct();
    expCTData.(filedataExp.Key) = expCTDataAll{i};

    fprintf('Contour map batch save (multi-level overlay) %s\n',filedataExp.Key)

    colsW_px   = 160;   % same tile width as original ax1/ax2/ax3
    row1H_px   = 530;   % same tile height as original
    row2H_px   = 200;   % same BTC-row height as original
    hGap_px    = 56;    % same horizontal gap as original
    vGap_px    = 70;    % same vertical gap as original
    cbGap_px      = 10;
    cbWidth_px    = 14;
    cbLabelPad_px = 24;
    cbReserve_px  = cbGap_px + cbWidth_px + cbLabelPad_px;
    leftMargin_px  = 80;
    rightMargin_px = 80;
    bottomMargin_px = 100;
    topMargin_px    = 100;  % room for hTitle

    figWidth  = leftMargin_px + 5*colsW_px + 4*hGap_px + cbReserve_px + rightMargin_px;
    figHeight = bottomMargin_px + row2H_px + vGap_px + row1H_px + topMargin_px;

    fig = figure('Position', [50, 50, figWidth, figHeight]);

    imgPos = [leftMargin_px/figWidth, bottomMargin_px/figHeight, ...
              (figWidth-leftMargin_px-rightMargin_px)/figWidth, ...
              (figHeight-bottomMargin_px-topMargin_px)/figHeight];
    hGap = hGap_px/figWidth;
    vGap = vGap_px/figHeight;
    cbGap = cbGap_px/figWidth;
    cbWidth = cbWidth_px/figWidth;
    cbReserve = cbReserve_px/figWidth;
    colsW = colsW_px/figWidth;
    row1H = row1H_px/figHeight;
    row2H = row2H_px/figHeight;

    xExtra1 = imgPos(1);
    xExtra2 = xExtra1 + colsW + hGap;
    x1      = xExtra2 + colsW + hGap;
    x2      = x1 + colsW + hGap;
    x3      = x2 + colsW + hGap + cbReserve;
    rowY = imgPos(2) + row2H + vGap;

    axExtra1Pos = [xExtra1 rowY colsW row1H];
    axExtra2Pos = [x1      rowY colsW row1H];
    ax1Pos      = [xExtra2 rowY colsW row1H];
    ax2Pos      = [x2      rowY colsW row1H];
    ax3Pos      = [x3      rowY colsW row1H];
    ax4Pos      = [imgPos(1) imgPos(2) imgPos(3) row2H];

    axExtra1 = axes('Position',axExtra1Pos);
    axExtra2 = axes('Position',axExtra2Pos);
    ax1 = axes('Position',ax1Pos);
    ax2 = axes('Position',ax2Pos);
    ax3 = axes('Position',ax3Pos);
    ax4 = axes('Position',ax4Pos);

    hTitle = annotation('textbox', [0 0.9 1 0.05], ...
        'String', '', 'EdgeColor','none', ...
        'HorizontalAlignment','center', ...
        'FontSize', 12,'FontWeight','bold', 'Interpreter','none');

    cmap = flipud(winter(256));
    tDminContours = 0;
    tDmaxContours = tDmax;
    levels = [0.5 0.5];           
    levelsExtra1 = [0.16 0.16];
    levelsExtra2 = [0.84 0.84];
    levelsFull = tDminContours:0.1:tDmaxContours;

    frames = struct('tD',{},'run_name',{},'k',{},'rotPos',{}, ...
        'color',{},'xD',{},'zD',{},'C',{}, ...
        'xD2',{},'CVert',{},'hContour',{},'hScatter',{}, ...
        'hContourExtra1',{},'hContourExtra2',{});

    for j = 1:length(expFolderName)
        run_name = "run_" + sprintf('%02d', j);
        HDF5dataPath = ['/exp/' char(run_name) '/conc'];
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nx = dims(1);
        ny = dims(2);

        varsRun = expCTData.(filedataExp.Key).exp.(run_name).vars.(dataSource);
        tDRun = [varsRun.tDtotal];
        varsRun = varsRun(tDRun < tDmax);
        tDstep = 0.1;
        tDtargets = min([varsRun.tDtotal]):tDstep:max([varsRun.tDtotal]);
        kPlot = zeros(length(tDtargets),1);

        for m = 1:length(tDtargets)
            [~,kPlot(m)] = min(abs([varsRun.tDtotal] - tDtargets(m)));
        end
        kPlot = unique(kPlot,'stable');

        for ii = 1:length(kPlot)
            k = kPlot(ii);
            vars = expCTData.(filedataExp.Key).exp.(run_name).vars.(dataSource)(k);
            tD = vars.tDtotal;

            rhoNormImage = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            if strcmp(dataSource,'conc')
                plotImage = interpFcn(rhoNormImage);
            else
                plotImage = rhoNormImage;
            end
            imgSmooth = imgaussfilt(plotImage, 20);
            resXmm = expCTData.(filedataExp.Key).exp.(run_name).pca.Geometry.VoxelSizeX;
            resYmm = expCTData.(filedataExp.Key).exp.(run_name).pca.Geometry.VoxelSizeY;
            xcm = (1:ny)*resXmm/10;
            zcm = (1:nx)*resYmm/10;
            xD = xcm/max(xcm);
            zD = zcm/max(zcm);

            % --- new tile: C_D = 0.16 ---
            hold(axExtra1,'on')
            [CExtra1, hExtra1] = contour(axExtra1,xD,zD,imgSmooth,levelsExtra1, ...
                'LineColor','k','LineWidth',2.2);
            set(hExtra1,'HitTest','off','PickableParts','none');
            if ~isempty(CExtra1) && CExtra1(2,1) > 5
                mid = round(CExtra1(2,1)/2);
                xLabE1 = CExtra1(1,mid+1);
                zLabE1 = CExtra1(2,mid+1)+0.06;
                text(axExtra1,xLabE1,zLabE1,sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,vars.rotPos),'Color','k', ...
                    'FontSize',8,'FontWeight','bold', ...
                    'HorizontalAlignment','center', ...
                    'BackgroundColor','none','Margin',1, ...
                    'HitTest','off','PickableParts','none');
            end

            % --- new tile: C_D = 0.84 ---
            hold(axExtra2,'on')
            [CExtra2, hExtra2] = contour(axExtra2,xD,zD,imgSmooth,levelsExtra2, ...
                'LineColor','k','LineWidth',2.2);
            set(hExtra2,'HitTest','off','PickableParts','none');
            if ~isempty(CExtra2) && CExtra2(2,1) > 5
                mid = round(CExtra2(2,1)/2);
                xLabE2 = CExtra2(1,mid+1);
                zLabE2 = CExtra2(2,mid+1)+0.06;
                text(axExtra2,xLabE2,zLabE2,sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,vars.rotPos),'Color','k', ...
                    'FontSize',8,'FontWeight','bold', ...
                    'HorizontalAlignment','center', ...
                    'BackgroundColor','none','Margin',1, ...
                    'HitTest','off','PickableParts','none');
            end

            % --- ax1 (C_D = 0.5), unchanged from original ---
            hold(ax1,'on')
            [C, h] = contour(ax1,xD,zD,imgSmooth,levels, ...
                'LineColor','k','LineWidth',2.2);
            set(h,'HitTest','off','PickableParts','none');

            % --- ax3 profile, unchanged from original ---
            x2v = vars.C1Profile.zVertcm;
            xD2 = x2v/max(x2v);
            y2 = vars.C1Profile.CVert;
            s = scatter(ax3,xD2,y2,3,'filled','MarkerFaceColor','k');
            set(s,'HitTest','off','PickableParts','none');
            hold(ax3,'on')

            frames(end+1) = struct( ...
                'tD',tD,'run_name',run_name,'k',k,'rotPos',vars.rotPos, ...
                'color','k','xD',xD,'zD',zD,'C',C, ...
                'xD2',xD2,'CVert',y2, ...
                'hContour',h,'hScatter',s, ...
                'hContourExtra1',hExtra1,'hContourExtra2',hExtra2);

            if isempty(C)
                continue
            end
            npts = C(2,1);
            if npts > 5
                mid = round(npts/2);
                xLab = C(1,mid+1);
                zLab = C(2,mid+1)+0.06;
                text(ax1,xLab,zLab,sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,vars.rotPos),'Color','k', ...
                    'FontSize',8,'FontWeight','bold', ...
                    'HorizontalAlignment','center', ...
                    'BackgroundColor','none','Margin',1, ...
                    'HitTest','off','PickableParts','none');
                text(ax3,zLab,0.3, ...
                    sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,vars.rotPos),'Color','k', ...
                    'FontSize',8,'FontWeight','bold', ...
                    'BackgroundColor','w','Margin',1, ...
                    'HitTest','off','PickableParts','none');
            end
        end
    end

    % format new tiles (same style as ax1)
    set(axExtra1,'YDir','reverse','FontSize',8)
    grid(axExtra1,'on')
    xlabel(axExtra1,'x_D [-]','FontSize',8)
    ylabel(axExtra1,'z_D [-]','FontSize',8)
    colormap(axExtra1,cmap)
    clim(axExtra1,[tDminContours tDmaxContours])
    xlim(axExtra1,[0 1])
    ylim(axExtra1,[0 1])
    title(axExtra1,'Front advance @ C_D = 0.16','FontSize',9)

    set(axExtra2,'YDir','reverse','FontSize',8)
    grid(axExtra2,'on')
    xlabel(axExtra2,'x_D [-]','FontSize',8)
    colormap(axExtra2,cmap)
    clim(axExtra2,[tDminContours tDmaxContours])
    xlim(axExtra2,[0 1])
    ylim(axExtra2,[0 1])
    title(axExtra2,'Front advance @ C_D = 0.84','FontSize',9)

    % ax1 (unchanged)
    set(ax1,'YDir','reverse','FontSize',8)
    grid(ax1,'on')
    xlabel(ax1,'x_D [-]','FontSize',8)
    colormap(ax1,cmap)
    clim(ax1,[tDminContours tDmaxContours])
    xlim(ax1,[0 1])
    ylim(ax1,[0 1])
    title(ax1,'Front advance @ C_D = 0.5','FontSize',9)

    % ax2 (unchanged)
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

    % ax3 (unchanged)
    camroll(ax3,270)
    set(ax3,'XTickLabel',[])
    ylabel(ax3,'C_{ave,1} [-]')
    colormap(ax3,cmap)
    clim(ax3,[tDminContours tDmaxContours])
    grid(ax3,'on')
    ylim(ax3,[-0.02 1])
    ax3.YAxisLocation = 'right';
    title(ax3,'Vert. conc. profile @ t_D','FontSize',9)

    % ax4 (unchanged)
    BTdata = expCTData.(filedataExp.Key).varsAll.(dataSource);
    colors = get(groot,'defaultAxesColorOrder');
    zDoutlet = 'CD1_zD1p0';
    zDmid    = 'CD1_zD0p5';
    zDinlet  = 'CD1_zD0p0';

    scatter(ax4, BTdata.tDtotal, BTdata.(zDinlet), 8, 'filled', ...
        'MarkerFaceColor',[0.75 0.75 0.75], ...
        'HitTest','off','PickableParts','none', ...
        'DisplayName','CT analog BTC (zD=0.0, inlet)');
    hold(ax4,'on')
    scatter(ax4, BTdata.tDtotal, BTdata.(zDmid), 8, 'filled', ...
        'MarkerFaceColor',[0.5 0.5 0.5], ...
        'HitTest','off','PickableParts','none', ...
        'DisplayName','CT analog BTC (zD=0.5, mid-core)');
    scatter(ax4, BTdata.tDtotal, BTdata.(zDoutlet), 8, 'filled', ...
        'MarkerFaceColor','k', ...
        'HitTest','off','PickableParts','none', ...
        'DisplayName','CT analog BTC (zD=1.0, outlet)');
    scatter(ax4, expProcFullData_MFM_CT.BT.tDtotal, expProcFullData_MFM_CT.BT.CDi, ...
        8, 'filled', 'MarkerFaceColor',colors(1,:), ...
        'HitTest','off','PickableParts','none', 'DisplayName','MFM analog BTC');
    scatter(ax4, expProcFullData_MFM_UHS.BT.tDtotal, expProcFullData_MFM_UHS.BT.CDi, ...
        8, 'filled', 'MarkerFaceColor',colors(3,:), ...
        'HitTest','off','PickableParts','none', 'DisplayName','MFM UHS BTC');
    grid(ax4,'on')
    xlabel(ax4,'t_D_{total} [-]')
    ylabel(ax4,'C_{ave,1} [-]')
    ylim(ax4,[-0.02 1])
    xlim(ax4,[0,tDmax])
    legend(ax4, 'Location','southeast','Interpreter','none')
    title(ax4,'Breakthrough curve @ zD = 0.0, 0.5 and 1.0','FontSize',9)

    hCurrentAx4 = xline(ax4, NaN, '--r', 'LineWidth', 2, 'DisplayName','');

    % --- per-frame save loop ---
    hImgAx2 = gobjects(0);
    hContourAx2 = gobjects(0);
    hContourAx2Hi = gobjects(0);
    prevIdx = [];

    for idx = 1:numel(frames)
        fr = frames(idx);

        % restore previous highlight
        if ~isempty(prevIdx)
            set(frames(prevIdx).hContour,'LineColor','k','LineWidth',2.2);
            set(frames(prevIdx).hContourExtra1,'LineColor','k','LineWidth',2.2);
            set(frames(prevIdx).hContourExtra2,'LineColor','k','LineWidth',2.2);
            set(frames(prevIdx).hScatter,'MarkerFaceColor','k','SizeData',3);
        end

        % apply new highlight
        set(fr.hContour,'LineColor','r','LineWidth',3);
        set(fr.hContourExtra1,'LineColor','r','LineWidth',3);
        set(fr.hContourExtra2,'LineColor','r','LineWidth',3);
        set(fr.hScatter,'MarkerFaceColor','r','SizeData',8);

        % ax2: re-read raw frame and rebuild image + contours (same as original updateSelection)
        HDF5dataPath = ['/exp/' char(fr.run_name) '/conc'];
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nx = dims(1); ny = dims(2);
        rhoNormImage = h5read(HDF5filename, HDF5dataPath, [1 1 fr.k], [nx ny 1]);
        if strcmp(dataSource,'conc')
            plotImage = interpFcn(rhoNormImage);
        else
            plotImage = rhoNormImage;
        end
        imgSmooth = imgaussfilt(plotImage, 20);

        if isempty(hImgAx2) || ~isvalid(hImgAx2)
            hold(ax2,'on')
            hImgAx2 = imagesc(ax2, fr.xD, fr.zD, plotImage);
            uistack(hImgAx2,'bottom');
        else
            set(hImgAx2,'CData',plotImage,'XData',fr.xD,'YData',fr.zD);
        end

        if ~isempty(hContourAx2Hi) && isvalid(hContourAx2Hi)
            delete(hContourAx2Hi);
        end
        [~, hContourAx2Hi] = contour(ax2, fr.xD, fr.zD, imgSmooth, levels, ...
            'LineColor','k','LineWidth',3, 'ShowText',true);
        set(hContourAx2Hi,'HitTest','off','PickableParts','none');
        uistack(hContourAx2Hi,'top');

        if ~isempty(hContourAx2) && isvalid(hContourAx2)
            delete(hContourAx2);
        end
        [~, hContourAx2] = contour(ax2, fr.xD, fr.zD, imgSmooth, levelsFull, ...
            'LineColor','k','LineWidth',1,'ShowText',true,'LabelFormat',"%0.1f");
        set(hContourAx2,'HitTest','off','PickableParts','none');

        xlim(ax2,[0 1]);
        ylim(ax2,[0 1]);
        title(ax2, sprintf('Concentration map @ t_D = %.1f', fr.tD), 'FontSize', 9)

        % ax4 current-point marker
        hCurrentAx4.Value = fr.tD;
        hCurrentAx4.DisplayName = sprintf('tD = %.1f', fr.tD);

        hTitle.String = sprintf('%s - CT %s %s, tD = %.1f, theta = %.0f°', ...
            char(filedataExp.Key), dataSource, fr.run_name, fr.tD, fr.rotPos);

        tDStr = strrep(sprintf('%.1f', fr.tD), '.', 'p');
        fname = sprintf('%s_tD%s_%s_%s_multiLevel', ...
            char(filedataExp.Key), tDStr, fr.run_name, dataSource);
        saveas(fig, fullfile(pathExportAll, fname), 'png');
        fprintf('Saved %s\n', fname);

        prevIdx = idx;
    end

    close(fig)

end
%% Countour map interactive
 
for i = 1:nExp

    filedataExp   = filedataExpAll{i};
    pathExportAll = pathExportAllVec{i};
    dataSource    = dataSourceAll{i};
    HDF5filename  = HDF5filenameAll{i};
    interpFcn     = interpFcnAll{i};
    expFolderName = expFolderNameAll{i};
    expProcFullData_MFM_CT  = MFM_CT_DataAll{i};   % only used in Interactive imaging & Countour map
    expProcFullData_MFM_UHS = MFM_UHS_DataAll{i};

    expCTData = struct();
    expCTData.(filedataExp.Key) = expCTDataAll{i};

    fprintf('Contour map interactive imaging %s\n',filedataExp.Key)

    fig = figure('Position', [50, 50, 800, 1000]); % [left, bottom, width, height];
    
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
    
    cmap = flipud(winter(256));
    varsAll = expCTData.(filedataExp.Key).varsAll.(dataSource);
    varsAll = varsAll(varsAll.tDtotal < 1,:);
    
    tDAll = varsAll.tDtotal;
    tDminContours = 0;
    tDmaxContours = 1;
    levels = [0.5 0.5];   % contour level, reused for both ax1 and ax2
    levelsFull = 0:0.1:1;  
    
    % struct array holding one entry per plotted frame
    frames = struct('tD',{},'run_name',{},'k',{},'rotPos',{}, ...
        'color',{},'xD',{},'zD',{},'C',{}, ...
        'xD2',{},'CVert',{},'hContour',{},'hScatter',{});
    
    for j = 1:length(expFolderName) % number of runs
        run_name = "run_" + sprintf('%02d', j);
        HDF5dataPath = ['/exp/' char(run_name) '/conc'];
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nx = dims(1);
        ny = dims(2);
        nz = dims(3);
    
        varsRun = expCTData.(filedataExp.Key).exp.(run_name).vars.(dataSource);
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
            vars = expCTData.(filedataExp.Key).exp.(run_name).vars.(dataSource)(k);
            tD = vars.tDtotal;
    
            % ax1
            rhoNormImage = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            if strcmp(dataSource,'conc')
                plotImage = interpFcn(rhoNormImage);
            else
                plotImage = rhoNormImage;
            end
            imgSmooth = imgaussfilt(plotImage, 20);
            resXmm = expCTData.(filedataExp.Key).exp.(run_name).pca.Geometry.VoxelSizeX;
            resYmm = expCTData.(filedataExp.Key).exp.(run_name).pca.Geometry.VoxelSizeY;
            xcm = (1:ny)*resXmm/10;
            zcm = (1:nx)*resYmm/10;
            xD = xcm/max(xcm);
            zD = zcm/max(zcm);
            hold(ax1,'on')
            [C, h] = contour(ax1,xD,zD,imgSmooth,levels, ...
                'LineColor','k',...
                'LineWidth',2.2);
            set(h,'HitTest','off','PickableParts','none');
    
            % ax3
            x2 = vars.C1Profile.zVertcm;
            xD2 = x2/max(x2);
            y2 = vars.C1Profile.CVert;
            s = scatter(ax3,xD2,y2,3,'filled','MarkerFaceColor','k');
            set(s,'HitTest','off','PickableParts','none');
            hold(ax3,'on')
    
            % store this frame (image + BT point NOT plotted yet)
            frames(end+1) = struct( ...
                'tD',tD,'run_name',run_name,'k',k,'rotPos',vars.rotPos, ...
                'color','k','xD',xD,'zD',zD,'C',C, ...
                'xD2',xD2,'CVert',y2, ...
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
    clim(ax1,[tDminContours tDmaxContours])
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
    clim(ax3,[tDminContours tDmaxContours])
    grid(ax3,'on')
    ylim(ax3,[-0.02 1])
    ax3.YAxisLocation = 'right';
    title(ax3,'Vert. conc. profile @ t_D','FontSize',9)
    
    % ax4 Breakthrough curve (base black data only; red current point deferred)
    BTdata = expCTData.(filedataExp.Key).varsAll.(dataSource);
    colors = get(groot,'defaultAxesColorOrder');
    
    zDoutlet = 'CD1_zD1p0';
    zDmid    = 'CD1_zD0p5';
    zDinlet    = 'CD1_zD0p0';
    
    hBT_CT_inlet = scatter(ax4, BTdata.tDtotal, BTdata.(zDinlet), 8, 'filled', ...
        'MarkerFaceColor',[0.75 0.75 0.75], ...
        'HitTest','off','PickableParts','none', ...
        'DisplayName','CT analog BTC (zD=0.0, inlet)');
    hold(ax4,'on')
    hBT_CT_mid = scatter(ax4, BTdata.tDtotal, BTdata.(zDmid), 8, 'filled', ...
        'MarkerFaceColor',[0.5 0.5 0.5], ...
        'HitTest','off','PickableParts','none', ...
        'DisplayName','CT analog BTC (zD=0.5, mid-core)');
    hBT_CT = scatter(ax4, BTdata.tDtotal, BTdata.(zDoutlet), 8, 'filled', ...
        'MarkerFaceColor','k', ...
        'HitTest','off','PickableParts','none', ...
        'DisplayName','CT analog BTC (zD=1.0, outlet)');
    
    hBT_MFM_CT = scatter(ax4, expProcFullData_MFM_CT.BT.tDtotal, expProcFullData_MFM_CT.BT.CDi, ...
        8, 'filled', 'MarkerFaceColor',colors(1,:), ...
        'HitTest','off','PickableParts','none', 'DisplayName','MFM analog BTC');
    hBT_MFM_UHS = scatter(ax4, expProcFullData_MFM_UHS.BT.tDtotal, expProcFullData_MFM_UHS.BT.CDi, ...
        8, 'filled', 'MarkerFaceColor',colors(3,:), ...
        'HitTest','off','PickableParts','none', 'DisplayName','MFM UHS BTC');
    grid(ax4,'on')
    xlabel(ax4,'t_D_{total} [-]')
    ylabel(ax4,'C_{ave,1} [-]')
    ylim(ax4,[-0.02 1])
    xlim(ax4,[0,tDmax])
    legend(ax4, 'Location','southeast','Interpreter','none')
    title(ax4,'Breakthrough curve @ zD = 0.0, 0.5 and 1.0','FontSize',9)
    
    % wire up interactivity
    setappdata(fig,'frames',frames);
    setappdata(fig,'HDF5filename',HDF5filename);
    setappdata(fig,'interpFcn',interpFcn);
    setappdata(fig,'ax2',ax2);
    setappdata(fig,'ax4',ax4);
    setappdata(fig,'levels',levels);
    setappdata(fig,'levelsFull',levelsFull);
    setappdata(fig,'hImgAx2',gobjects(0));
    setappdata(fig,'hContourAx2',gobjects(0));   
    setappdata(fig,'hCurrentAx4',gobjects(0));  
    setappdata(fig,'hTitle',hTitle);
    setappdata(fig,'keyName',filedataExp.Key);
    setappdata(fig,'pathExportAll',pathExportAll);
    setappdata(fig,'selectedIdx',[]);
    setappdata(fig,'dataSource',dataSource);
    
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
    interpFcn     = getappdata(fig,'interpFcn'); 
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
    dataSource = getappdata(fig,'dataSource');

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
    rhoNormImage = h5read(HDF5filename, HDF5dataPath, [1 1 frames(idx).k], [nx ny 1]);
    if strcmp(dataSource,'conc')
        plotImage = interpFcn(rhoNormImage);
    else
        plotImage = rhoNormImage;
    end
    imgSmooth = imgaussfilt(plotImage, 20);

    % ax2 image: create on first use, otherwise just update it
    if isempty(hImgAx2) || ~isvalid(hImgAx2)
        hold(ax2,'on')
        hImgAx2 = imagesc(ax2, frames(idx).xD, frames(idx).zD, plotImage);
        uistack(hImgAx2,'bottom');   % keep it under the contours
    else
        set(hImgAx2,'CData',plotImage,'XData',frames(idx).xD,'YData',frames(idx).zD);
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
        hCurrentAx4 = xline(ax4, frames(idx).tD, '--r', 'LineWidth', 2, ...
            'DisplayName', sprintf('tD = %.1f', frames(idx).tD));
    else
        hCurrentAx4.Value = frames(idx).tD;
        hCurrentAx4.DisplayName = sprintf('tD = %.1f', frames(idx).tD);
    end
    setappdata(fig,'hCurrentAx4',hCurrentAx4);

    % update title
    if ~isempty(hTitle) && isvalid(hTitle)
        hTitle.String = sprintf('%s - CT %s %s, tD = %.1f, theta = %.0f°', ...
                char(keyName), dataSource, frames(idx).run_name, frames(idx).tD, frames(idx).rotPos);
        title(ax2, sprintf('Concentration map @ t_D = %.1f', frames(idx).tD), 'FontSize', 9)
    end

    setappdata(fig,'selectedIdx',idx);
end

function saveFrame(fig, idx)
    updateSelection(fig, idx);
    frames        = getappdata(fig,'frames');
    keyName       = getappdata(fig,'keyName');
    pathExportAll = getappdata(fig,'pathExportAll');
    dataSource    = getappdata(fig,'dataSource');

    tDStr = strrep(sprintf('%.1f', frames(idx).tD), '.', 'p');
    fname = sprintf('%s_tD%s_%s_%s', char(keyName), tDStr, frames(idx).run_name, dataSource);
    saveas(fig, fullfile(pathExportAll, fname), 'png');
    % saveas(fig, fullfile(pathExportAll, fname), 'fig');
    fprintf('Saved %s\n', fname);
end