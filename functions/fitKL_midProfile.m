function S = fitKL_midProfile(vars, variantSuffix, zDtarget, zDwin, tLines_min, vFront_cmmin, ...
    u_cmmin, L_cm, tauMode, Ci, Cj, plotFile)
% FITKL_MIDPROFILE  KL from the vertical concentration profile of the frame(s) whose
% front centre (C = 0.5) sits at zD = zDtarget (default mid-core).
%
% Each selected profile C(z) is fitted with the ADE step solution in space
% (resident concentration, the second erfc term is negligible for uL/KL >> 1):
%
%       C(z) = Ci + (Cj - Ci) * 0.5 * erfc( s*(z - z50) / w ),   w = 2*sqrt(KL*tau)
%
% with z50 and w free (s = +1 when the injected gas enters at z = 0). Then
%
%       KL = w^2 / (4*tau)
%
% tau = time the front has been travelling in the core:
%   "front" : tau = z50 / v_front   (measured front velocity from main_CTpreproc; falls
%             back to the interstitial velocity when it is not available)
%   "lines" : tau = t - tLines      (elapsed time minus the line volume before the core)
%   "nominal": tau = z50 / u        (interstitial velocity)
% All three are computed and stored; KL_cm2min_best uses tauMode.
%
% Frames: every frame with |z50/L - zDtarget| <= zDwin (mean +/- std over them), and
% the single closest frame (KL_cm2min_best). Profiles from vars.C1Profile:
% columns zVertcm, zDimLess, CVert (full width) and CVert_xtrim (x-trimmed).
%
% INPUT  vars (varsAll.(dataSource)), variantSuffix "" | "_xtrim", zDtarget, zDwin,
%        tLines_min, vFront_cmmin, u_cmmin, L_cm, tauMode, Ci, Cj, plotFile ("" = no figure)
% OUTPUT S struct: KL_cm2min_best, dKL_cm2min_best (fit CI of w), KL_cm2min_mean, KL_cm2min_std,
%        frame table T (one row per selected frame), best frame data for plotting

if nargin < 12, plotFile = ""; end
cCol = "CVert" + variantSuffix;
nF   = height(vars);

S = struct('zDtarget',zDtarget, 'zDwin',zDwin, 'tauMode',string(tauMode), ...
    'KL_cm2min_best',NaN, 'dKL_cm2min_best',NaN, 'KL_cm2min_mean',NaN, 'KL_cm2min_std',NaN, ...
    'KL_front_mean',NaN, 'KL_lines_mean',NaN, 'KL_nominal_mean',NaN, ...
    'nFrames',0, 'bestFrame',NaN, 'tD_best',NaN, 'z50D_best',NaN, 'w_cm_best',NaN, ...
    'R2_best',NaN, 'v_used_cmmin',NaN, 'T',table(), 'z_best',[], 'C_best',[], 'Cfit_best',[]);

if isfinite(vFront_cmmin) && vFront_cmmin > 0, vUse = vFront_cmmin; else, vUse = u_cmmin; end
S.v_used_cmmin = vUse;

% ---- front centre (C = 0.5 crossing) of every frame
z50D = NaN(nF,1);
for l = 1:nF
    pr = getProf(vars.C1Profile, l);
    if isempty(pr) || ~ismember(cCol, string(pr.Properties.VariableNames)), continue, end
    z50D(l) = crossing(pr.zDimLess, pr.(cCol), 0.5*(Ci + Cj));
end
if all(~isfinite(z50D))
    warning('fitKL_midProfile: no C = 0.5 crossing in %s profiles', cCol);  return
end
dz  = abs(z50D - zDtarget);
sel = find(dz <= zDwin);
[~, lBest] = min(dz);
if isempty(sel), sel = lBest; end

% ---- fit each selected profile
rows = cell(numel(sel),1);
fits = struct('z',{},'C',{},'Cfit',{});
for q = 1:numel(sel)
    l  = sel(q);
    pr = getProf(vars.C1Profile, l);
    z  = pr.zVertcm(:);  C = pr.(cCol)(:);
    ok = isfinite(z) & isfinite(C);  z = z(ok);  C = C(ok);
    s  = sign(mean(C(z <= median(z))) - mean(C(z > median(z))));  if s == 0, s = 1; end
    model = @(p, zz) Ci + (Cj - Ci)*0.5*erfc(s*(zz - p(1))/p(2));
    p0 = [z50D(l)*L_cm, 0.1*L_cm];
    try
        [p, Rres, ~, CovB] = nlinfit(z, C, model, p0);
        w  = abs(p(2));  dw = sqrt(CovB(2,2));
        Cf = model(p, z);
        R2 = 1 - sum(Rres.^2)/sum((C - mean(C)).^2);
    catch
        p = [NaN NaN];  w = NaN;  dw = NaN;  Cf = NaN(size(z));  R2 = NaN;
    end
    z50cm = p(1);
    t_min = vars.secondsElapsed(l)/60;
    tauF  = z50cm / vUse;
    tauL  = t_min - tLines_min;
    tauN  = z50cm / u_cmmin;
    KLf = w^2/(4*tauF);  KLl = w^2/(4*tauL);  KLn = w^2/(4*tauN);
    if ~(tauF > 0), KLf = NaN; end
    if ~(tauL > 0), KLl = NaN; end
    if ~(tauN > 0), KLn = NaN; end
    switch string(tauMode)
        case "lines",   KL = KLl;
        case "nominal", KL = KLn;
        otherwise,      KL = KLf;
    end
    dKL = KL*2*dw/w;
    rows{q} = table(l, vars.tDtotal(l), t_min, z50D(l), z50cm, w, dw, R2, tauF, tauL, tauN, ...
        KLf, KLl, KLn, KL, dKL, ...
        'VariableNames', {'frame','tDtotal','t_min','z50D','z50_cm','w_cm','dw_cm','R2', ...
        'tau_front_min','tau_lines_min','tau_nominal_min', ...
        'KL_front_cm2min','KL_lines_cm2min','KL_nominal_cm2min','KL_cm2min','dKL_cm2min'});
    fits(q).z = z;  fits(q).C = C;  fits(q).Cfit = Cf;
