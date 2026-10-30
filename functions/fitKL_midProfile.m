function S = fitKL_midProfile(vars, variantSuffix, zDtarget, zDwin, ...
    tArrContour_min, vFront_cmmin, tArrLines_min, uInt_cmmin, L_cm, Ci, Cj, sigmaTau, plotFile)
% FITKL_MIDPROFILE  KL from the vertical concentration profile of the frame(s) whose
% front centre (C = 0.5) sits at zD = zDtarget (default mid-core), three methods.
%
% Front-width method (Lake & Johns; Ekwere Peters): the profile at fixed time is fitted
% with the first term of the ADE step solution, centre and width free,
%     C(z) = Ci + (Cj-Ci)/2 erfc((z - z50)/w),     w = 2 sqrt(KL tau)
% so  KL = w^2/(4 tau).  (Equivalent to the 10-90 % mixing-zone form
% Delta z(10-90) = 3.625 sqrt(KL tau), but uses every point of the profile.)
% The velocity does not enter: only the width and the time since arrival tau do.
% Same first-term approximation as the BTC fit (ADE_short_dt_shift), whose free dt
% plays the role of the free centre z50 here, so the two are directly comparable.
%
%   "contour" : KL = w^2/(4 tau),  tau = t - t_arrival_contour (first C = 0.01 contour)
%   "lines"   : KL = w^2/(4 tau),  tau = t - V_linesbefore/Q
%       dKL = 2 KL dw/w (dw = standard error of w from nlinfit)
%   "sigma"   : spatial second moment of the front pulse -dC/dz (weightedMoments, as
%               fitKL_moments, within z50 +/- 4 w), KL = sigma_z^2/(2 tau), tau from the
%               contour arrival (sigmaTau = "contour") or the lines ("lines").
%               For an erfc front sigma_z = w/sqrt(2), so it estimates the same KL.
%
% Diagnostics per frame:
%   z50 - v tau  : is the front centre where the chosen velocity / arrival put it?
%   KL_fullADE   : full Ogata-Banks profile (both terms) with v = u_int and tau from the
%                  contour arrival fixed, KL free -- shows how much the second term
%                  (neglected by the width method and by the BTC fit) changes KL;
%                  it matters when Pe_front = v z/KL is small (~13 % at Pe_front ~ 10).
%
% Diagnostic per frame: free erfc fit (z50, w) -> how far the front centre is from v*tau
% (z50 - v tau shows whether the chosen velocity / arrival is consistent with the image).
%
% Frames: every frame with |z50/L - zDtarget| <= zDwin (mean +/- std per method) and the
% single closest frame ("best"). Profiles: vars.C1Profile, columns zVertcm, zDimLess,
% CVert (full width) / CVert_xtrim (x-trimmed).
%
% OUTPUT S.zDtarget, S.nFrames, S.bestFrame, S.tD_best, S.z50D_best, S.T (one row per frame),
%        S.methods.(contour|lines|sigma): KL_cm2min_best, dKL_cm2min_best, KL_cm2min_mean,
%        KL_cm2min_std, v_cmmin, tArr_min, label

if nargin < 13, plotFile = ""; end
if nargin < 12 || isempty(sigmaTau), sigmaTau = "contour"; end
cCol = "CVert" + variantSuffix;
nF   = height(vars);

meth = ["contour","lines","sigma"];
lbl  = struct('contour',"w^2/(4\tau), t_{arr} contour", 'lines',"w^2/(4\tau), t_{arr} lines", ...
              'sigma', "\sigma_z, t_{arr} " + string(sigmaTau));
emptyM = struct('KL_cm2min_best',NaN, 'dKL_cm2min_best',NaN, 'KL_cm2min_mean',NaN, ...
    'KL_cm2min_std',NaN, 'v_cmmin',NaN, 'tArr_min',NaN, 'label',"");
S = struct('zDtarget',zDtarget, 'zDwin',zDwin, 'nFrames',0, 'bestFrame',NaN, 'tD_best',NaN, ...
    'z50D_best',NaN, 'T',table(), 'methods',struct());
for m = meth, S.methods.(m) = emptyM;  S.methods.(m).label = lbl.(m); end

vC = vFront_cmmin;  if ~(isfinite(vC) && vC > 0), vC = uInt_cmmin; end   % no contour velocity -> u_int
tC = tArrContour_min;  if ~isfinite(tC), tC = tArrLines_min; end
S.methods.contour.v_cmmin = vC;          S.methods.contour.tArr_min = tC;
S.methods.lines.v_cmmin   = uInt_cmmin;  S.methods.lines.tArr_min   = tArrLines_min;
if sigmaTau == "lines", tSig = tArrLines_min; else, tSig = tC; end
S.methods.sigma.tArr_min = tSig;

% ---- front centre (C = 0.5 crossing) of every frame
cMid = 0.5*(Ci + Cj);
z50D = NaN(nF,1);
for l = 1:nF
    pr = getProf(vars.C1Profile, l);
    if isempty(pr) || ~ismember(cCol, string(pr.Properties.VariableNames)), continue, end
    z50D(l) = crossing(pr.zDimLess, pr.(cCol), cMid);
