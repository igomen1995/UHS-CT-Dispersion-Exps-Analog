
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
    
    fig = figure('Position', [50, 50, 800, 1000]); % [left, bottom, width, height];
    % figure config
    imgPos  = [0.1 0.1  0.8 0.8]; % xleft ybottom W H
    hGap = 0.07;
    vGap = 0.07;   
    % colorbar alignment settings
    cbGapL     = 0.012;   % gap between axes and colorbar when colorbar is on the LEFT
    cbGapR     = 0.012;   % gap between axes and colorbar when colorbar is on the RIGHT
    cbWidth    = 0.018;   % fixed colorbar width
    cbLabelPad = 0.008;    % extra room reserved for the colorbar's title/label text
    cbReserve = cbGapR + cbWidth + cbLabelPad; % reserve room for one colorbar + its label per column
    % plotting window
    colsW = (imgPos(3) - 2*hGap)/3 - cbReserve;
    row1H = imgPos(4)*3/4 - vGap;
    row2H = imgPos(4)/4;
    ax1Pos  = [imgPos(1) imgPos(2)+row2H+vGap colsW row1H];
    ax2Pos  = [imgPos(1)+(colsW+cbReserve)+hGap ax1Pos(2) ax1Pos(3) ax1Pos(4)];
    ax3Pos  = [imgPos(1)+2*(colsW+cbReserve+hGap) ax1Pos(2) ax1Pos(3) ax1Pos(4)];
    ax4Pos  = [imgPos(1) imgPos(2) imgPos(3) row2H];
    % axes
    ax1 = axes('Position',ax1Pos);
    ax2 = axes('Position',ax2Pos);
    ax3 = axes('Position',ax3Pos);
    ax4 = axes('Position',ax4Pos);
    % colorbar spacing
    cbGap   = 0.02;   % fixed horizontal gap between axes and its colorbar
    cbWidth = 0.018;   % fixed colorbar width

    % hTitle
    hTitle = annotation('textbox', [0 0.93 1 0.05], ...
        'String', '', ...
        'EdgeColor','none', ...
        'HorizontalAlignment','center', ...
        'FontWeight','bold', ...
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

    tDtargetsAll = [];

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
        tDtargetsAll = [tDtargetsAll, tDtargets];
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
            levels = [0.5 0.5];
            cidx = round(1 + 255*(tD-tDmin)/(tDmax-tDmin));
            cidx = max(1,min(256,cidx));
            hold(ax1,'on')
            [C, h] = contour(ax1,xD,zD,imgSmooth,levels, ...
                'LineColor',cmap(cidx,:),...
                'LineWidth',3);

            % ax3
            x2 = vars.C1Profile.zVertcm;
            xD2 = x2/max(x2);
            y2 = vars.C1Profile.rhoNormVert;
            scatter(ax3,xD2,y2,3,'filled','MarkerFaceColor',cmap(cidx,:))
            hold(ax3,'on')

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
                    tD,vars.rotPos),'Color',cmap(cidx,:),...
                    'FontSize',8,'FontWeight','bold',...
                    'HorizontalAlignment','center',...
                    'BackgroundColor','none','Margin',1);
                % ax3
                text(ax3,zLab,0.3, ...
                sprintf('t_D = %.1f\n\\theta = %.0f °', ...
                    tD,vars.rotPos),'Color',cmap(cidx,:), ...
                'FontSize',8,'FontWeight','bold', ...
                'BackgroundColor','w','Margin',1);

            end        
            
        end

        kshow = k;
        varsShow = vars;
        imgShow = concCTimages;
    end
    
    % ax1
    set(ax1,'YDir','reverse','FontSize',8)
    % axis(ax1,'equal')
    grid(ax1,'on')
    xlabel(ax1,'x_D [-]','FontSize',8)
    ylabel(ax1,'z_D [-]','FontSize',8)
    colormap(ax1,cmap)
    clim(ax1,[tDmin tDmax])
    cb1 = colorbar(ax1);
    cb1.Label.String = 't_D_{total} [-]';
    cb1.FontSize = 8;
    cb1.Direction = 'reverse';
    % legend(hLeg,legTxt,'Location','southeastoutside');
    % title(ax1,{'Evolution of C ~ 0.5 Front', char(filedataExp.Key)}, ...
    %     'Interpreter','none','FontSize',8)

    % ax2
    concCTimages = h5read(HDF5filename,HDF5dataPath,...
    [1 1 k],[nx ny 1]);
    cla(ax2)
    imagesc(ax2,concCTimages)
    axis(ax2,'xy')
    set(ax2,'YDir','reverse')
    xlabel(ax2,'Pixel Number')
    % ylabel(ax2,'Pixel Number')
    set(ax2,'YTick',[],'YTickLabel',[])
    colormap(ax2,turbo)
    clim(ax2,[0 1])
    cb2 = colorbar(ax2);
    cb2.Label.String = 'C_1 [-]';
    
    % ax3
    camroll(ax3,270)
    % xlabel(ax3,'z_D [-]')
    set(ax3,'XTick',[],'XTickLabel',[])
    ylabel(ax3,'C_{ave,1} [-]')
    colormap(ax3,cmap)
    clim(ax3,[tDmin tDmax])
    cb3 = colorbar(ax3);
    cb3.Label.String = 't_D_{total} [-]';
    cb3.FontSize = 8;
    cb3.Direction = 'reverse';
    grid(ax3,'on')
    ylim(ax3,[-0.02 1])
    ax3.YAxisLocation = 'right';

    % ax4 Breakthrough curve 
    BT = expCTData.(filedataExp.Key(i)).BTcore;
    scatter(ax4, BT.tDtotal, BT.rhoNorm,3,'filled',...
        'MarkerFaceColor','k')
    hold(ax4,'on')
    tCurrent = varsShow.tDtotal;
    CCurrent = varsShow.C1Profile.rhoNormVert(end);
    scatter(ax4,tCurrent,CCurrent,50,...
        'r','filled')
    grid(ax4,'on')
    xlabel(ax4,'t_D [-]')
    ylabel(ax4,'C_{ave,1} [-]')
    ylim(ax4,[-0.02 1])
    xlim(ax4,[BT.tDtotal(1),BT.tDtotal(end)])

    % ---- force identical plot boxes + identically-offset colorbars ----
    drawnow
    alignAxesColorbar(ax1, cb1, ax1Pos, cbGapR, cbWidth, 'right');
    alignAxesColorbar(ax2, cb2, ax2Pos, cbGapR, cbWidth, 'right');
    alignAxesColorbar(ax3, cb3, ax3Pos, cbGapR, cbWidth, 'right');
end
saveas(gcf,pathExportAll + filedataExp.Key + "_ContourfrontAdvance",'png')
saveas(gcf,pathExportAll + filedataExp.Key + "_ContourfrontAdvance")

% ---- local function (put at the bottom of the script file) ----
function alignAxesColorbar(ax, cb, axPos, cbGap, cbWidth, side)
    if nargin < 6
        side = 'right';
    end
    ax.Units = 'normalized';
    cb.Units = 'normalized';
    ax.Position = axPos;   % restore exact plot box

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