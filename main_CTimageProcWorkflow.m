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
% Processing:
%   raw -> I/I0, with ONE I0 per scan (Xe, He, exp run) taken from a frame that shows
%   air (kAir, default k = 1, air at the left edge) and applied to every projection
%   of that scan -> findCropWindow_xAxis (cropWidth) on refInit -> cropImage
%   -> satImage -> rhoNorm_wVacRef -> interpFcn
%   (useAirNorm = false gives the old normImage, i.e. I/max(I) of each projection)
%
% Figure 2: same as figure 1 but the saturation is computed on ln(I).
% Figure 3: I vs ln(I) side by side - row 1 rhoNorm, row 2 C_molar:
%   version with I | version with ln(I) | difference ln(I) - I | horizontal profiles
%
% Outputs in <exportPath> (base = paperFig_<Key>_run_jj_kkkk_angXXXdeg[_I0k1max]):
%   <base>.png/.fig         figure 1 (I)
%   <base>_lnI.png/.fig     figure 2 (ln I)
%   <base>_IvsLnI.png/.fig  figure 3 (comparison)

clear;

%% IMPORT input

CT_setupPaths;

inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

% Crop parameters (same as main_CTextract)
pixDist      = 70;
partsScanned = 5;      % air, core holder, water, sleeve, core
cropWidth    = 1400;

