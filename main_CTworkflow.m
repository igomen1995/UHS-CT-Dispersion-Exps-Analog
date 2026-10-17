%% CT pipeline step by step for ONE image (i, j, k): OLD vs NEW processing (test)
%
% NEW: raw -> median (medWin) -> normImage -> crop full core (cropWidthFull)
%          -> imgaussfilt(sigmaNew) -> trim pixTrimEdge inside the core each side
%          -> satImage -> rhoNorm_wVacRef
% OLD: raw -> normImage -> crop (cropWidthOld) -> satImage -> rhoNorm_wVacRef
%          (+ imgaussfilt(sigmaOld) only to draw the contours, as in main_CTimaging)
%
% REFPROP (conc) is left to the downstream scripts; here it is computed only for
% the old-vs-new comparison in fig4.
%
% Outputs in <exportPath>/stepByStep_<Key>_run_jj_kkkk/
%   fig1a_steps_new.png    NEW: raw / median / norm + crop / cropped / smoothed + trimmed, satImage, rhoNorm
%   fig1b_steps_old.png    OLD: same panels (steps not applied are marked)
%   fig2_rhoNorm_new.png   satImage and rhoNorm of the new pipeline
%   fig3_old_vs_new.png    image + contours old vs new, vertical and horizontal profiles
%   fig4_final_old_vs_new.png  rhoNorm (vac. corr.) and REFPROP conc, old vs new, with profiles
%   fig5_I_vs_lnI_old_new.png  saturation on I vs on ln(I), for OLD and NEW processing
%                              (rhoNorm and conc rows; images + vertical/horizontal profiles)
%   fig6_gauss_vs_REFPROP.png  effect of the Gaussian on rhoNorm, and on conc when it is
%                              applied before vs after REFPROP (or not at all)
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
sigmaPostNew = 0;       % light Gaussian on the FINAL new rhoNorm and conc (0 = none) or 20

% Old pipeline (for comparison)
cropWidthOld = 1400;
sigmaOld     = 20;      % Gaussian used for the contours in main_CTimaging

% I vs ln(I) test (fig5)
logBeforeGauss = true;  % NEW + ln: take ln before the Gaussian (smooth attenuation, a linear quantity)
                        % false = ln of the already smoothed intensity
frontBand      = [0.3 0.7];  % front rows: NEW-I rhoNorm vertical profile within this range
edgeFrac       = 0.05;  % outer band per side for the wall-excess number

% Gaussian vs REFPROP test (fig6)
gaussTestVar   = 1;     % which variant of fig5 to test: 1 OLD-I | 2 OLD-ln | 3 NEW-I | 4 NEW-ln
gaussTestSigma = 20;    % Gaussian sigma [px] tested (20 = the one used in main_CTimaging)

% Contours
levelsFull = 0:0.1:1;
levelMain  = [0.5 0.5];

%% USER SELECTION

iSel = 1;          % experiment row in inputCTExpConfig.xlsx
jSel = 1;          % run
kSel = 91;        % projection

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
    Iair.(names{n})   = findIair(double(importImages(imgFiles{n}, 1)));
    med.(names{n})    = medfilt2(raw.(names{n}), [medWin medWin], 'symmetric');
    nrm.(names{n})    = double(normImage(med.(names{n}),Iair.(names{n})));
    fprintf('  %-8s raw [%.4g %.4g] | hot/dead px removed by median: %d | I0 = Iair (max of k = 1): %.4g\n', ...
        names{n}, min(raw.(names{n})(:)), max(raw.(names{n})(:)), countOutliers(raw.(names{n})), Iair.(names{n}));
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

% light final smoothing of the new output (contours and plots use this)
if sigmaPostNew > 0
    rhoNormNewFinal = imgaussfilt(rhoNormNew, sigmaPostNew, 'Padding','replicate');
else
    rhoNormNewFinal = rhoNormNew;
end

%% OLD: raw -> normalize -> crop -> satImage -> rhoNorm (smoothing only for contours)

for n = 1:3
    nrmOld.(names{n}) = normImage(raw.(names{n}), Iair.(names{n}));   % same I0 as NEW
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



%% FIG 1a / 1b: step panels for NEW and OLD pipelines
% Rows 1-3: refInit, refFinal, exp. Rows 4-5 (last column): satImage without
% and with vacuum correction. Colour limits per image (0.5-99.5 percentiles).

satStats = @(x) sprintf('mean %.3f | <0: %.1f%% | >1: %.1f%%', mean(x(:),'omitnan'), ...
    100*mean(x(:)<0), 100*mean(x(:)>1));

% ---- NEW
colTitlesNew = {'raw', sprintf('removed by median %dx%d', medWin, medWin), ...
    'normalized | red = full core, white = trim', 'cropped full core', ...
    sprintf('gauss %d + trim %d', sigmaNew, pixTrimEdge)};
colModes = {'seq','div','seq','seq','seq'};
cbLabels = {'intensity [counts]','raw - median [counts]','I / I_{air} [-]','I / I_{air} [-]','I / I_{air} [-]'};
imgsNew = cell(3,5); ovNew = cell(3,5);
for n = 1:3
    imgsNew(n,:) = {raw.(names{n}), raw.(names{n}) - med.(names{n}), nrm.(names{n}), ...
        cropFull.(names{n}), trimmed.(names{n})};
    ovNew{n,3} = [struct('x',crop_xCoords_kFull(:)','spec','r'), struct('x',crop_xCoords_kTrim(:)','spec','w--')];
    ovNew{n,4} = struct('x',[pixTrimEdge, size(cropFull.(names{n}),2)-pixTrimEdge],'spec','w--');
