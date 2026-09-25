function z = frontZmean(image, lo, hi, resYmm)
    idx = (image>=lo & image<=hi);
    [rows,~] = find(idx);
    if ~isempty(rows)
        z = mean(rows)*resYmm/10;
    else
        z = NaN;
    end
end