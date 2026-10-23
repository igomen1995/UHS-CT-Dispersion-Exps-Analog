function plotKLComparison(resultsOut, Key, dataSource, pathExportAll)
% PLOTKLCOMPARISON
%   1) KL bar chart: BTC per zD (full/xtrim), front width/sigma (full/xtrim),
%      MFM CT and MFM UHS (with total uncertainty)
%   2) one figure per completed BTC fit (variant x zD): data + fitted curve,
%      KL in the title -> saved in <pathExportAll>/KLfits_<Key>_<dataSource>/
%   3) one overview per variant: all completed zD fits overlaid

Key = string(Key);  dataSource = string(dataSource);
if ~isfolder(pathExportAll), mkdir(pathExportAll); end
fitDir = fullfile(pathExportAll, "KLfits_" + Key + "_" + dataSource);
if ~isfolder(fitDir), mkdir(fitDir); end

mfmTag = "";
if isfield(resultsOut, 'MFM_fitData'), mfmTag = " (" + string(resultsOut.MFM_fitData) + ")"; end

variants = ["full","xtrim"];

%% 1) KL bar chart
labels = strings(0,1);  vals = [];  errs = [];  grp = [];
% groups: 1 BTC full, 2 BTC xtrim, 3 front full, 4 front xtrim, 5 MFM CT, 6 MFM UHS
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
        end
    end

    frontFns = fieldnames(resultsOut.(variant).KL_front_CT);
    for f = 1:numel(frontFns)
        S2 = resultsOut.(variant).KL_front_CT.(frontFns{f});
        labels(end+1,1) = strrep(frontFns{f},'_','/') + " " + variant;   %#ok<AGROW>
        vals(end+1) = S2.KL_cm2min_best;                                  %#ok<AGROW>
        errs(end+1) = S2.KL_cm2min_se;                                    %#ok<AGROW>
        grp(end+1)  = 2 + v;                                              %#ok<AGROW>
    end
end

labels(end+1,1) = "MFM CT"  + mfmTag + " - " + string(resultsOut.MFM_CT_bestModel);
vals(end+1) = resultsOut.KL_MFM_CT;   errs(end+1) = resultsOut.dKL_MFM_CT;   grp(end+1) = 5;
labels(end+1,1) = "MFM UHS" + mfmTag + " - " + string(resultsOut.MFM_UHS_bestModel);
vals(end+1) = resultsOut.KL_MFM_UHS;  errs(end+1) = resultsOut.dKL_MFM_UHS;  grp(end+1) = 6;

errs(~isfinite(errs)) = 0;
grpNames = ["BTC full","BTC xtrim","front full","front xtrim","MFM CT","MFM UHS"];
grpCol   = lines(6);

nBars = numel(vals);
figBar = figure('Position',[100 100 900 max(450, 22*nBars)]);
ax = axes(figBar); hold(ax,'on')
y = 1:nBars;
b = barh(ax, y, vals, 'FaceColor','flat');
b.CData = grpCol(grp,:);
b.HandleVisibility = 'off';
errorbar(ax, vals, y, errs, 'horizontal', 'k.', 'LineWidth',1, 'HandleVisibility','off')
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
xlabel(ax, 'K_L [cm^2/min]')
title(ax, sprintf('%s (%s): K_L by method', Key, dataSource), 'Interpreter','none')
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
        title(a1, sprintf('%s (%s, %s) z_D=%.1f: K_L = %.3g \\pm %.2g cm^2/min, R^2=%.3f [%s]', ...
            Key, dataSource, variant, e.zD, KLv, dKLv, R2v, string(e.bestMethod)), ...
            'Interpreter','tex', 'FontSize',9)
        fn1 = sprintf('BTCfit_%s_%s_%s_zD%s', Key, dataSource, variant, strrep(sprintf('%.1f',e.zD),'.','p'));
        saveas(f1, fullfile(fitDir, fn1), 'png');
        saveas(f1, fullfile(fitDir, fn1), 'fig');
        close(f1)

        % --- overview
        c = cols(m,:);
        scatter(axAll, t_min, e.C_vals, 8, c, 'filled', 'MarkerFaceAlpha',0.4, 'HandleVisibility','off')
        if hasFit
            plot(axAll, t_min, best.C_pred, '-', 'Color',c, 'LineWidth',2, ...
                'DisplayName', sprintf('z_D=%.1f: K_L=%.3g', e.zD, KLv))
        end
        nPlotted = nPlotted + 1;
    end

    if nPlotted == 0
        text(axAll, 0.5, 0.5, "No completed BTC fit (" + variant + ")", ...
            'Units','normalized', 'HorizontalAlignment','center')
    else
        legend(axAll, 'Location','southeast', 'FontSize',8)
    end
    xlabel(axAll,'t [min]'); ylabel(axAll,'C_D [-]'); ylim(axAll,[-0.05 1.05]); grid(axAll,'on')
    title(axAll, sprintf('%s (%s, %s): all BTC fits along the core', Key, dataSource, variant), ...
        'Interpreter','none')
    fnAll = sprintf('BTCfitsAll_%s_%s_%s', Key, dataSource, variant);
    saveas(figAll, fullfile(pathExportAll, fnAll), 'png');
    saveas(figAll, fullfile(pathExportAll, fnAll), 'fig');
end
end