%% main_CTimageProcWorkflow.m
% CT figure for the paper: one projection (i, j, k), current (old) processing
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
% Processing (same as main_CTextract / main_CTpreproc):
%   raw -> normImage -> findCropWindow_xAxis (cropWidth) on refInit -> cropImage
%       -> satImage -> rhoNorm_wVacRef -> interpFcn
%   The rhoNorm -> C_molar interpolant is built, as in main_CTpreproc, at the
%   MEASURED average conditions of the matching MFM analog run
%   (exp_params.T_mean, Pavg_avg, with T_std, Pavg_std for the uncertainty),
%   not at the set T and P of the input file. The C_molar uncertainty
%   (T +/- dT, P +/- dP, in quadrature) is reported in the command window.
%
% Figure 2: same as figure 1 but the saturation is computed on ln(I).
% Figure 3: I vs ln(I) side by side - row 1 rhoNorm, row 2 C_molar:
%   version with I | version with ln(I) | difference ln(I) - I | horizontal profiles
%
% Outputs in <exportPath> (base = paperFig_<Key>_run_jj_kkkk_angXXXdeg):
%   <base>.png/.fig         figure 1 (I)
%   <base>_lnI.png/.fig     figure 2 (ln I)
%   <base>_IvsLnI.png/.fig  figure 3 (comparison)

clear;

%% IMPORT input

Root = CT_setupPaths;

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

% MFM analog (CT) data for this experiment -- measured average T and P (as main_CTpreproc)
pathImport_MFM_CT = regexprep(inputFileConfig.MFM_BTC_CT_Path{iSel}, '^(\.\./)+', '');
MFM_CT_name = inputFileConfig.MFM_BTC_CT_Key{iSel};
MFM_CT_file = fullfile(Root, pathImport_MFM_CT, 'expProcFullData.mat');
if ~isfile(MFM_CT_file)
    error('MFM results file not found: %s', MFM_CT_file);
end
MFM_CT_Data = load(MFM_CT_file);
expProcFullData_MFM_CT = MFM_CT_Data.expProcFullData.(MFM_CT_name);

Fluid1      = expProcFullData_MFM_CT.exp_params.Fluid1;
Fluid2      = expProcFullData_MFM_CT.exp_params.Fluid2;
T_C_avg     = expProcFullData_MFM_CT.exp_params.T_mean;
dT_C_avg    = expProcFullData_MFM_CT.exp_params.T_std;
P_psig_avg  = expProcFullData_MFM_CT.exp_params.Pavg_avg;
dP_psig_avg = expProcFullData_MFM_CT.exp_params.Pavg_std;
fprintf('%s: interpolant at measured T = %.2f +/- %.2f C, P = %.1f +/- %.1f psig (set: %g C, %g psig)\n', ...
    key, T_C_avg, dT_C_avg, P_psig_avg, dP_psig_avg, mean(filedataExp.T), mean(filedataExp.P));

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

% I0 (air) of each scan = max of its own frame k = 1 (air visible at the left edge)
refInitImage_Iair  = findIair(importImages(refInitimgFiles,  1));
refFinalImage_Iair = findIair(importImages(refFinalimgFiles, 1));
expImage_Iair      = findIair(importImages(expimgFiles,      1));

refInitImage  = normImage(importImages(refInitimgFiles,  kSel), refInitImage_Iair);
refFinalImage = normImage(importImages(refFinalimgFiles, kSel), refFinalImage_Iair);
expImage      = normImage(importImages(expimgFiles,      kSel), expImage_Iair);

crop_xCoords_k = findCropWindow_xAxis(refInitImage, pixDist, partsScanned-1, cropWidth);
fprintf('%s run %02d k %d: crop x = [%d %d]\n', key, jSel, kSel, crop_xCoords_k(1), crop_xCoords_k(2));

refInitCropped  = double(cropImage(refInitImage,  crop_xCoords_k, crop_yCoords));
refFinalCropped = double(cropImage(refFinalImage, crop_xCoords_k, crop_yCoords));
expCropped      = double(cropImage(expImage,      crop_xCoords_k, crop_yCoords));

% rhoNorm -> C_molar at the measured average conditions, plus T/P-perturbed versions
[interpFcn, interpFcn_Tp, interpFcn_Tm, interpFcn_Pp, interpFcn_Pm] = ...
    buildInterpolant(Fluid1, Fluid2, T_C_avg, P_psig_avg, dT_C_avg, dP_psig_avg);

% sat with I
rhoNormNoCorr = satImage(expCropped, refInitCropped, refFinalCropped);       % (exp, min, max)
rhoNorm = double(rhoNorm_wVacRef(single(rhoNormNoCorr), filedataExp.Fluid1, ...
    filedataExp.Fluid2, filedataExp.T, filedataExp.P));

Cmolar    = double(interpFcn(rhoNorm));

