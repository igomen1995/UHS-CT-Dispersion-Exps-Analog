%% CT pipeline, step by step, for ONE image (i, j, k) + wall-artifact checks
%
% New pipeline (per projection, same for init / final / exp):
%   raw -> median 3x3 -> normImage (max) -> crop to the core walls
%       -> Gaussian sigma -> trim sides -> satImage -> rhoNorm_wVacRef -> REFPROP
%
% Two variants are always computed side by side:
%   C0 : median only, no Gaussian, NO trim   (closest to acquisition, out to the wall)
%   Cs : median + Gaussian sigma + side trim (the processed result)
% plus a log-attenuation version of Cs, and the CURRENT pipeline for comparison.
%
% Wall-channeling checks:
%   A) flat-state test: a projection where C should be 0 everywhere (k0) and one
%      where C should be 1 everywhere (k1). Any rise at the walls there is an
%      ARTIFACT, not channeling.
%   B) column profiles C(x) in the selected projection: ahead of / in / behind
%      the front, with the contrast Delta(x) to show where C can't be trusted.
%   C) smoothing check: C0 vs Cs. If the wall excess is the same, smoothing is
%      not the cause.
%   D) intensity vs log-attenuation: if the wall excess shrinks with log, it
%      comes from Beer-Lambert nonlinearity.
%   E) misalignment: sub-pixel shift of exp and final vs init at both walls.
%
% Outputs in <exportPath>/stepByStep_<Key>_run_jj_kkkk/ :
%   fig1_steps.png, fig2_flatImages.png, fig3_columnProfiles.png,
%   fig4_wallShift.png, fig5_oldVsNew.png, summary.csv, stepByStep.mat

clear; clc;

%% USER SELECTION
iSel = 1;          % experiment row in inputCTExpConfig.xlsx
jSel = 1;          % run
kSel = 100;        % projection

% Flat-state projections for test A. Leave [] to guess automatically.
j0 = [];  k0 = []; % C should be 0 everywhere (tracer not yet in the core)
j1 = [];  k1 = []; % C should be 1 everywhere (core fully swept)

medWin   = 3;      % median window (0 or 1 = off)
sigmaG   = 5;      % Gaussian sigma [px]
trimPx   = [];     % side trim after Gaussian; [] = max(15, ceil(3*sigma))
cropMode = 'delta';% 'delta'  : core walls from the Xe-He contrast profile (exact core width)
                   % 'window' : findCropWindow_xAxis with cropWidth (current method)
deltaThr = 0.05;   % 'delta': wall = where column-mean contrast < deltaThr * centre value
wallMarginPx = 0;  % extra px removed inside the detected walls

edgeFrac = 0.05;   % edge band (fraction of width) for the wall-excess metric
wallWin  = 60;     % half-window [px] around each wall for the shift estimate
maxLag   = 10;     % max shift searched [px]

% crop parameters of the current method (same as main_CTextract)
pixDist      = 70;
partsScanned = 5;
cropWidth    = 1400;
sigmaOld     = 20;  % current end-of-pipeline smoothing, for comparison

if isempty(trimPx), trimPx = max(15, ceil(3*sigmaG)); end

%% SETUP
CT_setupPaths;
cfg = readtable('inputCTExpConfig.xlsx');
filedataExp = import_inputCTExp(cfg.inputFileName{iSel});
key = char(filedataExp.Key);

outDir = fullfile(cfg.exportPath{iSel}, ...
    sprintf('stepByStep_%s_run_%02d_k%04d', key, jSel, kSel));
if ~isfolder(outDir), mkdir(outDir); end

refInitDirs  = listSubdirs(filedataExp.path + filedataExp.CT_data_ref_init);   % Xe
refFinalDirs = listSubdirs(filedataExp.path + filedataExp.CT_data_ref_final);  % He
expDirs      = listSubdirs(filedataExp.path + filedataExp.CT_data_exp);
F.init  = dir(fullfile(refInitDirs(1).folder,  refInitDirs(1).name,  '*.tif'));
F.final = dir(fullfile(refFinalDirs(1).folder, refFinalDirs(1).name, '*.tif'));
expTif  = @(j) dir(fullfile(expDirs(j).folder, expDirs(j).name, '*.tif'));

