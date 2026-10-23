%% main_CTpostproc.m
% KL estimation, mirroring the structure of the old main_CTpreproc.m KL
% block, extended to:
%   - fit the BTC/CDE method for both full and x-trimmed CD1_zD* columns
%   - weight the BTC fit by dConc_std (not ones(...), as the old script did)
%   - add front-width (all symmetric pairs) and moment (sigma) KL, full+xtrim
%   - carry the MFM reference KL
%   - plot fitted BTC vs scatter, and compare all methods

%% IMPORT input
Root = CT_setupPaths;
inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

%% Extract data from images, preproc and MFM

for i = 1:height(inputFileConfig)

    filenameExp   = inputFileConfig.inputFileName{i};
    pathExportAll = inputFileConfig.exportPath{i};

    filedataExp = import_inputCTExp(filenameExp);

    pathImport_MFM_CT = regexprep(inputFileConfig.MFM_BTC_CT_Path{i}, '^(\.\./)+', '');
    MFM_CT_name = inputFileConfig.MFM_BTC_CT_Key{i};
    MFM_CT_file = fullfile(Root, pathImport_MFM_CT, 'expProcFullData.mat');
    if ~isfile(MFM_CT_file)
        error('MFM results file not found: %s', MFM_CT_file);
    end
    MFM_CT_Data = load(MFM_CT_file);
    expProcFullData_MFM_CT = MFM_CT_Data.expProcFullData.(MFM_CT_name);

    % experiment data all in cm (not m) and min (not seconds) -- same as main_CTpreproc.m
    Ci = filedataExp.C1init/100;
    Cj = filedataExp.C1j/100;
    uint_cmmin = filedataExp.Q/(filedataExp.phi*pi*((filedataExp.D*2.54/2)^2));
    L_cm = filedataExp.L*2.54;
    D_MFM = expProcFullData_MFM_CT.exp_params.D12_cm2min;

    u_SI = uint_cmmin/(60*100);
    L_SI = L_cm/100;
    dt_guess = 0;
    Cmin = 0.16; Cmax = 0.84;

    zDlevels_KLfit = 0.1:0.1:1.0;

    % tcore reference, same convention as the old populate_CTframeVars:
    % time (minutes) to clear the line volume before the core
    tLines_min = filedataExp.Vlinesbefore/filedataExp.Q;

    % load the data produced by main_CTpreproc.m
    expCT_name = pathExportAll + filedataExp.Key;
    S = load(expCT_name + ".mat");
    expCTData = S.expCTDataSave;

    fitWithIntercept = false;   % false = force fit through origin (physically expected)

    for dataSource = ["rhoNorm","conc"]

        vars = expCTData.varsAll.(dataSource);
        t_arrival_min = max(tLines_min, 0);   % scalar, broadcasts in fitKL_frontWidth/fitKL_moments

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
                else
                    dC_vals = zeros(size(tD_vals));
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

            % KL from front width growth -- one best-fit KL per pair,
            % with its standard error from the regression
            KL_width_byPair = fitKL_frontWidth(vars, t_arrival_min, variantSuffix, fitWithIntercept);
            widthFns = fieldnames(KL_width_byPair);
            KL_front = struct();
            for f = 1:numel(widthFns)
                S2 = KL_width_byPair.(widthFns{f});
                KL_front.("width_" + widthFns{f}) = struct( ...
                    'KL_cm2min_best', S2.KL_cm2min, ...
                    'KL_cm2min_se',   S2.KL_cm2min_se, ...
                    'R2',             S2.R2, ...
                    'intercept_cm2',  S2.intercept_cm2, ...
                    'nValidFrames',   S2.nPts);
            end

            % KL from moments (sigma) -- one best-fit KL, with fit SE
            S3 = fitKL_moments(vars, t_arrival_min, variantSuffix, fitWithIntercept);
            KL_front.sigma = struct( ...
                'KL_cm2min_best', S3.KL_cm2min, ...
                'KL_cm2min_se',   S3.KL_cm2min_se, ...
                'R2',             S3.R2, ...
                'intercept_cm2',  S3.intercept_cm2, ...
                'nValidFrames',   S3.nPts);

            resultsOut.(variant).KL_front_CT = KL_front;
        end

        resultsOut.KL_MFM = D_MFM;

        expCTData.resultsAll.(dataSource) = resultsOut;

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
                frontT = [frontT; table(string(frontFns{f}), S2.KL_cm2min_best, S2.KL_cm2min_se, ...
                    S2.R2, S2.nValidFrames, ...
                    'VariableNames', {'method','KL_cm2min_best','KL_cm2min_se','R2','nValidFrames'})]; %#ok<AGROW>
            end
            writetable(frontT, xlsxName, 'Sheet', "KL_front_" + variant);
        end

        summaryT = table(D_MFM, 'VariableNames', {'KL_MFM_cm2min'});
        if ismember('tD_corr_vFrontC50', vars.Properties.VariableNames)
            summaryT.tD_corr_vFrontC50       = median(vars.tD_corr_vFrontC50,'omitnan');
            summaryT.tD_corr_vFrontC50_xtrim = median(vars.tD_corr_vFrontC50_xtrim,'omitnan');
        end
        writetable(summaryT, xlsxName, 'Sheet', 'Summary');

        % comparison plot
        plotKLComparison(resultsOut, filedataExp.Key, dataSource, pathExportAll);

    end

    expCTDataSave = expCTData;
    save(pathExportAll + filedataExp.Key + "_postproc.mat", 'expCTDataSave', '-v7.3')

end

%% local helper
function out = ternary_str(cond, a, b)
if cond, out = a; else, out = b; end
end