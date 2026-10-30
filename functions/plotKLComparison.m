function plotKLComparison(resultsOut, Key, dataSource, pathExportAll, plotSources, zDcompare, midMethod)
% PLOTKLCOMPARISON
%   Runs only for the data sources in plotSources (default "conc"); others return at once.
%   0) mid-core comparison (KLmidCompare_<Key>_<ds>): BTC at zD = zDcompare (default 0.5),
%      mid-profile KL (method midMethod, default "contour": w^2/(4 tau), tau from the
%      contour arrival), full and xtrim, against MFM CT and MFM UHS
%   1) KL bar chart (0-10 cm2/min): BTC per zD (full/xtrim), front
%      width/sigma (full/xtrim), mid-core profile (full/xtrim, if computed),
%      MFM CT and MFM UHS (with total uncertainty)
%   2) one figure per completed BTC fit (variant x zD): data + fitted curve
%   3) one overview per variant: all completed zD BTC fits overlaid
%   4) one figure per front width pair / sigma fit (variant x method):
%      all frames, frames used, fitted line + overview per variant
%   Individual fits -> <pathExportAll>/KLfits_<Key>_<dataSource>/

if nargin < 5 || isempty(plotSources), plotSources = "conc"; end
if nargin < 6 || isempty(zDcompare),   zDcompare   = 0.5;    end
if nargin < 7 || isempty(midMethod),   midMethod   = "contour"; end
Key = string(Key);  dataSource = string(dataSource);
if ~ismember(dataSource, string(plotSources)), return, end
if ~isfolder(pathExportAll), mkdir(pathExportAll); end
fitDir = fullfile(pathExportAll, "KLfits_" + Key + "_" + dataSource);
if ~isfolder(fitDir), mkdir(fitDir); end

mfmTag = "";
if isfield(resultsOut, 'MFM_fitData'), mfmTag = " (" + string(resultsOut.MFM_fitData) + ")"; end

variants = ["full","xtrim"];
KLmax = 10;   % bar chart x-limit [cm2/min]

%% 0) mid-core comparison: BTC at zDcompare vs mid-profile KL vs MFM
zTag = "zD" + strrep(sprintf('%.1f', zDcompare), '.', 'p');
cLab = strings(0,1);  cVal = [];  cErr = [];  cMean = [];  cStd = [];  cCol = zeros(0,3);
colBTC = [0.00 0.45 0.74; 0.55 0.75 0.90];      % full / xtrim
colMid = [0.55 0.35 0.65; 0.80 0.65 0.90];
for v = 1:numel(variants)
    variant = variants(v);
    % BTC at zDcompare
    kl = NaN;  dkl = NaN;
    if isfield(resultsOut.(variant), 'KL_BTC_CT_byZD') && isfield(resultsOut.(variant).KL_BTC_CT_byZD, zTag)
        e = resultsOut.(variant).KL_BTC_CT_byZD.(zTag);
        if e.complete && isfield(e.best,'KL_cm2min')
            kl = e.best.KL_cm2min;
            if isfield(e.best,'dKL_cm2min'), dkl = e.best.dKL_cm2min; end
        end
    end
    cLab(end+1,1) = sprintf("BTC z_D = %.1f, %s", zDcompare, variant);  %#ok<AGROW>
    cVal(end+1) = kl;  cErr(end+1) = dkl;  cMean(end+1) = NaN;  cStd(end+1) = NaN;  %#ok<AGROW>
    cCol(end+1,:) = colBTC(v,:);                                         %#ok<AGROW>
    % mid-profile
    kl = NaN;  dkl = NaN;  km = NaN;  ks = NaN;  zmid = zDcompare;  lblM = midMethod;
    if isfield(resultsOut.(variant), 'KL_midProfile') && isfield(resultsOut.(variant).KL_midProfile, 'methods') ...
            && isfield(resultsOut.(variant).KL_midProfile.methods, midMethod)
        mp = resultsOut.(variant).KL_midProfile;  r = mp.methods.(midMethod);
        kl = r.KL_cm2min_best;  dkl = r.dKL_cm2min_best;  km = r.KL_cm2min_mean;  ks = r.KL_cm2min_std;
        zmid = mp.zDtarget;  lblM = r.label;
    end
    cLab(end+1,1) = sprintf("mid-profile z_{50} = %.1f, %s, %s", zmid, lblM, variant);  %#ok<AGROW>
    cVal(end+1) = kl;  cErr(end+1) = dkl;  cMean(end+1) = km;  cStd(end+1) = ks;  %#ok<AGROW>
    cCol(end+1,:) = colMid(v,:);                                         %#ok<AGROW>