end
notesNew = repmat({''},1,5);
txtNoCorrNew = {'\bfsatImage (no vacuum correction)\rm', ...
    'rhoNorm_{noCorr} = (exp - refInit) / (refFinal - refInit)', ...
    'from the smoothed + trimmed images of column 5', satStats(rhoNormNoCorrNew)};
txtCorrNew = {'\bfrhoNorm\_wVacRef (vacuum corrected)\rm', ...
    'rhoNorm = rhoNorm\_wVacRef(rhoNorm_{noCorr}, Fluid1, Fluid2, T, P)', ...
    'reference changed from He (refFinal) to vacuum', satStats(rhoNormNew)};
fig1a = plotStepFigure(sprintf('%s run %02d k %d - NEW pipeline steps', key, jSel, kSel), ...
    labels, colTitlesNew, colModes, cbLabels, imgsNew, ovNew, notesNew, ...
    rhoNormNoCorrNew, rhoNormNew, txtNoCorrNew, txtCorrNew);
saveFig(fig1a, outDir, 'fig1a_steps_new');

% ---- OLD
colTitlesOld = {'raw', 'median', 'normalized | red = crop', ...
    sprintf('cropped (%d px)', cropWidthOld), 'smoothing + trim'};
imgsOld = cell(3,5); ovOld = cell(3,5);
for n = 1:3
    imgsOld(n,:) = {raw.(names{n}), [], nrmOld.(names{n}), cropOld.(names{n}), []};
    ovOld{n,3} = struct('x',crop_xCoords_kOld(:)','spec','r');
end
notesOld = {'', 'not applied in the old pipeline', '', '', ...
    sprintf('none before satImage\n(gauss %d applied only to draw contours)', sigmaOld)};
txtNoCorrOld = {'\bfsatImage (no vacuum correction)\rm', ...
    'rhoNorm_{noCorr} = (exp - refInit) / (refFinal - refInit)', ...
    'from the cropped images of column 4 (no median, no smoothing)', satStats(rhoNormNoCorrOld)};
txtCorrOld = {'\bfrhoNorm\_wVacRef (vacuum corrected)\rm', ...
    'rhoNorm = rhoNorm\_wVacRef(rhoNorm_{noCorr}, Fluid1, Fluid2, T, P)', ...
    'reference changed from He (refFinal) to vacuum', satStats(rhoNormOld)};
fig1b = plotStepFigure(sprintf('%s run %02d k %d - OLD pipeline steps', key, jSel, kSel), ...
    labels, colTitlesOld, colModes, cbLabels, imgsOld, ovOld, notesOld, ...
    rhoNormNoCorrOld, rhoNormOld, txtNoCorrOld, txtCorrOld);
saveFig(fig1b, outDir, 'fig1b_steps_old');

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
plotImageContour(nexttile(tl), rhoNormNewFinal, rhoNormNewFinal, levelsFull, levelMain, ...
    sprintf('NEW: median %d, crop %d, gauss %d, trim %d, final gauss %d', medWin, cropWidthFull, sigmaNew, pixTrimEdge, sigmaPostNew));

% vertical profile (central 40 % of columns), x axis = z_D
ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
pOld = mean(rhoNormOldSmooth(:, centerCols(size(rhoNormOldSmooth,2))), 2, 'omitnan');
pNew = mean(rhoNormNewFinal(:, centerCols(size(rhoNormNewFinal,2))), 2, 'omitnan');
plot(ax, (1:numel(pOld))/numel(pOld), pOld, 'Color',[.6 .6 .6], 'DisplayName',sprintf('old (gauss %d)', sigmaOld));
plot(ax, (1:numel(pNew))/numel(pNew), pNew, 'b', 'LineWidth',1.5, 'DisplayName','new');
xlabel(ax,'z_D [-]'); ylabel(ax,'rhoNorm (central 40 % of columns)'); ylim(ax,[-0.1 1.1]);
legend(ax,'Location','best'); title(ax,'vertical profile');

% horizontal profile (wall channeling): all rows and the front rows of the new image
ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
frontRows = pNew >= 0.3 & pNew <= 0.7;
xOld = (1:size(rhoNormOld,2)) - (crop_xCoords_kFull(1)+pixTrimEdge - crop_xCoords_kOld(1)); % align to new trimmed frame
plot(ax, xOld, mean(rhoNormOldSmooth,1,'omitnan'), 'Color',[.6 .6 .6], 'DisplayName',sprintf('old (gauss %d), all rows', sigmaOld));
plot(ax, 1:size(rhoNormNewFinal,2), mean(rhoNormNewFinal,1,'omitnan'), 'b', 'LineWidth',1.5, 'DisplayName','new, all rows');
if any(frontRows)
    plot(ax, xOld, mean(rhoNormOldSmooth(frontRows,:),1,'omitnan'), 'Color',[1 0.6 0.6], 'LineWidth',1.5, ...
        'DisplayName', sprintf('old (gauss %d), front rows (%d)', sigmaOld, nnz(frontRows)));
    plot(ax, 1:size(rhoNormNewFinal,2), mean(rhoNormNewFinal(frontRows,:),1,'omitnan'), 'r', 'LineWidth',1.5, ...
        'DisplayName', sprintf('new, front rows (%d)', nnz(frontRows)));
end
xlabel(ax,'x [px] (new trimmed frame)'); ylabel(ax,'rhoNorm (row mean)'); ylim(ax,[-0.1 1.1]);
legend(ax,'Location','best'); title(ax,'horizontal profile (wall channeling)');
saveFig(fig3, outDir, 'fig3_old_vs_new');

%% FIG 4: final result OLD vs NEW - rhoNorm (vacuum corr.) and REFPROP conc
% Columns: OLD as plotted (unsmoothed image + gauss sigmaOld contours) |
%          OLD smoothed field that feeds the contours (gauss sigmaOld) |
%          NEW (image + contours from the same image) | vertical profile | horizontal profile
% As in main_CTimaging, for conc the old smoothing is applied AFTER REFPROP.

interpFcn = buildInterpolant(filedataExp.Fluid1, filedataExp.Fluid2, filedataExp.T, filedataExp.P);

concOldRaw      = double(interpFcn(rhoNormOld));                 % old conc, as plotted
concOldSmooth   = imgaussfilt(concOldRaw, sigmaOld);             % old conc field behind the contours
rhoNormOldFinal = rhoNormOldSmooth;                              % imgaussfilt(rhoNormOld, sigmaOld)
concOld         = concOldSmooth;
concNewRaw      = double(interpFcn(rhoNormNew));                 % new conc before final smoothing
if sigmaPostNew > 0
    concNew = imgaussfilt(concNewRaw, sigmaPostNew, 'Padding','replicate');  % light final smoothing
else
    concNew = concNewRaw;
end
fprintf('  conc OLD (as plotted): mean %.3f | NaN %d   OLD gauss %d: NaN %d   NEW: mean %.3f | NaN %d\n', ...
    mean(concOldRaw(:),'omitnan'), nnz(isnan(concOldRaw)), sigmaOld, nnz(isnan(concOldSmooth)), ...
    mean(concNew(:),'omitnan'), nnz(isnan(concNew)));

% x in full-frame pixels, so old and new crops line up
xGlobOld = crop_xCoords_kOld(1)  + (0:size(rhoNormOld,2)-1);
xGlobNew = crop_xCoords_kTrim(1) + (0:size(rhoNormNewFinal,2)-1);
cOldRaw = [0.70 0.70 0.70];  cOldSm = [0.25 0.25 0.25];  cNew = [0 0.35 0.8];

fig4 = figure('Name','Final old vs new','Position',[20 20 2400 1150]);
tl = tiledlayout(2,6,'TileSpacing','compact');
title(tl, sprintf('%s run %02d k %d - final result OLD vs NEW (colour limits [0 1])', key, jSel, kSel), ...
    'Interpreter','none');

%      old as plotted, old smoothed (contours), new image, new contour field, name, unit
Q = {rhoNormOld, rhoNormOldSmooth, rhoNormNewFinal, rhoNormNewFinal, 'rhoNorm (vacuum corr.)', 'rhoNorm [-]'; ...
     concOldRaw, concOldSmooth,    concNew,         concNew,         'conc (REFPROP)',         'molar fraction [-]'};

for q = 1:2
    plotImageContour(nexttile(tl), Q{q,1}, Q{q,2}, levelsFull, levelMain, ...
        sprintf('OLD as plotted: unsmoothed + contours gauss %d | %s', sigmaOld, Q{q,5}), Q{q,6});
    plotImageContour(nexttile(tl), Q{q,2}, Q{q,2}, levelsFull, levelMain, ...
        sprintf('OLD gauss %d field that feeds the contours | %s', sigmaOld, Q{q,5}), Q{q,6});
    plotImageContour(nexttile(tl), Q{q,3}, Q{q,4}, levelsFull, levelMain, ...
        sprintf('NEW: median %d, gauss %d before sat, final gauss %d | %s', medWin, sigmaNew, sigmaPostNew, Q{q,5}), Q{q,6});

    % vertical profile, central 40 % of columns
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
    vR = mean(Q{q,1}(:, centerCols(size(Q{q,1},2))), 2, 'omitnan');
    vS = mean(Q{q,2}(:, centerCols(size(Q{q,2},2))), 2, 'omitnan');
    vN = mean(Q{q,3}(:, centerCols(size(Q{q,3},2))), 2, 'omitnan');
    plot(ax, (1:numel(vR))/numel(vR), vR, 'Color',cOldRaw, 'DisplayName','old, unsmoothed');
    plot(ax, (1:numel(vS))/numel(vS), vS, 'Color',cOldSm, 'LineWidth',1.5, 'DisplayName',sprintf('old, gauss %d', sigmaOld));
    plot(ax, (1:numel(vN))/numel(vN), vN, 'Color',cNew, 'LineWidth',1.5, 'DisplayName','new');
    xlabel(ax,'z_D [-]'); ylabel(ax, Q{q,6}); ylim(ax,[-0.1 1.1]);
    legend(ax,'Location','best'); title(ax, ['vertical profile | ' Q{q,5}], 'FontSize',9);

    % horizontal profile, all rows
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
    plot(ax, xGlobOld, mean(Q{q,1},1,'omitnan'), 'Color',cOldRaw, 'DisplayName','old, unsmoothed');
    plot(ax, xGlobOld, mean(Q{q,2},1,'omitnan'), 'Color',cOldSm, 'LineWidth',1.5, 'DisplayName',sprintf('old, gauss %d', sigmaOld));
    plot(ax, xGlobNew, mean(Q{q,3},1,'omitnan'), 'Color',cNew, 'LineWidth',1.5, 'DisplayName','new');
    xlabel(ax,'x [px, full frame]'); ylabel(ax, Q{q,6}); ylim(ax,[-0.1 1.1]);
    legend(ax,'Location','best'); title(ax, ['horizontal profile, all rows | ' Q{q,5}], 'FontSize',9);

    % horizontal profile, FRONT rows only (same rows for old and new: 0.3 <= new vertical profile <= 0.7)
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
    frontRows = vN >= 0.3 & vN <= 0.7;
    if any(frontRows)
        plot(ax, xGlobOld, mean(Q{q,1}(frontRows,:),1,'omitnan'), 'Color',cOldRaw, 'DisplayName','old, unsmoothed');
        plot(ax, xGlobOld, mean(Q{q,2}(frontRows,:),1,'omitnan'), 'Color',cOldSm, 'LineWidth',1.5, 'DisplayName',sprintf('old, gauss %d', sigmaOld));
        plot(ax, xGlobNew, mean(Q{q,3}(frontRows,:),1,'omitnan'), 'Color',cNew, 'LineWidth',1.5, 'DisplayName','new');
        zr = find(frontRows);
        ttlF = sprintf('front rows z = %d-%d (%d rows) | %s', zr(1), zr(end), numel(zr), Q{q,5});
        legend(ax,'Location','best');
    else
        ttlF = sprintf('no front rows (new profile never in 0.3-0.7) | %s', Q{q,5});
    end
    xlabel(ax,'x [px, full frame]'); ylabel(ax, Q{q,6}); ylim(ax,[-0.1 1.1]);
    title(ax, ttlF, 'FontSize',9);
end
saveFig(fig4, outDir, 'fig4_final_old_vs_new');

%% I vs ln(I) in OLD and NEW processing (test)
% OLD-I : current pipeline (as above)
% OLD-ln: same cropped images (no median, no smoothing), satImage on ln(I)
% NEW-I : median -> norm -> crop full -> gauss -> trim -> satImage on I (as above)
% NEW-ln: median -> norm -> crop full -> ln -> gauss -> trim -> satImage on ln(I)
% Old results are smoothed with sigmaOld exactly as in main_CTimaging (conc: after REFPROP).

Lfun = @(x) log(max(x, eps));
F1 = filedataExp.Fluid1; F2 = filedataExp.Fluid2; Tq = filedataExp.T; Pq = filedataExp.P;

% OLD with ln(I)
rhoNormNoCorrOldLn = double(satImage(Lfun(cropOld.exp), Lfun(cropOld.refInit), Lfun(cropOld.refFinal)));
rhoNormOldLn       = double(rhoNorm_wVacRef(single(rhoNormNoCorrOldLn), F1, F2, Tq, Pq));
rhoNormOldLnSmooth = imgaussfilt(rhoNormOldLn, sigmaOld);
concOldLnRaw       = double(interpFcn(rhoNormOldLn));
concOldLnSmooth    = imgaussfilt(concOldLnRaw, sigmaOld);

% NEW with ln(I)
for n = 1:3
    if logBeforeGauss
        tmp = imgaussfilt(Lfun(cropFull.(names{n})), sigmaNew, 'Padding','replicate');
    else
        tmp = Lfun(smoothFull.(names{n}));
    end
    trimmedLn.(names{n}) = tmp(:, pixTrimEdge+1:end-pixTrimEdge);
end
rhoNormNoCorrNewLn = double(satImage(trimmedLn.exp, trimmedLn.refInit, trimmedLn.refFinal));
rhoNormNewLn       = double(rhoNorm_wVacRef(single(rhoNormNoCorrNewLn), F1, F2, Tq, Pq));
concNewLnRaw       = double(interpFcn(rhoNormNewLn));
if sigmaPostNew > 0
    rhoNormNewLnFinal = imgaussfilt(rhoNormNewLn, sigmaPostNew, 'Padding','replicate');
    concNewLn         = imgaussfilt(concNewLnRaw, sigmaPostNew, 'Padding','replicate');
else
    rhoNormNewLnFinal = rhoNormNewLn;
    concNewLn         = concNewLnRaw;
end

% variants: image as plotted | contour field | field used for profiles/numbers
V = struct('name',{}, 'rho',{}, 'rhoC',{}, 'rhoP',{}, 'conc',{}, 'concC',{}, 'concP',{}, ...
           'x',{}, 'col',{}, 'ls',{});
V(1) = struct('name',sprintf('OLD, I (gauss %d)',sigmaOld),  'rho',rhoNormOld,   'rhoC',rhoNormOldSmooth,   'rhoP',rhoNormOldSmooth, ...
              'conc',concOldRaw,   'concC',concOldSmooth,   'concP',concOldSmooth,   'x',xGlobOld, 'col',[0.35 0.35 0.35], 'ls','-');
V(2) = struct('name',sprintf('OLD, ln I (gauss %d)',sigmaOld),'rho',rhoNormOldLn, 'rhoC',rhoNormOldLnSmooth, 'rhoP',rhoNormOldLnSmooth, ...
              'conc',concOldLnRaw, 'concC',concOldLnSmooth, 'concP',concOldLnSmooth, 'x',xGlobOld, 'col',[0.35 0.35 0.35], 'ls','--');
V(3) = struct('name','NEW, I',    'rho',rhoNormNewFinal,   'rhoC',rhoNormNewFinal,   'rhoP',rhoNormNewFinal, ...
              'conc',concNew,   'concC',concNew,   'concP',concNew,   'x',xGlobNew, 'col',[0 0.35 0.8], 'ls','-');
V(4) = struct('name','NEW, ln I', 'rho',rhoNormNewLnFinal, 'rhoC',rhoNormNewLnFinal, 'rhoP',rhoNormNewLnFinal, ...
              'conc',concNewLn, 'concC',concNewLn, 'concP',concNewLn, 'x',xGlobNew, 'col',[0 0.35 0.8], 'ls','--');

% same front rows for every variant: NEW-I rhoNorm vertical profile within frontBand
vFront    = mean(rhoNormNewFinal(:, centerCols(size(rhoNormNewFinal,2))), 2, 'omitnan');
frontRows5 = vFront >= frontBand(1) & vFront <= frontBand(2);

colProf = @(img, rows) mean(min(max(img(rows,:), -1), 2), 1, 'omitnan');   % clip near-wall blow-ups
edgeEx  = @(cp) [mean(cp(1:max(3,round(edgeFrac*numel(cp)))),'omitnan'), ...
                 mean(cp(end-max(3,round(edgeFrac*numel(cp)))+1:end),'omitnan')] ...
                 - mean(cp(centerCols(numel(cp))),'omitnan');

% ---- numbers
fprintf('\nI vs ln(I), OLD vs NEW  (wall excess = outer %d%% minus centre 40%%, [left right])\n', round(100*edgeFrac));
qName = {'rhoNorm','conc'};  qFld = {'rhoP','concP'};
for q = 1:2
    for v = 1:4
        img = V(v).(qFld{q});
        exA = edgeEx(colProf(img, true(size(img,1),1)));
        if any(frontRows5)
            exF = edgeEx(colProf(img, frontRows5));
            fprintf('  %-8s %-22s mean %.3f | all rows [%+.3f %+.3f] | front rows [%+.3f %+.3f]\n', ...
                qName{q}, V(v).name, mean(img(:),'omitnan'), exA, exF);
        else
            fprintf('  %-8s %-22s mean %.3f | all rows [%+.3f %+.3f] | no front rows\n', ...
                qName{q}, V(v).name, mean(img(:),'omitnan'), exA);
        end
    end
    dOld = V(2).(qFld{q}) - V(1).(qFld{q});
    dNew = V(4).(qFld{q}) - V(3).(qFld{q});
    fprintf('  %-8s ln - I: OLD mean %+.3f (max |d| %.3f) | NEW mean %+.3f (max |d| %.3f)\n', qName{q}, ...
        mean(dOld(:),'omitnan'), max(abs(dOld(:))), mean(dNew(:),'omitnan'), max(abs(dNew(:))));
end

% ---- figure: 2 rows (rhoNorm, conc) x [4 images + vertical + horizontal all + horizontal front]
fig5 = figure('Name','I vs ln I','Position',[20 20 2600 1150]);
tl = tiledlayout(2,7,'TileSpacing','compact');
title(tl, sprintf('%s run %02d k %d - saturation on I vs ln(I), OLD vs NEW processing', key, jSel, kSel), ...
    'Interpreter','none');
qUnit = {'rhoNorm [-]','molar fraction [-]'};
qImg  = {'rho','conc'};  qCnt = {'rhoC','concC'};
for q = 1:2
    for v = 1:4
        plotImageContour(nexttile(tl), V(v).(qImg{q}), V(v).(qCnt{q}), levelsFull, levelMain, ...
            sprintf('%s | %s', V(v).name, qName{q}), qUnit{q});
    end

    % vertical profile
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
    for v = 1:4
        img = V(v).(qFld{q});
        vp  = mean(img(:, centerCols(size(img,2))), 2, 'omitnan');
        plot(ax, (1:numel(vp))/numel(vp), vp, V(v).ls, 'Color',V(v).col, 'LineWidth',1.3, 'DisplayName',V(v).name);
    end
    xlabel(ax,'z_D [-]'); ylabel(ax, qUnit{q}); ylim(ax,[-0.1 1.1]);
    legend(ax,'Location','best','FontSize',7); title(ax, ['vertical profile | ' qName{q}], 'FontSize',9);

    % horizontal profile, all rows
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
    for v = 1:4
        img = V(v).(qFld{q});
        plot(ax, V(v).x, colProf(img, true(size(img,1),1)), V(v).ls, 'Color',V(v).col, 'LineWidth',1.3, 'DisplayName',V(v).name);
    end
    xlabel(ax,'x [px, full frame]'); ylabel(ax, qUnit{q}); ylim(ax,[-0.1 1.1]);
    legend(ax,'Location','best','FontSize',7); title(ax, ['horizontal, all rows | ' qName{q}], 'FontSize',9);

    % horizontal profile, front rows
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
    if any(frontRows5)
        for v = 1:4
            plot(ax, V(v).x, colProf(V(v).(qFld{q}), frontRows5), V(v).ls, 'Color',V(v).col, 'LineWidth',1.3, 'DisplayName',V(v).name);
        end
        zr = find(frontRows5);
        ttlF = sprintf('horizontal, front rows z = %d-%d | %s', zr(1), zr(end), qName{q});
        legend(ax,'Location','best','FontSize',7);
    else
        ttlF = sprintf('no front rows | %s', qName{q});
    end
    xlabel(ax,'x [px, full frame]'); ylabel(ax, qUnit{q}); ylim(ax,[-0.1 1.1]);
    title(ax, ttlF, 'FontSize',9);
end
saveFig(fig5, outDir, 'fig5_I_vs_lnI_old_new');

%% GAUSSIAN vs REFPROP (test)
% Starting from the UNSMOOTHED rhoNorm of the selected variant:
%   rhoNorm : R0 (no Gaussian)  vs  Rs = gauss(R0)
%   conc    : C_none   = f(R0)            no Gaussian
%             C_after  = gauss(f(R0))     Gaussian AFTER REFPROP (what main_CTimaging does for 'conc')
%             C_before = f(gauss(R0))     Gaussian BEFORE REFPROP
% f = REFPROP interpolant. C_after and C_before differ only because f is nonlinear
% (and because NaN from f outside its range spread through the Gaussian in C_after).

baseRho = {rhoNormOld, rhoNormOldLn, rhoNormNew, rhoNormNewLn};
baseX   = {xGlobOld, xGlobOld, xGlobNew, xGlobNew};
R0 = baseRho{gaussTestVar};
xG = baseX{gaussTestVar};
gTxt = sprintf('gauss %d', gaussTestSigma);

Rs       = imgaussfilt(R0, gaussTestSigma);
C_none   = double(interpFcn(R0));
C_after  = imgaussfilt(C_none, gaussTestSigma);
C_before = double(interpFcn(Rs));
dRho     = Rs - R0;
dC       = C_after - C_before;

st = @(x) sprintf('mean %.4f | NaN %6d | <0 %5.1f%% | >1 %5.1f%%', mean(x(:),'omitnan'), ...
    nnz(isnan(x)), 100*mean(x(:)<0), 100*mean(x(:)>1));
fprintf('\nGaussian vs REFPROP, variant "%s", sigma %d\n', V(gaussTestVar).name, gaussTestSigma);
fprintf('  rhoNorm  no gauss        : %s\n', st(R0));
fprintf('  rhoNorm  %-15s : %s\n', gTxt, st(Rs));
fprintf('  conc     no gauss        : %s\n', st(C_none));
fprintf('  conc     gauss AFTER f   : %s\n', st(C_after));
fprintf('  conc     gauss BEFORE f  : %s\n', st(C_before));
fprintf('  after - before           : mean %+.4f | max |d| %.4f | 99th pct |d| %.4f\n', ...
    mean(dC(:),'omitnan'), max(abs(dC(:))), prctile(abs(dC(isfinite(dC))), 99));

% REFPROP mapping, to see its curvature and range
rhoGrid = linspace(-0.2, 1.2, 281);
fGrid   = double(interpFcn(rhoGrid));
okGrid  = isfinite(fGrid);
if any(okGrid)
    fprintf('  REFPROP f defined for rhoNorm in [%.3f %.3f]; slope df/drho from %.2f to %.2f\n', ...
        min(rhoGrid(okGrid)), max(rhoGrid(okGrid)), ...
        min(gradient(fGrid(okGrid), rhoGrid(okGrid))), max(gradient(fGrid(okGrid), rhoGrid(okGrid))));
end

cA = [0.6 0.6 0.6];  cB = [0.85 0.33 0.10];  cC = [0 0.35 0.8];
fig6 = figure('Name','Gaussian vs REFPROP','Position',[20 20 2600 1150]);
tl = tiledlayout(2,6,'TileSpacing','compact');
title(tl, sprintf('%s run %02d k %d - Gaussian and REFPROP order, variant "%s", sigma %d', ...
    key, jSel, kSel, V(gaussTestVar).name, gaussTestSigma), 'Interpreter','none');

% ---- row 1: rhoNorm
plotImageContour(nexttile(tl), R0, Rs, levelsFull, levelMain, ['rhoNorm, no gauss (contours ' gTxt ')'], 'rhoNorm [-]');
plotImageContour(nexttile(tl), Rs, Rs, levelsFull, levelMain, ['rhoNorm, ' gTxt], 'rhoNorm [-]');
ax = nexttile(tl);
lim = max(prctile(abs(dRho(:)), 99), 1e-3);
imagesc(ax, dRho); axis(ax,'image'); colormap(ax, redblue(256)); clim(ax, [-lim lim]);
cb = colorbar(ax); cb.Label.String = '\Delta rhoNorm [-]';
title(ax, ['rhoNorm: ' gTxt ' - no gauss'], 'FontSize',9, 'Interpreter','none');

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
yyaxis(ax,'left');
plot(ax, rhoGrid, fGrid, 'k-', 'LineWidth',1.5, 'DisplayName','REFPROP f(rhoNorm)');
plot(ax, [0 1], [0 1], 'k:', 'DisplayName','linear');
ylabel(ax, 'conc = f(rhoNorm) [-]'); ylim(ax, [-0.1 1.1]);
yyaxis(ax,'right');
edges = linspace(-0.2, 1.2, 141);
histogram(ax, R0(:), edges, 'Normalization','probability', 'DisplayStyle','stairs', 'EdgeColor',cA, 'DisplayName','rhoNorm no gauss');
histogram(ax, Rs(:), edges, 'Normalization','probability', 'DisplayStyle','stairs', 'EdgeColor',cC, 'DisplayName',['rhoNorm ' gTxt]);
ylabel(ax, 'fraction of pixels');
xlabel(ax, 'rhoNorm [-]'); legend(ax,'Location','northwest','FontSize',7);
title(ax, 'REFPROP mapping + rhoNorm histograms', 'FontSize',9);

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
v0 = mean(R0(:, centerCols(size(R0,2))), 2, 'omitnan');
vS = mean(Rs(:, centerCols(size(Rs,2))), 2, 'omitnan');
plot(ax, (1:numel(v0))/numel(v0), v0, 'Color',cA, 'DisplayName','no gauss');
plot(ax, (1:numel(vS))/numel(vS), vS, 'Color',cC, 'LineWidth',1.5, 'DisplayName',gTxt);
xlabel(ax,'z_D [-]'); ylabel(ax,'rhoNorm [-]'); ylim(ax,[-0.1 1.1]);
legend(ax,'Location','best','FontSize',7); title(ax,'vertical profile | rhoNorm','FontSize',9);

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
plot(ax, xG, colProf(R0, true(size(R0,1),1)), 'Color',cA, 'DisplayName','no gauss, all rows');
plot(ax, xG, colProf(Rs, true(size(Rs,1),1)), 'Color',cC, 'LineWidth',1.5, 'DisplayName',[gTxt ', all rows']);
if any(frontRows5)
    plot(ax, xG, colProf(R0, frontRows5), '--', 'Color',cA, 'DisplayName','no gauss, front rows');
    plot(ax, xG, colProf(Rs, frontRows5), '--', 'Color',cC, 'LineWidth',1.5, 'DisplayName',[gTxt ', front rows']);
end
xlabel(ax,'x [px, full frame]'); ylabel(ax,'rhoNorm [-]'); ylim(ax,[-0.1 1.1]);
legend(ax,'Location','best','FontSize',7); title(ax,'horizontal profile | rhoNorm','FontSize',9);

% ---- row 2: conc
plotImageContour(nexttile(tl), C_none,  C_after,  levelsFull, levelMain, ['conc = f(rhoNorm), no gauss (contours ' gTxt ' after f)'], 'molar fraction [-]');
plotImageContour(nexttile(tl), C_after, C_after,  levelsFull, levelMain, ['conc = ' gTxt '( f(rhoNorm) )  [current]'], 'molar fraction [-]');
plotImageContour(nexttile(tl), C_before, C_before, levelsFull, levelMain, ['conc = f( ' gTxt '(rhoNorm) )'], 'molar fraction [-]');
ax = nexttile(tl);
lim = max(prctile(abs(dC(isfinite(dC))), 99), 1e-3);
imagesc(ax, dC); axis(ax,'image'); colormap(ax, redblue(256)); clim(ax, [-lim lim]);
cb = colorbar(ax); cb.Label.String = '\Delta conc [-]';
title(ax, 'conc: gauss after f - gauss before f', 'FontSize',9, 'Interpreter','none');

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
Cset = {C_none, C_after, C_before};  Cnm = {'no gauss', [gTxt ' after f'], [gTxt ' before f']};  Ccol = {cA, cB, cC};
for c = 1:3
    vp = mean(Cset{c}(:, centerCols(size(Cset{c},2))), 2, 'omitnan');
    plot(ax, (1:numel(vp))/numel(vp), vp, 'Color',Ccol{c}, 'LineWidth',1+0.5*(c>1), 'DisplayName',Cnm{c});
end
xlabel(ax,'z_D [-]'); ylabel(ax,'molar fraction [-]'); ylim(ax,[-0.1 1.1]);
legend(ax,'Location','best','FontSize',7); title(ax,'vertical profile | conc','FontSize',9);

ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
for c = 1:3
    plot(ax, xG, colProf(Cset{c}, true(size(Cset{c},1),1)), 'Color',Ccol{c}, 'LineWidth',1+0.5*(c>1), 'DisplayName',[Cnm{c} ', all rows']);
    if any(frontRows5)
        plot(ax, xG, colProf(Cset{c}, frontRows5), '--', 'Color',Ccol{c}, 'LineWidth',1+0.5*(c>1), 'DisplayName',[Cnm{c} ', front rows']);
    end
end
xlabel(ax,'x [px, full frame]'); ylabel(ax,'molar fraction [-]'); ylim(ax,[-0.1 1.1]);
legend(ax,'Location','best','FontSize',7); title(ax,'horizontal profile | conc','FontSize',9);

saveFig(fig6, outDir, 'fig6_gauss_vs_REFPROP');

%% SAVE

save(fullfile(outDir,'stepByStep.mat'), 'rhoNormNew','rhoNormNewFinal','rhoNormNoCorrNew','rhoNormOld','rhoNormOldFinal','rhoNormNoCorrOld', ...
    'concNew','concNewRaw','concOld','concOldRaw','sigmaPostNew', ...
    'rhoNormOldLn','rhoNormNewLn','rhoNormNewLnFinal','concOldLnRaw','concOldLnSmooth','concNewLn', ...
    'R0','Rs','C_none','C_after','C_before','gaussTestVar','gaussTestSigma', ...
    'crop_xCoords_kFull','crop_xCoords_kTrim','crop_xCoords_kOld', ...
    'medWin','sigmaNew','pixTrimEdge','cropWidthFull','cropWidthOld','sigmaOld', ...
    'iSel','jSel','kSel','-v7.3');
fprintf('Saved to %s\n', outDir);

%% local functions

function plotImageContour(ax, img, imgCont, levelsFull, levelMain, ttl, cbLabel)
    if nargin < 7, cbLabel = 'rhoNorm [-]'; end
    imagesc(ax, img); axis(ax,'image');
    colormap(ax, turbo); clim(ax,[0 1]);
    cb = colorbar(ax); cb.Label.String = cbLabel;
    hold(ax,'on');
    contour(ax, imgCont, levelsFull, 'LineColor','k', 'LineWidth',0.8, ...
        'ShowText',true, 'LabelFormat','%0.1f');
    % contour(ax, imgCont, levelMain, 'LineColor','k', 'LineWidth',2.5);
    xlabel(ax,'x [px]'); ylabel(ax,'z [px]');
    title(ax, ttl, 'FontSize',9, 'Interpreter','none');
end

function fig = plotStepFigure(figTitle, rowLabels, colTitles, colModes, cbLabels, ...
        imgs, overlays, notes, satNoCorr, satCorr, txtNoCorr, txtCorr)
% 5 x nCols panel figure: rows 1-3 = refInit / refFinal / exp through the steps,
% rows 4-5 (last column) = satImage without / with vacuum correction.
% Empty image -> the tile shows notes{c} ("not applied ...").
    nCols = numel(colTitles);
    fig = figure('Name',figTitle,'Position',[20 20 1800 1600]);
    tl = tiledlayout(5, nCols, 'TileSpacing','compact');
    title(tl, figTitle, 'Interpreter','none');
    tileIdx = @(r,c) (r-1)*nCols + c;

    for r = 1:3
        for c = 1:nCols
            ax = nexttile(tl, tileIdx(r,c));
            img = imgs{r,c};
            ttl = colTitles{c};
            if c == 1, ttl = [rowLabels{r} ' | ' ttl]; end
            if isempty(img)
                axis(ax,'off');
                text(ax, 0.5, 0.5, notes{c}, 'HorizontalAlignment','center', ...
                    'FontSize',9, 'Color',[0.4 0.4 0.4], 'Interpreter','none');
                title(ax, ttl, 'FontSize',8, 'Interpreter','none');
                continue
            end
            ttl = sprintf('%s (%dx%d)', ttl, size(img,1), size(img,2));
            if strcmp(colModes{c}, 'div')
                lim = max(prctile(abs(img(:)), 99.9), eps);
                showImg(ax, img, ttl, [-lim lim]); colormap(ax, redblue(256));
            else
                showImg(ax, img, ttl, robustLim(img)); colormap(ax, turbo);
            end
            ylabel(colorbar(ax), cbLabels{c});
            ov = overlays{r,c};
            if ~isempty(ov)
                hold(ax,'on');
                for o = 1:numel(ov)
                    xline(ax, ov(o).x, ov(o).spec, 'LineWidth',1.2);
                end
            end
        end
    end

    rowImgs = {satNoCorr, satCorr};
    rowTxt  = {txtNoCorr, txtCorr};
    rowTtl  = {'satImage (no vacuum corr.)', 'rhoNorm (vacuum corrected)'};
    rowCb   = {'rhoNorm_{noCorr} [-]', 'rhoNorm [-]'};
    for r = 4:5
        ax = nexttile(tl, tileIdx(r,1), [1 nCols-1]); axis(ax,'off');
        text(ax, 0.98, 0.5, rowTxt{r-3}, 'HorizontalAlignment','right', ...
            'VerticalAlignment','middle', 'FontSize',11, 'Interpreter','tex');
        ax = nexttile(tl, tileIdx(r,nCols));
        showImg(ax, rowImgs{r-3}, rowTtl{r-3}, robustLim(rowImgs{r-3}));
        colormap(ax, turbo); ylabel(colorbar(ax), rowCb{r-3});
    end
end

function showImg(ax, img, ttl, cl)
    imagesc(ax, img); axis(ax,'image'); colorbar(ax);
    if ~isempty(cl), clim(ax, cl); end
    title(ax, ttl, 'FontSize',8, 'Interpreter','none');
end

function cl = robustLim(img)
% colour limits from the image's own 0.5-99.5 percentiles (ignores NaN/Inf and outliers)
    v = img(isfinite(img));
    if isempty(v), cl = [0 1]; return, end
    cl = double(prctile(v, [0.5 99.5]));
    if cl(2) <= cl(1), cl = cl(1) + [-1 1]*max(abs(cl(1))*1e-3, eps); end
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
% PNG always; uncomment the .fig line when you need an editable MATLAB figure
    exportgraphics(fig, fullfile(outDir, name + ".png"), 'Resolution', 200);
    % savefig(fig, fullfile(outDir, name + ".fig"));
end