
%% main_CTimaging.m
% Interactive CT Concentration Visualization
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
fitDataAll       = cell(nExp,1);

for i = 1:nExp

    filenameExp = inputFileConfig.inputFileName{i};

    pathExportAll = inputFileConfig.exportPath{i}; % Path for OUTPUT
    mkdir(pathExportAll); % Create directory for output
    dataSource = inputFileConfig.dataSource{i};   % "rhoNorm" or "conc"
    fitData = inputFileConfig.fitData{i};
    if ~ismember(dataSource, {'rhoNorm','conc'})
        error('dataSource must be "rhoNorm" or "conc", got "%s"', dataSource);
    end
    if ~ismember(fitData, {'woEOS','wEOS'})
        error('fitData must be "woEOS" or "wEOS", got "%s"', fitData);
    end

    filedataExp = import_inputCTExp(filenameExp); % import input to a local variable
        
    % Capture exp data folder (for run numbers)
    expFolderContent = dir(filedataExp.path+filedataExp.CT_data_exp); % exp
    expFolderContent = expFolderContent([expFolderContent.isdir] & ~startsWith({expFolderContent.name},'.'));
    expFolderName = {expFolderContent.name}';

    HDF5filename = fullfile(pathExportAll, filedataExp.Key + ".h5");
    expCTDataname = fullfile(pathExportAll, filedataExp.Key + ".mat");
    expCTDataTemp = load(expCTDataname);

    pathImport_MFM_CT = inputFileConfig.MFM_BTC_CT_Path{i};   % "../results/exp_He-Xe-T20-V_REFPROP/"
    pathImport_MFM_UHS = inputFileConfig.MFM_BTC_UHS_Path{i};   % "../results/exp_H2-CG-T40-P1160-V_REFPROP/"
    MFM_CT_name = inputFileConfig.MFM_BTC_CT_Key{i};
    MFM_UHS_name = inputFileConfig.MFM_BTC_UHS_Key{i};
    % main_Processing in other should have been executed first
    MFM_CT_file = fullfile(Root, pathImport_MFM_CT, 'expProcFullData.mat');
    MFM_UHS_file = fullfile(Root, pathImport_MFM_UHS, 'expProcFullData.mat');
    % load processed MFM data
    MFM_CT_Data  = load(MFM_CT_file);
    MFM_UHS_Data = load(MFM_UHS_file);

    eCT  = MFM_CT_Data.expProcFullData.(MFM_CT_name);
    eUHS = MFM_UHS_Data.expProcFullData.(MFM_UHS_name);
    if ~isfield(eCT, fitData) || ~isfield(eUHS, fitData)
        error('%s results missing for %s or %s', fitData, MFM_CT_name, MFM_UHS_name);
    end
    mfmCT  = eCT.(fitData);   mfmCT.exp_params  = eCT.exp_params;    % BT, results, ... + exp_params
    mfmUHS = eUHS.(fitData);  mfmUHS.exp_params = eUHS.exp_params;

    % exp params (shared, from the MFM analog experiment)
    Fluid1      = eCT.exp_params.Fluid1;
    Fluid2      = eCT.exp_params.Fluid2;
    T_C_avg     = eCT.exp_params.T_mean;
    dT_C_avg    = eCT.exp_params.T_std;
    P_psig_avg  = eCT.exp_params.Pavg_avg;
    dP_psig_avg = eCT.exp_params.Pavg_std;

    % interpolant for composition form array 0 to 1 (binary mixture)
    [interpFcn, interpFcn_Tp, interpFcn_Tm, interpFcn_Pp, interpFcn_Pm] = ...
        buildInterpolant(Fluid1, Fluid2, ...
        T_C_avg, P_psig_avg, dT_C_avg, dP_psig_avg);

    filedataExpAll{i}   = filedataExp;
    expCTDataAll{i}     = expCTDataTemp.expCTDataSave;
    MFM_CT_DataAll{i}   = mfmCT;
    MFM_UHS_DataAll{i}  = mfmUHS;
    HDF5filenameAll{i}  = HDF5filename;
    interpFcnAll{i}     = interpFcn;
    expFolderNameAll{i} = expFolderName;
    pathExportAllVec{i} = pathExportAll;
    dataSourceAll{i}    = dataSource;
    fitDataAll{i}       = fitData;

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

        varsRun = expCTData.(filedataExp.Key).varsAll.(dataSource);
        varsRun = varsRun(varsRun.runName == run_name, :);
    
        for k = 1:nz
            vars = varsRun(k,:);
            % profile / histogram columns are cells in the table -> unwrap
            axial = vars.C1Axial;    if iscell(axial), axial = axial{1}; end
            prof  = vars.C1Profile;  if iscell(prof),  prof  = prof{1};  end
            hist1 = vars.histImage;  if iscell(hist1), hist1 = hist1{1}; end
    
            % hTitle
            set(hTitle, 'String', ...
                filedataExp.Key + ": CT " + dataSource + " " + run_name + ...
                " ImgNumber_" + sprintf('%03d', k));
    
            % plot concentration in x ax1
            x1 = axial.xHorzcm;
            xD1 = x1 / max(x1);
            y1 = axial.CHorz;
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
            x2 = prof.zVertcm;
            zD2 = x2 / max(x2);
            y2 = prof.CVert;
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
            rhoNormImageVac = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            rhoNormImage = rhoNorm_wVacRef(rhoNormImageVac,filedataExp.Fluid1, ...
                filedataExp.Fluid2, filedataExp.T, filedataExp.P);
            if strcmp(dataSource,'conc')
                plotImage = interpFcn(rhoNormImage);
            else
                plotImage = rhoNormImage;
            end
            % imgSmooth = imgaussfilt(plotImage, 20);
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
            freq = hist1.counts;
            binCenters = (hist1.minEdge + hist1.maxEdge)/2;
            binWidth = abs(hist1.maxEdge-hist1.minEdge);
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

        varsRun = expCTData.(filedataExp.Key).varsAll.(dataSource);
        varsRun = varsRun(varsRun.runName == run_name, :);
    
        for k = 1:nz
    
            vars = varsRun(k,:);
    
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
    if strcmp(dataSource,'conc'), mfmCol = 'CDi'; else, mfmCol = 'rho_norm'; end
    scatter(ax5, expProcFullData_MFM_CT.BT.tDtotal, expProcFullData_MFM_CT.BT.(mfmCol), 8, ...
        'filled', 'MarkerFaceColor',colors(1,:), ...
        'MarkerEdgeColor','none','DisplayName','MFM_analog_BTC');
    scatter(ax5, expProcFullData_MFM_UHS.BT.tDtotal, expProcFullData_MFM_UHS.BT.(mfmCol), 8, ...
        'filled', 'MarkerFaceColor',colors(3,:), ...
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
    
        varsRun = expCTData.(filedataExp.Key).varsAll.(dataSource);
        varsRun = varsRun(varsRun.runName == run_name, :);
        tDRun = [varsRun.tDtotal];
    
        % fixed tD grid, same for every experiment regardless of flow rate
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
            vars = varsRun(k,:);
            tD = vars.tDtotal;
            theta = deg2rad(vars.rotPos);
    
            rhoNormImageVac = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            rhoNormImage = rhoNorm_wVacRef(rhoNormImageVac,filedataExp.Fluid1, ...
                filedataExp.Fluid2, filedataExp.T, filedataExp.P);
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
    tDminContours = 0;
    tDmaxContours = tDmax;
    levels = [0.5 0.5];
    levelsFull = 0:0.1:1;

    frames = struct('tD',{},'run_name',{},'k',{},'rotPos',{}, ...
        'color',{},'xD',{},'zD',{},'C',{}, ...
        'xD2',{},'CVert',{},'hContour',{},'hScatter',{});
    cache  = struct('plotImage',{},'imgSmooth',{});   % same order as frames

    % build static overlays (one read + smooth per frame)
    for j = 1:length(expFolderName)
        run_name = "run_" + sprintf('%02d', j);
        HDF5dataPath = ['/exp/' char(run_name) '/conc'];
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nx = dims(1);
        ny = dims(2);

        varsRun = expCTData.(filedataExp.Key).varsAll.(dataSource);
        varsRun = varsRun(varsRun.runName == run_name & varsRun.tDtotal < tDmax, :);
        if isempty(varsRun), continue, end

        tDstep = 0.1;
        tDtargets = min(varsRun.tDtotal):tDstep:max(varsRun.tDtotal);
        kPlot = zeros(length(tDtargets),1);
        for m = 1:length(tDtargets)
            [~,kPlot(m)] = min(abs(varsRun.tDtotal - tDtargets(m)));
        end
        kPlot = unique(kPlot,'stable');

        for ii = 1:length(kPlot)
            k = kPlot(ii);
            vars = varsRun(k,:);
            prof = vars.C1Profile;  if iscell(prof), prof = prof{1}; end
            tD = vars.tDtotal;

            rhoNormImageVac = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            rhoNormImage = rhoNorm_wVacRef(rhoNormImageVac,filedataExp.Fluid1, ...
                filedataExp.Fluid2, filedataExp.T, filedataExp.P);
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

            % ax1: C = 0.5 contour of this frame
            hold(ax1,'on')
            [C, h] = contour(ax1,xD,zD,imgSmooth,levels, ...
                'LineColor','k','LineWidth',2.2);
            set(h,'HitTest','off','PickableParts','none');

            % ax3: vertical profile of this frame
            x2 = prof.zVertcm;
            xD2 = x2/max(x2);
            y2 = prof.CVert;
            s = scatter(ax3,xD2,y2,3,'filled','MarkerFaceColor','k');
            set(s,'HitTest','off','PickableParts','none');
            hold(ax3,'on')

            frames(end+1) = struct( ...
                'tD',tD,'run_name',run_name,'k',k,'rotPos',vars.rotPos, ...
                'color','k','xD',xD,'zD',zD,'C',C, ...
                'xD2',xD2,'CVert',y2, ...
                'hContour',h,'hScatter',s); %#ok<SAGROW>
            cache(end+1) = struct('plotImage',plotImage,'imgSmooth',imgSmooth); %#ok<SAGROW>

            % labels
            if isempty(C), continue, end
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

    % format axes
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

    % ax4: breakthrough curves (CT at three zD + MFM analog/UHS)
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
    if strcmp(dataSource,'conc')
        scatter(ax4, expProcFullData_MFM_CT.BT.tDtotal, expProcFullData_MFM_CT.BT.CDi, ...
            8, 'filled', 'MarkerFaceColor',colors(1,:), ...
            'HitTest','off','PickableParts','none', 'DisplayName','MFM analog BTC');
        scatter(ax4, expProcFullData_MFM_UHS.BT.tDtotal, expProcFullData_MFM_UHS.BT.CDi, ...
            8, 'filled', 'MarkerFaceColor',colors(3,:), ...
            'HitTest','off','PickableParts','none', 'DisplayName','MFM UHS BTC');
    else
        scatter(ax4, expProcFullData_MFM_CT.BT.tDtotal, expProcFullData_MFM_CT.BT.rho_norm, ...
            8, 'filled', 'MarkerFaceColor',colors(1,:), ...
            'HitTest','off','PickableParts','none', 'DisplayName','MFM analog BTC');
        scatter(ax4, expProcFullData_MFM_UHS.BT.tDtotal, expProcFullData_MFM_UHS.BT.rho_norm, ...
            8, 'filled', 'MarkerFaceColor',colors(3,:), ...
            'HitTest','off','PickableParts','none', 'DisplayName','MFM UHS BTC');
    end
    grid(ax4,'on')
    xlabel(ax4,'t_D_{total} [-]')
    ylabel(ax4,'C_{ave,1} [-]')
    ylim(ax4,[-0.02 1])
    xlim(ax4,[0,tDmax])
    legend(ax4, 'Location','southeast','Interpreter','none')
    title(ax4,'Breakthrough curve @ zD = 0.0, 0.5 and 1.0','FontSize',9)

    % per-frame save: current tD contour in red, its map in ax2, tD line in ax4
    hCurrentAx4   = xline(ax4, NaN, '--r', 'LineWidth', 2, 'DisplayName','');
    hImgAx2       = gobjects(0);
    hContourAx2   = gobjects(0);
    hContourAx2Hi = gobjects(0);
    prevIdx = [];

    for idx = 1:numel(frames)
        fr  = frames(idx);
        cfr = cache(idx);

        % previous frame back to black, current one red
        if ~isempty(prevIdx)
            set(frames(prevIdx).hContour,'LineColor','k','LineWidth',2.2);
            set(frames(prevIdx).hScatter,'MarkerFaceColor','k','SizeData',3);
        end
        set(fr.hContour,'LineColor','r','LineWidth',3);
        set(fr.hScatter,'MarkerFaceColor','r','SizeData',8);

        % ax2: concentration map of this frame (cached)
        if isempty(hImgAx2) || ~isvalid(hImgAx2)
            hold(ax2,'on')
            hImgAx2 = imagesc(ax2, fr.xD, fr.zD, cfr.plotImage);
            uistack(hImgAx2,'bottom');
        else
            set(hImgAx2,'CData',cfr.plotImage,'XData',fr.xD,'YData',fr.zD);
        end

        if ~isempty(hContourAx2Hi) && isvalid(hContourAx2Hi), delete(hContourAx2Hi); end
        [~, hContourAx2Hi] = contour(ax2, fr.xD, fr.zD, cfr.imgSmooth, levels, ...
            'LineColor','k','LineWidth',3,'ShowText',true);
        set(hContourAx2Hi,'HitTest','off','PickableParts','none');
        uistack(hContourAx2Hi,'top');

        if ~isempty(hContourAx2) && isvalid(hContourAx2), delete(hContourAx2); end
        [~, hContourAx2] = contour(ax2, fr.xD, fr.zD, cfr.imgSmooth, levelsFull, ...
            'LineColor','k','LineWidth',1,'ShowText',true,'LabelFormat',"%0.1f");
        set(hContourAx2,'HitTest','off','PickableParts','none');

        xlim(ax2,[0 1]);  ylim(ax2,[0 1]);
        title(ax2, sprintf('Concentration map @ t_D = %.1f', fr.tD), 'FontSize', 9)

        % ax4: current tD
        hCurrentAx4.Value = fr.tD;
        hCurrentAx4.DisplayName = sprintf('tD = %.1f', fr.tD);

        hTitle.String = sprintf('%s - CT %s %s, tD = %.1f, theta = %.0f°', ...
            char(filedataExp.Key), dataSource, fr.run_name, fr.tD, fr.rotPos);

        tDStr = strrep(sprintf('%.1f', fr.tD), '.', 'p');
        fname = sprintf('%s_tD%s_%s_%s', char(filedataExp.Key), tDStr, fr.run_name, dataSource);
        saveas(fig, fullfile(pathExportAll, fname), 'png');
        fprintf('Saved %s\n', fname);

        prevIdx = idx;
    end

    close(fig)
end

%% Countour map (batch save, multi-level overlay C=0.1/0.5/0.9)

widthPairs = [0.1 0.9; 0.2 0.8; 0.3 0.7; 0.4 0.6];
% widthPairs = [0.4 0.6];
levelsFull = 0:0.1:1;   % fixed grid; covers every level requested
 
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
 
    cache = struct('tD',{},'run_name',{},'k',{},'rotPos',{}, ...
        'xD',{},'zD',{},'plotImage',{},'imgSmooth',{},'segsAll',{}, ...
        'xD2',{},'CVert',{});
 
    for j = 1:length(expFolderName)
        run_name = "run_" + sprintf('%02d', j);
        HDF5dataPath = ['/exp/' char(run_name) '/conc'];
        info = h5info(HDF5filename, HDF5dataPath);
        dims = info.Dataspace.Size;
        nx = dims(1);
        ny = dims(2);
 
        varsRun = expCTData.(filedataExp.Key).varsAll.(dataSource);
        varsRun = varsRun(varsRun.runName == run_name & varsRun.tDtotal < tDmax, :);

        tDstep = 0.1;
        tDtargets = min([varsRun.tDtotal]):tDstep:max([varsRun.tDtotal]);
        kPlot = zeros(length(tDtargets),1);
 
        for m = 1:length(tDtargets)
            [~,kPlot(m)] = min(abs([varsRun.tDtotal] - tDtargets(m)));
        end
        kPlot = unique(kPlot,'stable');
 
        for ii = 1:length(kPlot)
            k = kPlot(ii);
            vars = varsRun(k,:);
            prof  = vars.C1Profile;  if iscell(prof),  prof  = prof{1};  end

            tD = vars.tDtotal;
 
            rhoNormImageVac = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            rhoNormImage = rhoNorm_wVacRef(rhoNormImageVac,filedataExp.Fluid1, ...
                filedataExp.Fluid2, filedataExp.T, filedataExp.P);
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
 
            x2v = prof.zVertcm;
            xD2 = x2v/max(x2v);
            y2 = prof.CVert;
 
            Cfull = contourc(double(xD), double(zD), double(imgSmooth), levelsFull);
            segsAll = parseContourMatrix(Cfull);
 
            cache(end+1) = struct( ...
                'tD',tD,'run_name',run_name,'k',k,'rotPos',vars.rotPos, ...
                'xD',xD,'zD',zD,'plotImage',plotImage,'imgSmooth',imgSmooth, ...
                'segsAll',segsAll,'xD2',xD2,'CVert',y2); 
        end
    end
 
    for wIdx = 1:size(widthPairs,1)
 
        levelsExtra1 = [widthPairs(wIdx,1) widthPairs(wIdx,1)];
        levelsExtra2 = [widthPairs(wIdx,2) widthPairs(wIdx,2)];
 
        fprintf('Contour map batch save (multi-level overlay) %s, width C_D = %.1f/%.1f\n', ...
            filedataExp.Key, levelsExtra1(1), levelsExtra2(1))
 
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
        levelsFull = tDminContours:0.1:tDmaxContours;
 
        frames = struct('tD',{},'run_name',{},'k',{},'rotPos',{}, ...
            'color',{},'xD',{},'zD',{},'C',{}, ...
            'xD2',{},'CVert',{},'hContour',{},'hScatter',{}, ...
            'hContourExtra1',{},'hContourExtra2',{});
 
        % build static contour overlays from the CACHE 
        for idx = 1:numel(cache)
            fr = cache(idx);
            tD = fr.tD;
            rotPos = fr.rotPos;
            xD = fr.xD;
            zD = fr.zD;
 
            % C_D = levelsExtra1 
            hold(axExtra1,'on')
            [xE1, yE1, segListE1] = getLevelSegments(fr.segsAll, levelsExtra1(1));
            hExtra1 = line(axExtra1, xE1, yE1, 'Color','k','LineWidth',2.2, ...
                'HitTest','off','PickableParts','none');
            if ~isempty(segListE1) && numel(segListE1(1).x) > 5
                mid = round(numel(segListE1(1).x)/2);
                xLabE1 = segListE1(1).x(mid+1);
                zLabE1 = segListE1(1).y(mid+1)+0.06;
                text(axExtra1,xLabE1,zLabE1,sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,rotPos),'Color','k', ...
                    'FontSize',8,'FontWeight','bold', ...
                    'HorizontalAlignment','center', ...
                    'BackgroundColor','none','Margin',1, ...
                    'HitTest','off','PickableParts','none');
            end
 
            % C_D = levelsExtra2 
            hold(axExtra2,'on')
            [xE2, yE2, segListE2] = getLevelSegments(fr.segsAll, levelsExtra2(1));
            hExtra2 = line(axExtra2, xE2, yE2, 'Color','k','LineWidth',2.2, ...
                'HitTest','off','PickableParts','none');
            if ~isempty(segListE2) && numel(segListE2(1).x) > 5
                mid = round(numel(segListE2(1).x)/2);
                xLabE2 = segListE2(1).x(mid+1);
                zLabE2 = segListE2(1).y(mid+1)+0.06;
                text(axExtra2,xLabE2,zLabE2,sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,rotPos),'Color','k', ...
                    'FontSize',8,'FontWeight','bold', ...
                    'HorizontalAlignment','center', ...
                    'BackgroundColor','none','Margin',1, ...
                    'HitTest','off','PickableParts','none');
            end
 
            % ax1 (C_D = 0.5)
            hold(ax1,'on')
            [x1seg, y1seg, segList1] = getLevelSegments(fr.segsAll, levels(1));
            h = line(ax1, x1seg, y1seg, 'Color','k','LineWidth',2.2, ...
                'HitTest','off','PickableParts','none');
 
            % ax3 profile
            s = scatter(ax3,fr.xD2,fr.CVert,3,'filled','MarkerFaceColor','k');
            set(s,'HitTest','off','PickableParts','none');
            hold(ax3,'on')
 
            frames(end+1) = struct( ...
                'tD',tD,'run_name',fr.run_name,'k',fr.k,'rotPos',rotPos, ...
                'color','k','xD',xD,'zD',zD,'C',[], ...
                'xD2',fr.xD2,'CVert',fr.CVert, ...
                'hContour',h,'hScatter',s, ...
                'hContourExtra1',hExtra1,'hContourExtra2',hExtra2); 
 
            if isempty(segList1)
                continue
            end
            npts = numel(segList1(1).x);
            if npts > 5
                mid = round(npts/2);
                xLab = segList1(1).x(mid+1);
                zLab = segList1(1).y(mid+1)+0.06;
                text(ax1,xLab,zLab,sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,rotPos),'Color','k', ...
                    'FontSize',8,'FontWeight','bold', ...
                    'HorizontalAlignment','center', ...
                    'BackgroundColor','none','Margin',1, ...
                    'HitTest','off','PickableParts','none');
                text(ax3,zLab,0.3, ...
                    sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,rotPos),'Color','k', ...
                    'FontSize',8,'FontWeight','bold', ...
                    'BackgroundColor','w','Margin',1, ...
                    'HitTest','off','PickableParts','none');
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
        title(axExtra1,sprintf('Front advance @ C_D = %.2f',levelsExtra1(1)),'FontSize',9)
 
        set(axExtra2,'YDir','reverse','FontSize',8)
        grid(axExtra2,'on')
        xlabel(axExtra2,'x_D [-]','FontSize',8)
        colormap(axExtra2,cmap)
        clim(axExtra2,[tDminContours tDmaxContours])
        xlim(axExtra2,[0 1])
        ylim(axExtra2,[0 1])
        title(axExtra2,sprintf('Front advance @ C_D = %.2f',levelsExtra2(1)),'FontSize',9)
 
        % ax1
        set(ax1,'YDir','reverse','FontSize',8)
        grid(ax1,'on')
        xlabel(ax1,'x_D [-]','FontSize',8)
        colormap(ax1,cmap)
        clim(ax1,[tDminContours tDmaxContours])
        xlim(ax1,[0 1])
        ylim(ax1,[0 1])
        title(ax1,'Front advance @ C_D = 0.50','FontSize',9)
 
        % ax2 
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
 
        % ax4 
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

        if strcmp(dataSource,'conc')
            scatter(ax4, expProcFullData_MFM_CT.BT.tDtotal, expProcFullData_MFM_CT.BT.CDi, ...
                8, 'filled', 'MarkerFaceColor',colors(1,:), ...
                'HitTest','off','PickableParts','none', 'DisplayName','MFM analog BTC');
            scatter(ax4, expProcFullData_MFM_UHS.BT.tDtotal, expProcFullData_MFM_UHS.BT.CDi, ...
                8, 'filled', 'MarkerFaceColor',colors(3,:), ...
                'HitTest','off','PickableParts','none', 'DisplayName','MFM UHS BTC');
        else
            scatter(ax4, expProcFullData_MFM_CT.BT.tDtotal, expProcFullData_MFM_CT.BT.rho_norm, ...
                8, 'filled', 'MarkerFaceColor',colors(1,:), ...
                'HitTest','off','PickableParts','none', 'DisplayName','MFM analog BTC');
            scatter(ax4, expProcFullData_MFM_UHS.BT.tDtotal, expProcFullData_MFM_UHS.BT.rho_norm, ...
                8, 'filled', 'MarkerFaceColor',colors(3,:), ...
                'HitTest','off','PickableParts','none', 'DisplayName','MFM UHS BTC');
        end
        grid(ax4,'on')
        xlabel(ax4,'t_D_{total} [-]')
        ylabel(ax4,'C_{ave,1} [-]')
        ylim(ax4,[-0.02 1])
        xlim(ax4,[0,tDmax])
        legend(ax4, 'Location','southeast','Interpreter','none')
        title(ax4,'Breakthrough curve @ zD = 0.0, 0.5 and 1.0','FontSize',9)
 
        hCurrentAx4 = xline(ax4, NaN, '--r', 'LineWidth', 2, 'DisplayName','');
 
        % per-frame save loop (reuses cached plotImage/imgSmooth)
        hImgAx2 = gobjects(0);
        hContourAx2 = gobjects(0);
        hContourAx2Hi = gobjects(0);
        prevIdx = [];
 
        for idx = 1:numel(frames)
            fr = frames(idx);
            cfr = cache(idx);   % same build order as frames, so indices line up
 
            if ~isempty(prevIdx)
                set(frames(prevIdx).hContour,'Color','k','LineWidth',2.2);
                set(frames(prevIdx).hContourExtra1,'Color','k','LineWidth',2.2);
                set(frames(prevIdx).hContourExtra2,'Color','k','LineWidth',2.2);
                set(frames(prevIdx).hScatter,'MarkerFaceColor','k','SizeData',3);
            end
 
            set(fr.hContour,'Color','r','LineWidth',3);
            set(fr.hContourExtra1,'Color','r','LineWidth',3);
            set(fr.hContourExtra2,'Color','r','LineWidth',3);
            set(fr.hScatter,'MarkerFaceColor','r','SizeData',8);
 
            plotImage = cfr.plotImage;   % cached
            imgSmooth = cfr.imgSmooth;   % cached 
 
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
 
            hCurrentAx4.Value = fr.tD;
            hCurrentAx4.DisplayName = sprintf('tD = %.1f', fr.tD);
 
            hTitle.String = sprintf('%s - CT %s %s, tD = %.1f, theta = %.0f°', ...
                char(filedataExp.Key), dataSource, fr.run_name, fr.tD, fr.rotPos);
 
            tDStr = strrep(sprintf('%.1f', fr.tD), '.', 'p');
            fname = sprintf('%s_tD%s_%s_%s_multiLevel_%.0f-%.0f', ...
                char(filedataExp.Key), tDStr, fr.run_name, dataSource, ...
                levelsExtra1(1)*100, levelsExtra2(1)*100);
            saveas(fig, fullfile(pathExportAll, fname), 'png');
            fprintf('Saved %s\n', fname);
 
            prevIdx = idx;
        end
 
        close(fig)
    end
 
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
    varsAll = varsAll(varsAll.tDtotal < tDmax,:);
    
    tDAll = varsAll.tDtotal;
    tDminContours = 0;
    tDmaxContours = tDmax;
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
    
        varsRun = expCTData.(filedataExp.Key).varsAll.(dataSource);
        varsRun = varsRun(varsRun.runName == run_name & varsRun.tDtotal < tDmax, :);

        tDstep = 0.1;
        tDtargets = min([varsRun.tDtotal]):tDstep:max([varsRun.tDtotal]);
        kPlot = zeros(length(tDtargets),1);
        
        for m = 1:length(tDtargets)
            [~,kPlot(m)] = min(abs([varsRun.tDtotal] - tDtargets(m)));
        end
    
        kPlot = unique(kPlot,'stable');
    
        for ii = 1:length(kPlot)
            k = kPlot(ii);
            vars = varsRun(k,:);
            prof = vars.C1Profile;  if iscell(prof), prof = prof{1}; end
            tD = vars.tDtotal;
    
            % ax1
            rhoNormImageVac = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
            rhoNormImage = rhoNorm_wVacRef(rhoNormImageVac,filedataExp.Fluid1, ...
                filedataExp.Fluid2, filedataExp.T, filedataExp.P);
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
            x2 = prof.zVertcm;
            xD2 = x2/max(x2);
            y2 = prof.CVert;
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

    if strcmp(dataSource,'conc')
        hBT_MFM_CT = scatter(ax4, expProcFullData_MFM_CT.BT.tDtotal, expProcFullData_MFM_CT.BT.CDi, ...
            8, 'filled', 'MarkerFaceColor',colors(1,:), ...
            'HitTest','off','PickableParts','none', 'DisplayName','MFM analog BTC');
        hBT_MFM_UHS = scatter(ax4, expProcFullData_MFM_UHS.BT.tDtotal, expProcFullData_MFM_UHS.BT.CDi, ...
            8, 'filled', 'MarkerFaceColor',colors(3,:), ...
            'HitTest','off','PickableParts','none', 'DisplayName','MFM UHS BTC');
    else
        hBT_MFM_CT = scatter(ax4, expProcFullData_MFM_CT.BT.tDtotal, expProcFullData_MFM_CT.BT.rho_norm, ...
            8, 'filled', 'MarkerFaceColor',colors(1,:), ...
            'HitTest','off','PickableParts','none', 'DisplayName','MFM analog BTC');
        hBT_MFM_UHS = scatter(ax4, expProcFullData_MFM_UHS.BT.tDtotal, expProcFullData_MFM_UHS.BT.rho_norm, ...
            8, 'filled', 'MarkerFaceColor',colors(3,:), ...
            'HitTest','off','PickableParts','none', 'DisplayName','MFM UHS BTC');
    end

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
    setappdata(fig,'filedataExp',filedataExp);
    
    ax1.ButtonDownFcn = @(src,evt) axesClickCallback(fig, ax1, 'ax1');
    ax4.ButtonDownFcn = @(src,evt) axesClickCallback(fig, ax4, 'ax4');