pca = importPCA(dir(fullfile(refInitDirs(1).folder, refInitDirs(1).name, '*.pca')));
P.cropY = [1; pca.Image.DimY];
P.pixDist = pixDist;  P.partsScanned = partsScanned;  P.cropWidth = cropWidth;
P.F1 = filedataExp.Fluid1;  P.F2 = filedataExp.Fluid2;
P.T  = filedataExp.T;       P.P  = filedataExp.P;
P.interpFcn = buildInterpolant(P.F1, P.F2, P.T, P.P);

opt = struct('medWin',medWin,'sigma',sigmaG,'trim',trimPx,'cropMode',cropMode, ...
    'deltaThr',deltaThr,'wallMarginPx',wallMarginPx);

% guess flat-state projections if not given
if isempty(k0) || isempty(k1)
    [g0, g1, how] = guessFlat(cfg, iSel, key, numel(expDirs), expTif);
    if isempty(k0), j0 = g0(1); k0 = g0(2); end
    if isempty(k1), j1 = g1(1); k1 = g1(2); end
    fprintf('Flat-state guess (%s): C=0 -> run %02d k %d,  C=1 -> run %02d k %d\n', how, j0, k0, j1, k1);
end
fprintf('=== %s | selected run %02d k %d | median %d, sigma %d, trim %d px, crop ''%s'' ===\n\n', ...
    key, jSel, kSel, medWin, sigmaG, trimPx, cropMode);

%% PROCESS the three projections
t0 = tic;
Ssel = processProjection(F, expTif(jSel), kSel, P, opt);
S0   = processProjection(F, expTif(j0),   k0,   P, opt);
S1   = processProjection(F, expTif(j1),   k1,   P, opt);
Osel = oldPipeline(Ssel.raw, P, sigmaOld);
fprintf('Processed 3 projections in %.1f s\n', toc(t0));

for S = {Ssel, S0, S1}
    s = S{1};
    fprintf('  run %02d k %4d: median changed %d outlier px (exp) | core walls x = [%d %d] (width %d) | findCropWindow = [%d %d]\n', ...
        s.j, s.k, s.nOutlier.exp, s.coreX(1), s.coreX(2), s.coreX(2)-s.coreX(1)+1, s.winX(1), s.winX(2));
end

%% FIG 1 - the steps for the selected projection
fig1 = figure('Name','Steps','Position',[30 30 1700 850]);
tl = tiledlayout(2,4,'TileSpacing','compact');
title(tl, sprintf('%s run %02d k %d - pipeline steps (exp image)', key, jSel, kSel), 'Interpreter','none');
showImg(nexttile(tl), Ssel.raw.exp, 'raw', []);
showImg(nexttile(tl), Ssel.raw.exp - Ssel.med.exp, sprintf('removed by median %dx%d', medWin, medWin), []);
showImg(nexttile(tl), Ssel.norm.exp, 'normalized (normImage)', [0 1]);
ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
plot(ax, Ssel.deltaProf, 'k'); xline(ax, Ssel.coreX, 'r', 'LineWidth',1.5); xline(ax, Ssel.winX, 'b--');
legend(ax, {'column-mean (final - init)','core walls (used)','','findCropWindow',''}, 'Location','best');
xlabel(ax,'x [px]'); title(ax,'crop: contrast profile and walls');
showImg(nexttile(tl), Ssel.crop.exp, 'cropped to core walls', [0 1]);
showImg(nexttile(tl), Ssel.C0.sat,  'sat: median only, no trim', [-0.2 1.2]);
showImg(nexttile(tl), Ssel.Cs.sat,  sprintf('sat: + gauss %d + trim %d', sigmaG, trimPx), [-0.2 1.2]);
showImg(nexttile(tl), Ssel.Cs.conc, 'conc (REFPROP)', [0 1]);
colormap(fig1, turbo);
saveFig(fig1, outDir, 'fig1_steps');