end
mfmCols = lines(6);
cLab(end+1,1) = "MFM CT"  + mfmTag + " - " + string(resultsOut.MFM_CT_bestModel);
cVal(end+1) = resultsOut.KL_MFM_CT;   cErr(end+1) = resultsOut.dKL_MFM_CT;   cMean(end+1) = NaN;  cStd(end+1) = NaN;
cCol(end+1,:) = mfmCols(5,:);
cLab(end+1,1) = "MFM UHS" + mfmTag + " - " + string(resultsOut.MFM_UHS_bestModel);
cVal(end+1) = resultsOut.KL_MFM_UHS;  cErr(end+1) = resultsOut.dKL_MFM_UHS;  cMean(end+1) = NaN;  cStd(end+1) = NaN;
cCol(end+1,:) = mfmCols(6,:);
cErr(~isfinite(cErr)) = 0;

nC = numel(cVal);  yC = 1:nC;
cPlot = cVal;  cPlot(~isfinite(cPlot)) = 0;
figC = figure('Position',[100 100 850 60 + 45*nC]);
axC = axes(figC);  hold(axC,'on')
bC = barh(axC, yC, cPlot, 'FaceColor','flat', 'HandleVisibility','off');
bC.CData = cCol;
errorbar(axC, cPlot, yC, cErr, 'horizontal', 'k.', 'LineWidth',1, 'HandleVisibility','off')
okC = isfinite(cMean);
if any(okC)
    sC = cStd;  sC(~isfinite(sC)) = 0;
    errorbar(axC, cMean(okC), yC(okC), sC(okC), 'horizontal', 'LineStyle','none', ...
        'Color',[0.15 0.15 0.15], 'LineWidth',0.8, 'HandleVisibility','off')
    scatter(axC, cMean(okC), yC(okC), 32, 'd', 'filled', 'MarkerFaceColor','k', ...
        'DisplayName','mid-profile: mean \pm std over the frames')
    legend(axC, 'Location','southeast', 'FontSize',8)
end
if isfinite(resultsOut.KL_MFM_CT)
    xline(axC, resultsOut.KL_MFM_CT, '--', 'Color',mfmCols(5,:), 'LineWidth',1.2, 'HandleVisibility','off')
end
if isfinite(resultsOut.KL_MFM_UHS)
    xline(axC, resultsOut.KL_MFM_UHS, ':', 'Color',mfmCols(6,:), 'LineWidth',1.5, 'HandleVisibility','off')
end
for k = 1:nC                                    % value labels (or "n/a")
    if isfinite(cVal(k))
        txt = sprintf('  %.3g', cVal(k));  xt = min(cVal(k) + cErr(k), 0.97*KLmax);
    else
        txt = '  n/a';  xt = 0;
    end
    if isfinite(cVal(k)) && cVal(k) > KLmax, txt = sprintf('%.3g \\rightarrow', cVal(k)); end
    text(axC, xt, yC(k), txt, 'VerticalAlignment','middle', 'FontSize',8, ...
        'HorizontalAlignment', ternaryAlign(isfinite(cVal(k)) && cVal(k) > KLmax))
