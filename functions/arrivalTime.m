function [tArr, src] = arrivalTime(ctData, fd, ds, ref)
% arrival time [min] of one experiment / data source:
%   "levels"  arrival from the level trajectories, stored by the arrival-levels section of
%             main_CTpostproc (resultsAll.(ds).tArr_levels_min; default: averaged profile, C = 0.01,
%             time its per-level ADE curve is at z = 0)
%   "C50"     t0 = -b/v of the C = 0.5 front-centre line (resultsAll.(ds).vFront of main_CTpreproc;
%             fallback: t0_C50line_min stored by main_CTpostproc)
%   "contour" first C = 0.01 contour (resultsAll.(ds).tD_arrival_contour, tD = Q t / V_total)
%   "lines"   line volume before the core / Q
% fallback: levels -> C50 -> contour -> lines (with a warning); src = arrival actually used
ref  = string(ref);
tL   = fd.Vlinesbefore/fd.Q;
tC   = NaN;  t50 = NaN;  tLv = NaN;  lvTag = "levels";
if isfield(ctData, 'resultsAll') && isfield(ctData.resultsAll, ds)
    rA = ctData.resultsAll.(ds);
    if isfield(rA, 'tD_arrival_contour') && isfinite(rA.tD_arrival_contour)
        tC = rA.tD_arrival_contour*fd.Vtotal/fd.Q;
    end
    if isfield(rA, 'vFront') && isstruct(rA.vFront) && isfinite(rA.vFront.v_front_cmmin) && rA.vFront.v_front_cmmin > 0
        t50 = -rA.vFront.intercept_cm/rA.vFront.v_front_cmmin;
    elseif isfield(rA, 't0_C50line_min') && isfinite(rA.t0_C50line_min)
        t50 = rA.t0_C50line_min;
    end
    if isfield(rA, 'tArr_levels_min') && isfinite(rA.tArr_levels_min)
        tLv = rA.tArr_levels_min;
        if isfield(rA, 'tArr_levels_ref'), lvTag = "levels_" + string(rA.tArr_levels_ref); end
    end
end
switch ref
    case "levels",  tArr = tLv;  src = lvTag;
    case "C50",     tArr = t50;  src = "C50";
    case "contour", tArr = tC;   src = "contour";
    case "lines",   tArr = tL;   src = "lines";
    otherwise,      error('arrivalTime: unknown reference "%s" (levels | C50 | contour | lines)', ref);
end
if ~isfinite(tArr) && startsWith(src, "levels")
    warning('%s (%s): no stored level arrival (run the arrival-levels section of main_CTpostproc) -> C50 line', fd.Key, ds);
    tArr = t50;  src = "C50";
end
if ~isfinite(tArr) && src == "C50"
    warning('%s (%s): no C = 0.5 front line -> contour arrival', fd.Key, ds);
    tArr = tC;  src = "contour";
end
if ~isfinite(tArr) && src == "contour"
    warning('%s (%s): no contour arrival -> line volume', fd.Key, ds);
    tArr = tL;  src = "lines";
end
end
