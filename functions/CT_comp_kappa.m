function [x_He, dx_He] = CT_comp_kappa(CT_norm, T_C, P_psig, energyRange_keV)
% CT_comp_kappa  Converts normalized CT signal to He mole fraction,
% accounting for the He/Xe mass-attenuation-coefficient (kappa) mismatch.
% Fully standalone: initializes REFPROP and computes pure-fluid
% reference densities internally.
%
% CT_norm         : normalized CT profile, 0 = pure Xe (t=0), 1 = pure He
% T_C, P_psig     : experiment T [C], P [psig] (scalar or vector, averaged)
% energyRange_keV : effective X-ray energy, either a single value (e.g. 150)
%                   for a point estimate, or [min max] (e.g. [100 200])
%                   to bound the uncertainty from not knowing the exact
%                   effective energy of your polychromatic beam.

    persistent RP
    if isempty(RP)
        RP = initREFPROP();   % adjust to your actual initREFPROP.m signature
    end

    if isscalar(energyRange_keV)
        energyRange_keV = energyRange_keV([1 1]);   % point estimate -> zero-width range
    end

    T_K   = mean(T_C) + 273.15;
    P_kPa = (mean(P_psig) + 14.7)*6.89476;

    % pure-fluid reference densities at this experiment's T,P
    He_props = getFluidProps_REFPROP(RP, 'HELIUM', T_K, P_kPa);
    Xe_props = getFluidProps_REFPROP(RP, 'XENON',  T_K, P_kPa);
    rho_He = He_props.rho;
    rho_Xe = Xe_props.rho;

    % NIST XCOM mass attenuation coefficients, cm^2/g (Hubbell & Seltzer)
    E_tab   = [40 50 60 80 100 150 200];
    kHe_tab = [0.1763 0.1703 0.1651 0.1562 0.1486 0.1336 0.1224];
    kXe_tab = [22.70  12.72  7.825  3.633  2.011  0.7202 0.3760];

    x1 = 0:0.05:1;   % x1 = x_He
    x_He_bounds = nan(numel(CT_norm), 2);

    for e = 1:2
        kHe = interp1(E_tab, kHe_tab, energyRange_keV(e), 'pchip');
        kXe = interp1(E_tab, kXe_tab, energyRange_keV(e), 'pchip');

        rho_mix = zeros(size(x1));
        for k = 1:length(x1)
            z = [x1(k), 1-x1(k)];   % [x_He, x_Xe]
            Mix = getMixtureProps_REFPROP(RP, {'HELIUM','XENON'}, z, T_K, P_kPa);
            rho_mix(k) = Mix.rho;
        end
        w_He = x1*4.0026 ./ (x1*4.0026 + (1-x1)*131.293);   % mass fraction He
        kappa_mix = w_He*kHe + (1-w_He)*kXe;

        % CT_theory(x_He=0) = 0 (pure Xe), CT_theory(x_He=1) = 1 (pure He)
        CT_theory = (kappa_mix.*rho_mix - kXe*rho_Xe) ./ (kHe*rho_He - kXe*rho_Xe);

        [CT_sorted, idx] = sort(CT_theory);
        x_He_bounds(:,e) = interp1(CT_sorted, x1(idx), CT_norm, 'linear', 'extrap');
    end

    x_He  = mean(x_He_bounds, 2);
    dx_He = abs(x_He_bounds(:,2) - x_He_bounds(:,1)) / 2;   % 0 if scalar energy given
end