function KL_width_byPair = fitKL_frontWidth(vars, t_arrival_min, variantSuffix, fitWithIntercept)
% FITKL_FRONTWIDTH  One KL per symmetric width pair from normWidth2 = W^2/(4k^2)
% vs t_core_min (time since arrival) -- erfc growth law normWidth2 = KL*t.
%
%   1) frames with finite width and t_core > 0
%   2) positive-slope selection: quadratic fit, keep the rising branch
%      (selectPositiveSlope, as in main_CTplots)
%   3) linear regression on the selected frames -> KL_cm2min +/- KL_cm2min_se
%   4) pointwise KL_i = (y_i - b0)/t_i on the selected frames -> mean, std
%
% Returns per pair: KL_cm2min, KL_cm2min_se, intercept_cm2, R2, nPts (selected),
% nValid, KL_mean, KL_std, KL_pts, pQuad, t_vertex, and for plotting
% t_all/y_all (every frame), t_fit/y_fit (selected), y_pred.
if nargin < 4, fitWithIntercept = false; end
minPtsSel = 5;

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
    pairTag = "C" + tok{1} + "_" + tok{2};

    % 1) valid frames
    valid = isfinite(normWidth2) & isfinite(t_core_min) & t_core_min > 0;
    t_v = t_core_min(valid);
    y_v = normWidth2(valid);

    % 2) rising branch only
    [keep, pQuad, t_vertex] = selectPositiveSlope(t_v, y_v, minPtsSel);
    t_fit = t_v(keep);
    y_fit = y_v(keep);

    out = struct('KL_cm2min',NaN,'KL_cm2min_se',NaN,'intercept_cm2',NaN,'R2',NaN, ...
        'nPts',numel(t_fit),'nValid',numel(t_v), ...
        'KL_mean',NaN,'KL_std',NaN,'KL_pts',nan(size(t_fit)), ...
        'pQuad',pQuad,'t_vertex',t_vertex, ...
        't_all',t_core_min,'y_all',normWidth2, ...
        't_fit',t_fit,'y_fit',y_fit,'y_pred',nan(size(t_fit)));

    if numel(t_fit) < minPtsSel
        KL_width_byPair.(pairTag) = out;
        continue
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

    out.KL_cm2min     = beta(end);                 % slope = KL directly
    out.KL_cm2min_se  = sqrt(covBeta(end,end));
    out.intercept_cm2 = intercept_cm2;
    out.R2            = 1 - sum(resid.^2)/SStot;
    out.y_pred        = yPred;

    % 4) pointwise KL on the selected frames
    out.KL_pts  = (y_fit - intercept_cm2) ./ t_fit;
    out.KL_mean = mean(out.KL_pts, 'omitnan');
    out.KL_std  = std(out.KL_pts, 'omitnan');

    KL_width_byPair.(pairTag) = out;
end
end