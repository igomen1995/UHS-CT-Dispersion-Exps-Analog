%% CT pipeline step by step for ONE image (i, j, k): OLD vs NEW processing
%
% NEW: raw -> median (medWin) -> normImage -> crop full core (cropWidthFull)
%          -> imgaussfilt(sigmaNew) -> trim pixTrimEdge inside the core each side
%          -> satImage -> rhoNorm_wVacRef
% OLD: raw -> normImage -> crop (cropWidthOld) -> satImage -> rhoNorm_wVacRef
%          (+ imgaussfilt(sigmaOld) only to draw the contours, as in main_CTimaging)
%
% REFPROP (conc) is left to the downstream scripts (dataSource rhoNorm / conc).
%
% Outputs in <exportPath>/stepByStep_<Key>_run_jj_kkkk/
%   fig1_steps.png         raw / median / norm + crop / cropped / smoothed + trimmed (3 images)
%   fig2_rhoNorm_new.png   satImage and rhoNorm of the new pipeline
%   fig3_old_vs_new.png    image + contours old vs new, vertical and horizontal profiles
%   stepByStep.mat         intermediate images and crop coordinates
%
% Wall channeling check: run this script with kSel at a projection BEFORE the
% tracer reaches the core (rhoNorm should be flat 0) and one AFTER the core is
% fully swept (flat 1). A rise at the walls in those two is an artifact of the
% processing/measurement, not channeling.

clear;

%% IMPORT input

CT_setupPaths;

inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

% Crop parameters
pixDist       = 70;
partsScanned  = 5;      % air, core holder, water, sleeve, core
cropWidthFull = 1450;   % full core width (wall to wall)
pixTrimEdge   = 25;     % removed inside the core on each side after smoothing (>= 3*sigmaNew)
cropWidth     = cropWidthFull - 2*pixTrimEdge;

% Filters (new pipeline)
medWin       = 3;       % median window on the raw images (hot/dead pixels)
sigmaNew     = 5;       % Gaussian on the cropped full-core images, before satImage
sigmaContNew = 0;       % extra smoothing ONLY to draw the new contours (0 = none)

% Old pipeline (for comparison)
cropWidthOld = 1400;
sigmaOld     = 20;      % Gaussian used for the contours in main_CTimaging

% Contours
levelsFull = 0:0.1:1;
levelMain  = [0.5 0.5];

%% USER SELECTION

iSel = 1;          % experiment row in inputCTExpConfig.xlsx
jSel = 1;          % run
kSel = 100;        % projection

%% IMPORT folders and metadata

filenameExp   = inputFileConfig.inputFileName{iSel};
pathExportAll = inputFileConfig.exportPath{iSel};
filedataExp   = import_inputCTExp(filenameExp);
key           = char(filedataExp.Key);

outDir = fullfile(pathExportAll, sprintf('stepByStep_%s_run_%02d_k%04d', key, jSel, kSel));
if ~isfolder(outDir), mkdir(outDir); end

% init ref (Xe)
refInitFolderContent = dir(filedataExp.path+filedataExp.CT_data_ref_init);
refInitFolderContent = refInitFolderContent([refInitFolderContent.isdir] & ~startsWith({refInitFolderContent.name},'.'));
refInitFolderPathCT  = fullfile(refInitFolderContent.folder, refInitFolderContent.name);
refInitpca           = importPCA(dir(fullfile(refInitFolderPathCT, '*.pca')));
refInitimgFiles      = dir(fullfile(refInitFolderPathCT, '*.tif'));

% final ref (He)
refFinalFolderContent = dir(filedataExp.path+filedataExp.CT_data_ref_final);
refFinalFolderContent = refFinalFolderContent([refFinalFolderContent.isdir] & ~startsWith({refFinalFolderContent.name},'.'));
refFinalFolderPathCT  = fullfile(refFinalFolderContent.folder, refFinalFolderContent.name);
refFinalimgFiles      = dir(fullfile(refFinalFolderPathCT, '*.tif'));

% exp run jSel
expFolderContent = dir(filedataExp.path+filedataExp.CT_data_exp);
expFolderContent = expFolderContent([expFolderContent.isdir] & ~startsWith({expFolderContent.name},'.'));
expFolderPathCT  = fullfile(expFolderContent(jSel).folder, expFolderContent(jSel).name);
expimgFiles      = dir(fullfile(expFolderPathCT, '*.tif'));

