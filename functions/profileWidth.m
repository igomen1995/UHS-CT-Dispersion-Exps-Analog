function P = profileWidth(z, C, Ci, Cj, levelPairs, nSmooth, doErfc, trimFrac)
% PROFILEWIDTH  Front width of ONE averaged concentration profile C(z) at a fixed time.
% Shared by addProfileWidths (widths of every frame, fitted vs time by fitKL_frontWidth) and
% KL_profileAt (KL from a single profile at a fixed time, e.g. mid-core).
%
% INPUTS
%   z, C        profile (any orientation; z in cm), e.g. C1Profile.zVertcm / CVert
%   Ci, Cj      initial / injected concentration -> Cn = (C - Ci)/(Cj - Ci)
%   levelPairs  [low high] rows, default [0.1 0.9; 0.2 0.8; 0.3 0.7; 0.4 0.6]
%   nSmooth     moving-median window on the profile (default 5)
%   doErfc      fit the erfc profile (default true); false skips it (faster)
%   trimFrac    fraction of the core length dropped at EACH end before anything is
%               computed (default 0.02): end caps / partial slices at the image edges
%               often hold 0 or garbage and would otherwise break the level crossings
%
% Level crossings are found FROM THE FRONT OUTWARD: the front centre is the C = 0.5
% crossing with the steepest drop; levels < 0.5 are searched downstream of it, levels
% > 0.5 upstream. Noise or artefacts away from the front cannot cut the profile short.
% No 10-90 requirement: every pair (40-60, 30-70, ...) and the erfc fit are computed as
% soon as the profile crosses C = 0.5; a pair is NaN only if ITS levels are not crossed.
%
% OUTPUT P
%   zz, Cn, Cs  distance from the injection end [cm], normalized profile, smoothed profile
%   tags        "C10_90", ... per pair;  k = erfcinv(2 low) - erfcinv(2 high)
%   W           width per pair [cm] = z(Cn = low) - z(Cn = high) (NaN if not crossed)
%   z50_erfc, w_erfc, dw_erfc, rmse_erfc, r2_erfc
%               free erfc fit Cn = 0.5 erfc((z - z50)/w) (first ADE term); w = 2 sqrt(KL tau)
%   sigma, skew, kurt
%               moments of the front pulse -dCn/dz (weightedMoments), within z50 +/- 4 w
%   frontInside true if the 0.1 and 0.9 levels are both crossed inside the core
%               (information only, nothing depends on it)
%   note        why the widths are NaN, if they are
%
% KL at a time tau since arrival (first ADE term, Lake & Johns / Peters):
%   pairs : KL = W^2/(4 k^2 tau)     erfc : KL = w^2/(4 tau)     sigma : KL = sigma^2/(2 tau)

if nargin < 5 || isempty(levelPairs), levelPairs = [0.1 0.9; 0.2 0.8; 0.3 0.7; 0.4 0.6]; end
if nargin < 6 || isempty(nSmooth),    nSmooth  = 5;    end
if nargin < 7 || isempty(doErfc),     doErfc   = true; end
if nargin < 8 || isempty(trimFrac),   trimFrac = 0.02; end
nP = size(levelPairs,1);

P = struct('zz',[], 'Cn',[], 'Cs',[], 'tags',strings(1,nP), 'k',nan(1,nP), 'W',nan(1,nP), ...
    'z50_erfc',NaN, 'w_erfc',NaN, 'dw_erfc',NaN, 'rmse_erfc',NaN, 'r2_erfc',NaN, ...
    'sigma',NaN, 'skew',NaN, 'kurt',NaN, 'frontInside',false, 'note',"");
for p = 1:nP
    P.tags(p) = sprintf("C%02d_%02d", round(100*levelPairs(p,1)), round(100*levelPairs(p,2)));
    P.k(p)    = erfcinv(2*levelPairs(p,1)) - erfcinv(2*levelPairs(p,2));
end

z = double(z(:));  C = double(C(:));
ok = isfinite(z) & isfinite(C);  z = z(ok);  C = C(ok);
if numel(z) < 10, P.note = "profile empty"; return, end
[z, o] = sort(z);  C = C(o);
Cn = (C - Ci)/(Cj - Ci);

