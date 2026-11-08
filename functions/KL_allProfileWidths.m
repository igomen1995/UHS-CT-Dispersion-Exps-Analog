function [T, S] = KL_allProfileWidths(vars, variantSuffix, levelPair, tArr_min, tArrD, dtArr_min, zDcRange)
% KL_ALLPROFILEWIDTHS  KL from the front width of EVERY frame (not only the mid-core one),
% first ADE term (Lake & Johns / Peters):  KL = W^2/(4 k^2 tau),  k = erfcinv(2 lo) - erfcinv(2 hi)
%   profile : W = zDWidthProf_<lo>_<hi><sfx>_cm   averaged vertical profile (addProfileWidths)
%   contour : W = zDWidth_<lo>_<hi><sfx>_cm       2D contours, same frames (populate_CTframeVars)
% tau = t - t_arr (t_arr = contour arrival); frames with tau <= 0 or no width -> NaN.
%
% Uncertainty, per frame:
%   dKL = KL*sqrt( (2 dW/W)^2 + (dtau/tau)^2 )
%   dW   = dz/sqrt(2): each of the two level crossings is located to +/- dz/2
%          (dz = slice spacing of the profile, zVertcm)
%   dtau = sqrt( (dt/2)^2 + dtArr^2 ): frame time stamp +/- half the frame interval dt
%          (median spacing of secondsElapsed within a run) and the arrival uncertainty
%          dtArr (default dt/2: arrival is detected on a frame)
%
% INPUTS
%   vars          varsAll.(dataSource) with the addProfileWidths columns
%   variantSuffix "" (full image) or "_xtrim"
%   levelPair     [lo hi], e.g. [0.4 0.6]
%   tArr_min      arrival time [min] (same time base as secondsElapsed/60)
%   tArrD         the same arrival as tD_total [-] (only reported)
%   dtArr_min     arrival uncertainty [min]; [] = half the frame interval
%   zDcRange      [min max] zD of the front centre used in the summary (default [0 1])
%
% OUTPUT
%   T  one row per frame: run, rotPos, tDtotal, tD_arrival, tauD, t/tau [min], zD centre
%      (C = 0.5 crossing of the profile and erfc centre), widths [cm, -], KL +/- dKL
%      (profile and contour), inSummary flag
%   S  summary over the frames with a finite KL and the centre inside zDcRange:
%      n, inverse-variance weighted mean +/- its error, mean, std, median (profile and contour)

if nargin < 6, dtArr_min = []; end
if nargin < 7 || isempty(zDcRange), zDcRange = [0 1]; end
sfx = string(variantSuffix);
lo = levelPair(1);  hi = levelPair(2);
tag = sprintf("%02d_%02d", round(100*lo), round(100*hi));
k   = erfcinv(2*lo) - erfcinv(2*hi);
n   = height(vars);
vn  = string(vars.Properties.VariableNames);

colP = "zDWidthProf_" + tag + sfx + "_cm";
if ~ismember(colP, vn)
    error('KL_allProfileWidths: column %s missing -- run addProfileWidths with the pair [%g %g]', colP, lo, hi);
end
WP = abs(vars.(colP));
WPD = abs(vars.("zDWidthProf_" + tag + sfx));
colC = "zDWidth_" + tag + sfx + "_cm";
if ismember(colC, vn), WC = abs(vars.(colC)); else, WC = nan(n,1); end

% run number and rotation position
if ismember("runName", vn)
    runStr = string(vars.runName);
    run = str2double(regexprep(runStr, '\D', ''));
else
    runStr = strings(n,1);  run = nan(n,1);
end
if ismember("rotPos", vn), rotPos = vars.rotPos; else, rotPos = nan(n,1); end

% times
t_min = vars.secondsElapsed/60;
tau   = t_min - tArr_min;  tau(~(tau > 0)) = NaN;
tDtot = vars.tDtotal;
tauD  = tDtot - tArrD;     tauD(~(tauD > 0)) = NaN;

