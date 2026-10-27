function [interpFcn, interpFcn_Tplus, interpFcn_Tminus, interpFcn_Pplus, interpFcn_Pminus] = ...
    buildInterpolant(fluid1, fluid2, T_C, P_psig, dT_C, dP_psig)
% BUILDINTERPOLANT  CT_norm (rho_norm) -> x1 interpolant from REFPROP mixture
% densities, plus four perturbed versions (T+dT, T-dT, P+dP, P-dP) for
% finite-difference uncertainty propagation (same convention as
% main_fluidProps_errorProp.m).
%
%   interpFcn = buildInterpolant(fluid1, fluid2, T_C, P_psig)
%   [interpFcn, iTp, iTm, iPp, iPm] = buildInterpolant(fluid1, fluid2, T_C, P_psig, dT_C, dP_psig)
%
%   T_C, P_psig    temperature [C] and pressure [psig]; vectors are averaged
%   dT_C, dP_psig  one-std perturbations (default 0 -> perturbed = nominal)
%
%   The perturbed interpolants are only built when they are requested
%   (nargout > 1), so the 4-input call costs one REFPROP sweep only.

if nargin < 5 || isempty(dT_C),    dT_C    = 0; end
if nargin < 6 || isempty(dP_psig), dP_psig = 0; end

persistent RP
if isempty(RP)
    RP = initREFPROP();
end

fluid1 = char(fluid1);
fluid2 = char(fluid2);

T_K_mean   = mean(T_C, 'omitnan') + 273.15;
P_kPa_mean = (mean(P_psig, 'omitnan') + 14.696)*6.89476;
dP_kPa     = dP_psig*6.89476;                 % a pressure difference: no atmospheric offset

interpFcn = local_buildOne(RP, fluid1, fluid2, T_K_mean, P_kPa_mean);

if nargout > 1
    if dT_C == 0
        interpFcn_Tplus  = interpFcn;
        interpFcn_Tminus = interpFcn;
    else
        interpFcn_Tplus  = local_buildOne(RP, fluid1, fluid2, T_K_mean + dT_C, P_kPa_mean);
        interpFcn_Tminus = local_buildOne(RP, fluid1, fluid2, T_K_mean - dT_C, P_kPa_mean);
    end
    if dP_psig == 0
        interpFcn_Pplus  = interpFcn;
        interpFcn_Pminus = interpFcn;
    else
        interpFcn_Pplus  = local_buildOne(RP, fluid1, fluid2, T_K_mean, P_kPa_mean + dP_kPa);
        interpFcn_Pminus = local_buildOne(RP, fluid1, fluid2, T_K_mean, P_kPa_mean - dP_kPa);
    end
end
end

function interpFcn = local_buildOne(RP, fluid1, fluid2, T_K, P_kPa)
% rho_norm(x1) = (rho_mix(x1) - rho2)/(rho1 - rho2), inverted to x1(rho_norm)
p1 = getFluidProps_REFPROP(RP, fluid1, T_K, P_kPa);
p2 = getFluidProps_REFPROP(RP, fluid2, T_K, P_kPa);
x1 = 0:0.02:1;
rho_mix = zeros(size(x1));
for k = 1:length(x1)
    z = [x1(k), 1-x1(k)];
    Mix = getMixtureProps_REFPROP(RP, {fluid1, fluid2}, z, T_K, P_kPa);
    rho_mix(k) = Mix.rho;
end
rho_norm_theory = (rho_mix - p2.rho) / (p1.rho - p2.rho);
[rho_sorted, idx] = sort(rho_norm_theory);
x1_sorted = x1(idx);
interpFcn = @(CT_norm) interp1(rho_sorted, x1_sorted, CT_norm, 'linear', 'extrap');
end