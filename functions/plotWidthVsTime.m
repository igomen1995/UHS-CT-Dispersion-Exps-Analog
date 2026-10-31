function plotWidthVsTime(vars, t_arrival_min, variantSuffix, plotFile, titleTxt)
% PLOTWIDTHVSTIME  Front width vs time since arrival: averaged-profile widths
% (zDWidthProf_*, lines + filled markers), 2D-contour widths (zDWidth_*, open markers,
% same colour per level pair) and the erfc-fit width of the profile as its 10-90
% equivalent (zDWidthProfErfc_10_90, black line). Columns from addProfileWidths and
% populate_CTframeVars; saved as <plotFile>.png / .fig.
if nargin < 5, titleTxt = ""; end
sfx = string(variantSuffix);
t   = vars.secondsElapsed/60 - t_arrival_min;
cols = string(vars.Properties.VariableNames);
tok  = regexp(cols, "^zDWidthProf_(\d+_\d+)" + sfx + "_cm$", 'tokens', 'once');
tags = strings(0);
for k = 1:numel(tok), if ~isempty(tok{k}), tags(end+1) = string(tok{k}); end, end %#ok<AGROW>
if isempty(tags), return, end
c = lines(numel(tags));

fig = figure('Visible','off', 'Position',[100 100 900 600]);
ax = axes(fig);  hold(ax,'on')
for p = 1:numel(tags)
    plot(ax, t, vars.("zDWidthProf_" + tags(p) + sfx + "_cm"), '-o', 'Color',c(p,:), ...
        'MarkerFaceColor',c(p,:), 'MarkerSize',4, 'DisplayName', "profile " + strrep(tags(p),"_","-"))
    cN = "zDWidth_" + tags(p) + sfx + "_cm";
    if ismember(cN, cols)
        plot(ax, t, abs(vars.(cN)), 'o', 'Color',c(p,:), 'MarkerSize',6, ...
            'DisplayName', "contour " + strrep(tags(p),"_","-"))
    end
end
eN = "zDWidthProfErfc_10_90" + sfx + "_cm";
if ismember(eN, cols)
    plot(ax, t, vars.(eN), 'k-', 'LineWidth',1.8, 'DisplayName','profile erfc fit (10-90 equiv.)')
end
xlabel(ax, 't - t_{arr} [min]');  ylabel(ax, 'front width [cm]');  grid(ax,'on')
legend(ax, 'Location','northwest', 'FontSize',8, 'NumColumns',2)
title(ax, "Front width vs time: averaged profile (lines) vs 2D contours (open) " + titleTxt, ...
    'Interpreter','none', 'FontSize',10)
saveas(fig, plotFile + ".png");  savefig(fig, plotFile + ".fig");  close(fig)
end