end

%% Contour map by fixed angle: one figure per target angle, one tile per experiment
% theta (solid), theta+180 flipped (dashed), 360 = 0 not flipped (dotted); colour = tDtotal
% tiles keep the physical width/height of the image (as the other contour maps)

angleTargets = [0 45 90 135];   % one figure each
angleTol_deg = 3;               % matching tolerance; rotPos is sampled every ~2 deg
level = 0.5;                    % contour level to trace
tDminContours = 0;
tDmaxContours = tDmax;
cmap = flipud(winter(256));

nHalfMax = 2;                       % n = 0,1,2 -> theta, theta+180, theta+360 (only if <= 360)
lsHalf   = {'-', '--', ':'};        % line style per n
flipHalf = [false true false];      % theta+180 -> flipped; 360 is the same view as 0 -> not flipped

tileW_px = 230;                     % width of one tile in the figure [px]

% --- physical aspect (height/width) of the images, from the first experiment's run_01
info0  = h5info(HDF5filenameAll{1}, '/exp/run_01/conc');
geom0  = expCTDataAll{1}.exp.run_01.pca.Geometry;
Wcm0   = info0.Dataspace.Size(2) * geom0.VoxelSizeX/10;
Hcm0   = info0.Dataspace.Size(1) * geom0.VoxelSizeY/10;
aspHW  = Hcm0 / Wcm0;

