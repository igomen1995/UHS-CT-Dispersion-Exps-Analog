%% CT figure for the paper: one projection (i, j, k), current (old) processing
%
% Five panels, left to right:
%   (a) Xe reference (refInit)   normalized + cropped
%   (b) He reference (refFinal)  normalized + cropped
%   (c) experiment (exp)         normalized + cropped
%   (d) rhoNorm   = rhoNorm_wVacRef( satImage(exp, refInit, refFinal) )
%   (e) C_molar   = REFPROP interpolant of rhoNorm
% Panels (a)-(c) share one grey scale and colour bar. Panels (d)-(e) show the
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
levelMain  = [0.5 0.5];
labelContours = true;   % numbers on the thin contours

% Figure layout
figWidthCm   = 18;      % double-column width
figHeightCm  = 7.5;
fontName     = 'Helvetica';
fontSize     = 8;
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

fig = figure('Units','centimeters', 'Position',[2 2 figWidthCm figHeightCm], 'Color','w');
tl  = tiledlayout(fig, 1, 5, 'TileSpacing','compact', 'Padding','compact');

if showInfo
    infoStr = getScanInfo(pathExportAll, key, jSel, kSel);
    if ~isempty(infoStr)
        title(tl, infoStr, 'FontName',fontName, 'FontSize',fontSize, 'Interpreter','tex');
    end
end

normImgs   = {refInitCropped, refFinalCropped, expCropped};
normTitles = {'(a) Xe reference', '(b) He reference', '(c) Experiment'};
for p = 1:3
    ax = nexttile(tl);
    imagesc(ax, xAx, zAx, normImgs{p});
    styleAxes(ax, normTitles{p}, xLab, zLab, p == 1, fontName, fontSize);
    colormap(ax, gray); clim(ax, climNorm);
    if p == 3
        cb = colorbar(ax); cb.Label.String = 'I / I_{air} [-]';
        cb.FontName = fontName; cb.FontSize = fontSize;
    end
end

ax = nexttile(tl);
plotImageContours(ax, xAx, zAx, rhoNorm, rhoNormSmooth, levelsFull, levelMain, labelContours, fontSize);
styleAxes(ax, '(d) \rho_{norm}', xLab, zLab, false, fontName, fontSize);
cb = colorbar(ax); cb.Label.String = '\rho_{norm} [-]'; cb.FontName = fontName; cb.FontSize = fontSize;

ax = nexttile(tl);
plotImageContours(ax, xAx, zAx, Cmolar, CmolarSmooth, levelsFull, levelMain, labelContours, fontSize);
styleAxes(ax, '(e) C_{molar}', xLab, zLab, false, fontName, fontSize);
cb = colorbar(ax); cb.Label.String = 'C_{molar} [-]'; cb.FontName = fontName; cb.FontSize = fontSize;

%% EXPORT

baseName = fullfile(pathExportAll, sprintf('paperFig_%s_run_%02d_k%04d', key, jSel, kSel));
exportgraphics(fig, baseName + ".png", 'Resolution', 600);
exportgraphics(fig, baseName + ".pdf", 'ContentType','vector');
savefig(fig, baseName + ".fig");
fprintf('Saved %s.(png|pdf|fig)\n', baseName);

%% local functions

function plotImageContours(ax, xAx, zAx, img, imgCont, levelsFull, levelMain, labelContours, fontSize)
    imagesc(ax, xAx, zAx, img);
    colormap(ax, turbo); clim(ax, [0 1]);
    hold(ax, 'on');
    if labelContours
        [C, h] = contour(ax, xAx, zAx, imgCont, levelsFull, 'LineColor','k', 'LineWidth',0.5);
        clabel(C, h, 'FontSize', fontSize-2, 'LabelSpacing', 400, 'Color','k');
    else
        contour(ax, xAx, zAx, imgCont, levelsFull, 'LineColor','k', 'LineWidth',0.5);
    end
    contour(ax, xAx, zAx, imgCont, levelMain, 'LineColor','k', 'LineWidth',1.5);
    hold(ax, 'off');
end

function styleAxes(ax, ttl, xLab, zLab, showZ, fontName, fontSize)
    axis(ax, 'image');
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

function infoStr = getScanInfo(pathExportAll, key, j, k)
% t_D, elapsed time and rotation angle from the processed <Key>.mat, if present
    infoStr = '';
    try
        S = load(fullfile(pathExportAll, key + ".mat"), 'expCTDataSave');
        runVars = S.expCTDataSave.exp.(sprintf('run_%02d', j)).vars;
        f = fieldnames(runVars);
        v = runVars.(f{1})(k);   % tDtotal / time / angle are the same for rhoNorm and conc
        infoStr = sprintf('t_D = %.2f,  t = %g s,  \\theta = %.0f°', v.tDtotal, v.secondsElapsed, v.rotPos);
    catch
    end
end