end
set(axC, 'YTick',yC, 'YTickLabel',cLab, 'TickLabelInterpreter','tex', 'FontSize',9, 'YDir','reverse')
ylim(axC, [0.4, nC+0.6]);  xlim(axC, [0 KLmax]);  grid(axC,'on')
xlabel(axC, 'K_L [cm^2/min]')
title(axC, sprintf('%s (%s): K_L at mid-core -- BTC z_D = %.1f vs front profile vs MFM', ...
    Key, dataSource, zDcompare), 'Interpreter','tex', 'FontSize',10)
fnC = sprintf('KLmidCompare_%s_%s', Key, dataSource);
saveas(figC, fullfile(pathExportAll, fnC), 'png');
saveas(figC, fullfile(pathExportAll, fnC), 'fig');

%% 1) KL bar chart
labels = strings(0,1);  vals = [];  errs = [];  grp = [];  mVals = [];  sVals = [];
% groups: 1 BTC full, 2 BTC xtrim, 3/4 front no-int, 5 MFM CT, 6 MFM UHS, 7/8 front int,
%         9-14 mid-core profile (contour / lines / sigma, full and xtrim)
for v = 1:numel(variants)
    variant = variants(v);

    zDn = fieldnames(resultsOut.(variant).KL_BTC_CT_byZD);
    for m = 1:numel(zDn)
        e = resultsOut.(variant).KL_BTC_CT_byZD.(zDn{m});
        if e.complete && isfield(e.best,'KL_cm2min')
            labels(end+1,1) = sprintf("BTC z_D=%.1f %s", e.zD, variant); %#ok<AGROW>
            vals(end+1) = e.best.KL_cm2min;                              %#ok<AGROW>
            if isfield(e.best,'dKL_cm2min'), errs(end+1) = e.best.dKL_cm2min; else, errs(end+1) = 0; end %#ok<AGROW>
            grp(end+1) = v;                                              %#ok<AGROW>
            mVals(end+1) = NaN;  sVals(end+1) = NaN;                     %#ok<AGROW>
        end
    end

    frontFns = fieldnames(resultsOut.(variant).KL_front_CT);
    for f = 1:numel(frontFns)
        nm = string(frontFns{f});
        S2 = resultsOut.(variant).KL_front_CT.(nm);
        isInt = isfield(S2,'fitWithIntercept') && S2.fitWithIntercept;
        base  = strrep(erase(erase(nm,"_int1"),"_int0"), "_", "/");
        if isInt, intLbl = " int"; else, intLbl = " no-int"; end
        labels(end+1,1) = base + intLbl + " " + variant;   %#ok<AGROW>
        vals(end+1) = S2.KL_cm2min_best;                    %#ok<AGROW>
        errs(end+1) = S2.KL_cm2min_se;                      %#ok<AGROW>
        grp(end+1)  = 2 + v + 4*isInt;                      %#ok<AGROW>  % 3/4 no-int, 7/8 int
        if isfield(S2,'KL_cm2min_mean'), mVals(end+1) = S2.KL_cm2min_mean; else, mVals(end+1) = NaN; end %#ok<AGROW>
        if isfield(S2,'KL_cm2min_std'),  sVals(end+1) = S2.KL_cm2min_std;  else, sVals(end+1) = NaN; end %#ok<AGROW>
    end

    % KL from the profile with the front centre at mid-core (fitKL_midProfile),
    % three methods: w^2/(4 tau) with t_arr contour, w^2/(4 tau) with t_arr lines, sigma
    if isfield(resultsOut.(variant), 'KL_midProfile') && isfield(resultsOut.(variant).KL_midProfile, 'methods')
        mp = resultsOut.(variant).KL_midProfile;
        mNames = ["contour","lines","sigma"];
        for mm = 1:numel(mNames)
            r = mp.methods.(mNames(mm));
            if ~isfinite(r.KL_cm2min_best), continue, end
            labels(end+1,1) = sprintf("mid z_D=%.1f, %s %s", mp.zDtarget, r.label, variant); %#ok<AGROW>
            vals(end+1)  = r.KL_cm2min_best;                     %#ok<AGROW>
            errs(end+1)  = r.dKL_cm2min_best;                    %#ok<AGROW>
            grp(end+1)   = 8 + 2*(mm-1) + v;                     %#ok<AGROW>  % 9/10 contour, 11/12 lines, 13/14 sigma
            mVals(end+1) = r.KL_cm2min_mean;                     %#ok<AGROW>  % mean +/- std over the selected frames
            sVals(end+1) = r.KL_cm2min_std;                      %#ok<AGROW>
        end
    end
