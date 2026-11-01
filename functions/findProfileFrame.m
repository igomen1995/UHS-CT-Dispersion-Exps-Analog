function [lBest, lWin, zCross] = findProfileFrame(vars, zDtarget, CDtarget, variantSuffix, zDwin)
% FINDPROFILEFRAME  Frame(s) whose averaged profile passes through (zD, C) = (zDtarget, CDtarget).
% For every frame the position zCross where CVert<suffix> crosses CDtarget at the front
% (steepest crossing, end slices ignored) is found; the best frame is the one with zCross closest to
% zDtarget, the window frames those with |zCross - zDtarget| <= zDwin.
% Used by main_CTplots (profile through a target point) and KL_profileAt (KL at fixed time).
%
%   lBest   index of the closest frame (NaN if no profile crosses CDtarget)
%   lWin    indices of all frames inside the window (always contains lBest)
%   zCross  zD of the CDtarget crossing for every frame (NaN where not crossed)

if nargin < 4 || isempty(variantSuffix), variantSuffix = ""; end
if nargin < 5 || isempty(zDwin), zDwin = 0; end
cCol = "CVert" + variantSuffix;
n = height(vars);
zCross = nan(n,1);
for l = 1:n
    pr = getProf(vars.C1Profile, l);
    if isempty(pr) || ~ismember(cCol, string(pr.Properties.VariableNames)), continue, end
    zCross(l) = firstCrossing(pr.zDimLess, pr.(cCol), CDtarget);
end
lBest = NaN;  lWin = [];
if all(~isfinite(zCross)), return, end
d = abs(zCross - zDtarget);
[~, lBest] = min(d);
lWin = find(d <= zDwin);
if ~ismember(lBest, lWin), lWin = sort([lWin; lBest]); end
end

function zc = firstCrossing(zD, C, c0)
% crossing of c0 along zD with the steepest slope (the front), ignoring 2 % of the core
% at each end (edge slices often hold 0 / garbage); NaN if C never crosses c0
zc = NaN;
ok = isfinite(zD) & isfinite(C);  zD = zD(ok);  C = C(ok);
if numel(zD) < 5, return, end
[zD, o] = sort(zD);  C = C(o);
L  = zD(end) - zD(1);
in = zD >= zD(1) + 0.02*L & zD <= zD(end) - 0.02*L;
zD = zD(in);  C = movmedian(C(in), 5);
d  = C - c0;
k  = find(d(1:end-1).*d(2:end) <= 0 & d(1:end-1) ~= d(2:end));
if isempty(k), return, end
g  = abs(gradient(C, zD));
[~, b] = max(g(k));  k = k(b);
zc = zD(k) - d(k)*(zD(k+1) - zD(k))/(d(k+1) - d(k));
end

function pr = getProf(col, l)
if iscell(col), pr = col{l}; elseif istable(col), pr = col(l,:); else, pr = col(l); end
if iscell(pr), pr = pr{1}; end
if isstruct(pr), pr = struct2table(pr); end
end