%% FIG 2 - flat-state images (test A)
fig2 = figure('Name','Flat states','Position',[30 30 1500 850]);
tl = tiledlayout(2,3,'TileSpacing','compact');
title(tl,'Test A - C should be uniform 0 (left) and 1 (middle); any wall structure there is an artifact');
Sl  = {S0, S1, Ssel};
lab = {sprintf('C=0 state: run %02d k %d', j0, k0), sprintf('C=1 state: run %02d k %d', j1, k1), ...
       sprintf('selected: run %02d k %d', jSel, kSel)};
for v = 1:2
    for p = 1:3
        if v == 1, img = Sl{p}.C0.sat; vl = 'median only'; else, img = Sl{p}.Cs.sat; vl = sprintf('gauss %d + trim', sigmaG); end
        ax = nexttile(tl);
        showImg(ax, img, sprintf('%s | %s', lab{p}, vl), [-0.2 1.2]);
        if p == 3, hold(ax,'on'); contour(ax, img, [0.5 0.5], 'k', 'LineWidth', 1.2); end
    end
end
colormap(fig2, turbo);
saveFig(fig2, outDir, 'fig2_flatImages');

%% FIG 3 - column profiles C(x) (tests A-D)
rmSel = mean(Ssel.Cs.sat(:, centerCols(size(Ssel.Cs.sat,2))), 2, 'omitnan');
bands = { 'ahead of front (0.05-0.3)', rmSel > 0.05 & rmSel < 0.3; ...
          'in front (0.3-0.7)',        rmSel >= 0.3 & rmSel <= 0.7; ...
          'behind front (>0.7)',       rmSel > 0.7 };
allRows = @(S) true(size(S.C0.sat,1),1);

fig3 = figure('Name','Column profiles','Position',[30 30 1700 850]);
tl = tiledlayout(2,3,'TileSpacing','compact');
title(tl, {'Column-averaged C(x), x from left core wall.  grey = median only (to the wall), blue = gauss+trim, red dashed = log-attenuation', ...
           'dotted black (right axis) = contrast \Delta(x)/max: where it is low, C is unreliable'});
plotColProfiles(nexttile(tl), S0,   allRows(S0), 0, lab{1});
plotColProfiles(nexttile(tl), S1,   allRows(S1), 1, lab{2});
plotColProfiles(nexttile(tl), Ssel, allRows(Ssel), [], [lab{3} ' (all rows)']);
for b = 1:3
    plotColProfiles(nexttile(tl), Ssel, bands{b,2}, [], sprintf('selected, %s, %d rows', bands{b,1}, nnz(bands{b,2})));
end
saveFig(fig3, outDir, 'fig3_columnProfiles');

%% FIG 4 - misalignment at the walls (test E)
fig4 = figure('Name','Wall shift','Position',[30 30 1500 450]);
tl = tiledlayout(1,3,'TileSpacing','compact');
title(tl, sprintf('Test E - shift vs init at the core walls (run %02d k %d)', jSel, kSel));
shifts = struct();
wallName = {'left','right'};
for w = 1:2
    xc = Ssel.coreX(w);
    xr = max(1, xc-wallWin):min(size(Ssel.norm.init,2), xc+wallWin);
    pI = mean(Ssel.norm.init(:,xr), 1, 'omitnan');
    pF = mean(Ssel.norm.final(:,xr),1, 'omitnan');
    pE = mean(Ssel.norm.exp(:,xr),  1, 'omitnan');
    shifts.(wallName{w}).exp   = profileShift(pI, pE, maxLag);
    shifts.(wallName{w}).final = profileShift(pI, pF, maxLag);
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
    plot(ax, xr, gradient(pI), 'k', xr, gradient(pF), 'b', xr, gradient(pE), 'r');
    xline(ax, xc, 'k:');
    legend(ax, {'init','final','exp'}, 'Location','best');
    xlabel(ax,'x [px]'); ylabel(ax,'d(intensity)/dx');
    title(ax, sprintf('%s wall: shift exp %+.2f px, final %+.2f px', wallName{w}, ...
        shifts.(wallName{w}).exp, shifts.(wallName{w}).final));
