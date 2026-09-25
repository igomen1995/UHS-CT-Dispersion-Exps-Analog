function [zMean, xFront_cm, zFront_cm] = front50Evol(image, lo, hi, resXmm, resYmm)
    idx = (image>=lo & image<=hi);
    [rows, cols] = find(idx);
    if ~isempty(rows)
        xFront_cm = cols*resXmm/10;
        zFront_cm = rows*resYmm/10;
        zMean = mean(rows)*resYmm/10;
    else
        xFront_cm = [];
        zFront_cm = [];
        zMean = NaN;
    end
end