function [lBest, lWin, zCross] = findProfileFrame(vars, zDtarget, CDtarget, variantSuffix, zDwin)
% FINDPROFILEFRAME  Frame(s) whose averaged profile passes through (zD, C) = (zDtarget, CDtarget).
% For every frame the position zCross where CVert<suffix> first crosses CDtarget (along zD,
% from the injection end) is found; the best frame is the one with zCross closest to
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

function pr = getProf(col, l)
if iscell(col), pr = col{l}; elseif istable(col), pr = col(l,:); else, pr = col(l); end
if iscell(pr), pr = pr{1}; end
if isstruct(pr), pr = struct2table(pr); end
end