if ~isfolder('results/'), mkdir('results/'); end

for aIdx = 1:numel(angleTargets)
    targetAngle = angleTargets(aIdx);

    fig = figure('Position',[50 50 tileW_px*nExp+120 tileW_px*aspHW+150]);
    tl = tiledlayout(fig, 1, nExp, 'TileSpacing','compact', 'Padding','compact');

    for i = 1:nExp

        filedataExp   = filedataExpAll{i};
        dataSource    = dataSourceAll{i};
        HDF5filename  = HDF5filenameAll{i};
        interpFcn     = interpFcnAll{i};
        expFolderName = expFolderNameAll{i};

        expCTData = struct();
        expCTData.(filedataExp.Key) = expCTDataAll{i};

        fprintf('Contour-by-angle %d deg, %s\n', targetAngle, filedataExp.Key)

        nFound = false(1, nHalfMax+1);              % which theta+n*180 were found (for the legend)
        ax = nexttile(tl, i);
        hold(ax,'on')
        Wcm = NaN; Hcm = NaN;

        for j = 1:length(expFolderName)
            run_name = "run_" + sprintf('%02d', j);
            HDF5dataPath = ['/exp/' char(run_name) '/conc'];
            info = h5info(HDF5filename, HDF5dataPath);
            dims = info.Dataspace.Size;
            nx = dims(1); ny = dims(2);

            varsRun = expCTData.(filedataExp.Key).varsAll.(dataSource);
            varsRun = varsRun(varsRun.runName == run_name & varsRun.tDtotal < tDmax, :);
            if isempty(varsRun), continue, end

            geom = expCTData.(filedataExp.Key).exp.(run_name).pca.Geometry;
            Wcm  = ny*geom.VoxelSizeX/10;           % physical image width  [cm]
            Hcm  = nx*geom.VoxelSizeY/10;           % physical image height [cm]

            xD = (0:ny-1)/(ny-1);                   % symmetric about the centre -> clean 1-xD flip
            zD = (0:nx-1)/(nx-1);

            rot = varsRun.rotPos;                   % raw angle 0..360: 360 is kept apart from 0

            % NOTE: row position in varsRun == HDF5 frame index k, since the
            % tDtotal<tDmax filter above only trims a trailing suffix
            % (tDtotal is monotonic in frame order), never a scattered subset.
            for n = 0:nHalfMax
                angN = targetAngle + 180*n;
                if angN > 360, break, end           % rotation stops at 360
                idxN = find(abs(rot - angN) <= angleTol_deg);
                if isempty(idxN), continue, end
                nFound(n+1) = true;

                % frames within the tolerance come in groups of consecutive
                % indices (one group per pass) -> keep the closest frame per pass
                passId = cumsum([1; diff(idxN(:)) > 1]);
                for q = unique(passId)'
                    kq = idxN(passId == q);
                    [~, best] = min(abs(rot(kq) - angN));
                    kk = kq(best);
                    plotOneContour(ax, HDF5filename, HDF5dataPath, kk, nx, ny, xD, zD, ...
                        filedataExp, interpFcn, dataSource, level, cmap, tDmaxContours, ...
                        varsRun.tDtotal(kk), lsHalf{n+1}, flipHalf(n+1));
                end
            end
        end

        set(ax,'YDir','reverse','FontSize',8)
        grid(ax,'on'); box(ax,'on')
        xlim(ax,[0 1]); ylim(ax,[0 1])
        if isfinite(Wcm), pbaspect(ax,[Wcm Hcm 1]); else, pbaspect(ax,[1 aspHW 1]); end
        colormap(ax,cmap)
        clim(ax,[tDminContours tDmaxContours])

        % line-style legend (black dummies, only for the angles present)
        hL = gobjects(0); lbl = strings(0);
        for n = find(nFound) - 1
            hL(end+1) = plot(ax, NaN, NaN, 'k', 'LineStyle', lsHalf{n+1}, 'LineWidth', 1.2); %#ok<SAGROW>
            if flipHalf(n+1)
                lbl(end+1) = sprintf('%d° (flip)', targetAngle + 180*n); %#ok<SAGROW>
            else
                lbl(end+1) = sprintf('%d°', targetAngle + 180*n); %#ok<SAGROW>
            end
        end
        if ~isempty(hL)
            legend(ax, hL, lbl, 'Location','southoutside', 'Orientation','horizontal', ...
                'FontSize',6, 'Box','off')
        end

        xlabel(ax,'x_D [-]')
        if i == 1, ylabel(ax,'z_D [-]'), end
        title(ax, char(filedataExp.Key), 'Interpreter','none','FontSize',8)
    end

    cb = colorbar(ax);
    cb.Layout.Tile = 'east';
    cb.Label.String = 't_D [-]';

    if targetAngle == 0
        subStr = 'solid 0°, dashed 180° flipped, dotted 360° not flipped';
    else
        subStr = sprintf('solid %d°, dashed %d° flipped', targetAngle, targetAngle + 180);
    end
    title(tl, sprintf('Contours @ C_D = %.2f, \\theta = %d°  (%s)', level, targetAngle, subStr))

    fnameAngle = sprintf('contourByAngle_%03ddeg_%s', targetAngle, dataSourceAll{1});
    saveas(fig, fullfile('results/', fnameAngle), 'png');
    saveas(fig, fullfile('results/', fnameAngle), 'fig');
