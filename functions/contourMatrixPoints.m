function [xs, ys] = contourMatrixPoints(C)
% CONTOURMATRIXPOINTS  Parse the matrix returned by contourc into flat
% x,y coordinate vectors of the traced contour line(s).
    xs = [];
    ys = [];
    idx = 1;
    n = size(C,2);
    firstSeg = true;
    while idx <= n
        npts = C(2,idx);
        segX = C(1, idx+1 : idx+npts);
        segY = C(2, idx+1 : idx+npts);
        if ~firstSeg
            xs = [xs, NaN, segX];   % NaN break before each new segment
            ys = [ys, NaN, segY];
        else
            xs = [xs, segX];
            ys = [ys, segY];
            firstSeg = false;
        end
        idx = idx + npts + 1;
    end
end