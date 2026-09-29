function shapeMetrics = getFrontShapeMetrics(frontC)
% GETFRONTSHAPEMETRICS  Quantify front non-planarity via arc length,
% independent of whether the deviation is tilt, waviness, or fingering.
%
%   arcLengthRatio = actual contour arc length / core width (in xD units)
%   ratio = 1.0 exactly for a perfectly flat, piston-like front
%   ratio > 1.0 indicates any kind of non-planar front (tilt, waviness,
%   fingering) — larger values mean more distorted

    if frontC.isEmpty
        shapeMetrics = struct('arcLengthRatio',NaN,'isEmpty',true);
        return
    end
    [xD_sorted, idx] = sort(frontC.xDContour);
    zD_sorted = frontC.zDContour(idx);
    dx = diff(xD_sorted); dz = diff(zD_sorted);
    arcLength = sum(sqrt(dx.^2 + dz.^2));
    coreWidth = max(xD_sorted) - min(xD_sorted);
    shapeMetrics = struct('arcLengthRatio', arcLength/coreWidth, 'isEmpty',false);
end