%% main_CTpostproc.m
% KL estimation:
%   - fit the BTC/CDE method for both full and x-trimmed CD1_zD* columns
%   - weight the BTC fit by dConc_avg (not ones(...), as the old script did)
%   - add front-width (all symmetric pairs) and moment (sigma) KL, full+xtrim
%   - per-frame front widths of the AVERAGED profile (addProfileWidths: level pairs
%     10/90 ... 40/60 and erfc-fit width of CVert / CVert_xtrim), stored in varsAll next
%     to the contour widths (rebuilt every run) and fitted with the same fitKL_frontWidth
%     as the contour widths: W^2/(4k^2) = KL t
%   - carry the MFM reference KL
%   - KL from single profiles at a fixed time (KL_profileAt): the frame whose averaged
%     profile passes through (zD, C) = (zDtarget_mid, CDtarget_mid) (default mid-core,
%     C = 0.5) and the frames within +/- zDwin_mid; width from profileWidth (same as the
%     width-vs-time fit), first ADE term (Lake & Johns, Ekwere Peters):
%       level pairs : KL = W^2/(4 k^2 tau),  erfc : KL = w^2/(4 tau),  sigma : sigma^2/(2 tau)
%     for tau = t - t_arrival from contour detection ("contour", first C = 0.01 contour)
%     and from the line volume ("lines"); aliases contour / lines = erfc, sigma = sigma
%   - KL with an initial width (spreading before the core): for every level pair and width
%     source (averaged profile, 2D contours), linear fit of all frames (front centre in klW0ZDrange)
%       W^2 = W0^2 + 4 k^2 KL (t - t_arr)      (10-90: 4 k^2 = 3.625^2)
%     t_arr = contour arrival; gives KL and the width W0 at arrival (fitKL_W0); compared with the
%     fit through the origin (W0 = 0)
%   - initial width from the inlet BTC (CD1_zD0p0): W0 = u_front (t_hi - t_lo) for each level pair,
%     also corrected for the spreading while the front passes the slice:
%     W0c^2 = (u_front dt)^2 - 4 k^2 KL dt  (KL of the W0 fit) (inletBTCwidth)
%   - KL of the frame at theta = klRot (front centre closest to zD = 0.5 within klRotZD, as the
%     KL-by-method bar of main_CTplots): KL = W^2/(4k^2 tau), and corrected (W^2 - W0^2)/(4k^2 tau)
%     with W0 from the fit and from the inlet BTC
%   - plot fitted BTC vs scatter, and compare all methods
%   - ARRIVAL TIME of the single-profile KL (mid-profile, every frame, W0 fit, theta = klRot frame):
%     tArrProfRef = "C50" (default) | "C50prof" | "contour" | "lines"
%       C50     : t0 = -b/v of the straight line z = v t + b through the C = 0.5 2D-contour centres
%                 (frontVel on zDFront50_cm, full image, main_CTpreproc) -> time the front centre
%                 enters the rock
%       C50prof : same, through the AVERAGED-PROFILE centres, computed here (frontVel on
%                 zDFrontProfC50<vfProfVariant>_cm = Cn = 0.5 crossing of the profile, no fit, as the
%                 C = 0.5 contour; vfProfCenter = "erfc" uses the erfc-fit z50 instead) -> the time
%                 origin of the profile's own centre, consistent with the profile widths used for KL
%       levels  : arrival from the trajectories of every level C = 0.01 ... 0.5 (arrivalLevels, below):
%                 each level of the averaged profile (and of the contours) fitted with its own ADE form
%                 z_C = v50 (t - t0_C) + a_C sqrt(t - t0_C), a_C >= 0; stored arrival = t0_C of
%                 arrOpt.refSource / refLevel / refFit (default: profile, C = 0.01 -> time the front,
%                 C > 0, enters the rock); all inlet spreading goes into t_res, no W0 needed
%       contour : first frame with a C = 0.01 contour (leading edge)
%       lines   : line volume before the core / Q
%     stored in resultsAll.(ds).tArr_profKL_min / tArr_profKL_ref (read by klAllFrames in main_CTplots)
%   - KL_byArrival: the every-frame KL (W klAllPair, profile and contours) and the theta = klRot frame
%     for EVERY candidate arrival (levels, C50, C50prof, contour, lines, every level t0 of the contours
%     and the profile, joint2 t0s / t0c): resultsAll.(ds).<variant>.KL_byArrival, sheet KL_byArrival_<variant>
%   - level arrivals stored in resultsAll.(ds).arrLevels (.contour / .profile: .perLevel, .joint tables,
%     .v50), resultsAll.(ds).tArr_levels_min / tArr_levels_ref / tD_arr_levels (main_CTplots: tResRef
%     = "levels"); Excel sheets arrLevels_perLevel / arrLevels_joint, Summary columns tArr_levels_*;
%     figures <Key>_arrLevels_<ds>_<source>_<joint2|perLevel>.png

%% IMPORT input
Root = CT_setupPaths;
inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

%% Extract data from images, preproc and MFM

