function [KL_BTC_byZD, fitDetailByZD] = fitKL_BTC_allLevels(vars, variantSuffix, u_ms, Cj, Ci, L_core_m, dt_guess, Cmin, Cmax)
% FITKL_BTC_ALLLEVELS  Loops the fixed spatial grid zD = 0.1:0.1:1.0
% (zD=0 excluded -- L_zD=0 is degenerate), builds the BTC at that
% position from CD1_zDXpY(+variantSuffix), and fits KL via
% fitBTC_KL_allMethods using the NOMINAL velocity u_ms (consistent with
% tDtotal, NOT the measured front velocity) and L_zD = zD*L_core_m as the
% transport distance.

zDgrid = 0.1:0.1:1.0;
minPts = 5;

t_sec = vars.secondsElapsed;
dC    = vars.dConc_std;

KL_BTC_byZD   = nan(numel(zDgrid),1);
fitDetailByZD = cell(numel(zDgrid),1);

for iz = 1:numel(zDgrid)
    zD = zDgrid(iz);
    tag = strrep(sprintf('%.1f', zD), '.', 'p');
    colName = "CD1_zD" + tag + variantSuffix;

    if ~ismember(colName, string(vars.Properties.VariableNames))
        warning('Column %s not found, skipping zD=%.1f', colName, zD);
        continue
    end

    C_vals  = vars.(colName);
    t_vals  = t_sec;
    dC_vals = dC;

    good = ~isnan(C_vals) & ~isnan(t_vals) & ~isnan(dC_vals);
    C_vals  = C_vals(good);
    t_vals  = t_vals(good);
    dC_vals = dC_vals(good);

    [t_vals, ord] = sort(t_vals);
    C_vals  = C_vals(ord);
    dC_vals = dC_vals(ord);

    if numel(C_vals) < minPts
        continue
    end

    % checkBTCComplete's signature is (C,t,tD,Cmin,Cmax,minPts) and it
    % NaN-filters on C/t only then sorts by t -- we already did exactly
    % that above, so pass t_vals in the "tD" slot too (unused by
    % fitBTC_KL_allMethods) just to get the completeness gate as a no-op
    % filter, and keep dC_vals aligned with the (unchanged) result.
    [isComplete, C_c, t_c] = checkBTCComplete(C_vals, t_vals, t_vals, Cmin, Cmax, minPts);
    if ~isComplete
        continue
    end
    dC_c = dC_vals;   % unchanged by the no-op filter above

    L_zD_m = zD * L_core_m;

    fitResult = fitBTC_KL_allMethods(t_c, C_c, dC_c, u_ms, Cj, Ci, L_zD_m, dt_guess, Cmin, Cmax);

    best = fitResult.best_row;
    KL_BTC_byZD(iz) = best.KL_cm2min;
    fitDetailByZD{iz} = struct('fitResult', fitResult, 't_c', t_c, 'C_c', C_c);
end
end