end

labels(end+1,1) = "MFM CT"  + mfmTag + " - " + string(resultsOut.MFM_CT_bestModel);
vals(end+1) = resultsOut.KL_MFM_CT;   errs(end+1) = resultsOut.dKL_MFM_CT;   grp(end+1) = 5;
mVals(end+1) = NaN;  sVals(end+1) = NaN;
labels(end+1,1) = "MFM UHS" + mfmTag + " - " + string(resultsOut.MFM_UHS_bestModel);
vals(end+1) = resultsOut.KL_MFM_UHS;  errs(end+1) = resultsOut.dKL_MFM_UHS;  grp(end+1) = 6;
mVals(end+1) = NaN;  sVals(end+1) = NaN;

errs(~isfinite(errs)) = 0;
grpNames = ["BTC full","BTC xtrim","front full (no int)","front xtrim (no int)", ...
            "MFM CT","MFM UHS","front full (int)","front xtrim (int)", ...
            "mid w^2/4\tau contour full","mid w^2/4\tau contour xtrim", ...
            "mid w^2/4\tau lines full","mid w^2/4\tau lines xtrim", ...
            "mid sigma full","mid sigma xtrim"];
grpCol   = [lines(8); ...
            0.55 0.35 0.65; 0.80 0.65 0.90; ...     % contour: purple
            0.60 0.40 0.20; 0.85 0.70 0.50; ...     % lines: brown
            0.20 0.55 0.55; 0.55 0.85 0.85];        % sigma: teal

nBars = numel(vals);
figBar = figure('Position',[100 100 900 max(450, 22*nBars)]);
ax = axes(figBar); hold(ax,'on')
y = 1:nBars;
b = barh(ax, y, vals, 'FaceColor','flat');
b.CData = grpCol(grp,:);
b.HandleVisibility = 'off';
errorbar(ax, vals, y, errs, 'horizontal', 'k.', 'LineWidth',1, 'HandleVisibility','off')
okM = isfinite(mVals);
if any(okM)
    sV = sVals;  sV(~isfinite(sV)) = 0;
    errorbar(ax, mVals(okM), y(okM), sV(okM), 'horizontal', 'LineStyle','none', ...
        'Color',[0.15 0.15 0.15], 'LineWidth',0.8, 'HandleVisibility','off')
    scatter(ax, mVals(okM), y(okM), 28, 'd', 'filled', 'MarkerFaceColor','k', ...
        'DisplayName','mean +/- std of pointwise KL')
end
if isfinite(resultsOut.KL_MFM_CT)
    xline(ax, resultsOut.KL_MFM_CT, '--', 'Color',grpCol(5,:), 'LineWidth',1.2, 'HandleVisibility','off')
end
if isfinite(resultsOut.KL_MFM_UHS)
    xline(ax, resultsOut.KL_MFM_UHS, ':', 'Color',grpCol(6,:), 'LineWidth',1.5, 'HandleVisibility','off')
end
for g = unique(grp)                       % legend entries, one per group present
    plot(ax, NaN, NaN, 's', 'MarkerSize',10, 'MarkerFaceColor',grpCol(g,:), ...
        'MarkerEdgeColor','none', 'DisplayName', grpNames(g))
end
set(ax, 'YTick',y, 'YTickLabel',labels, 'TickLabelInterpreter','tex', 'FontSize',8, 'YDir','reverse')
ylim(ax, [0.4, nBars+0.6])
xlim(ax, [0 KLmax])
xlabel(ax, 'K_L [cm^2/min]')