if numel(refInitimgFiles) ~= numel(refFinalimgFiles) || numel(refInitimgFiles) ~= numel(expimgFiles)
    error("Mismatch in projections: init %d, final %d, exp run_%02d %d", ...
        numel(refInitimgFiles), numel(refFinalimgFiles), jSel, numel(expimgFiles));
end

DimY = refInitpca.Image.DimY;
crop_yCoords = [1;DimY];

names    = {'refInit','refFinal','exp'};
labels   = {'refInit (Xe)','refFinal (He)', sprintf('exp run %02d', jSel)};
imgFiles = {refInitimgFiles, refFinalimgFiles, expimgFiles};

fprintf('=== %s | run %02d | k %d ===\n', key, jSel, kSel);

%% NEW 1-3: raw -> median -> normalize

for n = 1:3
    raw.(names{n})    = double(importImages(imgFiles{n}, kSel));
    med.(names{n})    = medfilt2(raw.(names{n}), [medWin medWin], 'symmetric');
    nrm.(names{n})    = double(normImage(med.(names{n})));
    fprintf('  %-8s raw [%.4g %.4g] | hot/dead px removed by median: %d | max used by normImage: %.4g\n', ...
        names{n}, min(raw.(names{n})(:)), max(raw.(names{n})(:)), countOutliers(raw.(names{n})), max(med.(names{n})(:)));
end

%% NEW 4: crop full core (window detected on refInit, applied to all three)

[crop_xCoords_kFull, pv_sort_parts_kFull] = findCropWindow_xAxis(nrm.refInit, pixDist, partsScanned-1, cropWidthFull);
crop_xCoords_kTrim = [crop_xCoords_kFull(1)+pixTrimEdge, crop_xCoords_kFull(2)-pixTrimEdge];
fprintf('  crop full core x = [%d %d] | after trim x = [%d %d]\n', ...
    crop_xCoords_kFull(1), crop_xCoords_kFull(2), crop_xCoords_kTrim(1), crop_xCoords_kTrim(2));

for n = 1:3
    cropFull.(names{n}) = double(cropImage(nrm.(names{n}), crop_xCoords_kFull, crop_yCoords));
end

%% NEW 5-6: smooth full core, then trim inside the core
% Trim by index on the already-cropped image (not by findCropWindow again),
% so the trimmed window is exactly pixTrimEdge inside the full-core crop.

for n = 1:3
    smoothFull.(names{n}) = imgaussfilt(cropFull.(names{n}), sigmaNew, 'Padding','replicate');
    trimmed.(names{n})    = smoothFull.(names{n})(:, pixTrimEdge+1:end-pixTrimEdge);
end

%% NEW 7-8: satImage -> rhoNorm (vacuum corrected)

rhoNormNoCorrNew = double(satImage(trimmed.exp, trimmed.refInit, trimmed.refFinal)); % (exp, min, max)
rhoNormNew = double(rhoNorm_wVacRef(single(rhoNormNoCorrNew), filedataExp.Fluid1, ...
    filedataExp.Fluid2, filedataExp.T, filedataExp.P));
fprintf('  NEW rhoNorm: size %dx%d | mean %.3f | <0: %.1f%% | >1: %.1f%% | NaN %d\n', ...
    size(rhoNormNew,1), size(rhoNormNew,2), mean(rhoNormNew(:),'omitnan'), ...
    100*mean(rhoNormNew(:)<0), 100*mean(rhoNormNew(:)>1), nnz(isnan(rhoNormNew)));

%% OLD: raw -> normalize -> crop -> satImage -> rhoNorm (smoothing only for contours)

for n = 1:3
    nrmOld.(names{n}) = double(normImage(raw.(names{n})));
end
crop_xCoords_kOld = findCropWindow_xAxis(nrmOld.refInit, pixDist, partsScanned-1, cropWidthOld);
for n = 1:3
    cropOld.(names{n}) = double(cropImage(nrmOld.(names{n}), crop_xCoords_kOld, crop_yCoords));
end
rhoNormNoCorrOld = double(satImage(cropOld.exp, cropOld.refInit, cropOld.refFinal));
rhoNormOld = double(rhoNorm_wVacRef(single(rhoNormNoCorrOld), filedataExp.Fluid1, ...
    filedataExp.Fluid2, filedataExp.T, filedataExp.P));
rhoNormOldSmooth = imgaussfilt(rhoNormOld, sigmaOld);
fprintf('  OLD crop x = [%d %d] | rhoNorm mean %.3f | <0: %.1f%% | >1: %.1f%% | NaN %d\n', ...
    crop_xCoords_kOld(1), crop_xCoords_kOld(2), mean(rhoNormOld(:),'omitnan'), ...
    100*mean(rhoNormOld(:)<0), 100*mean(rhoNormOld(:)>1), nnz(isnan(rhoNormOld)));

