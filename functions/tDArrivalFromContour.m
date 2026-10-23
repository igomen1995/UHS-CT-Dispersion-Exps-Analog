function [tD_arrival, t_arrival_min] = tDArrivalFromContour(t_min, zDLow, Q, Vtotal)
% TDARRIVALFROMCONTOUR  Empirical arrival time: the first frame at which a
% low concentration-level contour (e.g. C = 0.01) is actually detected,
% converted to dimensionless time on the SAME scale as tDtotal.
%
% t_min  : real elapsed time per frame [min]
% zDLow  : per-frame zD of a low concentration level (NaN where not detected)
% Q      : injection rate [mL/min]
% Vtotal : total pore volume [mL]
arrivalIdx = find(isfinite(zDLow), 1, 'first');
if isempty(arrivalIdx)
    t_arrival_min = NaN;
    tD_arrival = NaN;
    warning('low-level contour never detected; cannot determine arrival.');
    return
end
t_arrival_min = t_min(arrivalIdx);
tD_arrival = t_arrival_min * Q / Vtotal;
end