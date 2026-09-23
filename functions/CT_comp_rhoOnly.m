function x_He = CT_comp_rhoOnly(CT_norm, T_C, P_psig)
% CT_comp_rhoOnly  Converts normalized CT signal to He mole fraction,
% assuming CT signal tracks mixture density only (no kappa correction).
% Fully standalone: initializes REFPROP and computes pure-fluid
% reference densities internally.
%
% CT_norm : normalized CT profile, 0 = pure Xe (t=0), 1 = pure He (end)
% T_C     : experiment temperature [C] (scalar or vector, averaged)
% P_psig  : experiment pressure [psig] (scalar or vector, averaged)

    persistent RP
    if isempty(RP)
        RP = initREFPROP();   % adjust if your initREFPROP.m has a
                               % different signature (e.g. sets a global
                               % instead of returning RP)
    end

    T_K   = mean(T_C) + 273.15;
    P_kPa = (mean(P_psig) + 14.7)*6.89476;

    % pure-fluid reference densities at this experiment's T,P
    He_props = getFluidProps_REFPROP(RP, 'HELIUM', T_K, P_kPa);
    Xe_props = getFluidProps_REFPROP(RP, 'XENON',  T_K, P_kPa);
    rho_He = He_props.rho;
    rho_Xe = Xe_props.rho;

    % mixture density grid across x_He
    x1 = 0:0.05:1;
    rho_mix = zeros(size(x1));
    for k = 1:length(x1)
        z = [x1(k), 1-x1(k)];   % [x_He, x_Xe]
        Mix = getMixtureProps_REFPROP(RP, {'HELIUM','XENON'}, z, T_K, P_kPa);
        rho_mix(k) = Mix.rho;
    end

    % normalized density, same convention as CT_norm: 0 at Xe, 1 at He
    rho_norm_theory = (rho_mix - rho_Xe) / (rho_He - rho_Xe);

    [rho_sorted, idx] = sort(rho_norm_theory);
    x_He = interp1(rho_sorted, x1(idx), CT_norm, 'linear', 'extrap');
end