end
T = vertcat(rows{:});
S.T = T;
S.nFrames = height(T);
good = isfinite(T.KL_cm2min) & T.KL_cm2min > 0;
S.KL_cm2min_mean  = mean(T.KL_cm2min(good), 'omitnan');
S.KL_cm2min_std   = std(T.KL_cm2min(good), 'omitnan');
S.KL_front_mean   = mean(T.KL_front_cm2min, 'omitnan');
S.KL_lines_mean   = mean(T.KL_lines_cm2min, 'omitnan');
S.KL_nominal_mean = mean(T.KL_nominal_cm2min, 'omitnan');

qb = find(T.frame == lBest, 1);
if ~isempty(qb)
    S.KL_cm2min_best = T.KL_cm2min(qb);   S.dKL_cm2min_best = T.dKL_cm2min(qb);
    S.bestFrame = lBest;  S.tD_best = T.tDtotal(qb);  S.z50D_best = T.z50D(qb);
    S.w_cm_best = T.w_cm(qb);  S.R2_best = T.R2(qb);
    S.z_best = fits(qb).z;  S.C_best = fits(qb).C;  S.Cfit_best = fits(qb).Cfit;
end

% ---- figure: selected profiles and fits, KL per frame
if strlength(plotFile) > 0 && S.nFrames > 0
    fig = figure('Position',[80 80 1200 480], 'Visible','on');
    tl  = tiledlayout(fig, 1, 2, 'TileSpacing','compact');
    ax = nexttile(tl);  hold(ax,'on')
    cmap = parula(max(S.nFrames,2));
    for q = 1:S.nFrames
        lw = 1;  if q == qb, lw = 2.5; end
        plot(ax, fits(q).z/L_cm, fits(q).C, '.', 'Color',cmap(q,:), 'HandleVisibility','off')
        plot(ax, fits(q).z/L_cm, fits(q).Cfit, '-', 'Color',cmap(q,:), 'LineWidth',lw, ...
            'DisplayName', sprintf('t_D = %.2f, K_L = %.3g', T.tDtotal(q), T.KL_cm2min(q)))
    end
    xline(ax, zDtarget, ':k', 'HandleVisibility','off');
    xlabel(ax, 'z_D [-]');  ylabel(ax, 'C [-]');  xlim(ax,[0 1]);  ylim(ax,[-0.05 1.05]);  grid(ax,'on')
    legend(ax, 'Location','best', 'FontSize',7)
    title(ax, sprintf('Profiles with z_{50} within %.2f \\pm %.2f (%s)', zDtarget, zDwin, cCol), 'Interpreter','tex')

    ax = nexttile(tl);  hold(ax,'on')
    plot(ax, T.tDtotal, T.KL_front_cm2min,   'o-', 'DisplayName','\tau = z_{50}/v_{front}')
    plot(ax, T.tDtotal, T.KL_lines_cm2min,   's-', 'DisplayName','\tau = t - t_{lines}')
    plot(ax, T.tDtotal, T.KL_nominal_cm2min, '^-', 'DisplayName','\tau = z_{50}/u')
    yline(ax, S.KL_cm2min_mean, '--k', sprintf('mean (%s) = %.3g', tauMode, S.KL_cm2min_mean), ...
        'HandleVisibility','off');
    xlabel(ax, 't_D [-]');  ylabel(ax, 'K_L [cm^2/min]');  grid(ax,'on')
    legend(ax, 'Location','best')
    title(ax, 'K_L = w^2 / (4 \tau) per frame', 'Interpreter','tex')
    saveas(fig, plotFile + ".png");  savefig(fig, plotFile + ".fig");
    close(fig)
end
end

function pr = getProf(col, l)
if iscell(col), pr = col{l}; elseif istable(col), pr = col(l,:); else, pr = col(l); end
if iscell(pr), pr = pr{1}; end
if isstruct(pr), pr = struct2table(pr); end
end

function zc = crossing(zD, C, c0)
% first crossing of C = c0 along zD (linear interpolation), NaN if none
zc = NaN;
ok = isfinite(zD) & isfinite(C);  zD = zD(ok);  C = C(ok);
if numel(zD) < 2, return, end
[zD, o] = sort(zD);  C = C(o);
d = C - c0;
k = find(d(1:end-1).*d(2:end) <= 0, 1);
if isempty(k), return, end
if d(k+1) == d(k), zc = zD(k); return, end
zc = zD(k) - d(k)*(zD(k+1) - zD(k))/(d(k+1) - d(k));
end