end
% vertical shift over the core columns (only meaningful if the image has z features)
cc = Ssel.coreX(1):Ssel.coreX(2);
zI = mean(Ssel.norm.init(:,cc),2,'omitnan');
shifts.z.exp   = profileShift(zI, mean(Ssel.norm.exp(:,cc),2,'omitnan'),   maxLag);
shifts.z.final = profileShift(zI, mean(Ssel.norm.final(:,cc),2,'omitnan'), maxLag);
ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
plot(ax, gradient(zI), 'k'); plot(ax, gradient(mean(Ssel.norm.exp(:,cc),2,'omitnan')), 'r');
xlabel(ax,'z [px]'); legend(ax,{'init','exp'});
title(ax, sprintf('vertical: shift exp %+.2f px, final %+.2f px', shifts.z.exp, shifts.z.final));
saveFig(fig4, outDir, 'fig4_wallShift');
fprintf('\nTest E - shift vs init [px]: left wall exp %+.2f final %+.2f | right wall exp %+.2f final %+.2f | z exp %+.2f final %+.2f\n', ...
    shifts.left.exp, shifts.left.final, shifts.right.exp, shifts.right.final, shifts.z.exp, shifts.z.final);
fprintf('  Opposite signs at the two walls = the core looks wider/narrower (magnification);\n');
fprintf('  same sign = sideways shift. Anything above ~0.3 px will show up at the walls.\n');

%% FIG 5 - current vs new pipeline, selected projection
fig5 = figure('Name','Old vs new','Position',[30 30 1700 500]);
tl = tiledlayout(1,4,'TileSpacing','compact');
title(tl, sprintf('Current vs new pipeline, run %02d k %d (conc)', jSel, kSel));
showImg(nexttile(tl), Osel.conc, sprintf('current: crop %d, gauss %d at end', cropWidth, sigmaOld), [0 1]);
showImg(nexttile(tl), Ssel.Cs.conc, sprintf('new: median %d, gauss %d before sat, trim %d', medWin, sigmaG, trimPx), [0 1]);
showImg(nexttile(tl), Ssel.C0.conc, 'new, median only (no gauss, no trim)', [0 1]);
ax = nexttile(tl); hold(ax,'on'); grid(ax,'on');
plot(ax, mean(Osel.conc(:, centerCols(size(Osel.conc,2))),2,'omitnan'), 'k', 'DisplayName','current');
plot(ax, mean(Ssel.Cs.conc(:, centerCols(size(Ssel.Cs.conc,2))),2,'omitnan'), 'b', 'LineWidth',1.5, 'DisplayName','new');
plot(ax, mean(Ssel.C0.conc(:, centerCols(size(Ssel.C0.conc,2))),2,'omitnan'), 'Color',[.6 .6 .6], 'DisplayName','median only');
xlabel(ax,'z [px]'); ylabel(ax,'C (central 40 % of columns)'); legend(ax,'Location','best'); ylim(ax,[-0.1 1.1]);
title(ax,'vertical profile');
colormap(fig5, turbo);
saveFig(fig5, outDir, 'fig5_oldVsNew');

%% SUMMARY TABLE
rows = {};
proj = {S0, 'C=0 state', 0; S1, 'C=1 state', 1; Ssel, 'selected', NaN};
for p = 1:3
    S = proj{p,1};
    rows = [rows; metricsRow(proj{p,2}, S, 'median only (sat)',        S.C0.sat,    edgeFrac, proj{p,3})]; %#ok<AGROW>
    rows = [rows; metricsRow(proj{p,2}, S, 'gauss+trim (sat)',         S.Cs.sat,    edgeFrac, proj{p,3})]; %#ok<AGROW>
    rows = [rows; metricsRow(proj{p,2}, S, 'gauss+trim, log (sat)',    S.Cs.satLog, edgeFrac, proj{p,3})]; %#ok<AGROW>
    rows = [rows; metricsRow(proj{p,2}, S, 'gauss+trim (conc)',        S.Cs.conc,   edgeFrac, proj{p,3})]; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'projection','run','k','variant','expected', ...
    'mean','bias','stdAll','stdCenter','edgeExcessLeft','edgeExcessRight','frontWidth_px','nNaN'});