for i = 1:height(inputFileConfig)

    filenameExp   = inputFileConfig.inputFileName{i};
    pathExportAll = inputFileConfig.exportPath{i};

    filedataExp = import_inputCTExp(filenameExp);

    % MFM analog (CT)
    pathImport_MFM_CT = regexprep(inputFileConfig.MFM_BTC_CT_Path{i}, '^(\.\./)+', '');
    MFM_CT_name = inputFileConfig.MFM_BTC_CT_Key{i};
    MFM_CT_file = fullfile(Root, pathImport_MFM_CT, 'expProcFullData.mat');

    % MFM UHS
    pathImport_MFM_UHS = regexprep(inputFileConfig.MFM_BTC_UHS_Path{i}, '^(\.\./)+', '');
    MFM_UHS_name = inputFileConfig.MFM_BTC_UHS_Key{i};
    MFM_UHS_file = fullfile(Root, pathImport_MFM_UHS, 'expProcFullData.mat');

    if ~isfile(MFM_CT_file),  error('MFM CT results file not found: %s',  MFM_CT_file);  end
    if ~isfile(MFM_UHS_file), error('MFM UHS results file not found: %s', MFM_UHS_file); end

    MFM_CT_Data  = load(MFM_CT_file);
    MFM_UHS_Data = load(MFM_UHS_file);

    if ~isfield(MFM_CT_Data.expProcFullData, MFM_CT_name)
        error('Experiment %s not found in %s', MFM_CT_name, MFM_CT_file);
    end
    if ~isfield(MFM_UHS_Data.expProcFullData, MFM_UHS_name)
        error('Experiment %s not found in %s', MFM_UHS_name, MFM_UHS_file);
    end

    mfmExpCT  = MFM_CT_Data.expProcFullData.(MFM_CT_name);    % exp_params + woEOS/wEOS
    mfmExpUHS = MFM_UHS_Data.expProcFullData.(MFM_UHS_name);

    D_cm2min     = mfmExpCT.exp_params.D12_cm2min;    % CT-analog fluid pair
    D_UHS_cm2min = mfmExpUHS.exp_params.D12_cm2min;   % UHS fluid pair (may differ)

    % placeholder when a variant has no results
    nanRes = table(NaN, NaN, "none", 'VariableNames', {'KL_cm2min','totUncertKL_cm2min','model'});

    % tcore reference, same convention as the old populate_CTframeVars:
    % time (minutes) to clear the line volume before the core
    tLines_min = filedataExp.Vlinesbefore/filedataExp.Q;

    % experiment data all in cm (not m) and min (not seconds) -- same as main_CTpreproc.m
    Ci = filedataExp.C1init/100;
    Cj = filedataExp.C1j/100;
    uint_cmmin = filedataExp.Q/(filedataExp.phi*pi*((filedataExp.D*2.54/2)^2));
    L_cm = filedataExp.L*2.54;

    u_SI = uint_cmmin/(60*100);
    L_SI = L_cm/100;
    dt_guess = tLines_min * 60;    % [s] line volume before the core, same time base as t_vals
    Cmin = 0.16; Cmax = 0.84;

    zDlevels_KLfit = 0.1:0.1:1.0;

    % KL from the profile with the front centre (C = 0.5) at mid-core
    zDtarget_mid = 0.5;       % target position zD of the profile ...
    CDtarget_mid = 0.5;       % ... at this concentration (0.5 = front centre)
    zDwin_mid    = 0.05;      % frames with |zD(C = CDtarget) - zDtarget| <= window are averaged

    % arrival time (origin of tau = t - t_arr) of every KL from single profiles / per-frame widths:
    % mid-profile (KL_profileAt), every frame (KL_allProfileWidths), W0 fit, theta = klRot frame
    tArrProfRef  = "levels";  % "levels" (level trajectories, arrOpt below) | "C50" (contour centre line, -b/v)
                              % | "C50prof" (profile centre line) | "contour" (C = 0.01) | "lines" (Vlines/Q)
    vfProfVariant = "_xtrim"; % profile centre used for C50prof: "_xtrim" (as the profile KL) | "" (full)
    vfProfCenter  = "crossing"; % profile centre: "crossing" (Cn = 0.5 crossing, no fit, zDFrontProfC50)
                                % | "erfc" (erfc-fit z50, zDFrontProf50)
    sigmaTau_mid = tArrProfRef; % arrival used by the sigma alias of the mid-profile KL
    % arrival time of the width-growth / moment fits vs time (fitKL_frontWidth, fitKL_moments,
    % widthVsTime plot): "lines" keeps the previous results; "C50" / "contour" also possible
    tArrFitRef   = "lines";   % "lines" | "levels" | "C50" | "C50prof" | "contour"

    % arrival from the trajectories of every level (arrivalLevels): "levels" arrival above
    arrOpt = struct( ...
        'levels',    [0.01 0.05 0.1 0.16 0.2 0.3 0.4 0.5], ... % contour levels not traced in preproc are skipped
        'variant',   "_xtrim", ...              % "" = full image | "_xtrim" (as the profile KL)
        'sources',   ["contour","profile"], ... % level positions from the 2D contours and the averaged profile
        'useV50',    true, ...                  % every fit uses the velocity of that source's C = 0.5 line
        'search',    120, ...                   % t0 searched up to this many min before the first point
        'refSource', "profile", ...             % stored arrival: "profile" | "contour"
        'refLevel',  0.01, ...                  % ... of level C (refFit "curve" / "line")
        'refFit',    "curve", ...               % ... "curve" (per-level ADE form, t0 at z = 0) | "line" | "t0s"
        'doPlot',    true, ...                  % figures per data source and level source
        'plots',     ["joint2","perLevel"], ... % "joint2" (common v, two origins) | "perLevel" | "joint1"
        'closeFig',  true);

    % front width from the averaged profile (addProfileWidths -> columns of varsAll)
    profWidthPairs = [0.10 0.90; 0.20 0.80; 0.30 0.70; 0.40 0.60];   % [low high] levels
    profErfcFit    = true;    % also fit C = 0.5 erfc((z - z50)/w) to every profile (w, RMSE, R2);
                              % false = level-pair widths and sigma only (much faster)
    % width definitions fitted against time by fitKL_frontWidth: {column prefix, result tag}
    widthSources   = {"zDWidth",         "width_"; ...      % 2D contours
                      "zDWidthProf",     "profW_"; ...      % averaged profile, level pairs
                      "zDWidthProfErfc", "profWerfc_"};     % averaged profile, erfc width

    % KL from the width of EVERY frame (KL_allProfileWidths): KL = W^2/(4 k^2 tau), contour arrival
    klAllPair     = [0.40 0.60];   % level pair of the width (must be one of profWidthPairs)
    klAllVariants = "xtrim";       % "xtrim", "full" or ["full","xtrim"]
    klAllDtArr    = [];            % arrival uncertainty [min]; [] = half the frame interval
    klAllZDrange  = [0.1 0.9];     % front centre zD range of the frames in the summary value

    % KL with initial width W0: W^2 = W0^2 + 4 k^2 KL (t - t_arr), every pair of profWidthPairs
    klW0Variants  = "xtrim";       % "xtrim", "full" or ["full","xtrim"]
    klW0ZDrange   = [0.1 0.9];     % front centre zD range of the frames in the fit
    klW0Plot      = true;          % figure W^2 vs t - t_arr with both fits, per data source / variant
    klW0PlotTD    = true;          % (temporary) figure W_pair and per-frame KL vs tD_total, with / without W0
    klW0PlotPair  = [0.40 0.60];   % level pair of that figure (must be one of profWidthPairs)
    % KL of the frame at a fixed rotation (same frame as the KL-by-method bar of main_CTplots)
    klRot         = 226;           % rotation position [deg]
    klRotTol      = 1;             % tolerance [deg]
    klRotZD       = [0.2 0.8];     % front-centre zD window; the frame closest to zD = 0.5 is used

    % load the data produced by main_CTpreproc.m
    expCT_name = pathExportAll + filedataExp.Key;
    S = load(expCT_name + ".mat");
    expCTData = S.expCTDataSave;

    for dataSource = ["rhoNorm","conc"]

        switch dataSource
            case "rhoNorm", fitDataMFM = "woEOS";
            case "conc",    fitDataMFM = "wEOS";
        end
        % MFM analog (CT)
        if isfield(mfmExpCT, fitDataMFM)
            mfmResCT = mfmExpCT.(fitDataMFM).results;
        else
            warning('MFM CT %s results not found for %s, KL = NaN', fitDataMFM, MFM_CT_name);
            mfmResCT = nanRes;
        end

        % MFM UHS
        if isfield(mfmExpUHS, fitDataMFM)
            mfmResUHS = mfmExpUHS.(fitDataMFM).results;
        else
            warning('MFM UHS %s results not found for %s, KL = NaN', fitDataMFM, MFM_UHS_name);
            mfmResUHS = nanRes;
        end

        KL_MFM_CT   = mfmResCT.KL_cm2min;            % NaN if no valid fit
        dKL_MFM_CT  = mfmResCT.totUncertKL_cm2min;
        KL_MFM_UHS  = mfmResUHS.KL_cm2min;
        dKL_MFM_UHS = mfmResUHS.totUncertKL_cm2min;

        vars = expCTData.varsAll.(dataSource);
        % averaged-profile widths per frame: old columns deleted, rebuilt, stored with time
        vars = addProfileWidths(vars, Ci, Cj, profWidthPairs, L_cm, profErfcFit);
        expCTData.varsAll.(dataSource) = vars;

        % measured front velocity and contour arrival from main_CTpreproc
        % (missing contour arrival -> KL_profileAt uses the line-volume arrival)
        vFront_cmmin = NaN;  tArrContour_min = NaN;
        if isfield(expCTData, 'resultsAll') && isfield(expCTData.resultsAll, dataSource)
            rA = expCTData.resultsAll.(dataSource);
            if isfield(rA, 'vFront_cmmin'), vFront_cmmin = rA.vFront_cmmin; end
            if isfield(rA, 'tD_arrival_contour')
                tArrContour_min = rA.tD_arrival_contour*filedataExp.Vtotal/filedataExp.Q;   % tD = Q t / Vtotal
            end
        end
        % diagnostic: time at which the C = 0.5 contour line (z = v t + b) crosses the inlet,
        % t0 = -b/v -- the ADE time origin implied by the measured front itself
        t0C50_min = NaN;
        if isfield(expCTData, 'resultsAll') && isfield(expCTData.resultsAll, dataSource) && ...
                isfield(expCTData.resultsAll.(dataSource), 'vFront')
            vf = expCTData.resultsAll.(dataSource).vFront;
            if isfinite(vf.v_front_cmmin) && vf.v_front_cmmin > 0, t0C50_min = -vf.intercept_cm/vf.v_front_cmmin; end
        end
        % front velocity and t0 from the AVERAGED-PROFILE centre (vfProfCenter: Cn = 0.5 crossing
        % zDFrontProfC50, or erfc-fit z50 zDFrontProf50; addProfileWidths), same fit as frontVel in
        % main_CTpreproc (z [cm] vs t [min], 0.03 < z_D < 0.97, >= 5 frames), full and x-trimmed; t0 = -b/v
        tMinAll = vars.secondsElapsed/60;
        vFrontProf = struct();
        for pv = ["", "_xtrim"]
            pvName = ternary_str(pv == "", "full", "xtrim");
            cZ = ternary_str(vfProfCenter == "erfc", "zDFrontProf50", "zDFrontProfC50") + pv;
            if all(ismember([cZ, cZ + "_cm"], string(vars.Properties.VariableNames)))
                vp = frontVel(tMinAll, vars.(cZ + "_cm"), vars.(cZ));
            else
                warning('%s (%s): %s / %s_cm missing, no profile front velocity', filedataExp.Key, dataSource, cZ, cZ);
                vp = struct('v_front_cmmin',NaN, 'intercept_cm',NaN, 'R2',NaN, 'nValidPts',0);
            end
            vp.t0_min = NaN;  vp.center = string(vfProfCenter);  vp.column = cZ;
            if isfinite(vp.v_front_cmmin) && vp.v_front_cmmin > 0, vp.t0_min = -vp.intercept_cm/vp.v_front_cmmin; end
            vFrontProf.(pvName) = vp;
        end
        vpSel = vFrontProf.(ternary_str(vfProfVariant == "", "full", "xtrim"));
        vFrontProf_cmmin = vpSel.v_front_cmmin;
        t0C50prof_min    = vpSel.t0_min;

        % arrival from the trajectories of every level (contours and averaged profile)
        rAll = struct();
        if isfield(expCTData, 'resultsAll') && isfield(expCTData.resultsAll, dataSource)
            rAll = expCTData.resultsAll.(dataSource);
        end
        [arrLevels, tArrLev_min, tArrLevRef] = arrivalLevels(vars, filedataExp, rAll, arrOpt, ...
            fullfile(pathExportAll, filedataExp.Key + "_arrLevels_" + dataSource));

        fprintf(['%s (%s): v_front contour = %.4g cm/min, v_front profile%s (%s) = %.4g cm/min (u_int = %.4g); ' ...
                 't_arr contour C=0.01 = %.3g min, t_arr lines = %.3g min, t0 of the C=0.5 line: contour = %.3g, ' ...
                 'profile = %.3g min; t_arr levels (%s) = %.3g min\n'], ...
            filedataExp.Key, dataSource, vFront_cmmin, vfProfVariant, vfProfCenter, vFrontProf_cmmin, uint_cmmin, ...
            tArrContour_min, tLines_min, t0C50_min, t0C50prof_min, tArrLevRef, tArrLev_min);

        % arrival times used below (fallback C50prof -> C50 -> contour -> lines when one is missing)
        tArrC = tArrContour_min;  if ~isfinite(tArrC), tArrC = tLines_min; end     % contour, else lines
        tArrAll = struct('levels', tArrLev_min, 'C50', t0C50_min, 'C50prof', t0C50prof_min, ...
            'contour', tArrC, 'lines', tLines_min);
        tArrP = pickArrival(tArrAll, tArrProfRef, filedataExp.Key, dataSource);     % single-profile KL
        tArrF = pickArrival(tArrAll, tArrFitRef,  filedataExp.Key, dataSource);     % width-growth fits
        t_arrival_min = max(tArrF, 0);   % scalar, broadcasts in fitKL_frontWidth/fitKL_moments
        tArrD_P = tArrP*filedataExp.Q/filedataExp.Vtotal;                           % tD = Q t / Vtotal
        fprintf('  arrival used: single-profile KL = %s (%.3g min, tD = %.3f), width-growth fits = %s (%.3g min)\n', ...
            tArrProfRef, tArrP, tArrD_P, tArrFitRef, tArrF);

        resultsOut = struct();

        for variantArr = ["full","xtrim"]
            variant = variantArr;
            variantSuffix = ternary_str(variant=="full", "", "_xtrim");

            % KL from CT breakthrough curves at each zD (CDE fit)
            KL_fit_byZD = struct();
            BTCMetrics_byZD = struct();
            for m = 1:length(zDlevels_KLfit)
                zD = zDlevels_KLfit(m);
                fieldName  = strrep(sprintf('zD%.1f', zD), '.', 'p');
                CfieldName = strrep(sprintf('CD1_zD%.1f', zD), '.', 'p') + variantSuffix;

                if ~ismember(CfieldName, string(vars.Properties.VariableNames))
                    warning('%s not found, skipping zD=%.1f (%s)', CfieldName, zD, variant);
                    continue
                end

                C_at_zD = vars.(CfieldName);
                t_vals  = vars.secondsElapsed;
                tD_vals = vars.tDtotal;
                if dataSource == "conc"
                    dC_vals = vars.dConc_mean;
                    dC_vals(~(dC_vals > 0)) = NaN;          % zero/negative -> dropped by the NaN filter below
                else
                    dC_vals = ones(size(tD_vals));         % no per-frame uncertainty for rhoNorm -> unweighted
                end
                L_eff   = zD * L_SI;

                % pre-filter/sort exactly as checkBTCComplete does
                % internally (NaN-drop on C/t, sort by t), so dC_vals
                % stays aligned with whatever it returns
                good = ~isnan(C_at_zD) & ~isnan(t_vals) & ~isnan(dC_vals);
                C_at_zD = C_at_zD(good); t_vals = t_vals(good);
                tD_vals = tD_vals(good); dC_vals = dC_vals(good);
                [t_vals, ord] = sort(t_vals);
                C_at_zD = C_at_zD(ord); tD_vals = tD_vals(ord); dC_vals = dC_vals(ord);

                [isComplete, C_at_zD, t_vals, tD_vals] = checkBTCComplete(C_at_zD, t_vals, tD_vals, Cmin, Cmax, 5);

                if isComplete
                    dC_c = dC_vals;   % unchanged by the no-op filter above
                    [methods_m, bestMethod_m, best_m] = fitBTC_KL_allMethods( ...
                        t_vals, C_at_zD, dC_c, ...
                        u_SI, Cj, Ci, L_eff, dt_guess, Cmin, Cmax);
                    [C_unique, idx] = unique(C_at_zD,'stable');
                    BTCMetrics_byZD.(fieldName) = getBTCMetrics(t_vals(idx), tD_vals(idx), C_unique);
                else
                    methods_m = struct(); bestMethod_m = "skipped_incompleteBTC"; best_m = struct();
                    BTCMetrics_byZD.(fieldName) = struct();
                    fprintf('  %s (%s): BTC at zD=%.1f incomplete (C range %.2f-%.2f), fit skipped\n', ...
                        dataSource, variant, zD, min(C_at_zD), max(C_at_zD));
                end

                KL_fit_byZD.(fieldName) = struct('zD',zD,'L_eff',L_eff,'complete',isComplete, ...
                    'allMethods',methods_m,'bestMethod',bestMethod_m,'best',best_m, ...
                    't_vals',t_vals,'C_vals',C_at_zD);
            end

            resultsOut.(variant).KL_BTC_CT_byZD  = KL_fit_byZD;
            resultsOut.(variant).BTCMetrics_byZD = BTCMetrics_byZD;
            resultsOut.(variant).KL_BTC_CT  = KL_fit_byZD.zD1p0;
            resultsOut.(variant).BTCMetrics = BTCMetrics_byZD.zD1p0;

            % front width vs time: averaged profile vs 2D contours
            plotWidthVsTime(vars, t_arrival_min, variantSuffix, ...
                fullfile(pathExportAll, filedataExp.Key + "_widthVsTime_" + dataSource + "_" + variant), ...
                "(" + filedataExp.Key + ", " + dataSource + ", " + variant + ")");

            % KL from front width growth and from moments (sigma),
            % each fitted twice: through the origin (int0) and with intercept (int1)
            KL_front = struct();
            for fitInt = [false true]
                intTag = ternary_str(fitInt, "int1", "int0");

                % width growth W^2/(4k^2) = KL t, same function for every width definition:
                %   width_     : 2D contours (zDWidth_*, populate_CTframeVars)
                %   profW_     : averaged profile, level pairs (zDWidthProf_*, addProfileWidths)
                %   profWerfc_ : averaged profile, erfc-fit width (zDWidthProfErfc_10_90)
                for ws = 1:size(widthSources,1)
                    KL_width_byPair = fitKL_frontWidth(vars, t_arrival_min, variantSuffix, fitInt, ...
                        widthSources{ws,1});
                    widthFns = fieldnames(KL_width_byPair);
                    for f = 1:numel(widthFns)
                        S2 = KL_width_byPair.(widthFns{f});
                        KL_front.(widthSources{ws,2} + widthFns{f} + "_" + intTag) = struct( ...
                            'KL_cm2min_best', S2.KL_cm2min, ...
                            'KL_cm2min_se',   S2.KL_cm2min_se, ...
                            'KL_cm2min_mean', S2.KL_mean, ...
                            'KL_cm2min_std',  S2.KL_std, ...
                            'R2',             S2.R2, ...
                            'intercept_cm2',  S2.intercept_cm2, ...
                            'nValidFrames',   S2.nPts, ...
                            'nFramesTotal',   S2.nValid, ...
                            'fitWithIntercept', fitInt, ...
                            't_vertex_min',   S2.t_vertex, 'pQuad', S2.pQuad, ...
                            'KL_pts', S2.KL_pts, ...
                            't_all', S2.t_all, 'y_all', S2.y_all, ...
                            't_fit', S2.t_fit, 'y_fit', S2.y_fit, 'y_pred', S2.y_pred);
                    end
                end

                S3 = fitKL_moments(vars, t_arrival_min, variantSuffix, fitInt);
                KL_front.("sigma_" + intTag) = struct( ...
                    'KL_cm2min_best', S3.KL_cm2min, ...
                    'KL_cm2min_se',   S3.KL_cm2min_se, ...
                    'KL_cm2min_mean', S3.KL_mean, ...
                    'KL_cm2min_std',  S3.KL_std, ...
                    'R2',             S3.R2, ...
                    'intercept_cm2',  S3.intercept_cm2, ...
                    'nValidFrames',   S3.nPts, ...
                    'nFramesTotal',   S3.nValid, ...
                    'fitWithIntercept', fitInt, ...
                    't_vertex_min',   S3.t_vertex, 'pQuad', S3.pQuad, ...
                    'KL_pts', S3.KL_pts, ...
                    't_all', S3.t_all, 'y_all', S3.y_all, ...
                    't_fit', S3.t_fit, 'y_fit', S3.y_fit, 'y_pred', S3.y_pred);
            end

            resultsOut.(variant).KL_front_CT = KL_front;

            % KL from the profile(s) with the front centre at zDtarget_mid
            plotFile_mid = fullfile(pathExportAll, filedataExp.Key + "_KLmidProfile_" + dataSource + "_" + variant);
            % every arrival is evaluated (methods <m>_levels, <m>_C50, <m>_C50prof, <m>_contour, <m>_lines);
            % the selected one first, so the per-frame KL plot of KL_profileAt uses it
            tArr = struct();  tArr.(tArrProfRef) = tArrP;
            for a = ["levels","C50","C50prof","contour","lines"]
                if ~isfield(tArr, a) && isfinite(tArrAll.(a)), tArr.(a) = tArrAll.(a); end
            end
            resultsOut.(variant).KL_midProfile = KL_profileAt(vars, variantSuffix, ...
                zDtarget_mid, CDtarget_mid, zDwin_mid, tArr, Ci, Cj, profWidthPairs, L_cm, ...
                plotFile_mid, sigmaTau_mid);
            mp = resultsOut.(variant).KL_midProfile;
            % every method: level pairs C10_90 ... C40_60 (KL = W^2/(4 k^2 tau)), erfc (w^2/(4 tau)),
            % sigma, each with the contour and the lines arrival (aliases contour/lines/sigma skipped)
            fprintf('  %s (%s) mid-profile, closest frame tD = %.2f, %d frame(s) in the window:\n', ...
                dataSource, variant, mp.tD_best, mp.nFrames);
            for mm = setdiff(string(fieldnames(mp.methods))', ["contour","lines","sigma"], 'stable')
                r = mp.methods.(mm);
                fprintf('    %-16s KL = %.4g +/- %.2g (closest), mean = %.4g +/- %.2g cm2/min\n', ...
                    mm, r.KL_cm2min_best, r.dKL_cm2min_best, r.KL_cm2min_mean, r.KL_cm2min_std);
            end

            % KL from the width of every frame (profile and 2D contours, level pair klAllPair)
            resultsOut.(variant).KL_allProf = table();  resultsOut.(variant).KL_allProfSum = struct();
            resultsOut.(variant).KL_byArrival = table();
            if ismember(variant, klAllVariants)
                [Tall_, Sall_] = KL_allProfileWidths(vars, variantSuffix, klAllPair, tArrP, tArrD_P, ...
                    klAllDtArr, klAllZDrange);
                resultsOut.(variant).KL_allProf    = Tall_;
                resultsOut.(variant).KL_allProfSum = Sall_;
                fprintf(['  %s (%s) KL from every frame, W %02d-%02d, t_arr %s (tD = %.3f), ' ...
                         'centre zD in [%.2f %.2f]:\n'], dataSource, variant, round(100*klAllPair), ...
                    tArrProfRef, tArrD_P, klAllZDrange);
                for wsrc = ["prof","cont"]
                    q = Sall_.(wsrc);
                    fprintf('    %-8s n = %2d  KL = %.4g +/- %.2g (weighted), mean = %.4g +/- %.2g, median = %.4g cm2/min\n', ...
                        wsrc, q.n, q.KL_wmean, q.dKL_wmean, q.KL_mean, q.KL_std, q.KL_median);
                end
                disp(Tall_(:, ["run","rotPos_deg","tDtotal","tD_arrival","tauD","zD_center_C50", ...
                    string(Tall_.Properties.VariableNames(contains(Tall_.Properties.VariableNames, ...
                    ["W_prof_","KL_prof_","dKL_prof_","KL_cont_","dKL_cont_"])))]))

                % sensitivity of KL to the arrival: the same every-frame KL (W klAllPair) and the
                % theta = klRot frame for every candidate arrival (tArrAll, every level t0 of
                % arrLevels, joint2 t0s / t0c)
                resultsOut.(variant).KL_byArrival = KL_byArrival(vars, variantSuffix, klAllPair, ...
                    candidateArrivals(tArrAll, arrLevels), filedataExp, klAllDtArr, klAllZDrange, ...
                    klRot, klRotTol, klRotZD);
                fprintf(['  %s (%s) KL from every frame, W %02d-%02d, for every candidate arrival ' ...
                         '(centre zD in [%.2f %.2f]; theta = %d deg frame):\n'], dataSource, variant, ...
                    round(100*klAllPair), klAllZDrange, klRot);
                disp(resultsOut.(variant).KL_byArrival)
            end

            % KL with an initial width (spreading before the core):
            %   W^2 = W0^2 + 4 k^2 KL (t - t_arr),  t_arr = tArrProfRef arrival (C50: W0 = width
            %   when the front centre is at the inlet)
            % every level pair, averaged profile and 2D contours; frames with the centre in klW0ZDrange
            resultsOut.(variant).KL_W0fit = table();
            if ismember(variant, klW0Variants)
                uW0 = vFront_cmmin;  if ~(isfinite(uW0) && uW0 > 0), uW0 = uint_cmmin; end   % front velocity [cm/min]
                rowsW0 = {};  fitsW0 = {};
                for pp = 1:size(profWidthPairs,1)
                    pair_ = profWidthPairs(pp,:);
                    tagp  = sprintf('%02d_%02d', round(100*pair_));
                    if ~ismember("zDWidthProf_" + tagp + variantSuffix + "_cm", string(vars.Properties.VariableNames))
                        continue
                    end
                    Tp_ = KL_allProfileWidths(vars, variantSuffix, pair_, tArrP, tArrD_P, klAllDtArr, klW0ZDrange);
                    inR = Tp_.zD_center_C50 >= klW0ZDrange(1) & Tp_.zD_center_C50 <= klW0ZDrange(2);
                    btc0 = inletBTCwidth(vars, variantSuffix, pair_, 0);          % inlet BTC level times
                    selR = rotZDsel(Tp_, klRot, klRotTol, klRotZD);              % frame at theta = klRot
                    for wsrc = ["prof","cont"]
                        W_ = Tp_.("W_" + wsrc + "_" + tagp + "_cm");
                        r_ = fitKL_W0(Tp_.tau_min(inR), W_(inR), pair_);
                        % (temporary) W and per-frame KL vs tD_total, without / with the W0 correction
                        if klW0PlotTD && wsrc == "prof" && isequal(round(100*pair_), round(100*klW0PlotPair))
                            plotKL_W0_vsTD(Tp_, r_, pair_, klW0ZDrange, ...
                                fullfile(pathExportAll, filedataExp.Key + "_KL_W0_vsTD_" + tagp + "_" + dataSource + "_" + variant), ...
                                "(" + filedataExp.Key + ", " + dataSource + ", " + variant + ")");
                        end
                        c4_ = 4*r_.k^2;
                        % initial width from the inlet BTC: W0 = u_front dt, and corrected for the
                        % spreading while the front passes the slice (KL of the W0 fit)
                        ex = struct('tInlet_lo_min',btc0.t_lo, 'tInlet_hi_min',btc0.t_hi, 'tInlet50_min',btc0.t50, ...
                            'dtInlet_min',btc0.dt, 'uFront_cmmin',uW0, 'W0btc_cm',uW0*btc0.dt, 'W0btcCorr_cm',NaN, ...
                            'rot_frame',NaN, 'rot_tD',NaN, 'rot_zD',NaN, 'rot_tau_min',NaN, 'rot_W_cm',NaN, ...
                            'KLrot_cm2min',NaN, 'KLrot_W0fit_cm2min',NaN, 'KLrot_W0btc_cm2min',NaN, 'KLrot_W0btcCorr_cm2min',NaN);
                        KLfit_ = r_.KL_cm2min;  if ~isfinite(KLfit_), KLfit_ = 0; end
                        if isfinite(ex.W0btc_cm)
                            ex.W0btcCorr_cm = sqrt(max(ex.W0btc_cm^2 - c4_*KLfit_*btc0.dt, 0));
                        end
                        % KL of the frame at theta = klRot: plain and with the three W0 corrections
                        if any(selR)
                            q_ = find(selR, 1);
                            Wq = W_(q_);  tq = Tp_.tau_min(q_);
                            W0f2 = r_.W0sq_cm2;  if ~isfinite(W0f2), W0f2 = 0; end
                            ex.rot_frame = Tp_.frame(q_);  ex.rot_tD = Tp_.tDtotal(q_);  ex.rot_zD = Tp_.zD_center_C50(q_);
                            ex.rot_tau_min = tq;  ex.rot_W_cm = Wq;
                            ex.KLrot_cm2min           = Wq^2/(c4_*tq);
                            ex.KLrot_W0fit_cm2min     = (Wq^2 - W0f2)/(c4_*tq);
                            ex.KLrot_W0btc_cm2min     = (Wq^2 - ex.W0btc_cm^2)/(c4_*tq);
                            ex.KLrot_W0btcCorr_cm2min = (Wq^2 - ex.W0btcCorr_cm^2)/(c4_*tq);
                        end
                        rowsW0{end+1,1} = [table(string(variant), string(tagp), wsrc, ...
                            'VariableNames', {'variant','pair','width'}), struct2table(rmfield(r_, {'tau','W2'})), ...
                            struct2table(ex)]; %#ok<AGROW>
                        fitsW0{end+1,1} = struct('pair',tagp, 'width',wsrc, 'r',r_); %#ok<AGROW>
                    end
                end
                if ~isempty(rowsW0)
                    TW0 = vertcat(rowsW0{:});
                    resultsOut.(variant).KL_W0fit = TW0;
                    fprintf(['  %s (%s) KL with initial width, W^2 = W0^2 + 4k^2 KL (t - t_arr), t_arr %s ' ...
                             '(%.3g min), centre zD in [%.2f %.2f]:\n'], dataSource, variant, tArrProfRef, tArrP, klW0ZDrange);
                    disp(TW0(:, {'pair','width','n','KL_cm2min','dKL_cm2min','W0_cm','dW0_cm', ...
                        'tShift_min','R2','KL0_cm2min','R2_0'}))
                    fprintf('  %s (%s) initial width from the inlet BTC (zD = 0, u_front = %.3g cm/min) vs fitted W0:\n', ...
                        dataSource, variant, uW0);
                    disp(TW0(TW0.width == "prof", {'pair','tInlet_lo_min','tInlet_hi_min','dtInlet_min', ...
                        'W0btc_cm','W0btcCorr_cm','W0_cm','dW0_cm'}))
                    fprintf('  %s (%s) KL of the frame at theta = %g deg (centre closest to zD = 0.5 in [%.1f %.1f]):\n', ...
                        dataSource, variant, klRot, klRotZD);
                    disp(TW0(:, {'pair','width','rot_frame','rot_tD','rot_zD','rot_tau_min','rot_W_cm', ...
                        'KLrot_cm2min','KLrot_W0fit_cm2min','KLrot_W0btc_cm2min','KLrot_W0btcCorr_cm2min'}))
                    if klW0Plot
                        plotKL_W0(fitsW0, fullfile(pathExportAll, filedataExp.Key + "_KL_W0fit_" + dataSource + "_" + variant), ...
                            "(" + filedataExp.Key + ", " + dataSource + ", " + variant + ")");
                    end
                end
            end
        end

        resultsOut.tArr_profKL_ref   = string(tArrProfRef);   % arrival of the single-profile KL
        resultsOut.tArr_profKL_min   = tArrP;                 % (read by klAllFrames in main_CTplots)
        resultsOut.tD_arr_profKL     = tArrD_P;
        resultsOut.tArr_fitKL_ref    = string(tArrFitRef);
        resultsOut.tArr_fitKL_min    = tArrF;
        resultsOut.t0_C50line_min    = t0C50_min;
        resultsOut.vFrontProf        = vFrontProf;            % .full / .xtrim: v_front_cmmin, intercept_cm, R2, nValidPts, t0_min
        resultsOut.vFrontProf_cmmin  = vFrontProf_cmmin;      % of vfProfVariant
        resultsOut.t0_C50prof_min    = t0C50prof_min;
        resultsOut.vFrontProf_variant = string(vfProfVariant);
        resultsOut.vFrontProf_center  = string(vfProfCenter);
        resultsOut.arrLevels          = arrLevels;            % .contour / .profile: .perLevel, .joint, .v50, ...
        resultsOut.tArr_levels_min    = tArrLev_min;          % arrival from the levels (main_CTplots: tResRef = "levels")
        resultsOut.tArr_levels_ref    = tArrLevRef;
        resultsOut.tD_arr_levels      = tArrLev_min*filedataExp.Q/filedataExp.Vtotal;
        resultsOut.MFM_fitData       = fitDataMFM;
        resultsOut.KL_MFM_CT         = KL_MFM_CT;
        resultsOut.dKL_MFM_CT        = dKL_MFM_CT;
        resultsOut.MFM_CT_bestModel  = string(mfmResCT.model);
        resultsOut.KL_MFM_UHS        = KL_MFM_UHS;
        resultsOut.dKL_MFM_UHS       = dKL_MFM_UHS;
        resultsOut.MFM_UHS_bestModel = string(mfmResUHS.model);
        resultsOut.D_cm2min          = D_cm2min;
        resultsOut.D_UHS_cm2min      = D_UHS_cm2min;

        for f = string(fieldnames(resultsOut))'
            expCTData.resultsAll.(dataSource).(f) = resultsOut.(f);
        end

        % Excel export, same sheet layout as the old script, per variant
        xlsxName = fullfile(pathExportAll, filedataExp.Key + "_KLresultsAll_" + dataSource + ".xlsx");
        if isfile(xlsxName), delete(xlsxName); end

        for variantArr = ["full","xtrim"]
            variant = variantArr;
            d = resultsOut.(variant);

            zDnames = fieldnames(d.KL_BTC_CT_byZD);
            btcRows = cell(numel(zDnames),1);
            metRows = cell(numel(zDnames),1);
            for m = 1:numel(zDnames)
                entry = d.KL_BTC_CT_byZD.(zDnames{m});
                base = struct('zD', entry.zD, 'L_eff_m', entry.L_eff, 'complete', entry.complete, ...
                              'bestMethod', string(entry.bestMethod));
                btcRows{m} = flatScalars(entry.best, 'best_', base);
                btcRows{m} = flatScalars(entry.allMethods, '', btcRows{m});
                metRows{m} = flatScalars(d.BTCMetrics_byZD.(zDnames{m}), '', struct('zD', entry.zD));
            end
            writetable(stackRows(btcRows), xlsxName, 'Sheet', "KL_BTC_byZD_" + variant);
            writetable(stackRows(metRows), xlsxName, 'Sheet', "BTCMetrics_byZD_" + variant);

            frontFns = fieldnames(d.KL_front_CT);
            frontT = table();
            for f = 1:numel(frontFns)
                S2 = d.KL_front_CT.(frontFns{f});
                frontT = [frontT; table(string(frontFns{f}), S2.fitWithIntercept, ...
                    S2.KL_cm2min_best, S2.KL_cm2min_se, S2.KL_cm2min_mean, S2.KL_cm2min_std, ...
                    S2.intercept_cm2, S2.R2, S2.nValidFrames, S2.nFramesTotal, S2.t_vertex_min, ...
                    'VariableNames', {'method','fitWithIntercept', ...
                                      'KL_cm2min_fit','KL_cm2min_se','KL_cm2min_mean','KL_cm2min_std', ...
                                      'intercept_cm2','R2','nSelected','nValid','t_vertex_min'})]; %#ok<AGROW>
            end
            writetable(frontT, xlsxName, 'Sheet', "KL_front_" + variant);

            if ~isempty(d.KL_midProfile.T)
                writetable(d.KL_midProfile.T, xlsxName, 'Sheet', "KL_midProfile_" + variant);
            end
            if isfield(d, 'KL_W0fit') && ~isempty(d.KL_W0fit)
                writetable(d.KL_W0fit, xlsxName, 'Sheet', "KL_W0fit_" + variant);
            end
            if isfield(d, 'KL_byArrival') && ~isempty(d.KL_byArrival)
                writetable(d.KL_byArrival, xlsxName, 'Sheet', "KL_byArrival_" + variant);
            end
            if isfield(d, 'KL_allProf') && ~isempty(d.KL_allProf)
                writetable(d.KL_allProf, xlsxName, 'Sheet', ...
                    sprintf('KL_allFrames_W%02d_%02d_%s', round(100*klAllPair), variant));
            end
            % per-frame widths vs time: 2D contours and averaged profile, side by side
            wCols = string(vars.Properties.VariableNames);
            if variant == "full"
                wSel = ~cellfun(@isempty, regexp(wCols, '^(zDWidth|zDWidthProf|zDWidthProfErfc)_\d+_\d+_cm$', 'once'));
            else
                wSel = ~cellfun(@isempty, regexp(wCols, '^(zDWidth|zDWidthProf|zDWidthProfErfc)_\d+_\d+_xtrim_cm$', 'once'));
            end
            wTab = [table(vars.tDtotal, vars.secondsElapsed/60 - t_arrival_min, ...
                'VariableNames', {'tDtotal','t_core_min'}), vars(:, wCols(wSel))];
            writetable(wTab, xlsxName, 'Sheet', "widths_vs_time_" + variant);
        end

        % arrival from the levels: per-level and joint fits of every source
        srcAL = string(fieldnames(arrLevels))';
        if ~isempty(srcAL)
            cP = cellfun(@(s_) arrLevels.(s_).perLevel, cellstr(srcAL), 'UniformOutput', false);
            cJ = cellfun(@(s_) arrLevels.(s_).joint,    cellstr(srcAL), 'UniformOutput', false);
            writetable(vertcat(cP{:}), xlsxName, 'Sheet', 'arrLevels_perLevel');
            writetable(vertcat(cJ{:}), xlsxName, 'Sheet', 'arrLevels_joint');
        end

        summaryT = table(string(fitDataMFM), ...
            KL_MFM_CT,  dKL_MFM_CT,  string(mfmResCT.model),  D_cm2min, ...
            KL_MFM_UHS, dKL_MFM_UHS, string(mfmResUHS.model), D_UHS_cm2min, ...
            'VariableNames', {'MFM_fitData', ...
            'KL_MFM_CT_cm2min','dKL_MFM_CT_cm2min','MFM_CT_bestModel','D12_CT_cm2min', ...
            'KL_MFM_UHS_cm2min','dKL_MFM_UHS_cm2min','MFM_UHS_bestModel','D12_UHS_cm2min'});
        for variantArr = ["full","xtrim"]
            mp = resultsOut.(variantArr).KL_midProfile;
            sfx = ternary_str(variantArr=="full", "", "_xtrim");
            for mm = string(fieldnames(mp.methods))'        % C10_90_contour, ..., erfc_lines, sigma_*, aliases
                r = mp.methods.(mm);
                summaryT.("KL_mid_" + mm + "_cm2min" + sfx)      = r.KL_cm2min_best;
                summaryT.("dKL_mid_" + mm + "_cm2min" + sfx)     = r.dKL_cm2min_best;
                summaryT.("KL_mid_" + mm + "_mean_cm2min" + sfx) = r.KL_cm2min_mean;
                summaryT.("KL_mid_" + mm + "_std_cm2min" + sfx)  = r.KL_cm2min_std;
            end
            summaryT.("midProfile_tD" + sfx) = mp.tD_best;
            if isfield(resultsOut.(variantArr), 'KL_W0fit') && ~isempty(resultsOut.(variantArr).KL_W0fit)
                TW0 = resultsOut.(variantArr).KL_W0fit;
                for q = 1:height(TW0)
                    nm = "W0fit_" + TW0.width(q) + "_" + TW0.pair(q);
                    summaryT.("KL_" + nm + "_cm2min" + sfx)  = TW0.KL_cm2min(q);
                    summaryT.("dKL_" + nm + "_cm2min" + sfx) = TW0.dKL_cm2min(q);
                    summaryT.("W0_" + nm + "_cm" + sfx)      = TW0.W0_cm(q);
                    summaryT.("dW0_" + nm + "_cm" + sfx)     = TW0.dW0_cm(q);
                    summaryT.("W0btc_" + nm + "_cm" + sfx)     = TW0.W0btc_cm(q);
                    summaryT.("W0btcCorr_" + nm + "_cm" + sfx) = TW0.W0btcCorr_cm(q);
                    nmR = "rot" + klRot + "_" + TW0.width(q) + "_" + TW0.pair(q);
                    summaryT.("KL_" + nmR + "_cm2min" + sfx)           = TW0.KLrot_cm2min(q);
                    summaryT.("KL_" + nmR + "_W0fit_cm2min" + sfx)     = TW0.KLrot_W0fit_cm2min(q);
                    summaryT.("KL_" + nmR + "_W0btc_cm2min" + sfx)     = TW0.KLrot_W0btc_cm2min(q);
                    summaryT.("KL_" + nmR + "_W0btcCorr_cm2min" + sfx) = TW0.KLrot_W0btcCorr_cm2min(q);
                    summaryT.(nmR + "_tD" + sfx)                         = TW0.rot_tD(q);
                end
            end
            sa = resultsOut.(variantArr).KL_allProfSum;
            if isfield(sa, 'prof')
                for wsrc = ["prof","cont"]
                    nm = sprintf('KL_allFrames_%s_%02d_%02d', wsrc, round(100*klAllPair));
                    summaryT.(nm + "_cm2min" + sfx)        = sa.(wsrc).KL_wmean;
                    summaryT.("d" + nm + "_cm2min" + sfx)  = sa.(wsrc).dKL_wmean;
                    summaryT.(nm + "_median_cm2min" + sfx) = sa.(wsrc).KL_median;
                    summaryT.(nm + "_std_cm2min" + sfx)    = sa.(wsrc).KL_std;
                    summaryT.(nm + "_n" + sfx)             = sa.(wsrc).n;
                end
            end
        end
        summaryT.vFront_cmmin      = vFront_cmmin;
        summaryT.uint_cmmin        = uint_cmmin;
        summaryT.tArr_contour_min  = tArrContour_min;
        summaryT.tArr_lines_min    = tLines_min;
        summaryT.t0_C50line_min    = t0C50_min;
        summaryT.R2_vFront_contour = NaN;
        if isfield(expCTData, 'resultsAll') && isfield(expCTData.resultsAll, dataSource) && ...
                isfield(expCTData.resultsAll.(dataSource), 'vFront') && isfield(expCTData.resultsAll.(dataSource).vFront, 'R2')
            summaryT.R2_vFront_contour = expCTData.resultsAll.(dataSource).vFront.R2;
        end
        for pvName = ["full","xtrim"]
            vp = vFrontProf.(pvName);  sfxP = ternary_str(pvName == "full", "", "_xtrim");
            summaryT.("vFrontProf_cmmin" + sfxP)  = vp.v_front_cmmin;
            summaryT.("t0_C50prof_min" + sfxP)    = vp.t0_min;
            summaryT.("R2_vFrontProf" + sfxP)     = vp.R2;
            summaryT.("nFit_vFrontProf" + sfxP)   = vp.nValidPts;
        end
        summaryT.vFrontProf_center = string(vfProfCenter);
        summaryT.tArr_levels_min   = tArrLev_min;
        summaryT.tArr_levels_ref   = tArrLevRef;
        summaryT.tD_arr_levels     = tArrLev_min*filedataExp.Q/filedataExp.Vtotal;
        for s_ = srcAL                                      % joint fit of every source
            summaryT.("t0s_joint2_" + s_ + "_min") = arrLevels.(s_).joint.t0s_joint2;
            summaryT.("t0c_joint2_" + s_ + "_min") = arrLevels.(s_).joint.t0c_joint2;
            summaryT.("KL_joint2_" + s_ + "_cm2min") = arrLevels.(s_).joint.KL_joint2;
            summaryT.("v50_" + s_ + "_cmmin")       = arrLevels.(s_).v50;
        end
        summaryT.tArr_profKL_ref   = string(tArrProfRef);
        summaryT.tArr_profKL_min   = tArrP;
        summaryT.tD_arr_profKL     = tArrD_P;
        summaryT.tArr_fitKL_ref    = string(tArrFitRef);
        summaryT.tArr_fitKL_min    = tArrF;
        summaryT.sigma_tArr_source = string(sigmaTau_mid);
        if ismember('tD_corr_vFrontC50', vars.Properties.VariableNames)
            summaryT.tD_corr_vFrontC50       = median(vars.tD_corr_vFrontC50,'omitnan');
            summaryT.tD_corr_vFrontC50_xtrim = median(vars.tD_corr_vFrontC50_xtrim,'omitnan');
        end
        writetable(summaryT, xlsxName, 'Sheet', 'Summary');

        % comparison plot
        % mid-profile bar = erfc width with the selected arrival (tArrProfRef)
        plotKLComparison(resultsOut, filedataExp.Key, dataSource, pathExportAll, [], [], "erfc_" + tArrProfRef);

    end

    expCTDataSave = expCTData;
    save(pathExportAll + filedataExp.Key + "_postproc.mat", 'expCTDataSave', '-v7.3')

end

%% local helpers
function out = ternary_str(cond, a, b)
if cond, out = a; else, out = b; end
end

function t = pickArrival(tArrAll, ref, key, ds)
% arrival time [min] of reference ref ("levels" | "C50" | "C50prof" | "contour" | "lines"); a missing
% level arrival falls back to the profile centre line, a missing profile centre line to the contour
% centre line, a missing C50 line to the contour arrival, a missing contour arrival is already the
% line-volume time
ref = string(ref);
if ~isfield(tArrAll, ref), error('unknown arrival reference "%s" (levels | C50 | C50prof | contour | lines)', ref); end
t = tArrAll.(ref);
if ~isfinite(t) && ref == "levels"
    warning('%s (%s): no level arrival -> profile C = 0.5 line used', key, ds);
    t = tArrAll.C50prof;  ref = "C50prof";
end
if ~isfinite(t) && ref == "C50prof"
    warning('%s (%s): no profile C = 0.5 front line (t0_C50prof) -> contour C = 0.5 line used', key, ds);
    t = tArrAll.C50;  ref = "C50";
end
if ~isfinite(t) && ref == "C50"
    warning('%s (%s): no C = 0.5 front line (t0_C50) -> contour arrival used', key, ds);
    t = tArrAll.contour;
end
end

function sel = rotZDsel(Tk, rot, tol, zDr, z0)
% frames at rotation rot +/- tol [deg] (wrapped) with the front centre (C = 0.5) inside zDr;
% of those, only the one whose centre is closest to z0 (default: middle of zDr) -- same rule as
% rotZDsel in main_CTplots (KL-by-method bar)
if nargin < 5 || isempty(z0), z0 = mean(zDr); end
dRot = mod(Tk.rotPos_deg - rot + 180, 360) - 180;
sel  = abs(dRot) <= tol & Tk.zD_center_C50 >= zDr(1) & Tk.zD_center_C50 <= zDr(2);
if isfinite(z0) && nnz(sel) > 1
    idx = find(sel);
    [~, b] = min(abs(Tk.zD_center_C50(idx) - z0));
    sel = false(size(sel));  sel(idx(b)) = true;
end
end


function A = candidateArrivals(tArrAll, AL)
% every candidate arrival [min]: name/value of tArrAll (levels, C50, C50prof, contour, lines), every
% level of every source of arrLevels (curved per-level t0, "<src>_C<CC>"), and their joint2 t0s / t0c
nm = string(fieldnames(tArrAll));  val = cellfun(@(f) tArrAll.(f), cellstr(nm));
for s_ = string(fieldnames(AL))'
    P  = AL.(s_).perLevel;
    nm  = [nm; s_ + "_C" + compose("%02d", round(100*P.C))];      %#ok<AGROW>
    val = [val; P.t0_curve_min];                                   %#ok<AGROW>
    nm  = [nm; s_ + "_joint2_t0s"; s_ + "_joint2_t0c"];            %#ok<AGROW>
    val = [val; AL.(s_).joint.t0s_joint2; AL.(s_).joint.t0c_joint2]; %#ok<AGROW>
end
A = table(nm, val, 'VariableNames', {'arrival','t_arr_min'});
A = A(isfinite(A.t_arr_min), :);
end

function T = KL_byArrival(vars, sfx, pair, A, fd, dtArr, zDr, rot, rotTol, rotZD)
% KL_allProfileWidths for every arrival of A: inverse-variance weighted mean, median and n over the
% frames with the centre in zDr (profile and 2D contours), and the KL of the frame at theta = rot
% (rotZDsel: centre closest to zD = 0.5 within rotZD) with its tau
tag = sprintf('%02d_%02d', round(100*pair));  rows = cell(height(A),1);
for q = 1:height(A)
    tA = A.t_arr_min(q);
    [Tq, Sq] = KL_allProfileWidths(vars, sfx, pair, tA, tA*fd.Q/fd.Vtotal, dtArr, zDr);
    KLr = NaN;  dKLr = NaN;  tauR = NaN;
    sel = rotZDsel(Tq, rot, rotTol, rotZD);
    if any(sel)
        KLr  = Tq.("KL_prof_" + tag + "_cm2min")(find(sel,1));
        dKLr = Tq.("dKL_prof_" + tag + "_cm2min")(find(sel,1));
        tauR = Tq.tau_min(find(sel,1));
    end
    rows{q} = table(A.arrival(q), tA, tA*fd.Q/fd.Vtotal, Sq.prof.n, Sq.prof.KL_wmean, Sq.prof.dKL_wmean, ...
        Sq.prof.KL_median, Sq.cont.KL_wmean, Sq.cont.KL_median, KLr, dKLr, tauR, ...
        'VariableNames', {'arrival','t_arr_min','tD_arr','n_prof','KL_prof_wmean','dKL_prof_wmean', ...
        'KL_prof_median','KL_cont_wmean','KL_cont_median', ...
        sprintf('KL_rot%d_prof', rot), sprintf('dKL_rot%d_prof', rot), sprintf('tau_rot%d_min', rot)});
end
T = vertcat(rows{:});
end

function [AL, tArrLev, refTag] = arrivalLevels(vars, fd, rA, o, plotBase)
% ARRIVALLEVELS  Arrival time from the trajectories z_C(t) of every level C = o.levels (0.01 ... 0.5),
% for every level source in o.sources:
%   "contour": mean z of the C contour (zDFront<CC><o.variant>_cm, main_CTpreproc)
%   "profile": crossing of level C on the averaged profile CVert<o.variant> (profLevels: as profileWidth,
%              low levels also before the C = 0.5 crossing exists, anchored at the inlet side)
% Frames used per level: 0.03 < z_D < 0.97 (as frontVel); t in min since the start of injection.
% ADE form of each level: z_C = v (t - t0_C) + a_C sqrt(t - t0_C), a_C = 2 erfcinv(2C) sqrt(KL) >= 0 for
% C < 0.5 (else a_C = 0: straight line), v = v50 of that source's C = 0.5 line when o.useV50.
% Fits:  perLevel  : t0_C (curve) and the straight-line t0 of every level
%        joint1    : all levels, one origin  z = v (t - t0) + 2 erfcinv(2C) sqrt(KL (t - t0))
%        joint2    : all levels, two origins z = v (t - t0c) + 2 erfcinv(2C) sqrt(KL (t - t0s))
% Returns AL.(source).perLevel / .joint (tables), .v50, .levels; the stored arrival tArrLev [min] =
% o.refFit of level o.refLevel of o.refSource ("curve" t0_C | "line" t0 | "t0s" joint2), refTag its name.
t  = vars.secondsElapsed/60;  vn = string(vars.Properties.VariableNames);
[Zprof, ZDprof] = profLevels(vars.C1Profile, "CVert" + o.variant, fd.C1init/100, fd.C1j/100, o.levels);
tArrC = NaN;  if isfield(rA, 'tD_arrival_contour'), tArrC = rA.tD_arrival_contour*fd.Vtotal/fd.Q; end
AL = struct();
for src = o.sources
    % ---- level positions
    T = [];  lv = [];
    for qL = 1:numel(o.levels)
        C = o.levels(qL);
        if src == "contour"
            cz = "zDFront" + sprintf('%02d', round(100*C)) + o.variant;
            if ~all(ismember([cz, cz + "_cm"], vn)), continue, end
            z = vars.(cz + "_cm");  zD = vars.(cz);
        else
            z = Zprof(:,qL);  zD = ZDprof(:,qL);
        end
        ok = isfinite(t) & isfinite(z) & zD > 0.03 & zD < 0.97;
        if nnz(ok) < 5, continue, end
        T = [T; t(ok), z(ok), C*ones(nnz(ok),1)]; %#ok<AGROW>
        lv(end+1) = C; %#ok<AGROW>
    end
    if isempty(lv), warning('%s: no %s level traced', fd.Key, src); continue, end
    % ---- velocity of the C = 0.5 line
    v50 = NaN;
    if any(abs(lv - 0.5) < 1e-9)
        s50 = abs(T(:,3) - 0.5) < 1e-9;  p50 = polyfit(T(s50,1), T(s50,2), 1);  v50 = p50(1);
    elseif o.useV50
        warning('%s (%s): no C = 0.5 level -> velocity fitted freely', fd.Key, src);
    end
    vFix = NaN;  if o.useV50, vFix = v50; end
    % ---- per level
    rowsL = cell(numel(lv),1);  lvT0 = nan(size(lv));  lvV = lvT0;  lvA = lvT0;
    for q = 1:numel(lv)
        C = lv(q);  s = T(:,3) == C;  tt = T(s,1);  zz = T(s,2);
        p = polyfit(tt, zz, 1);
        if abs(C - 0.5) < 1e-9
            t0q = -p(2)/p(1);  vq = p(1);  aq = 0;
        else
            [t0q, vq, aq] = fitLevelCurve(tt, zz, min(tt) - o.search, min(tt) - 1e-3, sign(0.5 - C), vFix);
        end
        lvT0(q) = t0q;  lvV(q) = vq;  lvA(q) = aq;
        eC = 2*erfcinv(2*C);  KLq = NaN;  if abs(eC) > 1e-6, KLq = (aq/eC)^2; end
        rowsL{q} = table(src, C, nnz(s), -p(2)/p(1), p(1), t0q, vq, aq, KLq, ...
            'VariableNames', {'source','C','n','t0_line_min','v_line_cmmin', ...
            't0_curve_min','v_curve_cmmin','a_curve','KL_curve_cm2min'});
    end
    % ---- all levels together
    e   = 2*erfcinv(2*T(:,3));
    tHi = min(T(:,1)) - 1e-3;  tLo = tHi - o.search;
    t0a = gridFminbnd(@(x) jointSSE(T(:,1), T(:,2), e, x, x, vFix), tLo, tHi);
    [~, va, ~, KLa] = jointSSE(T(:,1), T(:,2), e, t0a, t0a, vFix);
    t0s = gridFminbnd(@(x) jointSSE(T(:,1), T(:,2), e, NaN, x, vFix), tLo, tHi);
    [sseB, vb, t0c, KLb] = jointSSE(T(:,1), T(:,2), e, NaN, t0s, vFix);
    J = table(src, numel(lv), size(T,1), v50, t0a, va, KLa, t0c, t0s, t0c - t0s, vb, KLb, sqrt(sseB/size(T,1)), ...
        'VariableNames', {'source','nLevels','nPts','v50_cmmin','t0_joint1','v_joint1','KL_joint1', ...
        't0c_joint2','t0s_joint2','t0c_minus_t0s','v_joint2','KL_joint2','rmse_joint2_cm'});
    PL = vertcat(rowsL{:});
    AL.(src) = struct('perLevel', PL, 'joint', J, 'v50', v50, 'levels', lv, 'variant', o.variant, 'useV50', o.useV50);
    % ---- print
    fprintf('  arrival levels (%s%s, v = %s): t0 per level [min]:', src, o.variant, ternary_str(o.useV50, "v50", "free"));
    fprintf('  C%02d %.1f', [round(100*lv); lvT0]);
    fprintf('\n    joint2: t0s = %.1f, t0c = %.1f min, v = %.3g cm/min, KL = %.3g cm2/min\n', t0s, t0c, vb, KLb);
    % ---- figures
    if o.doPlot
        cm = parula(numel(lv) + 1);  tEnd = max(T(:,1));
        for pk = o.plots
            fig = figure('Position',[100 100 1000 650], 'Visible', ternary_str(o.closeFig, 'off', 'on'));
            ax = axes(fig);  hold(ax,'on');  hh = gobjects(0);
            for q = 1:numel(lv)
                s = T(:,3) == lv(q);
                switch pk
                    case "joint1"
                        tf = linspace(t0a, tEnd, 400)';
                        zf = va*(tf - t0a) + 2*erfcinv(2*lv(q))*sqrt(max(KLa,0)*(tf - t0a));
                        nm = sprintf('C = %.2f', lv(q));
                    case "perLevel"
                        tf = linspace(lvT0(q), tEnd, 400)';
                        zf = lvV(q)*(tf - lvT0(q)) + lvA(q)*sqrt(tf - lvT0(q));
                        nm = sprintf('C = %.2f, t_0 = %.1f', lv(q), lvT0(q));
                        plot(ax, lvT0(q), 0, 'o', 'MarkerSize',8, 'MarkerFaceColor',cm(q,:), ...
                            'MarkerEdgeColor','k', 'HandleVisibility','off')
                    case "joint2"
                        tf = linspace(t0s, tEnd, 400)';
                        zf = vb*(tf - t0c) + 2*erfcinv(2*lv(q))*sqrt(max(KLb,0)*(tf - t0s));
                        nm = sprintf('C = %.2f', lv(q));
                end
                hh(end+1) = scatter(ax, T(s,1), T(s,2), 8, cm(q,:), 'filled', 'DisplayName', nm); %#ok<AGROW>
                plot(ax, tf, zf, '-', 'Color',0.7*cm(q,:), 'LineWidth',1.5, 'HandleVisibility','off')
            end
            switch pk
                case "joint1"
                    xline(ax, t0a, 'k--', 't_{arr}', 'LineWidth',1.5, 'HandleVisibility','off');
                    ttl = sprintf('one ADE, common origin: t_{arr} = %.1f min, v = %.3g cm/min, K_L = %.3g cm^2/min', t0a, va, KLa);
                case "perLevel"
                    ttl = sprintf('one ADE form per level: t_0 from %.1f (C = %.2f) to %.1f min (C = %.2f)', ...
                        lvT0(1), lv(1), lvT0(end), lv(end));
                case "joint2"
                    xline(ax, t0s, 'k--', 't_{0s}', 'LineWidth',1.5, 'HandleVisibility','off');
                    xline(ax, t0c, 'k-',  't_{0c}', 'LineWidth',1.5, 'HandleVisibility','off');
                    ttl = sprintf('two origins: t_{0s} = %.1f, t_{0c} = %.1f min, v = %.3g cm/min, K_L = %.3g cm^2/min', t0s, t0c, vb, KLb);
            end
            if isfinite(tArrC), xline(ax, tArrC, 'r:', 't_{arr,C=0.01}', 'LineWidth',1.5, 'HandleVisibility','off'); end
            yline(ax, 0, 'k-', 'HandleVisibility','off');
            set(ax, 'FontSize',16);  grid(ax,'on');  box(ax,'on')
            xlabel(ax, 't [min]');  ylabel(ax, "z of the level [cm] (" + src + ")")
            title(ax, {strrep(fd.Key,'_','\_') + " (" + src + " levels)", ttl}, 'FontSize',12)
            legend(ax, hh, 'Location','northwest', 'FontSize',12)
            saveas(fig, plotBase + "_" + src + "_" + pk + ".png");
            if o.closeFig, close(fig); end
        end
    end
end
% ---- stored arrival
tArrLev = NaN;  refTag = o.refSource + "_" + o.refFit;
if o.refFit ~= "t0s", refTag = refTag + sprintf("_C%02d", round(100*o.refLevel)); end
if isfield(AL, o.refSource)
    A  = AL.(o.refSource);
    rL = A.perLevel(abs(A.perLevel.C - o.refLevel) < 1e-9, :);
    switch o.refFit
        case "curve", if height(rL) > 0, tArrLev = rL.t0_curve_min(1); end
        case "line",  if height(rL) > 0, tArrLev = rL.t0_line_min(1);  end
        case "t0s",   tArrLev = A.joint.t0s_joint2(1);
        otherwise,    error('arrOpt.refFit must be "curve", "line" or "t0s"');
    end
end
if ~isfinite(tArrLev), warning('%s: no level arrival from %s', fd.Key, refTag); end
end

function [t0, v, a] = fitLevelCurve(t, z, tLo, tHi, sgn, vFix)
% z = v (t - t0) + a sqrt(t - t0); linear in v, a for a given t0 -> 1D search on t0.
% ADE form: a = 2 erfcinv(2C) sqrt(KL), so sign(a) = sgn = sign(0.5 - C): for C < 0.5, a >= 0 (the
% level is ahead of the centre and its curve rises from z = 0 at t0). A wrong-sign a lets the curve
% dip below z = 0 and puts t0 far too early (artifact) -> a = 0 instead (straight line from t0).
% vFix (finite): v fixed (e.g. v of the C = 0.5 line), only t0 and a fitted.
if nargin < 6, vFix = NaN; end
t0 = gridFminbnd(@(x) levelSSE(t, z, x, sgn, vFix), tLo, tHi);
[~, v, a] = levelSSE(t, z, t0, sgn, vFix);
end

function [sse, v, a] = levelSSE(t, z, t0, sgn, vFix)
tau = t - t0;  r = sqrt(tau);
if isnan(vFix)
    X = [tau, r];  p = X\z;
    if p(2) ~= 0 && sign(p(2)) ~= sgn        % constraint active: a = 0, z = v (t - t0)
        p = [tau\z; 0];
    end
    v = p(1);  a = p(2);
else
    v = vFix;  y = z - v*tau;  a = r\y;      % z - v (t - t0) = a sqrt(t - t0)
    if a ~= 0 && sign(a) ~= sgn, a = 0; end
end
sse = sum((z - v*tau - a*r).^2);
end

function [sse, v, t0c, KL] = jointSSE(t, z, e, t0c, t0s, vFix)
% all levels: z = v (t - t0c) + e sqrt(KL (t - t0s)), e = 2 erfcinv(2C)
% t0c = NaN: t0c free (from the intercept), else fixed (= t0s for the one-origin fit)
% vFix (finite): v fixed (e.g. v of the C = 0.5 line); sqrt(KL) >= 0 (else KL = 0)
if nargin < 6, vFix = NaN; end
s = e.*sqrt(t - t0s);
if isnan(vFix)
    if isnan(t0c)
        X = [t, ones(size(t)), s];  p = X\z;
        if p(3) < 0, p = [X(:,1:2)\z; 0]; end
        v = p(1);  t0c = -p(2)/p(1);  q = p(3);  zh = X*p;
    else
        X = [t - t0c, s];  p = X\z;
        if p(2) < 0, p = [X(:,1)\z; 0]; end
        v = p(1);  q = p(2);  zh = X*p;
    end
else
    v = vFix;
    if isnan(t0c)                            % z - v t = -v t0c + q s
        X = [ones(size(t)), s];  p = X\(z - v*t);
        if p(2) < 0, p = [mean(z - v*t); 0]; end
        t0c = -p(1)/v;  q = p(2);  zh = v*t + X*p;
    else                                     % z - v (t - t0c) = q s
        q = s\(z - v*(t - t0c));  if q < 0, q = 0; end
        zh = v*(t - t0c) + q*s;
    end
end
sse = sum((z - zh).^2);
KL  = q^2;
end

function x = gridFminbnd(f, lo, hi)
% coarse grid, then fminbnd around the best grid point (avoids local minima)
g = linspace(lo, hi, 241);  F = arrayfun(f, g);  [~, k] = min(F);
x = fminbnd(f, g(max(k-1,1)), g(min(k+1,numel(g))));
end

function [Z, ZD] = profLevels(profCol, cCol, Ci, Cj, levels, trimFrac, nSmooth)
% Position of every level C on the averaged profile of every frame, as profileWidth does it:
% Cn = (C - Ci)/(Cj - Ci), 2 % of the column dropped at each end, injection end first, 5-slice moving
% median; anchor = the Cn = 0.5 down-crossing with the steepest drop; levels < 0.5 searched downstream
% of it, levels > 0.5 upstream (linear interpolation between slices). Before the centre is inside
% (no Cn = 0.5 crossing), the anchor is the highest Cn in the first 20 % of the column (inlet side),
% so the low levels (C = 0.01, 0.05, ...) are found from their first appearance, as the contours.
% z from the injection end [cm],
% zD = z / image length. Z, ZD: frames x levels (NaN where the level is not crossed).
if nargin < 6, trimFrac = 0.02; end
if nargin < 7, nSmooth = 5; end
if iscell(profCol) || isstruct(profCol), n = numel(profCol); else, n = height(profCol); end
Z = nan(n, numel(levels));  ZD = Z;
for r = 1:n
    pr = getProfRow(profCol, r);
    if isempty(pr) || ~ismember(cCol, string(pr.Properties.VariableNames)), continue, end
    z = double(pr.zVertcm(:));  C = double(pr.(cCol)(:));
    ok = isfinite(z) & isfinite(C);  z = z(ok);  C = C(ok);
    if numel(z) < 10, continue, end
    Limg = max(z);
    [z, o] = sort(z);  C = C(o);  Cn = (C - Ci)/(Cj - Ci);
    L  = z(end) - z(1);
    in = z >= z(1) + trimFrac*L & z <= z(end) - trimFrac*L;  z = z(in);  Cn = Cn(in);
    nE = ceil(numel(Cn)/5);
    if mean(Cn(1:nE)) < mean(Cn(end-nE+1:end)), Cn = flipud(Cn); end
    zz = z - z(1) + trimFrac*L;  Cm = movmedian(Cn, nSmooth);
    k50 = find(Cm(1:end-1) >= 0.5 & Cm(2:end) < 0.5);
    if isempty(k50)
        % centre not inside yet: anchor at the highest Cn in the first 20 % (inlet side), so the low
        % levels already in the core are found as soon as they appear (as the contours); levels >= 0.5
        % stay NaN until the C = 0.5 crossing exists
        nA = max(2, ceil(0.2*numel(Cm)));  [cMax, k50] = max(Cm(1:nA));
        if cMax <= min(levels), continue, end
        noCentre = true;
    else
        g = -gradient(Cm, zz);  [~, b] = max(g(k50));  k50 = k50(b);
        noCentre = false;
    end
    for q = 1:numel(levels)
        c = levels(q);
        if noCentre && c >= 0.5, continue, end
        if abs(c - 0.5) < 1e-9
            zc = interpLev(zz, Cm, k50, 0.5);
        elseif c < 0.5                                   % downstream of the centre
            j = find(Cm(k50+1:end) < c, 1);  zc = NaN;
            if ~isempty(j), j = k50 + j;  zc = interpLev(zz, Cm, j-1, c); end
        else                                             % upstream of the centre
            j = find(Cm(1:k50) > c, 1, 'last');  zc = NaN;
            if ~isempty(j) && j < numel(Cm), zc = interpLev(zz, Cm, j, c); end
        end
        Z(r,q) = zc;  ZD(r,q) = zc/Limg;
    end
end
end

function zc = interpLev(z, C, k, c0)
% position of c0 between samples k and k+1
if C(k) == C(k+1), zc = z(k); return, end
zc = z(k) + (c0 - C(k))*(z(k+1) - z(k))/(C(k+1) - C(k));
end

function pr = getProfRow(col, l)
if iscell(col), pr = col{l}; elseif istable(col), pr = col(l,:); else, pr = col(l); end
if iscell(pr), pr = pr{1}; end
if isstruct(pr), pr = struct2table(pr); end
end