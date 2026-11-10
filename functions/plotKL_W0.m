function plotKL_W0(fits, fileBase, titleTxt)
% PLOTKL_W0  W^2 vs t - t_arr for every level pair (one tile each): averaged profile (filled
% circles) and 2D contours (open squares), fit with initial width W^2 = W0^2 + 4k^2 KL tau (solid)
% and through the origin (dashed). fits: cell of struct('pair','width','r') from fitKL_W0.
% Saved as fileBase.png / .fig.

pairs = unique(string(cellfun(@(f) f.pair, fits, 'UniformOutput', false)), 'stable');
srcSty = struct('prof', struct('mk','o', 'col',[0.85 0.33 0.10], 'fill',true,  'name',"profile"), ...
                'cont', struct('mk','s', 'col',[0.00 0.45 0.74], 'fill',false, 'name',"2D contours"));
fig = figure('Position',[60 60 1300 950], 'Visible','on');
tl  = tiledlayout(fig, 'flow', 'TileSpacing','compact');
for p = pairs(:)'
    ax = nexttile(tl);  hold(ax,'on')
    for q = 1:numel(fits)
        f = fits{q};
        if string(f.pair) ~= p || isempty(f.r.tau), continue, end
        st = srcSty.(char(f.width));  r = f.r;
        if st.fill
            scatter(ax, r.tau, r.W2, 18, st.col, st.mk, 'filled', 'MarkerFaceAlpha',0.6, 'HandleVisibility','off')
        else
            scatter(ax, r.tau, r.W2, 22, st.col, st.mk, 'LineWidth',1, 'HandleVisibility','off')
        end
        xf = [0 max(r.tau)];
        c4 = 4*r.k^2;
        plot(ax, xf, r.W0sq_cm2 + c4*r.KL_cm2min*xf, '-', 'Color',st.col, 'LineWidth',2, ...
            'DisplayName', sprintf('%s: K_L = %.3g, W_0 = %.3g cm (R^2 %.3f)', st.name, r.KL_cm2min, r.W0_cm, r.R2))
        plot(ax, xf, c4*r.KL0_cm2min*xf, '--', 'Color',st.col, 'LineWidth',1.5, ...
            'DisplayName', sprintf('%s, W_0 = 0: K_L = %.3g (R^2 %.3f)', st.name, r.KL0_cm2min, r.R2_0))
    end
    xlabel(ax, 't - t_{arr} [min]');  ylabel(ax, 'W^2 [cm^2]')
    title(ax, "W_{" + strrep(p, "_", "-") + "}");  grid(ax,'on');  box(ax,'on')
    xlim(ax, [0 inf]);  ylim(ax, [0 inf])
    legend(ax, 'Location','northwest', 'FontSize',8, 'Interpreter','tex')
end
title(tl, "W^2 = W_0^2 + 4k^2 K_L (t - t_{arr})  " + titleTxt, 'Interpreter','tex')
saveas(fig, fileBase + ".png");
saveas(fig, fileBase + ".fig");
close(fig)
end
