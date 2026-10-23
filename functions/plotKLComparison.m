function plotKLComparison(resultsOut, Key, dataSource, pathExportAll)
% PLOTKLCOMPARISON  Two-panel figure:
%   (left)  BTC fitted curve vs raw scatter, at the first COMPLETED zD
%           level found (not hardcoded to zD=0.5, which may fail the
%           completeness gate for a given dataSource)
%   (right) KL comparison: one bar PER zD level from the BTC method
%           (not a collapsed mean), plus width/sigma/MFM

fig = figure('Position',[100 100 1300 500]);

%% Left: fitted curve vs scatter, first completed zD level (full)
ax1 = subplot(1,2,1);
hold(ax1,'on')
zDnames = fieldnames(resultsOut.full.KL_BTC_CT_byZD);
plotted = false;
for m = 1:numel(zDnames)
    entry = resultsOut.full.KL_BTC_CT_byZD.(zDnames{m});
    if entry.complete
        scatter(ax1, entry.t_vals, entry.C_vals, 18, 'filled', ...
            'MarkerFaceColor',[0.5 0.5 0.5], 'DisplayName','Measured');
        best = entry.best;
        if isfield(best,'C_pred') && ~all(isnan(best.C_pred))
            plot(ax1, entry.t_vals, best.C_pred, 'r-', 'LineWidth',2, 'DisplayName','Fit');
        end
        legend(ax1,'Location','best');
        title(ax1, sprintf('%s: BTC fit @ z_D=%.1f (full)', Key, entry.zD), 'Interpreter','none');
        plotted = true;
        break
    end
end
if ~plotted
    text(ax1, 0.5, 0.5, 'No completed BTC fit (full)', 'HorizontalAlignment','center', 'Units','normalized');
    title(ax1, sprintf('%s: BTC fit (full) -- none completed', Key), 'Interpreter','none');
end
xlabel(ax1,'t [s]'); ylabel(ax1,'C [-]');
grid(ax1,'on');

%% Right: KL comparison -- per-zD BTC bars + width/sigma + MFM
ax2 = subplot(1,2,2);
labels = {}; vals = []; errs = [];

for variantArr = ["full","xtrim"]
    variant = variantArr;

    zDnamesV = fieldnames(resultsOut.(variant).KL_BTC_CT_byZD);
    for m = 1:numel(zDnamesV)
        e = resultsOut.(variant).KL_BTC_CT_byZD.(zDnamesV{m});
        if e.complete && isfield(e.best,'KL_cm2min')
            labels{end+1} = char(sprintf('BTC z_D=%.1f %s', e.zD, variant));
            vals(end+1) = e.best.KL_cm2min;
            errs(end+1) = 0;   % per-zD point estimate, no spread to show here
        end
    end

    frontFns = fieldnames(resultsOut.(variant).KL_front_CT);
    for f = 1:numel(frontFns)
        S2 = resultsOut.(variant).KL_front_CT.(frontFns{f});
        labels{end+1} = char(strrep(frontFns{f},'_','/') + " " + variant);
        vals(end+1) = S2.KL_cm2min_best; errs(end+1) = S2.KL_cm2min_se;
    end
end
labels{end+1} = 'MFM';
vals(end+1) = resultsOut.KL_MFM; errs(end+1) = 0;

y = 1:numel(vals);
barh(ax2, y, vals);
hold(ax2,'on')
errorbar(ax2, vals, y, errs, 'horizontal', 'k.', 'LineWidth',1, 'HandleVisibility','off')
set(ax2,'YTick',y,'YTickLabel',labels,'FontSize',7)
xlabel(ax2,'K_L [cm^2/min]');
title(ax2, sprintf('%s (%s): K_L by method', Key, dataSource), 'Interpreter','none');
grid(ax2,'on')

sgtitle(sprintf('%s KL comparison', Key), 'Interpreter','none')

fname = sprintf('KLcomparison_%s_%s', Key, dataSource);
if ~isfolder(pathExportAll), mkdir(pathExportAll); end
saveas(fig, fullfile(pathExportAll, fname), 'png');
saveas(fig, fullfile(pathExportAll, fname), 'fig');
end