end
if all(~isfinite(z50D))
    warning('fitKL_midProfile: no C = 0.5 crossing in the %s profiles', cCol);  return
end
dz  = abs(z50D - zDtarget);
sel = find(dz <= zDwin);
[~, lBest] = min(dz);
if isempty(sel), sel = lBest; end

% ---- each selected frame: three methods + free-fit diagnostic
rows = cell(numel(sel),1);
fits = struct('z',{},'C',{},'Cc',{},'Cl',{});
for q = 1:numel(sel)
    l  = sel(q);
    pr = getProf(vars.C1Profile, l);
    z  = pr.zVertcm(:);  C = pr.(cCol)(:);
    ok = isfinite(z) & isfinite(C);  z = z(ok);  C = C(ok);
    [z, o] = sort(z);  C = C(o);
    s  = sign(mean(C(z <= median(z))) - mean(C(z > median(z))));  if s == 0, s = 1; end
    zz = z;  if s < 0, zz = max(z) - z; end      % distance from the injection end
    t_min = vars.secondsElapsed(l)/60;

    % free erfc fit (diagnostic, also defines the window for the sigma method)
    fFree = @(p, x) Ci + (Cj - Ci)*0.5*erfc((x - p(1))/p(2));
    try
        z0 = z50D(l)*L_cm;  if s < 0, z0 = (1 - z50D(l))*L_cm; end
        [pF, ~, ~, CovF] = nlinfit(zz, C, fFree, [z0, 0.1*L_cm]);
        wF = abs(pF(2));  z50F = pF(1);  dwF = sqrt(CovF(2,2));
    catch
        wF = NaN;  z50F = NaN;  dwF = NaN;
    end

    % front-width method (first ADE term): KL = w^2/(4 tau), tau from each arrival
    tauC = t_min - tC;  tauL = t_min - tArrLines_min;
    [KLc, dKLc] = klWidth(wF, dwF, tauC);
    [KLl, dKLl] = klWidth(wF, dwF, tauL);
    Cw = fFree([z50F, wF], zz);                                  % fitted erfc (both methods)

    % diagnostic: full Ogata-Banks with v = u_int, tau = contour arrival, KL free
    [KLfull, ~, Cfull] = fitADEfixed(zz, C, Ci, Cj, uInt_cmmin, tauC);

    % sigma: moments of the front pulse w = -dC/dz (weightedMoments, the same function
    % as fitKL_moments), restricted to z50 +/- 4 w_free so plateau noise does not
    % inflate the variance; also gives the skewness and kurtosis of the front
    tauS = t_min - tSig;
    sig2 = NaN;  KLs = NaN;  skF = NaN;  kuF = NaN;
    if isfinite(wF) && wF > 0
        inW = abs(zz - z50F) <= 4*wF;
        if nnz(inW) >= 5
            g  = -gradient(C(inW), zz(inW)) * sign(Cj - Ci);
            st = weightedMoments(zz(inW), g);
            sig2 = st.sigma^2;  skF = st.skewness;  kuF = st.kurtosis;
            if tauS > 0 && isfinite(sig2) && sig2 > 0, KLs = sig2/(2*tauS); end
        end
    end
    PeFront = z50F^2/(KLc*tauC);                                % v z/KL with v = z50/tau (front at z50)

    rows{q} = table(l, vars.tDtotal(l), t_min, z50D(l), z50F, wF, dwF, ...
        tauC, z50F - vC*tauC, z50F - uInt_cmmin*tauC, KLc, dKLc, PeFront, ...
        tauL, z50F - uInt_cmmin*tauL, KLl, dKLl, tauS, sqrt(sig2), skF, kuF, KLs, KLfull, ...
        'VariableNames', {'frame','tDtotal','t_min','z50D','z50_free_cm','w_free_cm','dw_free_cm', ...
        'tau_contour_min','z50_minus_vfront_tau_cm','z50_minus_uint_tau_cm', ...
        'KL_contour_cm2min','dKL_contour_cm2min','Pe_front', ...
        'tau_lines_min','z50_minus_uint_tauLines_cm','KL_lines_cm2min','dKL_lines_cm2min', ...
        'tau_sigma_min','sigma_z_cm','skew_front','kurt_front','KL_sigma_cm2min', ...
        'KL_fullADE_uint_contour_cm2min'});
    fits(q).z = zz;  fits(q).C = C;  fits(q).Cc = Cw;  fits(q).Cl = Cfull;
end
T = vertcat(rows{:});
S.T = T;  S.nFrames = height(T);

qb = find(T.frame == lBest, 1);
if ~isempty(qb)
    S.bestFrame = lBest;  S.tD_best = T.tDtotal(qb);  S.z50D_best = T.z50D(qb);
