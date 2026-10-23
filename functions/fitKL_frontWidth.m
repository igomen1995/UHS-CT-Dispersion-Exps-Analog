function KL_width_byPair = fitKL_frontWidth(vars, tCore, variantSuffix, fitWithIntercept, lenScale_cm, KLconv)
% FITKL_FRONTWIDTH  One best-fit KL per symmetric width pair (with its fit
% standard error), from a LINEAR FIT of
%       normWidth2 = (W/lenScale)^2 / (4k^2)   vs   tCore
% pooled across ALL frames -- erfc growth law normWidth2 = (1/NPe)*tD
% (dimensionless) or KL*t (physical).
%
%   tCore        n x 1 time since arrival for every frame (frames with
%                tCore <= 0 are not fitted): tD [-] or t [min]
%   lenScale_cm  L_cm for tD (y dimensionless), 1 for t in min (y in cm^2)
%   KLconv       KL_cm2min = slope*KLconv:  u*L [cm2/min] for tD, 1 for t in min
%   fitWithIntercept  true: y = b0 + b1*t ; false: y = b1*t
%
% Returns per pair: KL_cm2min, KL_cm2min_se, NPe, slope, intercept_cm2,
% R2, nPts and, for plotting, t_all/y_all (all frames), t_fit/y_fit (used),
% y_pred (fitted line at t_fit).
if nargin < 4, fitWithIntercept = false; end
if nargin < 5, lenScale_cm = 1; end
if nargin < 6, KLconv = 1; end

allCols = string(vars.Properties.VariableNames);
if variantSuffix == ""
    pat = '^zDWidth_(\d+)_(\d+)_cm$';
else
    pat = '^zDWidth_(\d+)_(\d+)_xtrim_cm$';
end
matchIdx = find(~cellfun(@isempty, regexp(allCols, pat, 'once')));
tCore = tCore(:);
KL_width_byPair = struct();

for c = matchIdx(:)'
    col = allCols(c);
    tok = regexp(col, pat, 'tokens', 'once');
    Cd_low  = str2double(tok{1})/100;
    Cd_high = str2double(tok{2})/100;
    k = erfcinv(2*Cd_low) - erfcinv(2*Cd_high);

    W = vars.(col) / lenScale_cm;          % W_D if lenScale = L
    normWidth2 = W.^2 ./ (4*k^2);          % = tD/NPe  (or KL*t)

    valid = isfinite(normWidth2) & isfinite(tCore) & tCore > 0;
    t_fit = tCore(valid);
    y_fit = normWidth2(valid);
    pairTag = "C" + tok{1} + "_" + tok{2};

    if numel(t_fit) < 3
        KL_width_byPair.(pairTag) = struct('KL_cm2min',NaN,'KL_cm2min_se',NaN, ...
            'NPe',NaN,'slope',NaN,'intercept_cm2',NaN,'R2',NaN,'nPts',numel(t_fit), ...
            't_all',tCore,'y_all',normWidth2, ...
            't_fit',t_fit,'y_fit',y_fit,'y_pred',nan(size(t_fit)));
        continue
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
    KL_cm2min    = slope    * KLconv;     % width: slope = KL/(uL) = 1/NPe
    KL_cm2min_se = slope_se * KLconv;
    NPe = 1/slope;

    intercept_cm2 = 0;
    if fitWithIntercept, intercept_cm2 = beta(1) * lenScale_cm^2; end   % back to cm^2

    SStot = sum((y_fit - mean(y_fit)).^2);
    R2 = 1 - sum(resid.^2)/SStot;

    KL_width_byPair.(pairTag) = struct('KL_cm2min',KL_cm2min,'KL_cm2min_se',KL_cm2min_se, ...
        'NPe',NPe,'slope',slope,'intercept_cm2',intercept_cm2,'R2',R2,'nPts',numel(t_fit), ...
        't_all',tCore,'y_all',normWidth2, ...
        't_fit',t_fit,'y_fit',y_fit,'y_pred',yPred);
end
end