if sigmaContNew > 0
    rhoNormNewCont = imgaussfilt(rhoNormNew, sigmaContNew);
else
    rhoNormNewCont = rhoNormNew;
end

%% FIG 1: steps for the three images

fig1 = figure('Name','Steps','Position',[20 20 1800 1000]);
tl = tiledlayout(3,5,'TileSpacing','compact');
title(tl, sprintf('%s run %02d k %d - new pipeline steps', key, jSel, kSel), 'Interpreter','none');
for n = 1:3
    % raw
    ax = nexttile(tl);
    showImg(ax, raw.(names{n}), [labels{n} ' | raw'], []);
    colormap(ax, turbo); ylabel(colorbar(ax), 'intensity [counts]');

    % what the median removed (symmetric limits, blue = removed bright, red = removed dark)
    ax = nexttile(tl);
    dMed = raw.(names{n}) - med.(names{n});
    lim  = max(prctile(abs(dMed(:)), 99.9), eps);
    showImg(ax, dMed, sprintf('removed by median %dx%d', medWin, medWin), [-lim lim]);
    colormap(ax, redblue(256)); ylabel(colorbar(ax), 'raw - median [counts]');

    % normalized with crop and trim lines
    ax = nexttile(tl);
    showImg(ax, nrm.(names{n}), 'normalized | red = full core, white = trim', [0 1]);
    colormap(ax, turbo); ylabel(colorbar(ax), 'I / I_{air} [-]');
    hold(ax,'on');
    xline(ax, crop_xCoords_kFull, 'r', 'LineWidth',1.2);
    xline(ax, crop_xCoords_kTrim, 'w--', 'LineWidth',1.2);

    % cropped full core
    ax = nexttile(tl);
    showImg(ax, cropFull.(names{n}), sprintf('cropped full core (%d px)', size(cropFull.(names{n}),2)), [0 1]);
    colormap(ax, turbo); ylabel(colorbar(ax), 'I / I_{air} [-]');
    hold(ax,'on'); xline(ax, [pixTrimEdge, size(cropFull.(names{n}),2)-pixTrimEdge], 'w--', 'LineWidth',1.2);

    % smoothed + trimmed
    ax = nexttile(tl);
    showImg(ax, trimmed.(names{n}), sprintf('gauss %d + trim %d (%d px)', sigmaNew, pixTrimEdge, ...
        size(trimmed.(names{n}),2)), [0 1]);
    colormap(ax, turbo); ylabel(colorbar(ax), 'I / I_{air} [-]');
end
saveFig(fig1, outDir, 'fig1_steps');

%% FIG 2: satImage and rhoNorm (new)

fig2 = figure('Name','rhoNorm new','Position',[20 20 1400 600]);
tl = tiledlayout(1,3,'TileSpacing','compact');
title(tl, sprintf('%s run %02d k %d - new pipeline output', key, jSel, kSel), 'Interpreter','none');
showImg(nexttile(tl), rhoNormNoCorrNew, 'satImage (rhoNorm, no vacuum corr.)', [0 1]);
showImg(nexttile(tl), rhoNormNew, 'rhoNorm (vacuum corrected)', [0 1]);
ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
histogram(ax, rhoNormNoCorrNew(:), linspace(-0.2,1.2,141), 'EdgeColor','none', 'DisplayName','no corr.');
histogram(ax, rhoNormNew(:),       linspace(-0.2,1.2,141), 'EdgeColor','none', 'DisplayName','vacuum corr.');
xlabel(ax,'rhoNorm [-]'); ylabel(ax,'counts'); legend(ax,'Location','best'); title(ax,'histogram');
colormap(fig2, turbo);
saveFig(fig2, outDir, 'fig2_rhoNorm_new');

%% FIG 3: old vs new, image + contours and profiles

fig3 = figure('Name','Old vs new','Position',[20 20 1800 800]);
tl = tiledlayout(1,4,'TileSpacing','compact');
title(tl, sprintf('%s run %02d k %d - rhoNorm, OLD vs NEW', key, jSel, kSel), 'Interpreter','none');

plotImageContour(nexttile(tl), rhoNormOld, rhoNormOldSmooth, levelsFull, levelMain, ...
    sprintf('OLD: crop %d, no median, contours gauss %d', cropWidthOld, sigmaOld));