% drop the end slices, then orient: injection end (high C) first
L  = z(end) - z(1);
in = z >= z(1) + trimFrac*L & z <= z(end) - trimFrac*L;
z  = z(in);  Cn = Cn(in);
nE = ceil(numel(Cn)/5);
if mean(Cn(1:nE)) < mean(Cn(end-nE+1:end)), Cn = flipud(Cn); end
zz = z - z(1);
Cm = movmedian(Cn, nSmooth);
P.zz = zz;  P.Cn = Cn;  P.Cs = Cm;

% front centre: the C = 0.5 down-crossing with the steepest drop
k50 = find(Cm(1:end-1) >= 0.5 & Cm(2:end) < 0.5);
if isempty(k50)
    P.note = sprintf("C = 0.5 not crossed (Cn range %.2f .. %.2f)", min(Cm), max(Cm));
    return
end
g = -gradient(Cm, zz);
[~, b] = max(g(k50));  k50 = k50(b);

% level crossings, searched outward from the front centre
for p = 1:nP
    zLo = crossDown(zz, Cm, levelPairs(p,1), k50);    % downstream (ahead of the front)
    zHi = crossUp(zz, Cm, levelPairs(p,2), k50);      % upstream (behind the front)
    if isfinite(zLo) && isfinite(zHi), P.W(p) = zLo - zHi; end
end
z10 = crossDown(zz, Cm, 0.1, k50);  z90 = crossUp(zz, Cm, 0.9, k50);
z5  = interpX(zz, Cm, k50, 0.5);
P.frontInside = isfinite(z10) && isfinite(z90);
if ~P.frontInside
    P.note = sprintf("front not inside the core (Cn range %.2f .. %.2f)", min(Cm), max(Cm));
end

% erfc fit (centre and width free), whenever C = 0.5 is crossed (as the first mid-profile fit)
fE = @(b, x) 0.5*erfc((x - b(1))/b(2));
if doErfc
    w0 = NaN;
    for p = 1:nP                                   % first width available -> start value
        if isfinite(P.W(p)), w0 = P.W(p)/P.k(p); break, end
    end
    if ~(isfinite(w0) && w0 > 0), w0 = 0.1*max(zz); end
    try
        [b, ~, ~, CovB] = nlinfit(zz, Cn, fE, [z5, w0]);
        if b(2) > 0, P.z50_erfc = b(1);  P.w_erfc = b(2);  P.dw_erfc = sqrt(CovB(2,2)); end
    catch
        try
            b = fminsearch(@(b) sum((fE(b, zz) - Cn).^2), [z5, w0], optimset('Display','off'));
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
% or, without the fit, z5 +/- 4 w with w from the widest level pair available (w = W/k)
inW = [];
if isfinite(P.w_erfc)
    inW = abs(zz - P.z50_erfc) <= 4*P.w_erfc;
else
    for p = 1:nP                                   % widest pair available, same 4 w margin
        if isfinite(P.W(p)), inW = abs(zz - z5) <= 4*P.W(p)/P.k(p); break, end
    end
end
if ~isempty(inW) && nnz(inW) >= 5
    st = weightedMoments(zz(inW), -gradient(Cm(inW), zz(inW)));
    P.sigma = st.sigma;  P.skew = st.skewness;  P.kurt = st.kurtosis;
end
end

% ========================================================================
function zc = crossDown(z, C, c0, k0)
% first point downstream of index k0 where C falls below c0 (linear interp), NaN if none
zc = NaN;
j = find(C(k0+1:end) < c0, 1);
if isempty(j), return, end
j = k0 + j;                                   % C(j) < c0 <= C(j-1)
zc = interpX(z, C, j-1, c0);
end

function zc = crossUp(z, C, c0, k0)
% last point upstream of index k0 (inclusive) where C is still above c0, NaN if none
zc = NaN;
j = find(C(1:k0) > c0, 1, 'last');
if isempty(j) || j >= numel(C), return, end   % C(j) > c0 >= C(j+1)
zc = interpX(z, C, j, c0);
end

function zc = interpX(z, C, k, c0)
% position of c0 between samples k and k+1
if C(k) == C(k+1), zc = z(k); return, end
zc = z(k) + (C(k) - c0)*(z(k+1) - z(k))/(C(k) - C(k+1));
end