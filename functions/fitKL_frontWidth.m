function KL_width_byPair = fitKL_frontWidth(vars, t_arrival_min, variantSuffix, fitWithIntercept)
% FITKL_FRONTWIDTH  One best-fit KL per symmetric width pair (with its fit
% standard error), from a LINEAR FIT of normWidth2 = W_cm^2/(4k^2) vs
% t_core_min (time since arrival) pooled across ALL frames -- matches the
% erfc growth law normWidth2 = KL*t.
%
% fitWithIntercept: true allows a small intercept; false (default) forces
% the fit through the origin.
%
% Returns, per pair: KL_cm2min (best fit), KL_cm2min_se (fit standard
% error), intercept_cm2, R2, nPts.

if nargin < 4, fitWithIntercept = false; end

allCols = string(vars.Properties.VariableNames);
if variantSuffix == ""
    pat = '^zDWidth_(\d+)_(\d+)_cm$';
else
    pat = '^zDWidth_(\d+)_(\d+)_xtrim_cm$';
end
matchIdx = find(~cellfun(@isempty, regexp(allCols, pat, 'once')));

t_core_min = max(vars.secondsElapsed/60 - t_arrival_min, 0);

KL_width_byPair = struct();
for c = matchIdx(:)'
    col = allCols(c);
    tok = regexp(col, pat, 'tokens', 'once');
    Cd_low  = str2double(tok{1})/100;
    Cd_high = str2double(tok{2})/100;
    k = erfcinv(2*Cd_low) - erfcinv(2*Cd_high);

    W_cm = vars.(col);
    normWidth2 = W_cm.^2 ./ (4*k^2);   % = KL*t (no factor of 2 here)

    valid = isfinite(normWidth2) & isfinite(t_core_min) & t_core_min > 0;
    t_fit = t_core_min(valid);
    y_fit = normWidth2(valid);

    pairTag = "C" + tok{1} + "_" + tok{2};

    if numel(t_fit) < 3
        KL_width_byPair.(pairTag) = struct('KL_cm2min',NaN,'KL_cm2min_se',NaN, ...
            'intercept_cm2',NaN,'R2',NaN,'nPts',numel(t_fit));
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
    if dof > 0
        sigma2_resid = sum(resid.^2)/dof;
    end
    covBeta = sigma2_resid * inv(X'*X); %#ok<MINV>

    KL_cm2min    = beta(end);              % slope = KL directly
    KL_cm2min_se = sqrt(covBeta(end,end));

    intercept_cm2 = 0;
    if fitWithIntercept, intercept_cm2 = beta(1); end

    SStot = sum((y_fit - mean(y_fit)).^2);
    R2 = 1 - sum(resid.^2)/SStot;

    KL_width_byPair.(pairTag) = struct('KL_cm2min',KL_cm2min,'KL_cm2min_se',KL_cm2min_se, ...
        'intercept_cm2',intercept_cm2,'R2',R2,'nPts',numel(t_fit));
end
end