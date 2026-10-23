function KL_sigma_fit = fitKL_moments(vars, t_arrival_min, variantSuffix, fitWithIntercept)
% FITKL_MOMENTS  One KL from the spatial variance sigma^2 (cm^2) of the vertical
% concentration profile vs t_core_min (time since arrival) -- sigma^2 = 2*KL*t.
%
%   1) frames with a valid profile and t_core > 0
%   2) positive-slope selection (selectPositiveSlope, as in main_CTplots)
%   3) linear regression on the selected frames -> KL = slope/2 +/- se/2
%   4) pointwise KL_i = (y_i - b0)/(2*t_i) on the selected frames -> mean, std
if nargin < 4, fitWithIntercept = false; end
minPtsSel = 5;

n = height(vars);
sigma2_all = nan(n,1);
t_core_min = max(vars.secondsElapsed/60 - t_arrival_min, 0);
profField = "CVert" + variantSuffix;

for r = 1:n
    if iscell(vars.C1Profile)
        prof = vars.C1Profile{r};   % {} unwraps the cell -- (r) alone returns a 1x1 cell
    else
        prof = vars.C1Profile(r);
    end
    if istable(prof)
        hasField = ismember(profField, string(prof.Properties.VariableNames));
    else
        hasField = isfield(prof, profField) || isprop(prof, profField);
    end
    if ~hasField, continue, end

    zVertcm = prof.zVertcm;
    Cvert   = prof.(profField);
    if isempty(Cvert) || all(isnan(Cvert)) || t_core_min(r) <= 0
        continue
    end
    w = -gradient(Cvert, zVertcm);
    w(w<0) = 0;
    if sum(w) <= 0, continue, end

    stats = weightedMoments(zVertcm, w);
    sigma2_all(r) = stats.sigma^2;
end

% 1) valid frames
valid = isfinite(sigma2_all) & isfinite(t_core_min) & t_core_min > 0;
t_v = t_core_min(valid);
y_v = sigma2_all(valid);

% 2) rising branch only
[keep, pQuad, t_vertex] = selectPositiveSlope(t_v, y_v, minPtsSel);
t_fit = t_v(keep);
y_fit = y_v(keep);

KL_sigma_fit = struct('KL_cm2min',NaN,'KL_cm2min_se',NaN,'intercept_cm2',NaN,'R2',NaN, ...
    'nPts',numel(t_fit),'nValid',numel(t_v), ...
    'KL_mean',NaN,'KL_std',NaN,'KL_pts',nan(size(t_fit)), ...
    'pQuad',pQuad,'t_vertex',t_vertex, ...
    't_all',t_core_min,'y_all',sigma2_all, ...
    't_fit',t_fit,'y_fit',y_fit,'y_pred',nan(size(t_fit)));

if numel(t_fit) < minPtsSel
    return
end

% 3) linear regression
if fitWithIntercept
    X = [ones(size(t_fit)), t_fit];
else
    X = t_fit;
end
beta  = X \ y_fit;
yPred = X*beta;
resid = y_fit - yPred;
dof   = numel(t_fit) - size(X,2);
sigma2_resid = NaN;
if dof > 0, sigma2_resid = sum(resid.^2)/dof; end
covBeta = sigma2_resid * inv(X'*X); %#ok<MINV>

intercept_cm2 = 0;
if fitWithIntercept, intercept_cm2 = beta(1); end
SStot = sum((y_fit - mean(y_fit)).^2);

KL_sigma_fit.KL_cm2min     = beta(end)/2;
KL_sigma_fit.KL_cm2min_se  = sqrt(covBeta(end,end))/2;
KL_sigma_fit.intercept_cm2 = intercept_cm2;
KL_sigma_fit.R2            = 1 - sum(resid.^2)/SStot;
KL_sigma_fit.y_pred        = yPred;

% 4) pointwise KL on the selected frames
KL_sigma_fit.KL_pts  = (y_fit - intercept_cm2) ./ (2*t_fit);
KL_sigma_fit.KL_mean = mean(KL_sigma_fit.KL_pts, 'omitnan');
KL_sigma_fit.KL_std  = std(KL_sigma_fit.KL_pts, 'omitnan');
end