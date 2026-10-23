function frontVel = frontVel(t_min, z_cm, zD)
% FRONTVEL  Measured front velocity from a linear fit of physical front
% position (z_cm) vs physical time (t_min), over the window where the
% front is clearly inside the core (0.03 < zD < 0.97) -- avoids the
% pre-arrival plateau and the outlet plateau after breakthrough.

valid = isfinite(t_min) & isfinite(z_cm) & zD > 0.03 & zD < 0.97;
tfit = t_min(valid);
zfit = z_cm(valid);

frontVel = struct('v_front_cmmin', NaN, 'intercept_cm', NaN, 'R2', NaN, 'nValidPts', nnz(valid));

if nnz(valid) < 5
    warning('fewer than 5 points in the 0.03-0.97 zD window, skipping front-velocity fit.');
    return
end

p = polyfit(tfit, zfit, 1);
zhat = polyval(p, tfit);

frontVel.intercept_cm  = p(2);
frontVel.v_front_cmmin = p(1);
frontVel.R2            = 1 - sum((zfit - zhat).^2) / sum((zfit - mean(zfit)).^2);

end