plotImageContour(nexttile(tl), rhoNormNew, rhoNormNewCont, levelsFull, levelMain, ...
    sprintf('NEW: median %d, crop %d, gauss %d, trim %d', medWin, cropWidthFull, sigmaNew, pixTrimEdge));

% vertical profile (central 40 % of columns), x axis = z_D
ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
pOld = mean(rhoNormOld(:, centerCols(size(rhoNormOld,2))), 2, 'omitnan');
pNew = mean(rhoNormNew(:, centerCols(size(rhoNormNew,2))), 2, 'omitnan');
plot(ax, (1:numel(pOld))/numel(pOld), pOld, 'Color',[.6 .6 .6], 'DisplayName','old');
plot(ax, (1:numel(pNew))/numel(pNew), pNew, 'b', 'LineWidth',1.5, 'DisplayName','new');
xlabel(ax,'z_D [-]'); ylabel(ax,'rhoNorm (central 40 % of columns)'); ylim(ax,[-0.1 1.1]);
legend(ax,'Location','best'); title(ax,'vertical profile');

% horizontal profile (wall channeling): all rows and the front rows of the new image
ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
frontRows = pNew >= 0.3 & pNew <= 0.7;
xOld = (1:size(rhoNormOld,2)) - (crop_xCoords_kFull(1)+pixTrimEdge - crop_xCoords_kOld(1)); % align to new trimmed frame
plot(ax, xOld, mean(rhoNormOld,1,'omitnan'), 'Color',[.6 .6 .6], 'DisplayName','old, all rows');
plot(ax, 1:size(rhoNormNew,2), mean(rhoNormNew,1,'omitnan'), 'b', 'LineWidth',1.5, 'DisplayName','new, all rows');
if any(frontRows)
    plot(ax, 1:size(rhoNormNew,2), mean(rhoNormNew(frontRows,:),1,'omitnan'), 'r', 'LineWidth',1.5, ...
        'DisplayName', sprintf('new, front rows (%d)', nnz(frontRows)));
end
xlabel(ax,'x [px] (new trimmed frame)'); ylabel(ax,'rhoNorm (row mean)'); ylim(ax,[-0.1 1.1]);
legend(ax,'Location','best'); title(ax,'horizontal profile (wall channeling)');
saveFig(fig3, outDir, 'fig3_old_vs_new');

%% SAVE

save(fullfile(outDir,'stepByStep.mat'), 'rhoNormNew','rhoNormNoCorrNew','rhoNormOld', ...
    'crop_xCoords_kFull','crop_xCoords_kTrim','crop_xCoords_kOld', ...
    'medWin','sigmaNew','pixTrimEdge','cropWidthFull','cropWidthOld','sigmaOld', ...
    'iSel','jSel','kSel','-v7.3');
fprintf('Saved to %s\n', outDir);

%% local functions

function plotImageContour(ax, img, imgCont, levelsFull, levelMain, ttl)
    imagesc(ax, img); axis(ax,'image');
    colormap(ax, turbo); clim(ax,[0 1]);
    cb = colorbar(ax); cb.Label.String = 'rhoNorm [-]';
    hold(ax,'on');
    contour(ax, imgCont, levelsFull, 'LineColor','k', 'LineWidth',0.8, ...
        'ShowText',true, 'LabelFormat','%0.1f');
    contour(ax, imgCont, levelMain, 'LineColor','k', 'LineWidth',2.5);
    xlabel(ax,'x [px]'); ylabel(ax,'z [px]');
    title(ax, ttl, 'FontSize',9, 'Interpreter','none');
end

function showImg(ax, img, ttl, cl)
    imagesc(ax, img); axis(ax,'image'); colorbar(ax);
    if ~isempty(cl), clim(ax, cl); end
    title(ax, ttl, 'FontSize',8, 'Interpreter','none');
end

function cmap = redblue(m)
% diverging blue-white-red colormap (no toolbox needed)
    if nargin < 1, m = 256; end
    h = floor(m/2);
    up   = linspace(0,1,h)';
    down = linspace(1,0,m-h)';
    cmap = [[up; ones(m-h,1)], [up; down], [ones(h,1); down]];
end

function n = countOutliers(img)
% hot/dead pixels: > 8 robust sigmas from the 3x3 median
    res = img - medfilt2(img, [3 3], 'symmetric');
    s = 1.4826 * median(abs(res(:) - median(res(:))));
    n = nnz(abs(res) > 8*s);
end

function c = centerCols(nx)
    c = max(1,round(0.3*nx)):round(0.7*nx);
end

function saveFig(fig, outDir, name)
    exportgraphics(fig, fullfile(outDir, name + ".png"), 'Resolution', 200);
end