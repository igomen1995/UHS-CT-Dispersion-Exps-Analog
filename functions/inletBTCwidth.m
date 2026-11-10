function b = inletBTCwidth(vars, variantSuffix, pair, zD)
% INLETBTCWIDTH  Times at which the CT breakthrough curve at z_D = zD (default 0, the inlet slice)
% crosses the two levels of `pair` and C = 0.5: column CD1_zD<zD><variantSuffix> (normalized C_D)
% vs secondsElapsed. The curve is cleaned like the F-Phi section (moving median over 5 scans, then
% cummax -> monotonic) and each level time is interpolated between the two scans around it.
%   b.t_lo, b.t_hi, b.t50 [min],  b.dt = t_hi - t_lo [min],  b.col (column used)
% NaN where the curve does not cross a level (e.g. already above it in the first scan).

if nargin < 4 || isempty(zD), zD = 0; end
col = strrep(sprintf('CD1_zD%.1f', zD), '.', 'p') + string(variantSuffix);
b = struct('t_lo',NaN, 't_hi',NaN, 't50',NaN, 'dt',NaN, 'col',col);
if ~ismember(col, string(vars.Properties.VariableNames))
    warning('inletBTCwidth: column %s not found', col);  return
end
t = vars.secondsElapsed/60;  C = vars.(col);
ok = isfinite(t) & isfinite(C);
[t, o] = sort(t(ok));  C = C(ok);  C = C(o);
[t, iu] = unique(t);   C = C(iu);
if numel(t) < 5, return, end
Cs = cummax(movmedian(C, 5));
b.t_lo = crossT(t, Cs, pair(1));
b.t_hi = crossT(t, Cs, pair(2));
b.t50  = crossT(t, Cs, 0.5);
b.dt   = b.t_hi - b.t_lo;
end

function tc = crossT(t, C, lv)
% first time the (monotonic) curve reaches lv, linear interpolation between the scans
tc = NaN;
j = find(C >= lv, 1);
if isempty(j) || j == 1, return, end
tc = t(j-1) + (lv - C(j-1))*(t(j) - t(j-1))/(C(j) - C(j-1));
end