end

%% Front velocity field by fixed angle: arrows = dz_front/dtD at each xD
% one figure per target angle, one tile per experiment
% frames: theta, theta+180 (flipped), 360 (= 0, not flipped) -> one time series per angle
% arrow: starts on the earlier front, length ~ local front velocity, colour = tD

angleTargets = [0 45 90 135];
angleTol_deg = 3;
level        = 0.5;               % contour level traced as "the front"
nXbins       = 15;                % number of arrows across xD
dtDmin       = 0.02;              % skip pass pairs closer than this in tD
velMode      = "abs";             % "abs": w = dzD/dtD (shared scale) | "rel": w / mean_x(w)
arrowMax     = 0.08;              % 95th-percentile arrow length in zD units ("abs")
relScale     = 0.05;              % arrow length for w/mean(w) = 1 ("rel")
tDminContours = 0;
tDmaxContours = tDmax;
cmap = flipud(winter(256));

nHalfMax = 2;
flipHalf = [false true false];    % theta+180 flipped, 360 not

xEdges = linspace(0, 1, nXbins+1);
xGrid  = 0.5*(xEdges(1:end-1) + xEdges(2:end));
tileW_px = 230;

% physical aspect from the first experiment
info0 = h5info(HDF5filenameAll{1}, '/exp/run_01/conc');
geom0 = expCTDataAll{1}.exp.run_01.pca.Geometry;
aspHW = (info0.Dataspace.Size(1)*geom0.VoxelSizeY) / (info0.Dataspace.Size(2)*geom0.VoxelSizeX);

