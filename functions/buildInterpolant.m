function [interpFcn, interpFcn_Tplus, interpFcn_Tminus, interpFcn_Pplus, interpFcn_Pminus] = ...
    buildInterpolant(fluid1, fluid2, T_C, P_psig, dT_C, dP_psig)
% Builds the nominal CT_norm(x1)->x1 interpolant plus four perturbed
% versions (T+dT, T-dT, P+dP, P-dP) for finite-difference uncertainty
% propagation, same convention as main_fluidProps_errorProp.m

persistent RP
if isempty(RP)
    RP = initREFPROP();
end

T_K_mean   = mean(T_C) + 273.15;
P_kPa_mean = (mean(P_psig) + 14.7)*6.89476;

interpFcn        = local_buildOne(RP, fluid1, fluid2, T_K_mean, P_kPa_mean);
interpFcn_Tplus  = local_buildOne(RP, fluid1, fluid2, T_K_mean + dT_C, P_kPa_mean);
interpFcn_Tminus = local_buildOne(RP, fluid1, fluid2, T_K_mean - dT_C, P_kPa_mean);
interpFcn_Pplus  = local_buildOne(RP, fluid1, fluid2, T_K_mean, P_kPa_mean + dP_psig*6.89476);
interpFcn_Pminus = local_buildOne(RP, fluid1, fluid2, T_K_mean, P_kPa_mean - dP_psig*6.89476);

end

function interpFcn = local_buildOne(RP, fluid1, fluid2, T_K, P_kPa)
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