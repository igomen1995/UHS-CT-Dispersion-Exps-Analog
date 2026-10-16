%% CT figure for the paper: one projection (i, j, k), current (old) processing
%
% Five panels, left to right:
%   (a) Xe reference (refInit)   normalized + cropped
%   (b) He reference (refFinal)  normalized + cropped
%   (c) experiment (exp)         normalized + cropped
%   (d) rhoNorm   = rhoNorm_wVacRef( satImage(exp, refInit, refFinal) )
%   (e) C_molar   = REFPROP interpolant of rhoNorm
% Panels (a)-(c) use the same grey-scale limits; every panel has its own colour bar. Panels (d)-(e) show the
% unsmoothed image with contours of the imgaussfilt(sigmaCont) field, exactly
% as in main_CTimaging (for C_molar the smoothing is applied after REFPROP).
%
% Processing (same as main_CTextract):
%   raw -> normImage -> findCropWindow_xAxis (cropWidth) on refInit -> cropImage
%       -> satImage -> rhoNorm_wVacRef -> interpFcn
%
% Outputs in <exportPath>:
%   paperFig_<Key>_run_jj_kkkk.png (600 dpi), .pdf, .fig

clear;

%% IMPORT input

CT_setupPaths;

inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

% Crop parameters (same as main_CTextract)
pixDist      = 70;
partsScanned = 5;      % air, core holder, water, sleeve, core
cropWidth    = 1400;

% Contours (same as main_CTimaging)
sigmaCont  = 20;        % Gaussian used ONLY to compute the contours
levelsFull = 0.1:0.1:0.9;
labelContours = true;   % numbers on the thin contours

% Figure layout, in pixels (same approach as main_CTimaging: fixed axes positions)
imgWpx       = 200;     % width of each image axes
imgHpx       = 500;     % height of each image axes
cbGapPx      = 6;       % gap image -> colour bar
cbWpx        = 12;      % colour-bar width
cbLabelPx    = 48;      % room for colour-bar ticks + label
hGapPx       = 22;      % extra gap before the next panel
leftPx       = 60;      % room for the z label
rightPx      = 10;
bottomPx     = 55;      % room for the x label
topPx        = 60;      % room for panel titles + info line
fontName     = 'Helvetica';
fontSize     = 10;
axisUnits    = 'D';     % 'D' = x_D, z_D [-]   |  'cm' = from the voxel size in the .pca
climNorm     = [];      % grey-scale limits for (a)-(c); [] = 0.5-99.5 percentiles of the three
showInfo     = true;    % t_D and angle in the figure title (needs <Key>.mat)

%% USER SELECTION

iSel = 1;          % experiment row in inputCTExpConfig.xlsx
jSel = 1;          % run
kSel = 100;        % projection

%% IMPORT folders and metadata

filenameExp   = inputFileConfig.inputFileName{iSel};
pathExportAll = inputFileConfig.exportPath{iSel};
if ~isfolder(pathExportAll), mkdir(pathExportAll); end
filedataExp   = import_inputCTExp(filenameExp);
key           = char(filedataExp.Key);

refInitFolderContent = dir(filedataExp.path+filedataExp.CT_data_ref_init);      % Xe
refInitFolderContent = refInitFolderContent([refInitFolderContent.isdir] & ~startsWith({refInitFolderContent.name},'.'));
refInitFolderPathCT  = fullfile(refInitFolderContent.folder, refInitFolderContent.name);
refInitpca           = importPCA(dir(fullfile(refInitFolderPathCT, '*.pca')));
refInitimgFiles      = dir(fullfile(refInitFolderPathCT, '*.tif'));

refFinalFolderContent = dir(filedataExp.path+filedataExp.CT_data_ref_final);    % He
refFinalFolderContent = refFinalFolderContent([refFinalFolderContent.isdir] & ~startsWith({refFinalFolderContent.name},'.'));
refFinalimgFiles      = dir(fullfile(refFinalFolderContent.folder, refFinalFolderContent.name, '*.tif'));

expFolderContent = dir(filedataExp.path+filedataExp.CT_data_exp);               % exp
expFolderContent = expFolderContent([expFolderContent.isdir] & ~startsWith({expFolderContent.name},'.'));
expFolderPathCT  = fullfile(expFolderContent(jSel).folder, expFolderContent(jSel).name);
exppca           = importPCA(dir(fullfile(expFolderPathCT, '*.pca')));
expimgFiles      = dir(fullfile(expFolderPathCT, '*.tif'));