end
cols = struct('contour',{{'KL_contour_cm2min','dKL_contour_cm2min'}}, ...
              'lines',  {{'KL_lines_cm2min','dKL_lines_cm2min'}}, ...
              'sigma',  {{'KL_sigma_cm2min',''}});
for m = meth
    v = T.(cols.(m){1});  okv = isfinite(v) & v > 0;
    S.methods.(m).KL_cm2min_mean = mean(v(okv));
    S.methods.(m).KL_cm2min_std  = std(v(okv));
    if ~isempty(qb)
        S.methods.(m).KL_cm2min_best = v(qb);
        if ~isempty(cols.(m){2}), S.methods.(m).dKL_cm2min_best = T.(cols.(m){2})(qb); end
    end
end

% ---- figure: profiles + ADE fits (closest frame), KL per frame for the three methods
if strlength(plotFile) > 0 && S.nFrames > 0 && ~isempty(qb)
    fig = figure('Position',[80 80 1250 480]);
    tl  = tiledlayout(fig, 1, 2, 'TileSpacing','compact');
    ax = nexttile(tl);  hold(ax,'on')
    plot(ax, fits(qb).z/L_cm, fits(qb).C, 'k.', 'DisplayName', sprintf('profile, t_D = %.2f', T.tDtotal(qb)))
    plot(ax, fits(qb).z/L_cm, fits(qb).Cc, '-', 'LineWidth',2, 'DisplayName', ...
        sprintf('erfc fit, w = %.3g cm: K_L = %.3g (contour), %.3g (lines)', T.w_free_cm(qb), ...
        T.KL_contour_cm2min(qb), T.KL_lines_cm2min(qb)))
    plot(ax, fits(qb).z/L_cm, fits(qb).Cl, '--', 'LineWidth',1.5, 'DisplayName', ...
        sprintf('full ADE (u_{int}, t_{arr} contour): K_L = %.3g', T.KL_fullADE_uint_contour_cm2min(qb)))
    xline(ax, zDtarget, ':k', 'HandleVisibility','off');
    xlabel(ax, 'z_D (from the injection end) [-]');  ylabel(ax, 'C [-]');
    xlim(ax,[0 1]);  ylim(ax,[-0.05 1.05]);  grid(ax,'on')
    legend(ax, 'Location','best', 'FontSize',8)
    title(ax, sprintf('Closest frame to z_{50} = %.2f (%s)', zDtarget, cCol), 'Interpreter','tex')

    ax = nexttile(tl);  hold(ax,'on')
    plot(ax, T.tDtotal, T.KL_contour_cm2min, 'o-', 'DisplayName', lbl.contour)
    plot(ax, T.tDtotal, T.KL_lines_cm2min,   's-', 'DisplayName', lbl.lines)
    plot(ax, T.tDtotal, T.KL_sigma_cm2min,   '^-', 'DisplayName', lbl.sigma)
    xlabel(ax, 't_D [-]');  ylabel(ax, 'K_L [cm^2/min]');  grid(ax,'on')
    legend(ax, 'Location','best')
    title(ax, sprintf('K_L per frame (%d frames, |z_{50} - %.2f| \\leq %.2f)', S.nFrames, zDtarget, zDwin), ...
        'Interpreter','tex')
    saveas(fig, plotFile + ".png");  savefig(fig, plotFile + ".fig");
    close(fig)
end
end

function [KL, dKL] = klWidth(w, dw, tau)
% front-width method: KL = w^2/(4 tau), dKL = 2 KL dw/w
KL = NaN;  dKL = NaN;
if ~(isfinite(w) && w > 0 && isfinite(tau) && tau > 0), return, end
KL  = w^2/(4*tau);
dKL = 2*KL*dw/w;
end

function [KL, dKL, Cfit, tau] = fitADEfixed(z, C, Ci, Cj, v, tau)
% one-parameter fit of the Ogata-Banks resident profile, v and tau fixed
KL = NaN;  dKL = NaN;  Cfit = NaN(size(z));
if ~(isfinite(v) && v > 0 && isfinite(tau) && tau > 0), return, end
f = @(p, x) adeProfile(x, exp(p(1)), v, tau, Ci, Cj);    % p = log(KL) keeps KL > 0
w0  = max(1e-3, 0.1*max(z));                              % initial width ~ 10 % of the core
KL0 = w0^2/(4*tau);
try
    [p, ~, ~, CovB] = nlinfit(z, C, f, log(KL0));
    KL   = exp(p(1));
    dKL  = KL*sqrt(CovB(1,1));                            % SE in log -> relative SE
    Cfit = f(p, z);
catch
end
end

function C = adeProfile(z, KL, v, tau, Ci, Cj)
% Ogata-Banks resident concentration; exp(a)*erfc(b) via erfcx to avoid overflow
d  = 2*sqrt(KL*tau);
b1 = (z - v*tau)/d;
b2 = (z + v*tau)/d;
term2 = erfcx(b2) .* exp(v*z/KL - b2.^2);
term2(~isfinite(term2)) = 0;
C = Ci + (Cj - Ci)*0.5*(erfc(b1) + term2);
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