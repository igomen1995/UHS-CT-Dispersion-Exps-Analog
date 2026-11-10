function plotKL_W0_vsTD(Tp, r, pair, zDr, fileBase, titleTxt)
% PLOTKL_W0_VSTD  (temporary check) averaged-profile width and per-frame KL vs tD_total, one experiment
%   left : W_<lo>-<hi> [z_D] vs tD_total (frames with the centre in zDr filled, others open)
%   right: per-frame KL vs tD_total
%            without correction  KL   = W^2 / (4 k^2 tau)            (grey)
%            with W0 correction  KL_c = (W^2 - W0^2) / (4 k^2 tau)    (colour)
%          plus the fitted KL of fitKL_W0 (solid line) and of the fit through the origin (dashed)
% Tp: table of KL_allProfileWidths for this pair; r: result of fitKL_W0 (profile width).
% Saved as fileBase.png / .fig (same style as the 7c / 15b figures of main_CTplots).

tag = sprintf('%02d_%02d', round(100*pair));
W   = Tp.("W_prof_" + tag + "_cm");          % [cm]
WD  = Tp.("WD_prof_" + tag);                 % [z_D]
tD  = Tp.tDtotal;  tau = Tp.tau_min;
c4  = 4*r.k^2;
KL  = W.^2 ./ (c4*tau);
W0sq = r.W0sq_cm2;  if ~isfinite(W0sq), W0sq = 0; end
KLc = (W.^2 - W0sq) ./ (c4*tau);
inR = Tp.zD_center_C50 >= zDr(1) & Tp.zD_center_C50 <= zDr(2);
ok  = isfinite(tD) & tau > 0;

fsAx = 20;  fsLbl = 24;  fsLeg = 16;  mk = 60;  colC = [0.85 0.33 0.10];  colU = [0.55 0.55 0.55];
fig = figure('Position',[60 60 1900 700], 'Visible','on');
tl  = tiledlayout(fig, 1, 2, 'TileSpacing','compact');

% ---- width vs tD
ax = nexttile(tl);  hold(ax,'on')
s1 = ok & inR;  s2 = ok & ~inR;
scatter(ax, tD(s1), WD(s1), mk, colC, 'o', 'filled', 'MarkerFaceAlpha',0.6, ...
    'DisplayName', sprintf('centre z_D in [%.1f %.1f] (fit)', zDr))
scatter(ax, tD(s2), WD(s2), mk, colC, 'o', 'DisplayName','other frames')
set(ax, 'FontSize',fsAx, 'LabelFontSizeMultiplier',1);  grid(ax,'on');  box(ax,'on')
xlabel(ax, 't_D [-]', 'FontSize',fsLbl)
ylabel(ax, "\Deltaz_{D," + strrep(tag,'_','-') + "}, profile [-]", 'FontSize',fsLbl)
ylim(ax, [0 inf])
legend(ax, 'Location','northwest', 'FontSize',fsLeg)

% ---- KL vs tD, without / with the W0 correction
ax = nexttile(tl);  hold(ax,'on')
okK = ok & isfinite(KL) & KL > 0;
scatter(ax, tD(okK & inR), KL(okK & inR), mk, colU, 'o', 'filled', 'MarkerFaceAlpha',0.6, ...
    'DisplayName','K_L = W^2/(4k^2\tau)  (W_0 = 0)')
okC = ok & isfinite(KLc);
scatter(ax, tD(okC & inR), KLc(okC & inR), mk, colC, 'o', 'filled', 'MarkerFaceAlpha',0.6, ...
    'DisplayName', sprintf('K_L = (W^2 - W_0^2)/(4k^2\\tau),  W_0 = %.3g cm', sqrt(max(W0sq,0))))
xr = [min(tD(ok & inR)) max(tD(ok & inR))];
if all(isfinite(xr))
    plot(ax, xr, r.KL_cm2min*[1 1], '-', 'Color',colC, 'LineWidth',2.5, ...
        'DisplayName', sprintf('fit with W_0: K_L = %.3g \\pm %.2g', r.KL_cm2min, r.dKL_cm2min))
    plot(ax, xr, r.KL0_cm2min*[1 1], '--', 'Color',colU, 'LineWidth',2.5, ...
        'DisplayName', sprintf('fit W_0 = 0: K_L = %.3g \\pm %.2g', r.KL0_cm2min, r.dKL0_cm2min))
end
set(ax, 'FontSize',fsAx, 'LabelFontSizeMultiplier',1);  grid(ax,'on');  box(ax,'on')
xlabel(ax, 't_D [-]', 'FontSize',fsLbl)
ylabel(ax, sprintf('K_L from W_{%d-%d}, profile [cm^2/min]', round(100*pair)), 'FontSize',fsLbl)
yv = [KL(okK & inR); KLc(okC & inR)];  yv = yv(isfinite(yv));
if ~isempty(yv), ylim(ax, [min(0, min(yv)) 1.1*prctile(yv, 98)]); end
legend(ax, 'Location','northeast', 'FontSize',fsLeg, 'Interpreter','tex')

title(tl, "W and K_L vs t_D, without / with W_0  " + titleTxt, 'Interpreter','none')
saveas(fig, fileBase + ".png");
saveas(fig, fileBase + ".fig");
close(fig)
end