crop_yCoords = [1; refInitpca.Image.DimY];

%% PROCESS (old pipeline)

refInitImage  = double(normImage(importImages(refInitimgFiles,  kSel)));
refFinalImage = double(normImage(importImages(refFinalimgFiles, kSel)));
expImage      = double(normImage(importImages(expimgFiles,      kSel)));

crop_xCoords_k = findCropWindow_xAxis(refInitImage, pixDist, partsScanned-1, cropWidth);
fprintf('%s run %02d k %d: crop x = [%d %d]\n', key, jSel, kSel, crop_xCoords_k(1), crop_xCoords_k(2));

refInitCropped  = double(cropImage(refInitImage,  crop_xCoords_k, crop_yCoords));
refFinalCropped = double(cropImage(refFinalImage, crop_xCoords_k, crop_yCoords));
expCropped      = double(cropImage(expImage,      crop_xCoords_k, crop_yCoords));

rhoNormNoCorr = satImage(expCropped, refInitCropped, refFinalCropped);       % (exp, min, max)
rhoNorm = double(rhoNorm_wVacRef(single(rhoNormNoCorr), filedataExp.Fluid1, ...
    filedataExp.Fluid2, filedataExp.T, filedataExp.P));

interpFcn = buildInterpolant(filedataExp.Fluid1, filedataExp.Fluid2, filedataExp.T, filedataExp.P);
Cmolar    = double(interpFcn(rhoNorm));

% fields used ONLY for the contours
rhoNormSmooth = imgaussfilt(rhoNorm, sigmaCont);
CmolarSmooth  = imgaussfilt(Cmolar,  sigmaCont);

if any(isnan(Cmolar(:)))
    warning('%d NaN pixels in C_molar (rhoNorm outside the REFPROP range); contours near them are missing.', ...
        nnz(isnan(Cmolar)));
end

%% COORDINATES

[nz, nx] = size(rhoNorm);
switch axisUnits
    case 'cm'
        xAx = (1:nx) * exppca.Geometry.VoxelSizeX / 10;
        zAx = (1:nz) * exppca.Geometry.VoxelSizeY / 10;
        xLab = 'x [cm]';  zLab = 'z [cm]';
    otherwise
        xAx = (1:nx) / nx;
        zAx = (1:nz) / nz;
        xLab = 'x_D [-]'; zLab = 'z_D [-]';
end

if isempty(climNorm)
    allNorm  = [refInitCropped(:); refFinalCropped(:); expCropped(:)];
    climNorm = prctile(allNorm(isfinite(allNorm)), [0.5 99.5]);
end

%% FIGURE

[infoStr, rotPos] = getScanInfo(pathExportAll, key, jSel, kSel);   % rotPos = NaN if <Key>.mat is missing

panelW = imgWpx + cbGapPx + cbWpx + cbLabelPx + hGapPx;     % one image + its colour bar
figW   = leftPx + 5*panelW - hGapPx + rightPx;
figH   = bottomPx + imgHpx + topPx;

fig = figure('Units','pixels', 'Position',[50 50 figW figH], 'Color','w');
axPos = @(p) [leftPx + (p-1)*panelW, bottomPx, imgWpx, imgHpx];   % [left bottom W H] in px

if showInfo
    if ~isempty(infoStr)
        annotation(fig, 'textbox', 'Units','pixels', 'Position',[0 figH-28 figW 24], ...
            'String', infoStr, 'EdgeColor','none', 'HorizontalAlignment','center', ...
            'FontName',fontName, 'FontSize',fontSize, 'Interpreter','tex');
    end
end

normImgs   = {refInitCropped, refFinalCropped, expCropped};
normTitles = {'(a) Xe reference', '(b) He reference', '(c) Experiment'};
for p = 1:3
    ax = axes(fig, 'Units','pixels', 'Position', axPos(p));
    imagesc(ax, xAx, zAx, normImgs{p});
    styleAxes(ax, normTitles{p}, xLab, zLab, p == 1, fontName, fontSize);
    colormap(ax, gray); clim(ax, climNorm);
    addColorbar(ax, 'CT normalized [-]', fontName, fontSize, cbGapPx, cbWpx);