% I0 (unattenuated intensity): one value per scan, from a frame that shows air
useAirNorm    = true;      % true = I/I0 of the scan | false = old normImage (I/max of each projection)
kAir          = 1;         % frame of each scan where air is visible (left edge at k = 1)
i0Mode        = 'max';     % 'max'   = maximum of frame kAir (after a 3x3 median, so a hot pixel can't set it)
                           % 'strip' = mean of the air columns airCols of frame kAir
airCols       = 1:12;      % 'strip': flat air columns at the left edge of frame kAir (check on its profile)
airPerRow     = false;     % 'strip' only: I0 per detector row (smoothed along z) instead of one value
airSmoothRows = 51;        % rows in the moving average of the per-row I0

% Contours (same as main_CTimaging)
sigmaCont  = 20;        % Gaussian used ONLY to compute the contours
levelsFull = 0.1:0.1:0.9;
labelContours = true;   % numbers on the thin contours

% Figure layout, in pixels (same approach as main_CTimaging: fixed axes positions)
imgWpx       = 200;     % width of each image axes
imgHpx       = 500;     % height of each image axes
cbGapPx      = 18;      % gap image -> colour bar
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

% Figure 3 (I vs ln I)
rowGapPx     = 90;      % vertical gap between the two rows (room for x label + title)
profWpx      = 360;     % width of the profile axes (height = imgHpx)
profGapPx    = 70;      % extra room left of the profile axes (its y label vs colour bar of panel C)
fig3Scale    = [];      % [] = scale figure 3 to fit the screen | number = fixed factor (1 = 200 x 500 px images)
fig3BottomPx = 80;      % fixed room under the bottom row for tick labels + x label (not scaled)
frontBand    = [0.3 0.7];   % rows counted as "front": vertical profile of rhoNorm (I) in this range
edgeFrac     = 0.05;    % outer band per side for the wall-excess number

%% USER SELECTION

iSel = 1;          % experiment row in inputCTExpConfig.xlsx
jSel = 1;          % run
kSel = 91;        % projection

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

%% WORKFLOW

imgNames  = {'Xe reference','He reference','Experiment'};
scanFiles = {refInitimgFiles, refFinalimgFiles, expimgFiles};
normFull  = cell(1,3);
for n = 1:3
    rawImg = double(importImages(scanFiles{n}, kSel));
    if useAirNorm
        I0 = scanI0(scanFiles{n}, kAir, i0Mode, airCols, airPerRow, airSmoothRows);   % I0 of this scan
        normFull{n} = rawImg ./ I0;                                                   % I / I0
        fprintf('  %-13s I0 (k=%d, %s) = %.1f | this frame (k=%d): max = %.4f x I0\n', ...
            imgNames{n}, kAir, i0Mode, mean(I0), kSel, max(rawImg(:))/mean(I0));
    else
        normFull{n} = double(normImage(rawImg));                                      % old: I / max(I)
    end
end
refInitImage  = normFull{1};
refFinalImage = normFull{2};
expImage      = normFull{3};
if useAirNorm, normTag = "_I0k" + kAir + i0Mode; else, normTag = ""; end

crop_xCoords_k = findCropWindow_xAxis(refInitImage, pixDist, partsScanned-1, cropWidth);
fprintf('%s run %02d k %d: crop x = [%d %d]\n', key, jSel, kSel, crop_xCoords_k(1), crop_xCoords_k(2));

refInitCropped  = double(cropImage(refInitImage,  crop_xCoords_k, crop_yCoords));
refFinalCropped = double(cropImage(refFinalImage, crop_xCoords_k, crop_yCoords));
expCropped      = double(cropImage(expImage,      crop_xCoords_k, crop_yCoords));
interpFcn = buildInterpolant(filedataExp.Fluid1, filedataExp.Fluid2, filedataExp.T, filedataExp.P);

% sat with I
rhoNormNoCorr = satImage(expCropped, refInitCropped, refFinalCropped);       % (exp, min, max)
rhoNorm = double(rhoNorm_wVacRef(single(rhoNormNoCorr), filedataExp.Fluid1, ...
    filedataExp.Fluid2, filedataExp.T, filedataExp.P));

Cmolar    = double(interpFcn(rhoNorm));

rhoNormSmooth = imgaussfilt(rhoNorm, sigmaCont);
CmolarSmooth  = imgaussfilt(Cmolar,  sigmaCont);

% sat with ln(I)
refInitCropped_log = -log(max(refInitCropped,eps));
refFinalCropped_log = -log(max(refFinalCropped,eps));
expCropped_log = -log(max(expCropped,eps));

rhoNormNoCorr_log = satImage(-expCropped_log, -refInitCropped_log, -refFinalCropped_log);       % (exp, min, max)
rhoNorm_log = double(rhoNorm_wVacRef(single(rhoNormNoCorr_log), filedataExp.Fluid1, ...
    filedataExp.Fluid2, filedataExp.T, filedataExp.P));

Cmolar_log    = double(interpFcn(rhoNorm_log));

% fields used ONLY for the contours
rhoNormSmooth_log = imgaussfilt(rhoNorm_log, sigmaCont);
CmolarSmooth_log  = imgaussfilt(Cmolar_log,  sigmaCont);

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

%% FIGURE 1

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
normTitles = {'(A) Xe reference', '(B) He reference', '(C) Experiment'};
for p = 1:3
    ax = axes(fig, 'Units','pixels', 'Position', axPos(p));
    imagesc(ax, xAx, zAx, normImgs{p});
    styleAxes(ax, normTitles{p}, xLab, zLab, p == 1, fontName, fontSize);
    colormap(ax, gray); clim(ax, climNorm);
    addColorbar(ax, 'CT normalized [-]', fontName, fontSize, cbGapPx, cbWpx, '%.2f');
end

ax = axes(fig, 'Units','pixels', 'Position', axPos(4));
plotImageContours(ax, xAx, zAx, rhoNorm, rhoNormSmooth, levelsFull, labelContours, fontSize);
styleAxes(ax, '(D) \rho_{norm}', xLab, zLab, false, fontName, fontSize);
addColorbar(ax, '\rho_{norm} [-]', fontName, fontSize, cbGapPx, cbWpx, '%.1f');

ax = axes(fig, 'Units','pixels', 'Position', axPos(5));
plotImageContours(ax, xAx, zAx, Cmolar, CmolarSmooth, levelsFull, labelContours, fontSize);
styleAxes(ax, '(E) C_{molar}', xLab, zLab, false, fontName, fontSize);
addColorbar(ax, 'C_{molar} [-]', fontName, fontSize, cbGapPx, cbWpx, '%.1f');

if isnan(rotPos)
    angStr = 'angNA';
    warning('Rotation angle not found (no %s.mat); file name uses angNA.', key);
else
    angStr = "ang" + strrep(sprintf('%.1f', rotPos), '.', 'p') + "deg";   % e.g. ang123p5deg
end
baseName = fullfile(pathExportAll, sprintf('paperFig_%s_run_%02d_k%04d_%s', key, jSel, kSel, angStr)) + normTag;
exportgraphics(fig, baseName + ".png", 'Resolution', 600);
% savefig(fig, baseName + ".fig");
fprintf('Saved %s.(png)\n', baseName);

%% FIGURE 2

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

normImgs   = {refInitCropped_log, refFinalCropped_log, expCropped_log};
normTitles = {'(A) Xe reference, ln', '(B) He reference, ln', '(C) Experiment, ln'};
allLog  = [refInitCropped_log(:); refFinalCropped_log(:); expCropped_log(:)];
climLog = prctile(allLog(isfinite(allLog)), [0.5 99.5]);        % ln(I) is <= 0: own limits
for p = 1:3
    ax = axes(fig, 'Units','pixels', 'Position', axPos(p));
    imagesc(ax, xAx, zAx, normImgs{p});
    styleAxes(ax, normTitles{p}, xLab, zLab, p == 1, fontName, fontSize);
    colormap(ax, gray); clim(ax, climLog);
    addColorbar(ax, 'ln(CT normalized) [-]', fontName, fontSize, cbGapPx, cbWpx, '%.2f');
end

ax = axes(fig, 'Units','pixels', 'Position', axPos(4));
plotImageContours(ax, xAx, zAx, rhoNorm_log, rhoNormSmooth_log, levelsFull, labelContours, fontSize);
styleAxes(ax, '(D) \rho_{norm}, ln(I)', xLab, zLab, false, fontName, fontSize);
addColorbar(ax, '\rho_{norm} [-]', fontName, fontSize, cbGapPx, cbWpx, '%.1f');

ax = axes(fig, 'Units','pixels', 'Position', axPos(5));
plotImageContours(ax, xAx, zAx, Cmolar_log, CmolarSmooth_log, levelsFull, labelContours, fontSize);
styleAxes(ax, '(E) C_{molar}, ln(I)', xLab, zLab, false, fontName, fontSize);
addColorbar(ax, 'C_{molar} [-]', fontName, fontSize, cbGapPx, cbWpx, '%.1f');

if isnan(rotPos)
    angStr = 'angNA';
    warning('Rotation angle not found (no %s.mat); file name uses angNA.', key);
else
    angStr = "ang" + strrep(sprintf('%.1f', rotPos), '.', 'p') + "deg";   % e.g. ang123p5deg
end
baseName = fullfile(pathExportAll, sprintf('paperFig_%s_run_%02d_k%04d_%s', key, jSel, kSel, angStr)) + normTag;
exportgraphics(fig, baseName + "_lnI.png", 'Resolution', 600);
% savefig(fig, baseName + "_lnI.fig");
fprintf('Saved %s_lnI.(png)\n', baseName);

%% FIGURE 3: I vs ln(I) - row 1 rhoNorm, row 2 C_molar

% front rows: vertical profile (central 40 % of columns) of rhoNorm with I, within frontBand
ctr       = max(1,round(0.3*nx)):round(0.7*nx);
vProf     = mean(rhoNormSmooth(:, ctr), 2, 'omitnan');
frontRows = vProf >= frontBand(1) & vProf <= frontBand(2);
allRows   = true(nz,1);
colProf   = @(img, rows) mean(min(max(img(rows,:), -1), 2), 1, 'omitnan');   % clip near-wall blow-ups
eb        = max(3, round(edgeFrac*nx));
edgeEx    = @(cp) [mean(cp(1:eb),'omitnan'), mean(cp(end-eb+1:end),'omitnan')] - mean(cp(ctr),'omitnan');

rowsQ = { rhoNorm, rhoNormSmooth, rhoNorm_log, rhoNormSmooth_log, '\rho_{norm}', 'rhoNorm'; ...
          Cmolar,  CmolarSmooth,  Cmolar_log,  CmolarSmooth_log,  'C_{molar}',   'C_molar' };

fprintf('\nI vs ln(I), %s run %02d k %d   (wall excess = outer %d%% minus centre 40%%, [left right])\n', ...
    key, jSel, kSel, round(100*edgeFrac));

% Only the IMAGES are scaled to fit the screen. Margins and gaps that hold text
% (tick labels, axis labels, titles, colour-bar labels) stay at fixed pixel sizes,
% because the font does not shrink - otherwise the bottom x axis gets cut off.
bottom3 = fig3BottomPx;   rowGap3 = rowGapPx;   top3 = topPx;   left3 = leftPx;
cbGap3  = cbGapPx;        cbW3    = cbWpx;
fixW = left3 + 3*(cbGap3 + cbW3 + cbLabelPx + hGapPx) + profGapPx + rightPx + 20;   % px not scaled
fixH = bottom3 + rowGap3 + top3;

scr = get(groot, 'ScreenSize');                                    % [1 1 W H] in pixels
if isempty(fig3Scale)
    s3 = min([1, (scr(3)-80-fixW)/(3*imgWpx + profWpx), (scr(4)-90-fixH)/(2*imgHpx)]);
else
    s3 = fig3Scale;
end
imgW3   = round(s3*imgWpx);   imgH3 = round(s3*imgHpx);   profW3 = round(s3*profWpx);
panelW3 = imgW3 + cbGap3 + cbW3 + cbLabelPx + hGapPx;
profLeft = left3 + 3*panelW3 + profGapPx;
figW3 = profLeft + profW3 + rightPx + 20;
figH3 = bottom3 + 2*imgH3 + rowGap3 + top3;
fprintf('Figure 3: images scaled %.2f -> figure %d x %d px, images %d x %d px\n', s3, figW3, figH3, imgW3, imgH3);

fig3  = figure('Units','pixels', 'Position',[20 50 figW3 figH3], 'Color','w');
if showInfo && ~isempty(infoStr)
    annotation(fig3, 'textbox', 'Units','pixels', 'Position',[0 figH3-28 figW3 24], ...
        'String', infoStr, 'EdgeColor','none', 'HorizontalAlignment','center', ...
        'FontName',fontName, 'FontSize',fontSize, 'Interpreter','tex');
end
letters = 'ABCDEFGH';
cI = [0.85 0.33 0.10];  cL = [0 0.35 0.8];

for r = 1:2
    yRow = bottom3 + (2-r)*(imgH3 + rowGap3);                       % row 1 on top
    pos3 = @(p) [left3 + (p-1)*panelW3, yRow, imgW3, imgH3];
    imgI = rowsQ{r,1};  smI = rowsQ{r,2};
    imgL = rowsQ{r,3};  smL = rowsQ{r,4};
    nm   = rowsQ{r,5};
    L0   = (r-1)*4;

    % with I
    ax = axes(fig3, 'Units','pixels', 'Position', pos3(1));
    plotImageContours(ax, xAx, zAx, imgI, smI, levelsFull, labelContours, fontSize);
    styleAxes(ax, sprintf('(%s) %s, I', letters(L0+1), nm), xLab, zLab, true, fontName, fontSize);
    addColorbar(ax, [nm ' [-]'], fontName, fontSize, cbGap3, cbW3, '%.1f');

    % with ln(I)
    ax = axes(fig3, 'Units','pixels', 'Position', pos3(2));
    plotImageContours(ax, xAx, zAx, imgL, smL, levelsFull, labelContours, fontSize);
    styleAxes(ax, sprintf('(%s) %s, ln(I)', letters(L0+2), nm), xLab, zLab, false, fontName, fontSize);
    addColorbar(ax, [nm ' [-]'], fontName, fontSize, cbGap3, cbW3, '%.1f');

    % difference ln(I) - I
    d    = imgL - imgI;
    dLim = max(prctile(abs(d(:)), 99), 1e-3);
    ax = axes(fig3, 'Units','pixels', 'Position', pos3(3));
    imagesc(ax, xAx, zAx, d);
    styleAxes(ax, sprintf('(%s) ln(I) - I', letters(L0+3)), xLab, zLab, false, fontName, fontSize);
    colormap(ax, redblue(256)); clim(ax, [-dLim dLim]);
    addColorbar(ax, ['\Delta' nm ' [-]'], fontName, fontSize, cbGap3, cbW3, '%.2f');

    % horizontal profiles: all rows (solid), front rows (dashed)
    ax = axes(fig3, 'Units','pixels', 'Position', [profLeft yRow profW3 imgH3]);
    hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    plot(ax, xAx, colProf(imgI, allRows), '-', 'Color',cI, 'LineWidth',1.2, 'DisplayName','I, all rows');
    plot(ax, xAx, colProf(imgL, allRows), '-', 'Color',cL, 'LineWidth',1.2, 'DisplayName','ln(I), all rows');
    if any(frontRows)
        plot(ax, xAx, colProf(imgI, frontRows), '--', 'Color',cI, 'LineWidth',1.2, 'DisplayName','I, front rows');
        plot(ax, xAx, colProf(imgL, frontRows), '--', 'Color',cL, 'LineWidth',1.2, 'DisplayName','ln(I), front rows');
    end
    set(ax, 'FontName',fontName, 'FontSize',fontSize, 'TickDir','out');
    ax.YRuler.TickLabelFormat = '%.1f';
    xlim(ax, [xAx(1) xAx(end)]); ylim(ax, [-0.05 1.05]);
    xlabel(ax, xLab); ylabel(ax, [nm ' (row mean) [-]']);
    legend(ax, 'Location','best', 'FontSize',fontSize-2);
    title(ax, sprintf('(%s) horizontal profile', letters(L0+4)), 'FontWeight','normal');

    % numbers
    fprintf('  %-8s all rows  : I [%+.3f %+.3f] | ln(I) [%+.3f %+.3f] | mean ln(I)-I %+.3f, max |diff| %.3f\n', ...
        rowsQ{r,6}, edgeEx(colProf(imgI,allRows)), edgeEx(colProf(imgL,allRows)), ...
        mean(d(:),'omitnan'), max(abs(d(:))));
    if any(frontRows)
        fprintf('  %-8s front rows: I [%+.3f %+.3f] | ln(I) [%+.3f %+.3f]  (%d rows)\n', ...
            rowsQ{r,6}, edgeEx(colProf(imgI,frontRows)), edgeEx(colProf(imgL,frontRows)), nnz(frontRows));
    end
end
if ~any(frontRows)
    fprintf('  no front rows in this projection (rhoNorm vertical profile never within %.1f-%.1f)\n', frontBand);
end

exportgraphics(fig3, baseName + "_IvsLnI.png", 'Resolution', 600);
% savefig(fig3, baseName + "_IvsLnI.fig");
fprintf('Saved %s_IvsLnI.(png)\n', baseName);

%% local functions

function I0 = scanI0(files, kAir, mode, airCols, perRow, smoothRows)
% Unattenuated intensity I0 of one scan, from frame kAir (a frame that shows air).
% The same I0 is used for every projection of that scan.
%   'max'   : maximum of frame kAir after a 3x3 median (removes hot pixels)
%   'strip' : mean of the air columns airCols of frame kAir (per row if perRow)
    img = double(importImages(files, kAir));
    switch mode
        case 'max'
            I0 = max(medfilt2(img, [3 3], 'symmetric'), [], 'all');
        case 'strip'
            if perRow
                I0 = smoothdata(mean(img(:, airCols), 2), 'movmean', smoothRows);   % one value per row
            else
                I0 = mean(img(:, airCols), 'all');                                  % one value
            end
        otherwise
            error('i0Mode must be ''max'' or ''strip''.');
    end
end

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

function addColorbar(ax, lbl, fontName, fontSize, cbGapPx, cbWpx, tickFmt)
% colour bar pinned next to the image; the image axes keeps its exact size
    pos = ax.Position;                       % pixels
    cb = colorbar(ax);
    cb.Units = 'pixels';
    ax.Position = pos;                       % colorbar() would shrink the axes: restore it
    cb.Position = [pos(1)+pos(3)+cbGapPx, pos(2), cbWpx, pos(4)];
    cb.Label.String = lbl;
    cb.FontName = fontName; cb.FontSize = fontSize; cb.TickDirection = 'out';
    cb.Ruler.TickLabelFormat = tickFmt;   % '%.2f' for CT normalized, '%.1f' for rhoNorm / C_molar
end

function cmap = redblue(m)
% diverging blue-white-red colormap (white = 0)
    if nargin < 1, m = 256; end
    h = floor(m/2);
    up   = linspace(0,1,h)';
    down = linspace(1,0,m-h)';
    cmap = [[up; ones(m-h,1)], [up; down], [ones(h,1); down]];
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