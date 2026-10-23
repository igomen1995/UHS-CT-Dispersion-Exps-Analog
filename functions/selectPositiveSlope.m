function [keep, pQuad, t_vertex] = selectPositiveSlope(t, y, minPts)
% SELECTPOSITIVESLOPE  Fit y = p1*t^2 + p2*t + p3 and keep the points on the
% branch where dy/dt > 0 (same logic as fitAndPlotPooled in main_CTplots).
%   keep      logical mask (same size as t)
%   pQuad     [p1 p2 p3] (NaN if not enough points)
%   t_vertex  vertex of the parabola, -p2/(2*p1) (NaN / -Inf if not defined)
if nargin < 3, minPts = 5; end
keep = true(size(t));  pQuad = nan(1,3);  t_vertex = NaN;
if numel(t) < max(minPts, 3), return, end

pQuad = polyfit(t, y, 2);
if pQuad(1) == 0                      % linear: positive slope everywhere or nowhere
    t_vertex = -Inf;
    if pQuad(2) <= 0, keep(:) = false; end
    return
end
t_vertex = -pQuad(2) / (2*pQuad(1));
if pQuad(1) > 0
    keep = t > t_vertex;              % convex: rising after the vertex
else
    keep = t < t_vertex;              % concave: rising before the vertex
end
end