% C_molar uncertainty from T and P (same convention as main_CTpreproc)
dC_dT   = (double(interpFcn_Tp(rhoNorm)) - double(interpFcn_Tm(rhoNorm)))/2;
dC_dP   = (double(interpFcn_Pp(rhoNorm)) - double(interpFcn_Pm(rhoNorm)))/2;
dCmolar = sqrt(dC_dT.^2 + dC_dP.^2);
fprintf('C_molar uncertainty from T/P: mean %.4f, std %.4f, max %.4f\n', ...
    mean(dCmolar(:),'omitnan'), std(dCmolar(:),'omitnan'), max(dCmolar(:)));

rhoNormSmooth = imgaussfilt(rhoNorm, sigmaCont);
CmolarSmooth  = imgaussfilt(Cmolar,  sigmaCont);

% sat with ln(I)
refInitCropped_log = -log(max(refInitCropped,eps));
refFinalCropped_log = -log(max(refFinalCropped,eps));
expCropped_log = -log(max(expCropped,eps));

rhoNormNoCorr_log = satImage(expCropped_log, refInitCropped_log, refFinalCropped_log);       % (exp, min, max)
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
        xAx = ((1:nx) - 0.5) / nx;          % pixel centres -> image edges exactly at 0 and 1
        zAx = ((1:nz) - 0.5) / nz;
        xLab = 'x_D [-]'; zLab = 'z_D [-]';
end

if isempty(climNorm)
    allNorm  = [refInitCropped(:); refFinalCropped(:); expCropped(:)];
    climNorm = prctile(allNorm(isfinite(allNorm)), [0.5 99.5]);
end

%% FIGURE 1: processing steps in one row (8 panels, page width)
%   (A-C) normalized intensity I/I0      : Xe (cushion), He (working gas), experiment
%   (D-F) attenuation -ln(I/I0)          : Xe, He, experiment
%   (G)   C*_He = rho_norm               (H) C_He = molar concentration (REFPROP)
% Sized in centimetres -> font sizes are the printed sizes.

useLogChain = true;     % true: G-H from the attenuation chain (-ln I) | false: from I

% ---- page layout [cm] and fonts [pt]
figWcm   = 18.0;        % full text width (17-18 cm for A4 / letter, two columns ~ 18)
leftCm   = 1.25;        % z label + ticks
rightCm  = 0.25;
botCm    = 1.65;        % x ticks + label
topCm    = 1.45;        % panel titles + group headers (+ info line)
gapCm    = 0.60;        % between panels of a group
grpGapCm = 0.65;        % after a colour bar, before the next group
cbGapCm  = 0.12;  cbWcm = 0.22;  cbLabCm = 1.05;   % colour bar: gap, width, room for ticks + label
cbTickCm = 0.62;        % width of the colour-bar tick labels (header line ends here) [cm]
fsAx     = 9;           % axes ticks / labels / colour-bar ticks
fsTitle  = 10;          % panel titles
fsHead   = 10;          % group headers
fsCb     = 9;           % colour-bar labels

if useLogChain
    imgG = rhoNorm_log;  imgH = Cmolar_log;   chainStr = 'attenuation';
else
    imgG = rhoNorm;      imgH = Cmolar;       chainStr = 'intensity';
end

allLog  = [refInitCropped_log(:); refFinalCropped_log(:); expCropped_log(:)];
climLog = prctile(allLog(isfinite(allLog)), [0.5 99.5]);

% {image, title, colormap, clim, group}
panels = { ...
    refInitCropped,      '(A) Gas 2',  gray(256),  climNorm, 1; ...
    refFinalCropped,     '(B) Gas 1',  gray(256),  climNorm, 1; ...
    expCropped,          '(C) Exp.',   gray(256),  climNorm, 1; ...
    refInitCropped_log,  '(D) Gas 2',  gray(256),  climLog,  2; ...
    refFinalCropped_log, '(E) Gas 1',  gray(256),  climLog,  2; ...
    expCropped_log,      '(F) Exp.',   gray(256),  climLog,  2; ...
    imgG,                '(G) C^*_1',  turbo(256), [0 1],    3; ...
    imgH,                '(H) C_1',    turbo(256), [0 1],    3};
grpHead = {'Normalized intensity I/I_0', 'Attenuation -ln(I/I_0)', 'Gas 1 concentration'};
grpCb   = {'I/I_0 [-]', '-ln(I/I_0) [-]', 'C_1 [-]'};
grpFmt  = {'%.2f', '%.1f', '%.1f'};
nP = size(panels,1);  nG = 3;

% ---- panel size: fill the width, keep the physical aspect of the image
nGapIn = nP - nG;                                            % gaps inside groups
pw  = (figWcm - leftCm - rightCm - nGapIn*gapCm - nG*(cbGapCm + cbWcm + cbLabCm) - (nG-1)*grpGapCm) / nP;
hw  = (nz*exppca.Geometry.VoxelSizeY) / (nx*exppca.Geometry.VoxelSizeX);   % image height/width
ph  = pw*hw;
figHcm = botCm + ph + topCm;

[infoStr, rotPos] = getScanInfo(pathExportAll, key, jSel, kSel);

