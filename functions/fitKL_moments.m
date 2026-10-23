function KL_sigma_fit = fitKL_moments(vars, tCore, variantSuffix, fitWithIntercept, lenScale_cm, KLconv)
% FITKL_MOMENTS  ONE best-fit KL (with its fit standard error), from a
% LINEAR FIT of the spatial variance (sigma/lenScale)^2 of the vertical
% concentration profile vs tCore, pooled across ALL frames -- growth law
% sigma_D^2 = 2*tD/NPe (dimensionless) or sigma^2 = 2*KL*t (physical).
%
%   tCore        n x 1 time since arrival for every frame (tCore <= 0 not fitted)
%   lenScale_cm  L_cm for tD (y dimensionless), 1 for t in min (y in cm^2)
%   KLconv       KL_cm2min = (slope/2)*KLconv: u*L [cm2/min] for tD, 1 for min
if nargin < 4, fitWithIntercept = false; end
if nargin < 5, lenScale_cm = 1; end
if nargin < 6, KLconv = 1; end

n = height(vars);
tCore = tCore(:);
sigma2_all = nan(n,1);
profField = "CVert" + variantSuffix;

for r = 1:n
    if iscell(vars.C1Profile)
        prof = vars.C1Profile{r};
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
    if isempty(Cvert) || all(isnan(Cvert)) || ~(tCore(r) > 0)
        continue
    end
    w = -gradient(Cvert, zVertcm);
    w(w<0) = 0;
    if sum(w) <= 0, continue, end

    stats = weightedMoments(zVertcm, w);
    sigma2_all(r) = (stats.sigma / lenScale_cm)^2;     % sigma_D^2 if lenScale = L
end

valid = isfinite(sigma2_all) & isfinite(tCore) & tCore > 0;
t_fit = tCore(valid);
y_fit = sigma2_all(valid);

if numel(t_fit) < 3
    KL_sigma_fit = struct('KL_cm2min',NaN,'KL_cm2min_se',NaN,'NPe',NaN,'slope',NaN, ...
        'intercept_cm2',NaN,'R2',NaN,'nPts',numel(t_fit), ...
        't_all',tCore,'y_all',sigma2_all, ...
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
if dof > 0, sigma2_resid = sum(resid.^2)/dof; end
covBeta = sigma2_resid * inv(X'*X); %#ok<MINV>

slope    = beta(end);
slope_se = sqrt(covBeta(end,end));
KL_cm2min    = slope/2    * KLconv;     % sigma: slope = 2/NPe
KL_cm2min_se = slope_se/2 * KLconv;
NPe = 2/slope;

intercept_cm2 = 0;
if fitWithIntercept, intercept_cm2 = beta(1) * lenScale_cm^2; end

SStot = sum((y_fit - mean(y_fit)).^2);
R2 = 1 - sum(resid.^2)/SStot;

KL_sigma_fit = struct('KL_cm2min',KL_cm2min,'KL_cm2min_se',KL_cm2min_se, ...
    'NPe',NPe,'slope',slope,'intercept_cm2',intercept_cm2,'R2',R2,'nPts',numel(t_fit), ...
    't_all',tCore,'y_all',sigma2_all, ...
    't_fit',t_fit,'y_fit',y_fit,'y_pred',yPred);
end