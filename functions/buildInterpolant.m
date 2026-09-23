function interpFcn = buildInterpolant(fluid1, fluid2, T_C, P_psig)
% Builds CT_norm(x1) or rho_norm -> x1 interpolant for ANY two-fluid pair via REFPROP,
% using mixture density only
%
% fluid1, fluid2 : REFPROP fluid names, e.g. 'HELIUM','XENON'
%                  CT_norm convention: 0 = pure fluid2, 1 = pure fluid1
% T_C, P_psig    : experiment T [C], P [psig]
%
% Returns interpFcn: apply to CT_norm (scalar, vector, or full image) -> x1

    persistent RP
    if isempty(RP)
        RP = initREFPROP(); 
    end

    T_K   = mean(T_C) + 273.15;
    P_kPa = (mean(P_psig) + 14.7)*6.89476;

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