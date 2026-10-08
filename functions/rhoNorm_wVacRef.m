function CT_norm_corrected = rhoNorm_wVacRef(CT_norm_raw, fluid1, fluid2, T_C, P_psig)
% rhoNorm_wVacRef  Rescale a CT_norm signal whose "1" reference
% was a vacuum scan, not a true pure-Fluid1-at-P scan, to the correct
% physical normalization anchored at rho_Fluid1(T,P) instead of rho=0.
%
% fluid1 : the fluid whose reference scan was actually vacuum (e.g. 'HELIUM')
% fluid2 : the other endpoint fluid (e.g. 'XENON'), assumed correctly referenced

    persistent RP
    if isempty(RP), RP = initREFPROP(); end

    T_K   = mean(T_C) + 273.15;
    P_kPa = (mean(P_psig) + 14.7)*6.89476;

    p1 = getFluidProps_REFPROP(RP, fluid1, T_K, P_kPa);   % He at actual P
    p2 = getFluidProps_REFPROP(RP, fluid2, T_K, P_kPa);   % Xe at actual P

    correctionFactor = p2.rho / (p2.rho - p1.rho);
    CT_norm_corrected = CT_norm_raw * correctionFactor;
end