% bars beyond KLmax are cut at the axis edge -> print their value there
for k = find(vals > KLmax)
    text(ax, 0.99*KLmax, y(k), sprintf('%.3g \\rightarrow', vals(k)), ...
        'HorizontalAlignment','right', 'VerticalAlignment','middle', 'FontSize',7)
end

title(ax, sprintf('%s (%s): KL by method', Key, dataSource), 'Interpreter','none')
legend(ax, 'Location','southeast', 'FontSize',8)
grid(ax,'on')

fname = sprintf('KLcomparison_%s_%s', Key, dataSource);
saveas(figBar, fullfile(pathExportAll, fname), 'png');
saveas(figBar, fullfile(pathExportAll, fname), 'fig');

%% 2) one figure per completed BTC fit + 3) overview per variant
for v = 1:numel(variants)
    variant = variants(v);
    zDn = fieldnames(resultsOut.(variant).KL_BTC_CT_byZD);
    cols = parula(numel(zDn) + 1);

    figAll = figure('Position',[100 100 1000 650]);
    axAll = axes(figAll); hold(axAll,'on')
    nPlotted = 0;

    for m = 1:numel(zDn)
        e = resultsOut.(variant).KL_BTC_CT_byZD.(zDn{m});
        if ~e.complete, continue, end

        best = e.best;
        hasFit = isfield(best,'C_pred') && numel(best.C_pred) == numel(e.t_vals) ...
                 && ~all(isnan(best.C_pred));
        KLv = NaN; dKLv = NaN; R2v = NaN;
        if isfield(best,'KL_cm2min'),  KLv  = best.KL_cm2min;  end
        if isfield(best,'dKL_cm2min'), dKLv = best.dKL_cm2min; end
        if isfield(best,'R2'),         R2v  = best.R2;         end
        t_min = e.t_vals/60;

        % --- individual figure
        f1 = figure('Visible','off', 'Position',[100 100 800 550]);
        a1 = axes(f1); hold(a1,'on')
        scatter(a1, t_min, e.C_vals, 14, 'filled', 'MarkerFaceColor',[0.55 0.55 0.55], ...
            'DisplayName','CT data')
        if hasFit
            plot(a1, t_min, best.C_pred, 'r-', 'LineWidth',2, 'DisplayName','fit')
        end
        yline(a1, [0.16 0.84], ':k', 'HandleVisibility','off')
        xlabel(a1,'t [min]'); ylabel(a1,'C_D [-]'); ylim(a1,[-0.05 1.05]); grid(a1,'on')
        legend(a1,'Location','southeast')
        title(a1, sprintf('%s (%s, %s) zD=%.1f: KL = %.3g +/- %.2g cm2/min, R2=%.3f [%s]', ...
            Key, dataSource, variant, e.zD, KLv, dKLv, R2v, string(e.bestMethod)), ...
            'Interpreter','none', 'FontSize',9)
        fn1 = sprintf('BTCfit_%s_%s_%s_zD%s', Key, dataSource, variant, strrep(sprintf('%.1f',e.zD),'.','p'));
        saveas(f1, fullfile(fitDir, fn1), 'png');
        saveas(f1, fullfile(fitDir, fn1), 'fig');
        close(f1)

        % --- overview
        c = cols(m,:);
        scatter(axAll, t_min, e.C_vals, 8, c, 'filled', 'MarkerFaceAlpha',0.4, 'HandleVisibility','off')
        if hasFit
            plot(axAll, t_min, best.C_pred, '-', 'Color',c, 'LineWidth',2, ...
                'DisplayName', sprintf('zD=%.1f: KL=%.3g', e.zD, KLv))
        end
        nPlotted = nPlotted + 1;
    end

    if nPlotted == 0
        text(axAll, 0.5, 0.5, "No completed BTC fit (" + variant + ")", ...
            'Units','normalized', 'HorizontalAlignment','center', 'Interpreter','none')
    else
        legend(axAll, 'Location','southeast', 'FontSize',8, 'Interpreter','none')
    end
    xlabel(axAll,'t [min]'); ylabel(axAll,'C_D [-]'); ylim(axAll,[-0.05 1.05]); grid(axAll,'on')
    title(axAll, sprintf('%s (%s, %s): all BTC fits along the core', Key, dataSource, variant), ...
        'Interpreter','none')
    fnAll = sprintf('BTCfitsAll_%s_%s_%s', Key, dataSource, variant);
    saveas(figAll, fullfile(pathExportAll, fnAll), 'png');
    saveas(figAll, fullfile(pathExportAll, fnAll), 'fig');
