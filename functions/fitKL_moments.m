function KL_sigma_fit = fitKL_moments(vars, t_arrival_min, variantSuffix, fitWithIntercept)
% FITKL_MOMENTS  ONE best-fit KL (with its fit standard error), from a
% LINEAR FIT of the spatial variance sigma^2 (cm^2) of the vertical
% concentration profile vs t_core_min (time since arrival), pooled across
% ALL frames -- matches the diffusive growth law sigma^2 = 2*KL*t.
%
% Also returns, for plotting:
%   t_all, y_all   every frame (time since arrival, sigma^2)
%   t_fit, y_fit   frames used in the fit
%   y_pred         fitted line at t_fit
if nargin < 4, fitWithIntercept = false; end
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
    if ~hasField
        continue
    end
    zVertcm = prof.zVertcm;
    Cvert   = prof.(profField);
    if isempty(Cvert) || all(isnan(Cvert)) || t_core_min(r) <= 0
        continue
    end
    w = -gradient(Cvert, zVertcm);
    w(w<0) = 0;
    if sum(w) <= 0
        continue
    end
    stats = weightedMoments(zVertcm, w);
    sigma2_all(r) = stats.sigma^2;
end
valid = isfinite(sigma2_all) & isfinite(t_core_min) & t_core_min > 0;
t_fit = t_core_min(valid);
y_fit = sigma2_all(valid);
if numel(t_fit) < 3
    KL_sigma_fit = struct('KL_cm2min',NaN,'KL_cm2min_se',NaN,'intercept_cm2',NaN,'R2',NaN,'nPts',numel(t_fit), ...
        't_all',t_core_min,'y_all',sigma2_all, ...
        't_fit',t_fit,'y_fit',y_fit,'y_pred',nan(size(t_fit)));
    return
end
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
if dof > 0
    sigma2_resid = sum(resid.^2)/dof;
end
covBeta = sigma2_resid * inv(X'*X); %#ok<MINV>
slope    = beta(end);
slope_se = sqrt(covBeta(end,end));
KL_cm2min    = slope/2;
KL_cm2min_se = slope_se/2;
intercept_cm2 = 0;
if fitWithIntercept, intercept_cm2 = beta(1); end
SStot = sum((y_fit - mean(y_fit)).^2);
R2 = 1 - sum(resid.^2)/SStot;
KL_sigma_fit = struct('KL_cm2min',KL_cm2min,'KL_cm2min_se',KL_cm2min_se, ...
    'intercept_cm2',intercept_cm2,'R2',R2,'nPts',numel(t_fit), ...
    't_all',t_core_min,'y_all',sigma2_all, ...
    't_fit',t_fit,'y_fit',y_fit,'y_pred',yPred);
end