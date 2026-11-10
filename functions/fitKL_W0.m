function r = fitKL_W0(tau, W, pair)
% FITKL_W0  KL and initial front width from the growth of the front width with time
%   W^2 = W0^2 + 4 k^2 KL tau,    k = erfcinv(2 lo) - erfcinv(2 hi)
% (first ADE term with a finite width W0 at tau = 0, e.g. from spreading before the core;
%  10-90: 2k = 3.625). Ordinary least squares of W^2 vs tau with intercept; also the fit
% through the origin (W0 = 0) for comparison.
%
% INPUTS
%   tau   time since arrival, t - t_arr [min]   (frames with tau <= 0 are left out)
%   W     front width between the two levels [cm]
%   pair  [lo hi], e.g. [0.1 0.9]
%
% OUTPUT r (struct, scalars + the fitted data)
%   n, k, KL_cm2min +/- dKL_cm2min, W0sq_cm2 +/- dW0sq_cm2, W0_cm +/- dW0_cm (NaN if W0^2 < 0),
%   tShift_min = W0^2/(4 k^2 KL): virtual time origin, i.e. the front looks like it started
%   tShift minutes before the arrival, R2;
%   KL0_cm2min +/- dKL0_cm2min, R2_0: fit through the origin; tau, W2: data used

k = erfcinv(2*pair(1)) - erfcinv(2*pair(2));
tau = tau(:);  W = abs(W(:));
ok  = isfinite(tau) & tau > 0 & isfinite(W) & W > 0;
r = struct('n',nnz(ok), 'k',k, 'KL_cm2min',NaN, 'dKL_cm2min',NaN, 'W0sq_cm2',NaN, 'dW0sq_cm2',NaN, ...
    'W0_cm',NaN, 'dW0_cm',NaN, 'tShift_min',NaN, 'R2',NaN, ...
    'KL0_cm2min',NaN, 'dKL0_cm2min',NaN, 'R2_0',NaN, 'tau',tau(ok), 'W2',W(ok).^2);
n = r.n;
if n < 3, return, end
x = tau(ok);  y = W(ok).^2;
c4 = 4*k^2;
SStot = sum((y - mean(y)).^2);

% with intercept: y = b1 + b2 x
X  = [ones(n,1) x];
b  = X \ y;
res = y - X*b;
s2 = sum(res.^2)/(n - 2);
C  = s2 * inv(X'*X); %#ok<MINV>
se = sqrt(diag(C));
r.KL_cm2min  = b(2)/c4;          r.dKL_cm2min = se(2)/c4;
r.W0sq_cm2   = b(1);             r.dW0sq_cm2  = se(1);
if b(1) > 0
    r.W0_cm  = sqrt(b(1));       r.dW0_cm     = se(1)/(2*sqrt(b(1)));
end
if b(2) > 0, r.tShift_min = b(1)/b(2); end
r.R2 = 1 - sum(res.^2)/SStot;

% through the origin: y = b0 x
b0   = (x'*y)/(x'*x);
res0 = y - b0*x;
se0  = sqrt(sum(res0.^2)/(n - 1)/(x'*x));
r.KL0_cm2min  = b0/c4;           r.dKL0_cm2min = se0/c4;
r.R2_0 = 1 - sum(res0.^2)/SStot;
end