end

ax = axes(fig, 'Units','pixels', 'Position', axPos(4));
plotImageContours(ax, xAx, zAx, rhoNorm, rhoNormSmooth, levelsFull, labelContours, fontSize);
styleAxes(ax, '(d) \rho_{norm}', xLab, zLab, false, fontName, fontSize);
addColorbar(ax, '\rho_{norm} [-]', fontName, fontSize, cbGapPx, cbWpx);

ax = axes(fig, 'Units','pixels', 'Position', axPos(5));
plotImageContours(ax, xAx, zAx, Cmolar, CmolarSmooth, levelsFull, labelContours, fontSize);
styleAxes(ax, '(e) C_{molar}', xLab, zLab, false, fontName, fontSize);
addColorbar(ax, 'C_{molar} [-]', fontName, fontSize, cbGapPx, cbWpx);

%% EXPORT

if isnan(rotPos)
    angStr = 'angNA';
    warning('Rotation angle not found (no %s.mat); file name uses angNA.', key);
else
    angStr = "ang" + strrep(sprintf('%.1f', rotPos), '.', 'p') + "deg";   % e.g. ang123p5deg
end
baseName = fullfile(pathExportAll, sprintf('paperFig_%s_run_%02d_k%04d_%s', key, jSel, kSel, angStr));
exportgraphics(fig, baseName + ".png", 'Resolution', 600);
savefig(fig, baseName + ".fig");
fprintf('Saved %s.(png|fig)\n', baseName);

%% local functions

function plotImageContours(ax, xAx, zAx, img, imgCont, levelsFull, labelContours, fontSize)
    imagesc(ax, xAx, zAx, img);
    colormap(ax, turbo); clim(ax, [0 1]);
    hold(ax, 'on');
    if labelContours
        [C, h] = contour(ax, xAx, zAx, imgCont, levelsFull, 'LineColor','k', 'LineWidth',0.5);
        clabel(C, h, 'FontSize', fontSize-2, 'LabelSpacing', 400, 'Color','k');
    else
        contour(ax, xAx, zAx, imgCont, levelsFull, 'LineColor','k', 'LineWidth',0.5);
    end
    hold(ax, 'off');
end

function addColorbar(ax, lbl, fontName, fontSize, cbGapPx, cbWpx)
% colour bar pinned next to the image; the image axes keeps its exact size
    pos = ax.Position;                       % pixels
    cb = colorbar(ax);
    cb.Units = 'pixels';
    ax.Position = pos;                       % colorbar() would shrink the axes: restore it
    cb.Position = [pos(1)+pos(3)+cbGapPx, pos(2), cbWpx, pos(4)];
    cb.Label.String = lbl;
    cb.FontName = fontName; cb.FontSize = fontSize; cb.TickDirection = 'out';
    cb.Ruler.TickLabelFormat = '%.2f';    % 0.xx, never 0.xxx
end

function styleAxes(ax, ttl, xLab, zLab, showZ, fontName, fontSize)
    axis(ax, 'tight');
    set(ax, 'YDir','reverse', 'FontName',fontName, 'FontSize',fontSize, ...
        'TickDir','out', 'Box','on', 'Layer','top');
    xlabel(ax, xLab);
    if showZ
        ylabel(ax, zLab);
    else
        set(ax, 'YTickLabel', []);
    end
    title(ax, ttl, 'FontWeight','normal', 'Interpreter','tex');
end

function [infoStr, rotPos] = getScanInfo(pathExportAll, key, j, k)
% t_D, elapsed time and rotation angle from the processed <Key>.mat, if present
    infoStr = '';
    rotPos  = NaN;
    try
        S = load(fullfile(pathExportAll, key + ".mat"), 'expCTDataSave');
        runVars = S.expCTDataSave.exp.(sprintf('run_%02d', j)).vars;
        f = fieldnames(runVars);
        v = runVars.(f{1})(k);   % tDtotal / time / angle are the same for rhoNorm and conc
        rotPos  = v.rotPos;
        infoStr = sprintf('t_D = %.2f,  t = %g s,  \\theta = %.0f°', v.tDtotal, v.secondsElapsed, v.rotPos);
    catch
    end
end