% frame interval (median spacing inside each run)
dtAll = [];
for r = unique(runStr)'
    tr = sort(t_min(runStr == r));
    dtAll = [dtAll; diff(tr)]; %#ok<AGROW>
end
dtAll = dtAll(dtAll > 0);
if isempty(dtAll), dtFrame = NaN; else, dtFrame = median(dtAll); end
if isempty(dtArr_min), dtArr_min = dtFrame/2; end
dtau = sqrt((dtFrame/2)^2 + dtArr_min^2);

% front centre and slice spacing of each profile
[~, ~, zC50] = findProfileFrame(vars, 0.5, 0.5, sfx, 0);    % zD of the C = 0.5 crossing
zErfcCol = "zDFrontProf50" + sfx;
if ismember(zErfcCol, vn), zErfc = vars.(zErfcCol); else, zErfc = nan(n,1); end
dz = nan(n,1);
for l = 1:n
    pr = getProf(vars.C1Profile, l);
    if isempty(pr) || ~ismember("zVertcm", string(pr.Properties.VariableNames)), continue, end
    zz = sort(pr.zVertcm(isfinite(pr.zVertcm)));
    if numel(zz) > 1, dz(l) = median(diff(zz)); end
end
dW = dz/sqrt(2);

% KL +/- dKL
KLP  = WP.^2 ./ (4*k^2*tau);
dKLP = KLP .* sqrt((2*dW./WP).^2 + (dtau./tau).^2);
KLC  = WC.^2 ./ (4*k^2*tau);
dKLC = KLC .* sqrt((2*dW./WC).^2 + (dtau./tau).^2);

inS = isfinite(KLP) & KLP > 0 & zC50 >= zDcRange(1) & zC50 <= zDcRange(2);

T = table(run, runStr, rotPos, tDtot, repmat(tArrD,n,1), tauD, t_min, tau, zC50, zErfc, ...
    WP, WPD, dW, KLP, dKLP, WC, KLC, dKLC, inS, ...
    'VariableNames', {'run','runName','rotPos_deg','tDtotal','tD_arrival','tauD', ...
    't_min','tau_min','zD_center_C50','zD_center_erfc', ...
    char("W_prof_" + tag + "_cm"), char("WD_prof_" + tag), 'dW_cm', ...
    char("KL_prof_" + tag + "_cm2min"), char("dKL_prof_" + tag + "_cm2min"), ...
    char("W_cont_" + tag + "_cm"), char("KL_cont_" + tag + "_cm2min"), char("dKL_cont_" + tag + "_cm2min"), ...
    'inSummary'});
T = T(isfinite(WP) | isfinite(WC), :);                  % frames with a width only
T = sortrows(T, 'tDtotal');

S = struct('levelPair',levelPair, 'variant',sfx, 'tArr_min',tArr_min, 'tD_arrival',tArrD, ...
    'dtFrame_min',dtFrame, 'dtArr_min',dtArr_min, 'zDcRange',zDcRange);
S.prof = summ(KLP(inS), dKLP(inS));
okC = isfinite(KLC) & KLC > 0 & zC50 >= zDcRange(1) & zC50 <= zDcRange(2);
S.cont = summ(KLC(okC), dKLC(okC));
end

% ========================================================================
function s = summ(v, dv)
s = struct('n',numel(v), 'KL_wmean',NaN, 'dKL_wmean',NaN, 'KL_mean',NaN, 'KL_std',NaN, 'KL_median',NaN);
if isempty(v), return, end
s.KL_mean = mean(v);  s.KL_std = std(v);  s.KL_median = median(v);
okw = isfinite(dv) & dv > 0;
if any(okw)
    wgt = 1./dv(okw).^2;
    s.KL_wmean  = sum(wgt.*v(okw))/sum(wgt);
    s.dKL_wmean = max(1/sqrt(sum(wgt)), s.KL_std/sqrt(numel(v)));   % not below the scatter
end
end

function pr = getProf(col, l)
if iscell(col), pr = col{l}; elseif istable(col), pr = col(l,:); else, pr = col(l); end
if iscell(pr), pr = pr{1}; end
if isstruct(pr), pr = struct2table(pr); end
end
