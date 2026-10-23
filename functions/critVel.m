function u_crit_cmmin = critVel(K_mD, rho1, rho2, mu1, mu2, theta_deg)
% CRITVEL  Gravity/viscous-stabilization critical velocity.
% K_mD: permeability [mD]. rho1, rho2: densities [kg/m^3]. mu1, mu2:
% viscosities [Pa.s]. theta_deg: tilt from horizontal [deg].
% rho1/mu1 = displacing fluid, rho2/mu2 = displaced fluid

K_m2 = K_mD * 9.86923e-16;      % mD -> m^2
M = mu2/mu1;                     % viscosity ratio, displacing/displaced
mu_mix = ((0.5*mu1^(-1/4)) + 0.5*mu2^(-1/4))^(-4);

u_crit_ms = K_m2*(rho2-rho1)*9.8*sind(theta_deg) / (mu_mix*(M-1));
u_crit_cmmin = u_crit_ms*60*100;   % m/s -> cm/min

end