fig = figure('Units','centimeters', 'Position',[2 2 figWcm figHcm], 'Color','w', ...
    'PaperUnits','centimeters', 'PaperSize',[figWcm figHcm]);

x = leftCm;  grpX0 = nan(1,nG);  grpX1 = nan(1,nG);
for p = 1:nP
    g = panels{p,5};
    if isnan(grpX0(g)), grpX0(g) = x; end

    ax = axes(fig, 'Units','centimeters', 'Position',[x botCm pw ph]);
    imagesc(ax, xAx, zAx, panels{p,1});
    colormap(ax, panels{p,3});  clim(ax, panels{p,4});
    set(ax, 'YDir','reverse', 'FontName',fontName, 'FontSize',fsAx, 'TickDir','out', ...
        'Box','on', 'Layer','top', 'TickLength',[0.03 0.03], 'LineWidth',0.6);
    axis(ax, 'tight');
    if axisUnits == "D"
        xlim(ax, [0 1]);  ylim(ax, [0 1]);
        set(ax, 'XTick',[0 0.5 1], 'XTickLabel',{'0','0.5','1'}, ...
                'YTick',0:0.2:1,   'YTickLabel',{'0','0.2','0.4','0.6','0.8','1'});
    end
    ax.XTickLabelRotation = 45;         % angled x_D tick labels
    xlabel(ax, xLab, 'FontSize',fsAx);
    if p == 1, ylabel(ax, zLab, 'FontSize',fsAx); else, set(ax, 'YTickLabel',[]); end
    title(ax, panels{p,2}, 'FontWeight','bold', 'FontSize',fsTitle, 'Interpreter','tex');

    lastInGroup = p == nP || panels{p+1,5} ~= g;
    if lastInGroup
        grpX1(g) = x + pw;
        pos = ax.Position;
        cb = colorbar(ax);
        cb.Units = 'centimeters';
        ax.Position = pos;                                   % colorbar() shrinks the axes: restore
        cb.Position = [pos(1)+pos(3)+cbGapCm, pos(2), cbWcm, pos(4)];
        cb.FontName = fontName;  cb.FontSize = fsAx;  cb.TickDirection = 'out';
        cb.TickLength = 0.03;                               % tick mark length (default 0.01)
        cb.Ruler.TickLabelFormat = grpFmt{g};
        cb.Label.String = grpCb{g};  cb.Label.FontSize = fsCb;  cb.Label.Interpreter = 'tex';
        x = pos(1) + pos(3) + cbGapCm + cbWcm + cbLabCm + grpGapCm;
    else
        x = x + pw + gapCm;
    end
end

% group headers: line from the first panel to the end of the colour-bar tick labels,
% title centred on that line
yHead = botCm + ph + 0.78;           % height of the header line above the panels [cm]
for g = 1:nG
    xL = grpX0(g);                                   % left edge of the first panel
    xR = grpX1(g) + cbGapCm + cbWcm + cbTickCm;      % end of the colour-bar tick labels
    annotation(fig, 'line', 'Units','centimeters', ...
        'X',[xL xR], 'Y',[yHead yHead], 'LineWidth',0.6);
    annotation(fig, 'textbox', 'Units','centimeters', ...
        'Position',[xL yHead+0.05 (xR-xL) 0.5], 'String',grpHead{g}, ...
        'EdgeColor','none', 'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
        'FontName',fontName, 'FontSize',fsHead, 'FontWeight','bold', 'Interpreter','tex', ...
        'Margin',0, 'FitBoxToText','off');
end

if isnan(rotPos)
    angStr = 'angNA';
    warning('Rotation angle not found (no %s.mat); file name uses angNA.', key);
else
    angStr = "ang" + strrep(sprintf('%.1f', rotPos), '.', 'p') + "deg";
end
baseName = fullfile(pathExportAll, sprintf('paperFig_%s_run_%02d_k%04d_%s', key, jSel, kSel, angStr));
exportgraphics(fig, baseName + "_steps.png", 'Resolution', 600);
savefig(fig, baseName + "_steps.fig");
fprintf('Saved %s_steps.(png/fig), %s chain for G-H, panels %.2f x %.2f cm\n', ...
    baseName, chainStr, pw, ph);

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
savefig(fig3, baseName + "_IvsLnI.fig");
fprintf('Saved %s_IvsLnI.(png)\n', baseName);

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
        E = S.expCTDataSave;
        runName = sprintf('run_%02d', j);
        if isfield(E, 'varsAll')                     % current main_CTpreproc layout
            f = fieldnames(E.varsAll);
            V = E.varsAll.(f{1});                    % time / angle are the same for rhoNorm and conc
            V = V(string(V.runName) == runName, :);
            v = table2struct(V(k,:));
        else                                         % older layout
            runVars = E.exp.(runName).vars;
            f = fieldnames(runVars);
            v = runVars.(f{1})(k);
        end
        rotPos  = v.rotPos;
        infoStr = sprintf('t_D = %.2f,  t = %g s,  \\theta = %.0f°', v.tDtotal, v.secondsElapsed, v.rotPos);
    catch
    end
end