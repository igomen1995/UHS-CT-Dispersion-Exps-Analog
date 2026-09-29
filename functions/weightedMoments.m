function stats = weightedMoments(x, w)
% WEIGHTEDMOMENTS  Compute mean, sigma, skewness, and kurtosis of a
% pulse-like weighting function w(x) (e.g. -dC/dz or dC/dt).
%
% x : independent variable (z or t)
% w : weighting function, should be non-negative and pulse-shaped

    w = w(:); x = x(:);
    w(w < 0) = 0;   % guard against noise producing small negative weights

    W = trapz(x, w);
    if W <= 0
        stats = struct('mean',NaN,'sigma',NaN,'skewness',NaN,'kurtosis',NaN);
        return
    end

    x_mean = trapz(x, x.*w) / W;
    m2 = trapz(x, (x-x_mean).^2 .* w) / W;
    m3 = trapz(x, (x-x_mean).^3 .* w) / W;
    m4 = trapz(x, (x-x_mean).^4 .* w) / W;

    sigma = sqrt(m2);
    skewness = m3 / sigma^3;
    kurtosis = m4 / sigma^4;   % ~3 for Gaussian; report raw, not "excess"

    stats.mean = x_mean;
    stats.sigma = sigma;
    stats.skewness = skewness;
    stats.kurtosis = kurtosis;

end