if ~isfolder('results/'), mkdir('results/'); end
tD2c = @(tD) cmap(max(1,min(256, round(1 + 255*min(tD/tDmaxContours,1)))), :);

for aIdx = 1:numel(angleTargets)
    targetAngle = angleTargets(aIdx);

    % ---------- 1) collect passes (front profiles) for every experiment ----------
    P    = cell(1, nExp);          % P{i}: struct array of passes
    geomE = cell(1, nExp);
    for i = 1:nExp
        filedataExp   = filedataExpAll{i};
        dataSource    = dataSourceAll{i};
        HDF5filename  = HDF5filenameAll{i};
        interpFcn     = interpFcnAll{i};
        expFolderName = expFolderNameAll{i};
        expData       = expCTDataAll{i};

        fprintf('Front velocity %d deg, %s\n', targetAngle, filedataExp.Key)
        passes = struct('tD',{},'z',{},'xc',{},'zc',{},'n',{});

        for j = 1:length(expFolderName)
            run_name = "run_" + sprintf('%02d', j);
            HDF5dataPath = ['/exp/' char(run_name) '/conc'];
            info = h5info(HDF5filename, HDF5dataPath);
            nx = info.Dataspace.Size(1); ny = info.Dataspace.Size(2);

            varsRun = expData.varsAll.(dataSource);
            varsRun = varsRun(varsRun.runName == run_name & varsRun.tDtotal < tDmax, :);
            if isempty(varsRun), continue, end
            geomE{i} = [ny*expData.exp.(run_name).pca.Geometry.VoxelSizeX, ...
                        nx*expData.exp.(run_name).pca.Geometry.VoxelSizeY];

            xD = (0:ny-1)/(ny-1);
            zD = (0:nx-1)/(nx-1);
            rot = varsRun.rotPos;

            for n = 0:nHalfMax
                angN = targetAngle + 180*n;
                if angN > 360, break, end
                idxN = find(abs(rot - angN) <= angleTol_deg);
                if isempty(idxN), continue, end

                % consecutive frame indices = one pass through this angle
                passId = cumsum([1; diff(idxN(:)) > 1]);
                for q = unique(passId)'
                    kq = idxN(passId == q);
                    zFr = NaN(numel(kq), nXbins);
                    xcMid = []; zcMid = [];
                    for m = 1:numel(kq)
                        [xs, zs] = getContourXY(HDF5filename, HDF5dataPath, kq(m), nx, ny, xD, zD, ...
                            filedataExp, interpFcn, dataSource, level, flipHalf(n+1));
                        if isempty(xs), continue, end
                        zFr(m,:) = frontProfile(xs, zs, xEdges);
                        if m == ceil(numel(kq)/2), xcMid = xs; zcMid = zs; end
                    end
                    passes(end+1) = struct('tD', mean(varsRun.tDtotal(kq)), ...
                        'z', mean(zFr, 1, 'omitnan'), 'xc', xcMid, 'zc', zcMid, 'n', n); %#ok<SAGROW>
                end
            end
        end

        % time series sorted by tD; drop passes too close in time
        if ~isempty(passes)
            [~, o] = sort([passes.tD]);
            passes = passes(o);
            keep = [true, diff([passes.tD]) >= dtDmin];
            passes = passes(keep);
        end
        P{i} = passes;
    end

    % ---------- 2) velocities and a shared arrow scale ----------
    W = cell(1, nExp);
    for i = 1:nExp
        ps = P{i};
        W{i} = NaN(max(numel(ps)-1,0), nXbins);
        for p = 1:numel(ps)-1
            w = (ps(p+1).z - ps(p).z) / (ps(p+1).tD - ps(p).tD);   % dzD/dtD, >0 = moving down
            if velMode == "rel"
                w = w / mean(w, 'omitnan');
            end
            W{i}(p,:) = w;
        end
    end
    if velMode == "abs"
        wAll  = abs(cell2mat(cellfun(@(w) w(:), W, 'UniformOutput', false)'));
        scale = arrowMax / prctile(wAll(isfinite(wAll)), 95);
        velStr = 'dz_D/dt_D';
    else
        scale = relScale;
        velStr = 'w / mean_x(w)';
    end

    % ---------- 3) plot ----------
    fig = figure('Position',[50 50 tileW_px*nExp+120 tileW_px*aspHW+150]);
    tl = tiledlayout(fig, 1, nExp, 'TileSpacing','compact', 'Padding','compact');

    for i = 1:nExp
        ax = nexttile(tl, i);
        hold(ax,'on')
        ps = P{i};

        % faint contours of every pass, coloured by tD
        for p = 1:numel(ps)
            if isempty(ps(p).xc), continue, end
            c = tD2c(ps(p).tD);
            line(ax, ps(p).xc, ps(p).zc, 'Color', [c 0.25], 'LineWidth', 0.8, ...
                'HitTest','off','PickableParts','none');
        end

        % arrows: start on the earlier front, vertical, length ~ velocity
        for p = 1:numel(ps)-1
            ok = isfinite(W{i}(p,:)) & isfinite(ps(p).z);
            if ~any(ok), continue, end
            tMid = 0.5*(ps(p).tD + ps(p+1).tD);
            quiver(ax, xGrid(ok), ps(p).z(ok), zeros(1,nnz(ok)), scale*W{i}(p,ok), 0, ...
                'Color', tD2c(tMid), 'LineWidth', 1.1, 'MaxHeadSize', 0.6);
        end

        set(ax,'YDir','reverse','FontSize',8)
        grid(ax,'on'); box(ax,'on')
        xlim(ax,[0 1]); ylim(ax,[0 1])
        if ~isempty(geomE{i}), pbaspect(ax,[geomE{i} 1]); else, pbaspect(ax,[1 aspHW 1]); end
        colormap(ax,cmap)
        clim(ax,[tDminContours tDmaxContours])
        xlabel(ax,'x_D [-]')
        if i == 1, ylabel(ax,'z_D [-]'), end
        title(ax, char(filedataExpAll{i}.Key), 'Interpreter','none','FontSize',8)
    end

    cb = colorbar(ax);
    cb.Layout.Tile = 'east';
    cb.Label.String = 't_D [-]';

    if targetAngle == 0
        angStr = '0°, 180° (flip), 360°';
    else
        angStr = sprintf('%d°, %d° (flip)', targetAngle, targetAngle + 180);
    end
    if velMode == "abs"
        scStr = sprintf('arrow 0.1 z_D = %.2g', 0.1/scale);
    else
        scStr = sprintf('arrow %.2f z_D = mean speed', relScale);
    end
    title(tl, sprintf('Front velocity %s @ C_D = %.2f, \\theta = %s  (%s)', ...
        velStr, level, angStr, scStr))

    fname = sprintf('frontVelocity_%s_%03ddeg_%s', velMode, targetAngle, dataSourceAll{1});
    saveas(fig, fullfile('results/', fname), 'png');
    saveas(fig, fullfile('results/', fname), 'fig');
end

%% Velocity field (0): shared data -- one smoothed, flip-corrected image per pass
% For each angle family (theta, theta+180 flipped, 360 = 0 not flipped) and each
% experiment: the frame closest to the angle in every pass, smoothed like the
% contour maps and downsampled. Used by sections (1)-(4).

vfAngles  = [0 45 90 135];
vfTol     = 3;          % deg, angle matching tolerance
vfLevel   = 0.5;        % front = this C_D contour
vfSigma   = 20;         % px, Gaussian smoothing (as the contour maps)
vfDs      = 4;          % downsampling factor after smoothing (speed / memory)
vfDtDmin  = 0.02;       % passes closer than this in tD are dropped
vfNbins   = 40;         % xD bins for the front profile z_front(xD)
vfFlip    = [false true false];   % n = 0,1,2 -> theta, theta+180 (flip), theta+360

vfEdges = linspace(0,1,vfNbins+1);
vfXc    = 0.5*(vfEdges(1:end-1) + vfEdges(2:end));
cmap    = flipud(winter(256));
tileW_px = 230;

VF = cell(numel(vfAngles), nExp);
for aIdx = 1:numel(vfAngles)
    targetAngle = vfAngles(aIdx);
    for i = 1:nExp
        filedataExp   = filedataExpAll{i};
        dataSource    = dataSourceAll{i};
        HDF5filename  = HDF5filenameAll{i};
        interpFcn     = interpFcnAll{i};
        expFolderName = expFolderNameAll{i};
        expData       = expCTDataAll{i};
        fprintf('Velocity-field data %d deg, %s\n', targetAngle, filedataExp.Key)

        imgs = {}; tDs = []; ns = []; js = []; W = NaN; H = NaN;
        for j = 1:length(expFolderName)
            run_name = "run_" + sprintf('%02d', j);
            HDF5dataPath = ['/exp/' char(run_name) '/conc'];
            info = h5info(HDF5filename, HDF5dataPath);
            nx = info.Dataspace.Size(1); ny = info.Dataspace.Size(2);

            varsRun = expData.varsAll.(dataSource);
            varsRun = varsRun(varsRun.runName == run_name & varsRun.tDtotal < tDmax, :);
            if isempty(varsRun), continue, end
            geom = expData.exp.(run_name).pca.Geometry;
            W = ny*geom.VoxelSizeX/10;  H = nx*geom.VoxelSizeY/10;     % image size [cm]
            rot = varsRun.rotPos;

            for n = 0:2
                angN = targetAngle + 180*n;
                if angN > 360, break, end
                idxN = find(abs(rot - angN) <= vfTol);
                if isempty(idxN), continue, end
                passId = cumsum([1; diff(idxN(:)) > 1]);          % one group per pass
                for q = unique(passId)'
                    kq = idxN(passId == q);
                    [~, b] = min(abs(rot(kq) - angN));            % closest frame of the pass
                    kk = kq(b);
                    img = getSmoothImage(HDF5filename, HDF5dataPath, kk, nx, ny, ...
                        filedataExp, interpFcn, dataSource, vfSigma, vfFlip(n+1));
                    imgs{end+1} = single(imresize(img, 1/vfDs)); %#ok<SAGROW>
                    tDs(end+1)  = varsRun.tDtotal(kk);           %#ok<SAGROW>
                    ns(end+1)   = n;                             %#ok<SAGROW>
                    js(end+1)   = j;                             %#ok<SAGROW>
                end
            end
        end

        rec = struct('key', string(filedataExp.Key), 'W', W, 'H', H, 'xD', [], 'zD', [], ...
            'tD', [], 'n', [], 'run', [], 'C', [], 'xc', {{}}, 'zc', {{}}, 'zProf', []);
        if ~isempty(imgs)
            [tDs, o] = sort(tDs);  imgs = imgs(o);  ns = ns(o);  js = js(o);
            keep   = [true, diff(tDs) >= vfDtDmin];
            rec.tD = tDs(keep);  rec.n = ns(keep);  rec.run = js(keep);
            rec.C  = cat(3, imgs{keep});
            [nzs, nxs, P] = size(rec.C);
            rec.xD = linspace(0,1,nxs);  rec.zD = linspace(0,1,nzs);
            rec.xc = cell(1,P);  rec.zc = cell(1,P);  rec.zProf = NaN(P, vfNbins);
            for p = 1:P
                Cm = contourc(rec.xD, rec.zD, double(rec.C(:,:,p)), [vfLevel vfLevel]);
                [xs, zs] = getLevelSegments(parseContourMatrix(Cm), vfLevel);
                rec.xc{p} = xs;  rec.zc{p} = zs;
                if ~isempty(xs), rec.zProf(p,:) = frontProfile(xs, zs, vfEdges); end
            end
        end
        VF{aIdx,i} = rec;
    end
end

r1 = [VF{:}];  r1 = r1(isfinite([r1.W]));
aspHW = r1(1).H / r1(1).W;                 % physical height/width of the images

if ~isfolder('results/'), mkdir('results/'); end
save(fullfile('results','velField_data.mat'), 'VF', 'vfAngles', 'vfLevel', 'vfXc', '-v7.3');

%% Velocity field (1): arrival-time map and front-speed map
% t_arr(x,z) = tD at which C first crosses vfLevel (linear between passes)
% isochrones = contours of t_arr; front velocity v = grad(t_arr)/|grad(t_arr)|^2
% top row: t_arr + isochrones + arrows (direction of motion); bottom row: speed |v|

arrSigma = 2;      % px (downsampled grid), smoothing of t_arr before the gradient
arrStep  = 10;     % px between arrows
nIso     = 12;     % number of isochrones

for aIdx = 1:numel(vfAngles)
    targetAngle = vfAngles(aIdx);
    TA = cell(1,nExp); SP = cell(1,nExp); VX = cell(1,nExp); VZ = cell(1,nExp);

    for i = 1:nExp
        rec = VF{aIdx,i};
        if numel(rec.tD) < 2, continue, end
        C = double(rec.C);  P = size(C,3);
        tArr = NaN(size(C,1), size(C,2));
        for p = 2:P
            if rec.run(p) ~= rec.run(p-1), continue, end     % no interpolation across runs (360 -> next 0)
            c0 = C(:,:,p-1);  c1 = C(:,:,p);
            hit = isnan(tArr) & c0 < vfLevel & c1 >= vfLevel;
            fr  = (vfLevel - c0(hit)) ./ (c1(hit) - c0(hit));
            tArr(hit) = rec.tD(p-1) + fr*(rec.tD(p) - rec.tD(p-1));
        end
        m  = isfinite(tArr);  t0 = tArr;  t0(~m) = 0;            % NaN-aware smoothing
        tS = imgaussfilt(t0, arrSigma) ./ imgaussfilt(double(m), arrSigma);
        tS(~m) = NaN;

        dx = rec.W/(numel(rec.xD)-1);  dz = rec.H/(numel(rec.zD)-1);   % cm per px
        [gx, gz] = gradient(tS, dx, dz);                 % tD per cm
        g2 = gx.^2 + gz.^2;
        VX{i} = gx./g2;  VZ{i} = gz./g2;                 % cm per tD
        SP{i} = sqrt(VX{i}.^2 + VZ{i}.^2) / rec.H;       % zD per tD
        TA{i} = tS;
    end

    tmp = cellfun(@(s) s(isfinite(s)), SP, 'UniformOutput', false);
    spAll = vertcat(tmp{:});
    if isempty(spAll), spLim = [0 1]; else, spLim = [0 prctile(spAll, 95)]; end

    fig = figure('Position',[50 50 tileW_px*nExp+180 2*tileW_px*aspHW+180]);
    tl = tiledlayout(fig, 2, nExp, 'TileSpacing','compact', 'Padding','compact');
    for i = 1:nExp
        rec = VF{aIdx,i};
        axT = nexttile(tl, i);  axS = nexttile(tl, nExp+i);
        if isempty(TA{i}), axis(axT,'off'); axis(axS,'off'); continue, end

        [Xg, Zg] = meshgrid(rec.xD, rec.zD);
        iso = linspace(min(TA{i}(:)), max(TA{i}(:)), nIso);
        ir = 1:arrStep:numel(rec.zD);  ic = 1:arrStep:numel(rec.xD);
        U = VX{i}(ir,ic)/rec.W;  V = VZ{i}(ir,ic)/rec.H;            % xD, zD per tD
        mag = hypot(U,V);  capM = prctile(mag(isfinite(mag)), 95);
        f = min(1, capM./mag);  U = U.*f;  V = V.*f;                 % clip outliers

        imagesc(axT, rec.xD, rec.zD, TA{i}, 'AlphaData', isfinite(TA{i}));  hold(axT,'on')
        contour(axT, Xg, Zg, TA{i}, iso, 'k', 'LineWidth', 0.5);
        quiver(axT, Xg(ir,ic), Zg(ir,ic), U, V, 1, 'k', 'LineWidth', 0.8);
        colormap(axT, cmap);  clim(axT, [0 tDmax]);

        imagesc(axS, rec.xD, rec.zD, SP{i}, 'AlphaData', isfinite(SP{i}));  hold(axS,'on')
        contour(axS, Xg, Zg, TA{i}, iso, 'w', 'LineWidth', 0.4);
        colormap(axS, parula);  clim(axS, spLim);

        for ax = [axT axS]
            set(ax, 'YDir','reverse', 'FontSize',8);  box(ax,'on')
            xlim(ax,[0 1]);  ylim(ax,[0 1]);  pbaspect(ax, [rec.W rec.H 1])
            if i == 1, ylabel(ax,'z_D [-]'), end
        end
        title(axT, char(rec.key), 'Interpreter','none', 'FontSize',8)
        xlabel(axS, 'x_D [-]')
    end
    cbT = colorbar(axT);  cbT.Label.String = 't_{arr} [t_D]';
    cbS = colorbar(axS);  cbS.Label.String = 'front speed [z_D / t_D]';

    title(tl, sprintf('Arrival time and front speed @ C_D = %.2f, \\theta = %d° family', ...
        vfLevel, targetAngle))
    fname = sprintf('velField1_arrival_%03ddeg_%s', targetAngle, dataSourceAll{1});
    saveas(fig, fullfile('results', fname), 'png');  saveas(fig, fullfile('results', fname), 'fig');
end

%% Velocity field (3): front contours coloured by local normal speed
% each point of the contour at pass p is coloured by its distance to the nearest
% point of the contour at pass p+1, divided by delta tD [zD per tD]; + = moving down.
% Last pass drawn in grey (no next contour).

for aIdx = 1:numel(vfAngles)
    targetAngle = vfAngles(aIdx);
    SPc = cell(1,nExp);

    for i = 1:nExp
        rec = VF{aIdx,i};
        P = numel(rec.tD);
        SPc{i} = cell(1, max(P-1,0));
        for p = 1:P-1
            if rec.run(p+1) ~= rec.run(p), continue, end       % same run only
            A = [rec.xc{p}(:)*rec.W,   rec.zc{p}(:)*rec.H];       % cm
            B = [rec.xc{p+1}(:)*rec.W, rec.zc{p+1}(:)*rec.H];
            okA = all(isfinite(A),2);  B = B(all(isfinite(B),2), :);
            if isempty(B) || ~any(okA), continue, end
            [id, d] = knnsearch(B, A(okA,:));
            sgn = sign(B(id,2) - A(okA,2));  sgn(sgn == 0) = 1;
            s = NaN(size(A,1),1);
            s(okA) = sgn .* d / (rec.H * (rec.tD(p+1) - rec.tD(p)));
            SPc{i}{p} = s;
        end
    end

    tmp = [SPc{:}];  allS = vertcat(tmp{:});  allS = allS(isfinite(allS));
    if isempty(allS), sLim = [0 1]; else, sLim = prctile(allS, [5 95]); end

    fig = figure('Position',[50 50 tileW_px*nExp+160 tileW_px*aspHW+150]);
    tl = tiledlayout(fig, 1, nExp, 'TileSpacing','compact', 'Padding','compact');
    for i = 1:nExp
        rec = VF{aIdx,i};
        ax = nexttile(tl, i);  hold(ax,'on')
        P = numel(rec.tD);
        for p = 1:P-1
            if isempty(SPc{i}{p}), continue, end
            scatter(ax, rec.xc{p}(:), rec.zc{p}(:), 5, SPc{i}{p}, 'filled');
        end
        if P >= 1 && ~isempty(rec.xc{P})
            line(ax, rec.xc{P}, rec.zc{P}, 'Color', [0.6 0.6 0.6], 'LineWidth', 1);
        end
        set(ax, 'YDir','reverse', 'FontSize',8);  grid(ax,'on');  box(ax,'on')
        xlim(ax,[0 1]);  ylim(ax,[0 1])
        if isfinite(rec.W), pbaspect(ax, [rec.W rec.H 1]); end
        colormap(ax, parula);  clim(ax, sLim);
        xlabel(ax,'x_D [-]');  if i == 1, ylabel(ax,'z_D [-]'), end
        title(ax, char(rec.key), 'Interpreter','none', 'FontSize',8)
    end
    cb = colorbar(ax);  cb.Layout.Tile = 'east';  cb.Label.String = 'normal front speed [z_D / t_D]';

    title(tl, sprintf('Front contours coloured by local speed @ C_D = %.2f, \\theta = %d° family', ...
        vfLevel, targetAngle))
    fname = sprintf('velField3_contourSpeed_%03ddeg_%s', targetAngle, dataSourceAll{1});
    saveas(fig, fullfile('results', fname), 'png');  saveas(fig, fullfile('results', fname), 'fig');
end

%% local functions

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
    dataSource    = getappdata(fig,'dataSource');
    filedataExp   = getappdata(fig,'filedataExp');

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
    rhoNormImageVac = h5read(HDF5filename, HDF5dataPath, [1 1 frames(idx).k], [nx ny 1]);
    rhoNormImage = rhoNorm_wVacRef(rhoNormImageVac,filedataExp.Fluid1, ...
        filedataExp.Fluid2, filedataExp.T, filedataExp.P);
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

function segs = parseContourMatrix(C)
%PARSECONTOURMATRIX Parse the raw output of contourc into named segments.
%
%   segs = parseContourMatrix(C) walks the 2-by-N contour matrix C
%   returned by contourc (same format contour() uses internally) and
%   returns a struct array, one entry per disjoint polyline, with
%   fields: level, x, y. A single contour LEVEL can produce more than
%   one disjoint polyline (e.g. a level crossed in two separate places),
%   each becoming its own entry here with the same .level value.
 
segs = struct('level',{},'x',{},'y',{});
idx = 1;
while idx <= size(C,2)
    lvl   = C(1,idx);
    npts  = C(2,idx);
    xseg  = C(1, idx+1 : idx+npts);
    yseg  = C(2, idx+1 : idx+npts);
    segs(end+1) = struct('level',lvl,'x',xseg,'y',yseg); 
    idx = idx + npts + 1;
end
end
 
function [xAll, yAll, segList] = getLevelSegments(segs, targetLevel, tol)
%GETLEVELSEGMENTS Pull out all polylines for one level from parsed segs.
%
%   [xAll, yAll, segList] = getLevelSegments(segs, targetLevel) returns:
%       xAll, yAll - NaN-separated coordinate vectors ready to hand
%                    straight to line()/plot() as ONE graphics object,
%                    even when the level has multiple disjoint pieces
%                    (matches what contour() would have drawn).
%       segList    - the matching entries of segs (struct array), for
%                    convenience when you need the first polyline's
%                    points individually (e.g. for label placement).
 
if nargin < 3
    tol = 1e-6;
end
if isempty(segs)
    xAll = []; yAll = []; segList = segs([]);
    return
end
sel = abs([segs.level] - targetLevel) < tol;
segList = segs(sel);
 
xAll = [];
yAll = [];
for s = 1:numel(segList)
    if s > 1
        xAll = [xAll NaN]; 
        yAll = [yAll NaN]; 
    end
    xAll = [xAll segList(s).x]; 
    yAll = [yAll segList(s).y]; 
end
end

function plotOneContour(ax, HDF5filename, HDF5dataPath, k, nx, ny, xD, zD, ...
    filedataExp, interpFcn, dataSource, level, cmap, tDmaxContours, tD, lineStyle, flipX)
% PLOTONECONTOUR  Reads one frame, extracts its C=level contour, and draws
% it on ax colored by tD (clamped to [0,tDmaxContours]) with the given
% line style. flipX=true mirrors the contour in x (xD -> 1-xD) -- needed
% for the +180 mirror angle when the target/mirror axis is not aligned
% with the detector's own x-axis (e.g. 90/270), but NOT when it is
% (e.g. 0/180).

rhoNormImageVac = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
rhoNormImage = rhoNorm_wVacRef(rhoNormImageVac, filedataExp.Fluid1, ...
    filedataExp.Fluid2, filedataExp.T, filedataExp.P);
if strcmp(dataSource,'conc')
    plotImage = interpFcn(rhoNormImage);
else
    plotImage = rhoNormImage;
end
imgSmooth = imgaussfilt(plotImage, 20);

Cmat = contourc(double(xD), double(zD), double(imgSmooth), [level level]);
segsAll = parseContourMatrix(Cmat);
[xSeg, ySeg] = getLevelSegments(segsAll, level);
if isempty(xSeg), return, end

if flipX
    xSeg = 1 - xSeg;
end

cidx = round(1 + 255*min(tD/tDmaxContours,1));
cidx = max(1,min(256,cidx));

line(ax, xSeg, ySeg, 'LineStyle', lineStyle, 'Color', cmap(cidx,:), 'LineWidth', 1.5, ...
    'HitTest','off','PickableParts','none');
end

function z = frontProfile(xs, zs, xEdges)
% FRONTPROFILE  Front depth per xD bin: median zD of the contour points in each bin.
ok = isfinite(xs) & isfinite(zs);
xs = xs(ok); zs = zs(ok);
nb = numel(xEdges) - 1;
z  = NaN(1, nb);
b  = discretize(xs, xEdges);
for q = 1:nb
    if any(b == q), z(q) = median(zs(b == q)); end
end
end

function img = getSmoothImage(HDF5filename, HDF5dataPath, k, nx, ny, ...
    filedataExp, interpFcn, dataSource, sigma, flipX)
% GETSMOOTHIMAGE  Frame k as conc (or rhoNorm), Gaussian-smoothed, optionally x-mirrored.
raw = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
rhoNormImage = rhoNorm_wVacRef(raw, filedataExp.Fluid1, filedataExp.Fluid2, ...
    filedataExp.T, filedataExp.P);
if strcmp(dataSource,'conc')
    img = interpFcn(rhoNormImage);
else
    img = rhoNormImage;
end
img = imgaussfilt(double(img), sigma);
if flipX, img = fliplr(img); end
end

function [xSeg, ySeg] = getContourXY(HDF5filename, HDF5dataPath, k, nx, ny, xD, zD, ...
    filedataExp, interpFcn, dataSource, level, flipX)
% GETCONTOURXY  C=level contour of frame k (NaN-separated), optionally x-mirrored.
img = getSmoothImage(HDF5filename, HDF5dataPath, k, nx, ny, ...
    filedataExp, interpFcn, dataSource, 20, flipX);
Cmat = contourc(double(xD), double(zD), img, [level level]);
[xSeg, ySeg] = getLevelSegments(parseContourMatrix(Cmat), level);
end

function G = interpCols(t, Y, tq)
% INTERPCOLS  Interpolate each column of Y (rows at times t) onto times tq.
G = NaN(numel(tq), size(Y,2));
for b = 1:size(Y,2)
    ok = isfinite(Y(:,b));
    if nnz(ok) >= 2
        G(:,b) = interp1(t(ok), Y(ok,b), tq, 'linear', NaN);
    end
end
end

function c = divergingMap(n)
% DIVERGINGMAP  Blue - white - red colormap (white in the middle).
h = floor(n/2);
blu = [linspace(0.15,1,h)',   linspace(0.35,1,h)',   linspace(0.75,1,h)'];
red = [linspace(1,0.75,n-h)', linspace(1,0.15,n-h)', linspace(1,0.15,n-h)'];
c = [blu; red];
end