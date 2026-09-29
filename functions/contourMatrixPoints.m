function [xs, ys] = contourMatrixPoints(C)
% CONTOURMATRIXPOINTS  Parse the matrix returned by contourc into flat
% x,y coordinate vectors of the traced contour line(s).
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