disp(T);
writetable(T, fullfile(outDir, 'summary.csv'));

fprintf(['\nHow to read it:\n' ...
 '  * C=0 / C=1 rows: bias and edgeExcess should be ~0. A wall excess here = ARTIFACT.\n' ...
 '  * stdCenter in the C=0 / C=1 rows = true noise of C (no front in the way).\n' ...
 '  * median only vs gauss+trim: similar edgeExcess -> smoothing is not the cause.\n' ...
 '  * intensity vs log: excess shrinks with log -> Beer-Lambert nonlinearity.\n' ...
 '  * channeling is real only if the selected projection shows a wall excess (fig3, ahead/in front)\n' ...
 '    that the C=0 and C=1 projections do NOT show, at both walls.\n']);

% %% SAVE
% save(fullfile(outDir,'stepByStep.mat'), 'T', 'shifts', 'opt', 'j0','k0','j1','k1', ...
%     'jSel','kSel', '-v7.3');
% saveC = @(S) struct('C0sat',single(S.C0.sat),'Cssat',single(S.Cs.sat),'CssatLog',single(S.Cs.satLog), ...
%     'Csconc',single(S.Cs.conc),'C0Delta',single(S.C0.Delta),'coreX',S.coreX);
% imgs.sel = saveC(Ssel); imgs.flat0 = saveC(S0); imgs.flat1 = saveC(S1); %#ok<STRNU>
% save(fullfile(outDir,'stepByStep.mat'), 'imgs', '-append');
% fprintf('\nDone in %.1f s. Output: %s\n', toc(t0), outDir);

%% ======================= local functions =======================

