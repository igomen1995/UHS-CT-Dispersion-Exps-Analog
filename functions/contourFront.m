function out = contourFront(imgSmooth, levels)
% levels    : vector of concentration levels to trace, e.g. [0.1 0.5 0.9]
%
% Returns, per level, the full contour point cloud in pixel and
% dimensionless coordinates. No averaging is done here -- the mean
% position (over the whole image or a restricted xD/zD window) is left
% to the caller, since different callers may want different windows.
imgSmooth = double(imgSmooth);   % contourc requires double
[ny, nx] = size(imgSmooth);
out = struct('level',{},'xContour_px',{},'zContour_px',{}, ...
    'xDContour',{},'zDContour',{},'isEmpty',{});
for i = 1:numel(levels)
    lvl = levels(i);
    C = contourc(imgSmooth, [lvl lvl]);   % pixel-index grid by default
    if isempty(C)
        entry = struct('level',lvl,'xContour_px',[],'zContour_px',[], ...
            'xDContour',[],'zDContour',[],'isEmpty',true);
    else
        [xContour_px, zContour_px] = contourMatrixPoints(C);
        entry = struct( ...
            'level', lvl, ...
            'xContour_px', xContour_px, ...
            'zContour_px', zContour_px, ...
            'xDContour', xContour_px/nx, ...
            'zDContour', zContour_px/ny, ...
            'isEmpty', false);
    end
    out(i) = entry;
end
end

function [xs, ys] = contourMatrixPoints(C)
    xs = [];
    ys = [];
    idx = 1;
    n = size(C,2);
    while idx <= n
        npts = C(2,idx);
        segX = C(1, idx+1 : idx+npts);
        segY = C(2, idx+1 : idx+npts);
        xs = [xs, segX];
        ys = [ys, segY];
        idx = idx + npts + 1;
    end
end