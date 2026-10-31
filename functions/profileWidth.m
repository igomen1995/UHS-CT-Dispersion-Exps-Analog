function P = profileWidth(z, C, Ci, Cj, levelPairs, nSmooth, doErfc)
% PROFILEWIDTH  Front width of ONE averaged concentration profile C(z) at a fixed time.
% Shared by addProfileWidths (widths of every frame, fitted vs time by fitKL_frontWidth) and
% KL_profileAt (KL from a single profile at a fixed time, e.g. mid-core).
%
% INPUTS
%   z, C        profile (any orientation; z in cm), e.g. C1Profile.zVertcm / CVert
%   Ci, Cj      initial / injected concentration -> Cn = (C - Ci)/(Cj - Ci)
%   levelPairs  [low high] rows, default [0.1 0.9; 0.2 0.8; 0.3 0.7; 0.4 0.6]
%   nSmooth     moving-median window before the level crossings (default 5)
%   doErfc      fit the erfc profile (default true); false skips it (faster) -> the
%               sigma window then uses the 10-90 crossings instead of z50 +/- 4 w
%
% OUTPUT P
%   zz, Cn, Cs  distance from the injection end [cm], normalized profile, cleaned
%               (moving median + monotonic) profile
%   tags        "C10_90", ... per pair;  k = erfcinv(2 low) - erfcinv(2 high)
%   W           width per pair [cm] = z(Cn = low) - z(Cn = high) (NaN if a level is
%               not crossed inside the core)
%   z50_erfc, w_erfc, dw_erfc, rmse_erfc, r2_erfc
%               free erfc fit Cn = 0.5 erfc((z - z50)/w) (first ADE term); w = 2 sqrt(KL tau);
%               goodness of fit on the normalized profile (all points of the core)
%   sigma, skew, kurt
%               moments of the front pulse -dCn/dz (weightedMoments), within z50 +/- 4 w
%   frontInside true if the cleaned profile spans 0.9 .. 0.1 inside the core
%
% KL at a time tau since arrival (first ADE term, Lake & Johns / Peters):
%   pairs : KL = W^2/(4 k^2 tau)     erfc : KL = w^2/(4 tau)     sigma : KL = sigma^2/(2 tau)

if nargin < 5 || isempty(levelPairs), levelPairs = [0.1 0.9; 0.2 0.8; 0.3 0.7; 0.4 0.6]; end
if nargin < 6 || isempty(nSmooth),    nSmooth = 5; end
if nargin < 7 || isempty(doErfc),     doErfc  = true; end
nP = size(levelPairs,1);

P = struct('zz',[], 'Cn',[], 'Cs',[], 'tags',strings(1,nP), 'k',nan(1,nP), 'W',nan(1,nP), ...
    'z50_erfc',NaN, 'w_erfc',NaN, 'dw_erfc',NaN, 'rmse_erfc',NaN, 'r2_erfc',NaN, 'sigma',NaN, 'skew',NaN, 'kurt',NaN, ...
    'frontInside',false);
for p = 1:nP
    P.tags(p) = sprintf("C%02d_%02d", round(100*levelPairs(p,1)), round(100*levelPairs(p,2)));
    P.k(p)    = erfcinv(2*levelPairs(p,1)) - erfcinv(2*levelPairs(p,2));
end

z = double(z(:));  C = double(C(:));
ok = isfinite(z) & isfinite(C);  z = z(ok);  C = C(ok);
if numel(z) < 10, return, end
[z, o] = sort(z);  C = C(o);
Cn = (C - Ci)/(Cj - Ci);
nE = ceil(numel(Cn)/5);
if mean(Cn(1:nE)) < mean(Cn(end-nE+1:end)), Cn = flipud(Cn); end   % injection end first
zz = z - z(1);
Cm = movmedian(Cn, nSmooth);
Cs = cummin(Cm);
P.zz = zz;  P.Cn = Cn;  P.Cs = Cs;
P.frontInside = Cs(1) >= 0.9 && Cs(end) <= 0.1;

% level-pair widths
for p = 1:nP
    zLo = crossFalling(zz, Cs, levelPairs(p,1));
    zHi = crossFalling(zz, Cs, levelPairs(p,2));
    if isfinite(zLo) && isfinite(zHi), P.W(p) = zLo - zHi; end
end

% erfc fit (centre and width free)
fE = @(b, x) 0.5*erfc((x - b(1))/b(2));
if P.frontInside && doErfc
    z0 = crossFalling(zz, Cs, 0.5);
    w0 = P.W(1)/(2*erfcinv(0.2));  if ~(isfinite(w0) && w0 > 0), w0 = 0.1*max(zz); end
    try
        [b, ~, ~, CovB] = nlinfit(zz, Cn, fE, [z0, w0]);
        if b(2) > 0, P.z50_erfc = b(1);  P.w_erfc = b(2);  P.dw_erfc = sqrt(CovB(2,2)); end
    catch
        try
            b = fminsearch(@(b) sum((fE(b, zz) - Cn).^2), [z0, w0], optimset('Display','off'));
            if b(2) > 0, P.z50_erfc = b(1);  P.w_erfc = b(2); end
        catch
        end
    end
end

if isfinite(P.w_erfc)                              % goodness of fit
    res = Cn - fE([P.z50_erfc, P.w_erfc], zz);
    P.rmse_erfc = sqrt(mean(res.^2));
    P.r2_erfc   = 1 - sum(res.^2)/sum((Cn - mean(Cn)).^2);
end

% moments of the front pulse -dCn/dz, restricted to the front: z50 +/- 4 w (erfc fit)
% or, without the fit, the 10-90 zone widened by the same margin (4 w = 2.2 W10-90)
inW = [];
if isfinite(P.w_erfc)
    inW = abs(zz - P.z50_erfc) <= 4*P.w_erfc;
else
    z10 = crossFalling(zz, Cs, 0.1);  z90 = crossFalling(zz, Cs, 0.9);  z5 = crossFalling(zz, Cs, 0.5);
    if isfinite(z10) && isfinite(z90) && isfinite(z5)
        inW = abs(zz - z5) <= 2.2*(z10 - z90);
    end
end
if ~isempty(inW)
    if nnz(inW) >= 5
        st = weightedMoments(zz(inW), -gradient(Cm(inW), zz(inW)));
        P.sigma = st.sigma;  P.skew = st.skewness;  P.kurt = st.kurtosis;
    end
end
end

function zc = crossFalling(z, C, c0)
% first position where a falling, monotonic C reaches c0 (linear interp), NaN if not crossed
zc = NaN;
k = find(C(1:end-1) >= c0 & C(2:end) < c0, 1);
if isempty(k), return, end
if C(k) == C(k+1), zc = z(k); return, end
zc = z(k) + (C(k) - c0)*(z(k+1) - z(k))/(C(k) - C(k+1));
end