function S = processProjection(F, expFiles, k, P, opt)
% New pipeline for one projection index k (init/final at k, exp of the given run at k)
    fl = {'init','final','exp'};
    files = {F.init, F.final, expFiles};
    S.k = k;
    S.j = runFromFiles(expFiles);
    for f = 1:3
        raw = double(importImages(files{f}, k));
        S.raw.(fl{f}) = raw;
        S.nOutlier.(fl{f}) = countOutliers(raw);
        if opt.medWin > 1
            med = medfilt2(raw, [opt.medWin opt.medWin], 'symmetric');
        else
            med = raw;
        end
        S.med.(fl{f})  = med;
        S.norm.(fl{f}) = double(normImage(med));
    end
    % crop window: current method (for reference) and core walls
    [S.winX, S.pv] = findCropWindow_xAxis(S.norm.init, P.pixDist, P.partsScanned-1, P.cropWidth);
    S.deltaProf = mean(S.norm.final - S.norm.init, 1, 'omitnan');
    switch opt.cropMode
        case 'delta'
            xw = wallsFromDelta(S.deltaProf, opt.deltaThr, opt.wallMarginPx);
        case 'window'
            xw = double(S.winX(:)');
        otherwise
            error('cropMode must be ''delta'' or ''window''');
    end
    S.coreX = round(xw);
    cropX = reshape(S.coreX, size(S.winX));
    for f = 1:3
        S.crop.(fl{f}) = double(cropImage(S.norm.(fl{f}), cropX, P.cropY));
    end
    S.C0 = computeC(S.crop, P, 0, 0);                  % median only, to the wall
    S.Cs = computeC(S.crop, P, opt.sigma, opt.trim);   % processed
end

function C = computeC(Cr, P, sigma, trim)
    fl = {'init','final','exp'};
    for f = 1:3
        I = Cr.(fl{f});
        if sigma > 0, I = imgaussfilt(I, sigma, 'Padding','replicate'); end
        if trim  > 0, I = I(:, trim+1:end-trim); end
        X.(fl{f}) = I;
    end
    L = @(x) log(max(x, 1e-6));
    C.trim   = trim;
    C.Delta  = X.final - X.init;
    C.sat    = double(satImage(X.exp, X.init, X.final));
    C.satLog = (L(X.init) - L(X.exp)) ./ (L(X.init) - L(X.final));   % Beer-Lambert version
    C.rho    = double(rhoNorm_wVacRef(single(C.sat), P.F1, P.F2, P.T, P.P));
    C.conc   = double(P.interpFcn(C.rho));
end

function O = oldPipeline(R, P, sigmaOld)
% Current pipeline: normImage(raw) -> findCropWindow (fixed width) -> satImage
%                   -> rhoNorm -> REFPROP -> Gaussian at the end
    fl = {'init','final','exp'};
    for f = 1:3, N.(fl{f}) = double(normImage(R.(fl{f}))); end
    winX = findCropWindow_xAxis(N.init, P.pixDist, P.partsScanned-1, P.cropWidth);
    for f = 1:3, X.(fl{f}) = double(cropImage(N.(fl{f}), winX, P.cropY)); end
    sat    = double(satImage(X.exp, X.init, X.final));
    rho    = double(rhoNorm_wVacRef(single(sat), P.F1, P.F2, P.T, P.P));
    O.conc = imgaussfilt(double(P.interpFcn(rho)), sigmaOld);
end

function x = wallsFromDelta(p, thr, margin)
% Core walls from the Xe-He contrast: only the gas-filled core changes between
% the two references, so the column-mean of (final - init) is ~0 outside it.
    p = smoothdata(p(:)', 'movmedian', 15);
    [~, im] = max(abs(p));
    p = p * sign(p(im));
    [pk, ic] = max(p);
    lo = thr * pk;
    xL = find(p(1:ic) < lo, 1, 'last');
    xR = find(p(ic:end) < lo, 1, 'first');
    if isempty(xL), xL = 1; else, xL = xL + 1; end
    if isempty(xR), xR = numel(p); else, xR = ic + xR - 2; end
    x = [xL + margin, xR - margin];
end

function [g0, g1, how] = guessFlat(cfg, iSel, key, nRuns, expTif)
% C=0: projection with the lowest mean of inlet/mid/outlet C; C=1: the highest.
% Uses the processed .mat from the current pipeline if it exists.
    g0 = [1 1];
    g1 = [nRuns numel(expTif(nRuns))];
    how = 'fallback: first projection of run 1 / last projection of last run';
    try
        matFile = fullfile(cfg.exportPath{iSel}, key + ".mat");
        if ~isfile(matFile), return; end
        M = load(matFile, 'expCTDataSave');
        ds = 'conc';
        if ismember('dataSource', cfg.Properties.VariableNames), ds = cfg.dataSource{iSel}; end
        best0 = Inf; best1 = -Inf;
        for j = 1:nRuns
            v = M.expCTDataSave.exp.(sprintf('run_%02d', j)).vars.(ds);
            m = ([v.CD1_zD0p0] + [v.CD1_zD0p5] + [v.CD1_zD1p0]) / 3;
            [mn, kn] = min(m);  [mx, kx] = max(m);
            if mn < best0, best0 = mn; g0 = [j kn]; end
            if mx > best1, best1 = mx; g1 = [j kx]; end
        end
        how = sprintf('from %s.mat, mean C = %.3f / %.3f', key, best0, best1);
    catch ME
        warning('Flat-state guess from .mat failed (%s); using fallback.', ME.message);
    end
end

function j = runFromFiles(files)
% run index is not stored in the file list; keep the folder name for labels
    j = NaN;
    if ~isempty(files)
        tok = regexp(files(1).folder, '(\d+)\D*$', 'tokens', 'once');
        if ~isempty(tok), j = str2double(tok{1}); end
    end
end

function d = listSubdirs(p)
    d = dir(p);
    d = d([d.isdir] & ~startsWith({d.name},'.'));
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

function prof = colProfile(img, rows)
    img = img(rows, :);
    img(~isfinite(img)) = NaN;
    img = min(max(img, -1), 2);          % keep near-wall blow-ups from dominating the mean
    prof = mean(img, 1, 'omitnan');
end

function r = metricsRow(label, S, variant, img, edgeFrac, expected)
    nx  = size(img,2);
    ctr = centerCols(nx);
    eb  = max(3, round(edgeFrac*nx));
    cp  = colProfile(img, true(size(img,1),1));
    v   = img(isfinite(img));
    vc  = img(:, ctr); vc = vc(isfinite(vc));
    fw  = NaN;
    if isnan(expected), fw = frontWidth(mean(img(:,ctr),2,'omitnan')); end
    r = {label, S.j, S.k, variant, expected, mean(v), mean(v) - expected, std(v), std(vc), ...
         mean(cp(1:eb),'omitnan') - mean(cp(ctr),'omitnan'), ...
         mean(cp(end-eb+1:end),'omitnan') - mean(cp(ctr),'omitnan'), fw, nnz(isnan(img))};
end

function plotColProfiles(ax, S, rows, expected, ttl)
    if ~any(rows)
        title(ax, [ttl ' - no rows']); axis(ax,'off'); return
    end
    c0 = colProfile(S.C0.sat, rows);
    cs = colProfile(S.Cs.sat, rows);
    cl = colProfile(S.Cs.satLog, rows);
    d  = mean(S.C0.Delta(rows,:), 1, 'omitnan');  d = d / max(d);
    x0 = 1:numel(c0);
    xs = S.Cs.trim + (1:numel(cs));
    yyaxis(ax,'left'); hold(ax,'on'); grid(ax,'on');
    plot(ax, x0, c0, '-', 'Color',[.6 .6 .6]);
    plot(ax, xs, cs, 'b-', 'LineWidth',1.5);
    plot(ax, xs, cl, 'r--', 'LineWidth',1.2);
    if ~isempty(expected), yline(ax, expected, 'k-'); end
    xline(ax, [S.Cs.trim, numel(c0)-S.Cs.trim], 'k--');
    ylim(ax, [-0.3 1.3]); ylabel(ax, 'C (column mean)');
    yyaxis(ax,'right');
    plot(ax, x0, d, 'k:', 'LineWidth',1.2); ylim(ax,[0 1.1]); ylabel(ax,'\Delta / max');
    xlabel(ax,'x from left core wall [px]');
    title(ax, ttl, 'FontSize', 8, 'Interpreter','none');
end

function dx = profileShift(a, b, maxLag)
% sub-pixel shift of b relative to a, from the correlation of their gradients
    ga = gradient(a(:));  gb = gradient(b(:));
    n = numel(ga);
    lags = -maxLag:maxLag;
    cc = nan(size(lags));
    for t = 1:numel(lags)
        L  = lags(t);
        ia = max(1, 1-L):min(n, n-L);
        x = ga(ia) - mean(ga(ia));  y = gb(ia+L) - mean(gb(ia+L));
        cc(t) = sum(x.*y) / sqrt(sum(x.^2) * sum(y.^2));
    end
    [~, im] = max(cc);
    dx = lags(im);
    if im > 1 && im < numel(lags)
        y1 = cc(im-1); y2 = cc(im); y3 = cc(im+1);
        dx = dx + 0.5*(y1 - y3)/(y1 - 2*y2 + y3);
    end
end

function w = frontWidth(prof)
% distance [px] between C = 0.9 and C = 0.1 on a column-averaged profile
    w = NaN;
    prof = prof(:);
    if mean(prof(1:10),'omitnan') < mean(prof(end-9:end),'omitnan')
        prof = flipud(prof);
    end
    z90 = find(prof < 0.9, 1, 'first');
    z10 = find(prof < 0.1, 1, 'first');
    if ~isempty(z90) && ~isempty(z10) && z10 > z90
        w = z10 - z90;
    end
end

function showImg(ax, img, ttl, cl)
    imagesc(ax, img); axis(ax,'image'); colorbar(ax);
    if ~isempty(cl), clim(ax, cl); end
    title(ax, ttl, 'FontSize', 8, 'Interpreter','none');
end

function saveFig(fig, outDir, name)
    exportgraphics(fig, fullfile(outDir, name + ".png"), 'Resolution', 200);
end