end

%% 4) front width / sigma fits vs time: one 2-panel figure per method +
%     overview per variant and intercept mode
intModes = [false true];
intNames = ["noInt","int"];

for v = 1:numel(variants)
    variant  = variants(v);
    frontFns = string(fieldnames(resultsOut.(variant).KL_front_CT));

    for im = 1:numel(intModes)
        sel = false(numel(frontFns),1);
        for f = 1:numel(frontFns)
            S2 = resultsOut.(variant).KL_front_CT.(frontFns(f));
            sel(f) = isfield(S2,'fitWithIntercept') && S2.fitWithIntercept == intModes(im);
        end
        fnsMode = frontFns(sel);
        cols    = lines(max(numel(fnsMode),1));

        figAll = figure('Position',[100 100 1000 650]);
        axAll = axes(figAll); hold(axAll,'on')
        nPlotted = 0;

        for f = 1:numel(fnsMode)
            name = fnsMode(f);
            S2   = resultsOut.(variant).KL_front_CT.(name);
            if ~all(isfield(S2, {'t_all','y_all','t_fit','y_fit','y_pred'})), continue, end

            if startsWith(name, "sigma")
                yLab = 'sigma^2 [cm^2]   (slope = 2 KL)';
            else
                yLab = 'W^2/(4k^2) [cm^2]   (slope = KL)';
            end

            % --- individual 2-panel figure
            f1 = figure('Visible','off', 'Position',[100 100 1300 520]);

            % left: data, quadratic used for the selection, linear fit
            a1 = subplot(1,2,1, 'Parent',f1); hold(a1,'on')
            okAll = isfinite(S2.t_all) & isfinite(S2.y_all) & S2.t_all > 0;
            scatter(a1, S2.t_all(okAll), S2.y_all(okAll), 10, [0.75 0.75 0.75], 'filled', ...
                'DisplayName','all frames')
            scatter(a1, S2.t_fit, S2.y_fit, 18, cols(f,:), 'filled', 'DisplayName','rising branch (used)')
            if isfield(S2,'pQuad') && all(isfinite(S2.pQuad)) && any(okAll)
                tq = linspace(min(S2.t_all(okAll)), max(S2.t_all(okAll)), 200);
                plot(a1, tq, polyval(S2.pQuad, tq), ':', 'Color',cols(f,:), 'LineWidth',1, ...
                    'DisplayName','quadratic (selection)')
                if isfield(S2,'t_vertex_min') && isfinite(S2.t_vertex_min)
                    xline(a1, S2.t_vertex_min, ':', 'Color',cols(f,:)*0.6, 'HandleVisibility','off')
                end
            end
            if any(isfinite(S2.y_pred))
                [tS, o] = sort(S2.t_fit);
                plot(a1, tS, S2.y_pred(o), '-', 'Color',cols(f,:)*0.6, 'LineWidth',2, 'DisplayName','linear fit')
            end
            xlabel(a1, 't since arrival [min]', 'Interpreter','none')
            ylabel(a1, yLab, 'Interpreter','none')
            grid(a1,'on'); legend(a1, 'Location','northwest', 'Interpreter','none', 'FontSize',8)
            title(a1, sprintf('fit: KL = %.3g +/- %.2g cm2/min, b0 = %.3g cm2, R2 = %.3f, n = %d/%d', ...
                S2.KL_cm2min_best, S2.KL_cm2min_se, S2.intercept_cm2, S2.R2, ...
                S2.nValidFrames, S2.nFramesTotal), 'Interpreter','none', 'FontSize',9)

            % right: pointwise KL on the selected frames
            a2 = subplot(1,2,2, 'Parent',f1); hold(a2,'on')
            if isfield(S2,'KL_pts') && any(isfinite(S2.KL_pts))
                scatter(a2, S2.t_fit, S2.KL_pts, 18, cols(f,:), 'filled', 'DisplayName','KL_i')
                yline(a2, S2.KL_cm2min_mean, '-k', 'LineWidth',1.5, 'DisplayName','mean')
                yline(a2, S2.KL_cm2min_mean + [-1 1]*S2.KL_cm2min_std, '--k', 'HandleVisibility','off')
                yline(a2, S2.KL_cm2min_best, '-', 'Color',cols(f,:)*0.6, 'LineWidth',1.5, ...
                    'DisplayName','regression KL')
                legend(a2, 'Location','best', 'Interpreter','none', 'FontSize',8)
            end
            xlabel(a2, 't since arrival [min]', 'Interpreter','none')
            ylabel(a2, 'KL_i [cm2/min]', 'Interpreter','none')
            grid(a2,'on')
            title(a2, sprintf('pointwise: KL = %.3g +/- %.2g cm2/min (mean +/- std)', ...
                S2.KL_cm2min_mean, S2.KL_cm2min_std), 'Interpreter','none', 'FontSize',9)

            sgtitle(f1, sprintf('%s (%s, %s) %s', Key, dataSource, variant, name), 'Interpreter','none')
            fn1 = sprintf('frontFit_%s_%s_%s_%s', Key, dataSource, variant, name);
            saveas(f1, fullfile(fitDir, fn1), 'png');
            saveas(f1, fullfile(fitDir, fn1), 'fig');
            close(f1)

            % --- overview
            scatter(axAll, S2.t_fit, S2.y_fit, 10, cols(f,:), 'filled', 'MarkerFaceAlpha',0.5, ...
                'HandleVisibility','off')
            if any(isfinite(S2.y_pred))
                [tS, o] = sort(S2.t_fit);
                plot(axAll, tS, S2.y_pred(o), '-', 'Color',cols(f,:), 'LineWidth',2, ...
                    'DisplayName', sprintf('%s: KL fit=%.3g, mean=%.3g+/-%.2g', ...
                    name, S2.KL_cm2min_best, S2.KL_cm2min_mean, S2.KL_cm2min_std))
            end
            nPlotted = nPlotted + 1;
        end

        if nPlotted == 0
            text(axAll, 0.5, 0.5, sprintf('No front fits (%s, %s)', variant, intNames(im)), ...
                'Units','normalized', 'HorizontalAlignment','center', 'Interpreter','none')
        else
            legend(axAll, 'Location','northwest', 'Interpreter','none', 'FontSize',8)
        end
        xlabel(axAll, 't since arrival [min]', 'Interpreter','none')
        ylabel(axAll, 'W^2/(4k^2) or sigma^2 [cm^2]', 'Interpreter','none')
        grid(axAll,'on')
        title(axAll, sprintf('%s (%s, %s, %s): front width / sigma fits (rising branch)', ...
            Key, dataSource, variant, intNames(im)), 'Interpreter','none')
        fnAll = sprintf('frontFitsAll_%s_%s_%s_%s', Key, dataSource, variant, intNames(im));
        saveas(figAll, fullfile(pathExportAll, fnAll), 'png');
        saveas(figAll, fullfile(pathExportAll, fnAll), 'fig');
    end
end
end

function a = ternaryAlign(isRight)
if isRight, a = 'right'; else, a = 'left'; end
end