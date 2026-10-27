%% main_CTplots.m
% Comparative plots of CT-derived concentration profiles, breakthrough
% curves (CT and MFM), front widths/envelopes, front planarity and KL.
%
% Both CT data sources are loaded for every experiment:
%       rhoNorm  <->  MFM fitData "woEOS"
%       conc     <->  MFM fitData "wEOS"
% and every block below is produced once per data source (one figure per
% data source, all experiments together). Figures that merge rhoNorm and
% conc are meant to be added in later blocks.
%
% Inputs
%   inputCTExpConfig.xlsx  (inputFileName, exportPath, MFM_BTC_CT_Path/Key,
%                           MFM_BTC_UHS_Path/Key)
%   <Key>_postproc.mat     from main_CTpostproc.m (falls back to <Key>.mat
%                          from main_CTpreproc.m; KL blocks then skipped)
%   expProcFullData.mat    from main_Processing.m (MFM analog + UHS)
%
% Blocks
%   1  Z profile closest to (zD, CD) target
%   2  Z profiles at a range of tD targets
%   3  CT outlet BTC vs time, tD_total and front-velocity-scaled tD_core
%   4  MFM analog BTC
%   5  MFM UHS BTC
%   6  MFM analog + UHS BTC together
%   7  measured front width vs tD
%   8  measured front envelope, all experiments together
%   9  front tilt / shape diagnostics vs tD and rotation
%   10 KL vs tD (pointwise front KL) + BTC-CT and MFM reference KL
%   11 outlet BTC width (tD16-tD84) per experiment
%   12 front tilt vs rotation position, coloured by tD

%% SETTINGS

Root = CT_setupPaths;

inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

exportPath = 'results/';
if ~isfolder(exportPath), mkdir(exportPath); end

dataSources = ["rhoNorm","conc"];
fitDataOf   = struct('rhoNorm',"woEOS",    'conc',"wEOS");   % CT source -> MFM variant
mfmCol      = struct('rhoNorm','rho_norm', 'conc','CDi');    % MFM BT column per source
mfmTimeVar  = 'tD';           % MFM BT time axis ('tD' core-based, or 'tDtotal')

closeAfterSave = false;       % true: close each figure once saved

%% Load data

nExp = height(inputFileConfig);
filedataExpAll  = cell(nExp,1);
expCTDataAll    = cell(nExp,1);
MFM_CT_DataAll  = cell(nExp,1);   % MFM_CT_DataAll{i}.(dataSource)  -> BT, results, exp_params
MFM_UHS_DataAll = cell(nExp,1);
hasPost         = false(nExp,1);
expKeys         = strings(nExp,1);

for i = 1:nExp
    filenameExp   = inputFileConfig.inputFileName{i};
    pathExportAll = inputFileConfig.exportPath{i};

    filedataExpAll{i} = import_inputCTExp(filenameExp);
    expKeys(i) = string(filedataExpAll{i}.Key);

    % CT: postproc file (varsAll + resultsAll with KL), else preproc file
    postFile = fullfile(pathExportAll, expKeys(i) + "_postproc.mat");
    preFile  = fullfile(pathExportAll, expKeys(i) + ".mat");
    if isfile(postFile)
        temp = load(postFile);
        hasPost(i) = true;
    else
        warning('%s: no _postproc.mat, loading preproc file (KL blocks skipped)', expKeys(i));
        temp = load(preFile);
    end
    expCTDataAll{i} = temp.expCTDataSave;

    % MFM analog (CT) and UHS, one variant per CT data source
    pathImport_MFM_CT  = regexprep(inputFileConfig.MFM_BTC_CT_Path{i},  '^(\.\./)+', '');
    pathImport_MFM_UHS = regexprep(inputFileConfig.MFM_BTC_UHS_Path{i}, '^(\.\./)+', '');
    MFM_CT_file  = fullfile(Root, pathImport_MFM_CT,  'expProcFullData.mat');
    MFM_UHS_file = fullfile(Root, pathImport_MFM_UHS, 'expProcFullData.mat');

    MFM_CT_DataAll{i}  = loadMFMbyDataSource(MFM_CT_file,  inputFileConfig.MFM_BTC_CT_Key{i},  fitDataOf);
    MFM_UHS_DataAll{i} = loadMFMbyDataSource(MFM_UHS_file, inputFileConfig.MFM_BTC_UHS_Key{i}, fitDataOf);
end

% one colour per experiment (first four = original palette)
baseCols = [0.318 0.654 0.976; 0.09 0.306 0.525; 0.435 0.753 0.251; 0.059 0.361 0.102];
if nExp > size(baseCols,1)
    cols = [baseCols; lines(nExp - size(baseCols,1))];
else
    cols = baseCols(1:nExp,:);
end
colsDark = 0.6*cols;
markers  = {'o','s','^','d','v','>','<','p','h'};

%% 1) Z profile closest to (zD, CD) target

ZD_target = 0.5;
CD_target = 0.5;

for ds = dataSources
    fig = figure;  hold on
    legendEntries = strings(1,nExp);

    for i = 1:nExp
        vars = expCTDataAll{i}.varsAll.(ds);

        best_dist = inf;  best_l = NaN;
        for l = 1:height(vars)
            prof = cellRow(vars.C1Profile, l);
            dist = min((prof.zDimLess - ZD_target).^2 + (prof.CVert - CD_target).^2);
            if dist < best_dist
                best_dist = dist;  best_l = l;
            end
        end
        if isnan(best_l), continue, end

        prof = cellRow(vars.C1Profile, best_l);
        plot(prof.zDimLess, prof.CVert, 'LineWidth',3, 'Color',cols(i,:))
        legendEntries(i) = sprintf('%s_tD_%.2f', expKeys(i), vars.tDtotal(best_l));
    end
    xlabel('Z_D [-]','FontSize',14);  ylabel('C_1 [-]','FontSize',14)
    xlim([0 1]);  ylim([0 1]);  set(gca,'FontSize',14);  grid on
    legend(legendEntries(legendEntries ~= ""), 'Interpreter','none','FontSize',9)
    title(sprintf('Z profiles through (z_D, C_D) = (%.1f, %.1f) (%s)', ZD_target, CD_target, ds), ...
        'Interpreter','tex')

    fname = sprintf('CT_profile_zD_%s_CD_%s_%s', strrep(sprintf('%.1f',ZD_target),'.','p'), ...
        strrep(sprintf('%.1f',CD_target),'.','p'), ds);
    saveFigBoth(fig, exportPath, fname, closeAfterSave)
end

%% 2) Z profiles at a range of tD targets

tD_target = 0.5:0.1:1.2;

for ds = dataSources
    for m = 1:numel(tD_target)
        fig = figure;  hold on
        legendEntries = strings(1,nExp);

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            [minDist, l] = min(abs(vars.tDtotal - tD_target(m)));
            if minDist > 0.05
                warning('%s (%s): nearest scan is tD=%.3f (target %.2f)', ...
                    expKeys(i), ds, vars.tDtotal(l), tD_target(m));
            end
            prof = cellRow(vars.C1Profile, l);
            plot(prof.zDimLess, prof.CVert, 'LineWidth',3, 'Color',cols(i,:))
            legendEntries(i) = expKeys(i) + sprintf(" (tD=%.2f)", vars.tDtotal(l));
        end
        xlabel('Z_D [-]','FontSize',14);  ylabel('C_1 [-]','FontSize',14)
        xlim([0 1]);  ylim([0 1]);  set(gca,'FontSize',14);  grid on
        if tD_target(m) < 0.8, loc = 'northeast'; else, loc = 'southwest'; end
        legend(legendEntries, 'Interpreter','none','FontSize',8,'Location',loc)
        title(sprintf('Z profiles (%s) @ tD = %.1f', ds, tD_target(m)), 'Interpreter','none')

        fname = sprintf('Zprofiles_%s_tD%s', ds, strrep(sprintf('%.1f',tD_target(m)),'.','p'));
        saveFigBoth(fig, exportPath, fname, closeAfterSave)
    end
end

%% 3) CT outlet BTC: time, tD_total, front-velocity-scaled tD_core

CfieldOutlet = 'CD1_zD1p0';
% {x column, x label, file tag, x limits ([] = auto)}
btcAxes = {'timeElapsed',            'time elapsed [hh:mm:ss]',                   'time',         []; ...
           'tDtotal',                't_D [-]',                                   'tD',           [0 1.2]; ...
           'tD_corr_contour_scaled', 't_{D,core} (v_{front}-scaled, contour arrival) [-]', 'tDcoreScaled', [0 1.2]};

for ds = dataSources
    for a = 1:size(btcAxes,1)
        xVar = btcAxes{a,1};
        fig = figure;  hold on
        nPlotted = 0;

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            if ~ismember(xVar, vars.Properties.VariableNames)
                warning('%s (%s): column %s missing, skipped', expKeys(i), ds, xVar);
                continue
            end
            plot(vars.(xVar), vars.(CfieldOutlet), 'LineWidth',2, 'Color',cols(i,:), ...
                'DisplayName', "CT " + expKeys(i))
            nPlotted = nPlotted + 1;
        end
        if nPlotted == 0, close(fig); continue, end

        xlabel(btcAxes{a,2},'FontSize',14);  ylabel('C_1 [-]','FontSize',14)
        ylim([-0.02 1]);  set(gca,'FontSize',14);  grid on
        if ~isempty(btcAxes{a,4}), xlim(btcAxes{a,4}); end
        legend('Interpreter','none','FontSize',8,'Location','southeast')
        title(sprintf('Outlet BT curves from CT (%s)', ds), 'Interpreter','none')

        saveFigBoth(fig, exportPath, sprintf('BT_CT_%s_%s', ds, btcAxes{a,3}), closeAfterSave)
    end
end

%% 3b) CT BTCs at every zD level vs tD_total and tD_core (one figure per experiment)

zDlevelsPlot = 0:0.1:1.0;
btcVariant   = "";            % "" = full x-range, "_xtrim" = x-trimmed columns
zDcols       = parula(numel(zDlevelsPlot) + 1);   % +1 avoids the pale last colour
% {x column, x label, x limits}
zDaxes = {'tDtotal',                't_D [-]',                                        [0 1.2]; ...
          'tD_corr_contour_scaled', 't_{D,core} (v_{front}-scaled, contour arrival) [-]', [-0.2 1.2]};

for ds = dataSources
    for i = 1:nExp
        vars = expCTDataAll{i}.varsAll.(ds);

        fig = figure('Position',[100 100 1300 550]);
        tl  = tiledlayout(fig, 1, size(zDaxes,1), 'TileSpacing','compact');

        for a = 1:size(zDaxes,1)
            ax = nexttile(tl);  hold(ax,'on')
            xVar = zDaxes{a,1};
            if ~ismember(xVar, vars.Properties.VariableNames)
                text(ax, 0.5, 0.5, xVar + " not available", 'Units','normalized', ...
                    'HorizontalAlignment','center', 'Interpreter','none')
                continue
            end

            for m = 1:numel(zDlevelsPlot)
                Cfield = strrep(sprintf('CD1_zD%.1f', zDlevelsPlot(m)), '.', 'p') + btcVariant;
                if ~ismember(Cfield, vars.Properties.VariableNames), continue, end
                [xS, o] = sort(vars.(xVar));
                yS = vars.(Cfield)(o);
                scatter(ax, xS, yS, 3, 'MarkerFaceColor',zDcols(m,:), 'MarkerEdgeColor',zDcols(m,:),...
                    'DisplayName', sprintf('z_D = %.1f', zDlevelsPlot(m)))
            end

            yline(ax, [0.16 0.5 0.84], ':k', 'HandleVisibility','off')
            xlabel(ax, zDaxes{a,2}, 'FontSize',13)
            ylabel(ax, 'C_1 [-]', 'FontSize',13)
            xlim(ax, zDaxes{a,3});  ylim(ax, [-0.02 1.02])
            set(ax,'FontSize',12);  grid(ax,'on')
            legend(ax, 'Location','northwest', 'FontSize',8)
        end

        title(tl, sprintf('%s (%s%s): BTC at each zD', expKeys(i), ds, btcVariant), ...
            'Interpreter','none')
        saveFigBoth(fig, exportPath, ...
            sprintf('BT_CT_allZD_%s_%s%s', expKeys(i), ds, btcVariant), closeAfterSave)
    end
end
%% 3c) Front position of every C-level vs tD_total and the three tD_core definitions

CplotLevels  = [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9];   % must be among Clevels in main_CTpreproc
frontVariant = "";           % "" = full x-range mean, "_xtrim" = x-trimmed mean
xLimPos      = [0 1.5];      % x-range for all four panels
lvlCols = parula(numel(CplotLevels) + 1);
lvlCols = lvlCols(1:numel(CplotLevels),:);              % one colour per C-level

% {x column, x label, arrival-corrected?}
posAxes = { ...
    'tDtotal',                't_{D,total} = Qt/V_{total} [-]  (no arrival correction)',          false; ...
    'tD_corr_lines',          't_{D,core} = t_{D,total} - t_{D,arrival,lines} [-]',                true; ...
    'tD_corr_contour',        't_{D,core,front} = t_{D,total} - t_{D,arrival,front} [-]',           true; ...
    'tD_corr_contour_scaled', 't_{D,core,front,scaled} = v_{front}(t - t_{arrival,front})/L [-]',  true};

for ds = dataSources
    for i = 1:nExp
        vars   = expCTDataAll{i}.varsAll.(ds);
        cols_i = string(vars.Properties.VariableNames);

        fig = figure('Position',[50 50 1400 1000]);
        tl  = tiledlayout(fig, 2, 2, 'TileSpacing','compact');

        for a = 1:size(posAxes,1)
            ax = nexttile(tl);  hold(ax,'on')
            xVar = posAxes{a,1};
            if ~ismember(xVar, cols_i)
                text(ax, 0.5, 0.5, xVar + " not available", 'Units','normalized', ...
                    'HorizontalAlignment','center', 'Interpreter','none')
                continue
            end
            x = vars.(xVar);

            for m = 1:numel(CplotLevels)
                tag     = sprintf('%02d', round(CplotLevels(m)*100));
                meanCol = "zDFront" + tag + frontVariant;
                if ~ismember(meanCol, cols_i)
                    warning('%s (%s): %s missing, level skipped', expKeys(i), ds, meanCol);
                    continue
                end
                zMean = vars.(meanCol);
                ok = isfinite(x) & isfinite(zMean);
                scatter(ax, x(ok), zMean(ok), 14, lvlCols(m,:), 'filled', ...
                    'DisplayName', sprintf('C = %.1f', CplotLevels(m)))
            end

            if posAxes{a,3}
                xline(ax, 0, '--k', 'LineWidth',1, 'HandleVisibility','off')   % arrival
            end

            % legend with every C_D level, in each panel
            legend(ax, 'Location','southeast', 'FontSize',8)

            xlabel(ax, posAxes{a,2}, 'FontSize',12)
            ylabel(ax, 'z_D front position [-]', 'FontSize',12)
            xlim(ax, xLimPos);  ylim(ax, [-0.02 1.02])
            set(ax,'FontSize',11);  grid(ax,'on')
        end

        if frontVariant == "", xTxt = "full x-range mean"; else, xTxt = "x-trimmed mean"; end
        title(tl, sprintf('%s (%s): zD front position of each CD level (%s) vs tD', ...
            expKeys(i), ds, xTxt), 'Interpreter','none')
        saveFigBoth(fig, exportPath, ...
            sprintf('frontPos_allC_%s_%s%s', expKeys(i), ds, frontVariant), closeAfterSave)
    end
end

%% 3c) Front position of one C_D level, all experiments together (one figure per level)

CplotLevels  = [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9];   % must be among Clevels in main_CTpreproc
frontVariant = "";           % "" = full x-range mean, "_xtrim" = x-trimmed mean
xLimPos      = [0 1.5];      % x-range for all four panels

% {x column, x label, arrival-corrected?}
posAxes = { ...
    'tDtotal',                't_{D,total} = Qt/V_{total} [-]  (no arrival correction)',          false; ...
    'tD_corr_lines',          't_{D,core} = t_{D,total} - t_{D,arrival,lines} [-]',                true; ...
    'tD_corr_contour',        't_{D,core,front} = t_{D,total} - t_{D,arrival,front} [-]',           true; ...
    'tD_corr_contour_scaled', 't_{D,core,front,scaled} = v_{front}(t - t_{arrival,front})/L [-]',  true};

if frontVariant == "", xTxt = "full x-range mean"; else, xTxt = "x-trimmed mean"; end

for ds = dataSources
    for m = 1:numel(CplotLevels)
        tag     = sprintf('%02d', round(CplotLevels(m)*100));
        meanCol = "zDFront" + tag + frontVariant;

        fig = figure('Position',[50 50 1400 1000]);
        tl  = tiledlayout(fig, 2, 2, 'TileSpacing','compact');

        for a = 1:size(posAxes,1)
            ax = nexttile(tl);  hold(ax,'on')
            xVar = posAxes{a,1};

            for i = 1:nExp
                vars   = expCTDataAll{i}.varsAll.(ds);
                cols_i = string(vars.Properties.VariableNames);
                if ~all(ismember([string(xVar) meanCol], cols_i))
                    warning('%s (%s): %s or %s missing, skipped', expKeys(i), ds, xVar, meanCol);
                    continue
                end
                x = vars.(xVar);
                z = vars.(meanCol);
                ok = isfinite(x) & isfinite(z);
                scatter(ax, x(ok), z(ok), 14, cols(i,:), markers{mod(i-1,numel(markers))+1}, ...
                    'filled', 'DisplayName', expKeys(i))
            end

            if posAxes{a,3}
                xline(ax, 0, '--k', 'LineWidth',1, 'HandleVisibility','off')   % arrival
            end

            xlabel(ax, posAxes{a,2}, 'FontSize',12)
            ylabel(ax, 'z_D front position [-]', 'FontSize',12)
            xlim(ax, xLimPos);  ylim(ax, [-0.02 1.02])
            set(ax,'FontSize',11);  grid(ax,'on')
            legend(ax, 'Location','southeast', 'FontSize',8, 'Interpreter','none')
        end

        title(tl, sprintf('z_D front position at C_D = %.1f, all experiments (%s, %s)', ...
            CplotLevels(m), ds, xTxt), 'Interpreter','tex')
        saveFigBoth(fig, exportPath, ...
            sprintf('frontPos_C%s_allExp_%s%s', tag, ds, frontVariant), closeAfterSave)
    end
end

%% 4) MFM analog BTC

for ds = dataSources
    fig = figure;  hold on
    for i = 1:nExp
        mfm = MFM_CT_DataAll{i}.(ds);
        if isempty(mfm), continue, end
        plot(mfm.BT.(mfmTimeVar), mfm.BT.(mfmCol.(ds)), 'LineWidth',2, 'Color',cols(i,:), ...
            'DisplayName', string(inputFileConfig.MFM_BTC_CT_Key{i}))
    end
    xlabel('t_D [-]','FontSize',14);  ylabel('C_1 [-]','FontSize',14)
    ylim([-0.02 1]);  xlim([0 2]);  set(gca,'FontSize',14);  grid on
    legend('Interpreter','none','FontSize',8,'Location','northwest')
    title(sprintf('BT curves from MFM analog CT-CF (%s, %s)', ds, fitDataOf.(ds)), 'Interpreter','none')
    saveFigBoth(fig, exportPath, sprintf('BT_MFM_CT_%s_tD', ds), closeAfterSave)
end

%% 5) MFM UHS BTC

for ds = dataSources
    fig = figure;  hold on
    for i = 1:nExp
        mfm = MFM_UHS_DataAll{i}.(ds);
        if isempty(mfm), continue, end
        plot(mfm.BT.(mfmTimeVar), mfm.BT.(mfmCol.(ds)), 'LineWidth',2, 'Color',cols(i,:), ...
            'DisplayName', string(inputFileConfig.MFM_BTC_UHS_Key{i}))
    end
    xlabel('t_D [-]','FontSize',14);  ylabel('C_1 [-]','FontSize',14)
    ylim([-0.02 1]);  xlim([0 2]);  set(gca,'FontSize',14);  grid on
    legend('Interpreter','none','FontSize',8,'Location','northwest')
    title(sprintf('BT curves from MFM UHS (%s, %s)', ds, fitDataOf.(ds)), 'Interpreter','none')
    saveFigBoth(fig, exportPath, sprintf('BT_MFM_UHS_%s_tD', ds), closeAfterSave)
end

%% 6) MFM analog + UHS BTC together

for ds = dataSources
    fig = figure;  hold on
    for i = 1:nExp
        mCT  = MFM_CT_DataAll{i}.(ds);
        mUHS = MFM_UHS_DataAll{i}.(ds);
        if ~isempty(mCT)
            plot(mCT.BT.(mfmTimeVar), mCT.BT.(mfmCol.(ds)), '--', 'LineWidth',2, 'Color',cols(i,:), ...
                'DisplayName', "analog " + string(inputFileConfig.MFM_BTC_CT_Key{i}))
        end
        if ~isempty(mUHS)
            plot(mUHS.BT.(mfmTimeVar), mUHS.BT.(mfmCol.(ds)), ':', 'LineWidth',2, 'Color',cols(i,:), ...
                'DisplayName', "UHS " + string(inputFileConfig.MFM_BTC_UHS_Key{i}))
        end
    end
    xlabel('t_D [-]','FontSize',14);  ylabel('C_1 [-]','FontSize',14)
    ylim([-0.02 1]);  xlim([0 2]);  set(gca,'FontSize',14);  grid on
    legend('Interpreter','none','FontSize',8,'Location','northwest')
    title(sprintf('BT curves MFM analog (--) and UHS (:) (%s, %s)', ds, fitDataOf.(ds)), 'Interpreter','none')
    saveFigBoth(fig, exportPath, sprintf('BT_MFM_CT_UHS_%s_tD', ds), closeAfterSave)
end

%% 7) Measured front width vs tD

widthPairs = {'10_90','16_84','20_80','30_70','40_60'};

for ds = dataSources
    for p = 1:numel(widthPairs)
        measField = ['zDWidth_' widthPairs{p}];
        fig = figure('Position',[100 100 1000 650]);  hold on
        nPlotted = 0;

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            if ~ismember(measField, vars.Properties.VariableNames), continue, end
            scatter(vars.tDtotal, vars.(measField), 8, 'filled', ...
                'MarkerFaceColor',cols(i,:), 'MarkerEdgeColor','none', 'DisplayName', expKeys(i))
            nPlotted = nPlotted + 1;
        end
        if nPlotted == 0, close(fig); continue, end

        xlabel('t_D [-]','FontSize',14);  ylabel('\DeltaZ_D [-]','FontSize',14)
        ylim([-0.02 1]);  xlim([0 1.2]);  set(gca,'FontSize',14);  grid on
        legend('Interpreter','none','FontSize',8,'Location','northeast')
        title(sprintf('Measured front width (%s) from CT (%s)', strrep(widthPairs{p},'_','-'), ds), ...
            'Interpreter','none')
        saveFigBoth(fig, exportPath, sprintf('width_CT_%s_%s_tD', widthPairs{p}, ds), closeAfterSave)
    end
end

%% 8) Measured front envelope, all experiments together

widthPairsEnv = {'10_90','30_70','40_60'};

for ds = dataSources
    for p = 1:numel(widthPairsEnv)
        measField = ['zDWidth_' widthPairsEnv{p}];
        fig = figure('Position',[100 100 1000 650]);  hold on

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            if ~ismember(measField, vars.Properties.VariableNames), continue, end

            tD = vars.tDtotal;
            centerMeas = vars.zDFront50;
            halfMeas   = vars.(measField)/2;
            validMeas  = isfinite(centerMeas) & isfinite(halfMeas);

            % one vertical segment per scan: front centre +/- half width
            xs = [tD(validMeas)'; tD(validMeas)'; nan(1,nnz(validMeas))];
            ys = [centerMeas(validMeas)' - halfMeas(validMeas)'; ...
                  centerMeas(validMeas)' + halfMeas(validMeas)'; nan(1,nnz(validMeas))];
            plot(xs(:), ys(:), '-', 'Color',[cols(i,:) 0.6], 'LineWidth',1.5, 'HandleVisibility','off')
            scatter(tD(validMeas), centerMeas(validMeas), 18, colsDark(i,:), 'filled', ...
                'DisplayName', expKeys(i))
        end

        xlabel('t_D [-]','FontSize',14);  ylabel('z_D [-]','FontSize',14)
        ylim([-0.02 1.02]);  xlim([0 1.2]);  set(gca,'FontSize',14);  grid on
        legend('Interpreter','none','FontSize',8,'Location','southeast')
        title(sprintf('Measured front envelope (%s, centred on C=0.5) (%s)', ...
            strrep(widthPairsEnv{p},'_','-'), ds), 'Interpreter','none')
        saveFigBoth(fig, exportPath, sprintf('frontEnvelope_CT_allExp_%s_%s_tD', widthPairsEnv{p}, ds), closeAfterSave)
    end
end

%% 9) Front tilt and shape diagnostics

for ds = dataSources
    fig = figure('Position',[100 100 650 2200]);
    panels = {'tDtotal','frontTiltSlope',      't_D [-]',                    'front tilt slope [z_D/x_D]', 'Front tilt vs t_D', false; ...
              'rotPos', 'frontTiltSlope',      'rotation position [\circ]', 'front tilt slope [z_D/x_D]', 'Front tilt vs rotation position', false; ...
              'tDtotal','frontArcLengthRatio', 't_D [-]',                    'arc length ratio [-]',       'Front non-planarity vs t_D', true; ...
              'rotPos', 'frontArcLengthRatio', 'rotation position [\circ]', 'arc length ratio [-]',       'Front non-planarity vs rotation position', true};

    for s = 1:size(panels,1)
        subplot(4,1,s);  hold on
        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            if ~all(ismember(panels(s,1:2), vars.Properties.VariableNames)), continue, end
            scatter(vars.(panels{s,1}), vars.(panels{s,2}), 5, 'filled', ...
                'MarkerFaceColor',cols(i,:), 'MarkerEdgeColor',cols(i,:), 'DisplayName', expKeys(i))
        end
        if panels{s,6}, yline(1, ':k', 'LineWidth',1, 'DisplayName','perfectly flat'), end
        if panels{s,1} == "rotPos", xlim([0 360]), end
        xlabel(panels{s,3},'FontSize',12);  ylabel(panels{s,4},'FontSize',12)
        title(panels{s,5},'FontSize',12);  grid on
        legend('Interpreter','none','FontSize',8,'Location','northwest')
    end
    sgtitle(sprintf('Front planarity diagnostics (%s)', ds), 'Interpreter','none')
    saveFigBoth(fig, exportPath, sprintf('frontTiltShape_%s_tD', ds), closeAfterSave)
end

%% 10) Front tilt vs rotation position, coloured by tD

for ds = dataSources
    fig = figure('Position',[100 100 1000 850]);
    tl = tiledlayout(fig, 'flow', 'TileSpacing','compact');

    for i = 1:nExp
        vars = expCTDataAll{i}.varsAll.(ds);
        ax = nexttile(tl);
        scatter(ax, vars.rotPos, vars.frontTiltSlope, 25, vars.tDtotal, 'filled')
        colormap(ax, parula);  clim(ax, [0 1.5])
        cb = colorbar(ax);  cb.Label.String = 't_D [-]';
        xlabel(ax,'rotation position [\circ]','FontSize',11)
        ylabel(ax,'front tilt slope [z_D/x_D]','FontSize',11)
        title(ax, expKeys(i), 'Interpreter','none','FontSize',11)
        grid(ax,'on');  xlim(ax,[0 360])
    end
    title(tl, sprintf('Front tilt vs rotation position, coloured by t_D (%s)', ds), 'Interpreter','none')
    saveFigBoth(fig, exportPath, sprintf('frontTilt_rotPos_tDcolor_%s', ds), closeAfterSave)
end


%% 11) KL vs tD: pointwise front KL + BTC-CT and MFM reference KL

% front methods from main_CTpostproc (full x-range): pointwise KL on the selected frames
frontMethodsKL = ["sigma_int0","width_C40_60_int0","width_C30_70_int0"];

for ds = dataSources
    fig = figure('Position',[100 100 1100 700]);  hold on
    nPlotted = 0;

    for i = 1:nExp
        if ~hasPost(i), continue, end
        fd = filedataExpAll{i};
        rs = expCTDataAll{i}.resultsAll.(ds);
        if ~isfield(rs,'full'), continue, end

        % pointwise KL along the run (t_fit = min since inlet-line arrival)
        if isfield(rs.full,'KL_front_CT')
            fr = rs.full.KL_front_CT;
            for mI = 1:numel(frontMethodsKL)
                nm = frontMethodsKL(mI);
                if ~isfield(fr, nm) || ~all(isfield(fr.(nm), {'t_fit','KL_pts'})), continue, end
                Sm = fr.(nm);
                if isempty(Sm.KL_pts) || all(~isfinite(Sm.KL_pts)), continue, end
                tD_pts = (Sm.t_fit*fd.Q + fd.Vlinesbefore) / fd.Vtotal;   % back to tD_total
                scatter(tD_pts, Sm.KL_pts, 14, cols(i,:), markers{mod(mI-1,numel(markers))+1}, ...
                    'DisplayName', expKeys(i) + " (" + strrep(nm,"_"," ") + ")")
                nPlotted = nPlotted + 1;
            end
        end

        % BTC-CT fit at the outlet
        if isfield(rs.full,'KL_BTC_CT') && isfield(rs.full.KL_BTC_CT,'best') && ...
                isfield(rs.full.KL_BTC_CT.best,'KL_cm2min') && isfinite(rs.full.KL_BTC_CT.best.KL_cm2min)
            yline(rs.full.KL_BTC_CT.best.KL_cm2min, '--', 'Color',cols(i,:), 'LineWidth',1.5, ...
                'DisplayName', expKeys(i) + " (BTC CT, zD=1)")
        end
        % MFM references
        if isfield(rs,'KL_MFM_CT') && isfinite(rs.KL_MFM_CT)
            yline(rs.KL_MFM_CT, ':', 'Color',cols(i,:), 'LineWidth',1.5, ...
                'DisplayName', expKeys(i) + " (MFM analog)")
        end
        if isfield(rs,'KL_MFM_UHS') && isfinite(rs.KL_MFM_UHS)
            yline(rs.KL_MFM_UHS, '-.', 'Color',cols(i,:), 'LineWidth',1.5, ...
                'DisplayName', expKeys(i) + " (MFM UHS)")
        end
    end

    xlabel('t_D [-]','FontSize',14);  ylabel('K_L [cm^2/min]','FontSize',14)
    xlim([0 1.2]);  ylim([0 10]);  set(gca,'FontSize',14);  grid on
    legend('Interpreter','none','FontSize',7,'Location','best','NumColumns',2)
    title(sprintf('K_L: pointwise front (markers), BTC CT (--), MFM analog (:), MFM UHS (-.) (%s)', ds), ...
        'Interpreter','none','FontSize',10)
    saveFigBoth(fig, exportPath, sprintf('KL_compare_%s_tD', ds), closeAfterSave)
end

%% 12) Outlet BTC width (tD16 - tD84), one row per experiment

for ds = dataSources
    fig = figure('Position',[100 100 1000 650]);  hold on
    yLabels = strings(nExp,1);

    for i = 1:nExp
        yLabels(i) = expKeys(i);
        if ~hasPost(i), continue, end
        rs = expCTDataAll{i}.resultsAll.(ds);
        if ~isfield(rs,'full') || ~isfield(rs.full,'BTCMetrics'), continue, end
        met = rs.full.BTCMetrics;
        if ~isstruct(met) || ~all(isfield(met, {'tD16','tD50','tD84'})), continue, end

        plot([met.tD16 met.tD84], [i i], '-', 'Color',[cols(i,:) 0.8], 'LineWidth',3, 'HandleVisibility','off')
        scatter(met.tD50, i, 40, colsDark(i,:), 'filled', 'DisplayName', expKeys(i))
    end

    xlabel('t_D [-]','FontSize',14);  ylabel('Experiment','FontSize',14)
    set(gca,'FontSize',14, 'TickLabelInterpreter','none')
    yticks(1:nExp);  yticklabels(yLabels);  ylim([0.5, nExp+0.5]);  xlim([0 2]);  grid on
    title(sprintf('Outlet BTC width (16-84%%), centred on tD at 50%% (%s)', ds), 'Interpreter','none')
    saveFigBoth(fig, exportPath, sprintf('BTCwidth_outlet_%s_tD', ds), closeAfterSave)
end

%% 13) Sweep, displacement and recovery efficiencies vs tD (all experiments together)

CeffLevels = 0.1:0.1:0.9;     % thresholds C* (all traced in main_CTpreproc)   % thresholds C* (must be among Clevels in main_CTpreproc)
effVariant = "";              % "" = full image, "_xtrim" = x-trimmed image
effXVar    = 'tDtotal';       % x-axis: 'tDtotal', 'tD_corr_lines', 'tD_corr_contour', 'tD_corr_contour_scaled'
effXLabel  = 't_{D,total} = Qt/V_{total} [-]';
effXLim    = [0 1.5];

if effVariant == "", vTxt = "full image"; else, vTxt = "x-trimmed"; end
overallCol = "overallRecovery_" + ternaryStr(effVariant == "", "full", "xtrim");

for ds = dataSources
    for m = 1:numel(CeffLevels)
        tag = sprintf('%02d', round(CeffLevels(m)*100));

        % {column, y label, panel title}
        effPanels = { ...
            "sweepEff" + tag + effVariant, 'E_A [-]', sprintf('Areal sweep efficiency E_A (C > %.2f)', CeffLevels(m)); ...
            "dispEff"  + tag + effVariant, 'E_D [-]', sprintf('Displacement efficiency E_D (mean C where C > %.2f)', CeffLevels(m)); ...
            "recovery" + tag + effVariant, 'R [-]',   sprintf('Recovery R = E_A E_D (C > %.2f)', CeffLevels(m)); ...
            overallCol,                    'R_{overall} [-]', 'Overall recovery (mean C over image, no threshold)'};

        fig = figure('Position',[50 50 1400 1000]);
        tl  = tiledlayout(fig, 2, 2, 'TileSpacing','compact');

        for p = 1:size(effPanels,1)
            ax = nexttile(tl);  hold(ax,'on')
            yCol = effPanels{p,1};

            for i = 1:nExp
                vars   = expCTDataAll{i}.varsAll.(ds);
                cols_i = string(vars.Properties.VariableNames);
                if ~all(ismember([string(effXVar) yCol], cols_i))
                    warning('%s (%s): %s or %s missing, skipped', expKeys(i), ds, effXVar, yCol);
                    continue
                end
                x = vars.(effXVar);  y = vars.(yCol);
                ok = isfinite(x) & isfinite(y);
                scatter(ax, x(ok), y(ok), 12, cols(i,:), 'filled', 'DisplayName', expKeys(i))
            end

            xlabel(ax, effXLabel, 'FontSize',12)
            ylabel(ax, effPanels{p,2}, 'FontSize',12)
            title(ax, effPanels{p,3}, 'FontSize',11)
            xlim(ax, effXLim);  ylim(ax, [-0.02 1.02])
            set(ax,'FontSize',11);  grid(ax,'on')
            legend(ax, 'Location','southeast', 'FontSize',8, 'Interpreter','none')
        end

        title(tl, sprintf('Efficiencies at C^* = %.2f (%s, %s)', CeffLevels(m), ds, vTxt), 'Interpreter','tex')
        saveFigBoth(fig, exportPath, ...
            sprintf('efficiencies_C%s_allExp_%s%s_%s', tag, ds, effVariant, effXVar), closeAfterSave)
    end
end

%% 14) rhoNorm vs conc BTC at each zD: left = lower Q, right = higher Q, both pressures superposed

zDcompare  = 0:0.1:1.0;
cmpVariant = "";            % "" = full x-range, "_xtrim" = x-trimmed columns
cmpXVar    = 'tDtotal';     % or 'tD_corr_lines', 'tD_corr_contour', 'tD_corr_contour_scaled'
cmpXLabel  = 't_{D,total} = Qt/V_{total} [-]';
cmpXLim    = [0 1.5];

% colours {pressure index, Q index}: row = pressure (1st = lower P), col = Q (1 = light/lower Q, 2 = dark/higher Q)
cmpCols.conc    = {[0.318 0.654 0.976], [0.090 0.306 0.525];    % blue:  light, dark
                   [0.435 0.753 0.251], [0.059 0.361 0.102]};   % green: light, dark
cmpCols.rhoNorm = {[1.000 0.550 0.550], [0.700 0.000 0.000];    % red:   light, dark
                   [0.600 0.600 0.600], [0.000 0.000 0.000]};   % black: grey, black

if cmpVariant == "", vTxt = "full x-range"; else, vTxt = "x-trimmed"; end

Qall  = cellfun(@(f) f.Q, filedataExpAll);
Pall  = cellfun(@(f) f.P, filedataExpAll);
Qlist = sort(unique(Qall));      % left panel = lowest Q
Plist = sort(unique(Pall));      % colour row = pressure order

for m = 1:numel(zDcompare)
    Cfield = strrep(sprintf('CD1_zD%.1f', zDcompare(m)), '.', 'p') + cmpVariant;

    fig = figure('Position',[50 50 1400 600]);
    tl  = tiledlayout(fig, 1, numel(Qlist), 'TileSpacing','compact');

    for q = 1:numel(Qlist)
        ax = nexttile(tl);  hold(ax,'on')
        qIdx = min(q, 2);                                   % light for 1st Q, dark otherwise

        for i = find(Qall == Qlist(q))'
            pIdx = min(find(Plist == Pall(i), 1), 2);       % 1st pressure -> blue/red, 2nd -> green/black

            for ds = dataSources
                vars   = expCTDataAll{i}.varsAll.(ds);
                cols_i = string(vars.Properties.VariableNames);
                if ~all(ismember([string(cmpXVar) Cfield], cols_i))
                    warning('%s (%s): %s or %s missing, skipped', expKeys(i), ds, cmpXVar, Cfield);
                    continue
                end
                x = vars.(cmpXVar);  y = vars.(Cfield);
                ok = isfinite(x) & isfinite(y);
                scatter(ax, x(ok), y(ok), 12, cmpCols.(ds){pIdx,qIdx}, 'filled', ...
                    'DisplayName', sprintf('%s, P = %g psig', ds, Pall(i)))
            end
        end

        yline(ax, [0.16 0.5 0.84], ':k', 'HandleVisibility','off')
        xlabel(ax, cmpXLabel, 'FontSize',11)
        ylabel(ax, 'C_D [-]', 'FontSize',11)
        xlim(ax, cmpXLim);  ylim(ax, [-0.05 1.05])
        set(ax,'FontSize',10);  grid(ax,'on')
        title(ax, sprintf('Q = %g ml/min', Qlist(q)), 'FontSize',11)
        legend(ax, 'Location','southeast', 'FontSize',8, 'Interpreter','none')
    end

    title(tl, sprintf('BTC at z_D = %.1f: rhoNorm vs conc, both pressures (%s)', ...
        zDcompare(m), vTxt), 'Interpreter','tex')
    saveFigBoth(fig, exportPath, ...
        sprintf('BT_rhoNorm_vs_conc_byQ_zD%s%s_%s', strrep(sprintf('%.1f',zDcompare(m)),'.','p'), ...
        cmpVariant, cmpXVar), closeAfterSave)
end

%% 14) Flow capacity vs storage capacity (F-Phi) from the BTC at several zD, and predicted sweep vs measured

fpZD       = [0.5 0.6 0.7 0.8 0.9 1.0];   % BTC levels (columns CD1_zD0p5 ... CD1_zD1p0)
fpXVar     = 'tD_corr_lines';  % time axis: 'tD_corr_lines' (lines volume removed) or 'tDtotal'
fpLocalT   = true;             % true: plot vs t/zD (pore volumes of the section 0..zD)
fpSmooth   = 5;                % points, moving-median window on the BTC before cummax
fpEffTag   = "50";             % sweepEff level shown at zD = 1 (C > 0.50)
fpVariant  = "";               % "" = full image, "_xtrim" = x-trimmed
fpXLim     = [0 1.5];

overallColFP = "overallRecovery_" + ternaryStr(fpVariant == "", "full", "xtrim");
profColFP    = "CVert" + fpVariant;          % column of C1Profile used for the section mean
fpSummary = table();

for ds = dataSources
    for z = fpZD
        btcCol = "CD1_zD" + strrep(sprintf('%.1f', z), '.', 'p');
        if fpLocalT, tScale = z; xLab = 't_D / z_D  [section PV]'; else, tScale = 1; xLab = 't_D [-]'; end

        fig = figure('Position',[50 50 1600 520]);
        tl  = tiledlayout(fig, 1, 3, 'TileSpacing','compact');
        axB = nexttile(tl);  hold(axB,'on')     % (a) BTC used
        axF = nexttile(tl);  hold(axF,'on')     % (b) F-Phi
        axE = nexttile(tl);  hold(axE,'on')     % (c) predicted Ev vs measured

        plot(axF, [0 1], [0 1], 'k--', 'LineWidth', 1, 'DisplayName', 'homogeneous (piston)')

        for i = 1:nExp
            vars   = expCTDataAll{i}.varsAll.(ds);
            cols_i = string(vars.Properties.VariableNames);
            if ~all(ismember([string(fpXVar) btcCol], cols_i))
                warning('%s (%s): %s or %s missing, skipped', expKeys(i), ds, fpXVar, btcCol);
                continue
            end
            mk = markers{mod(i-1,numel(markers))+1};

            % --- clean BTC at this zD: sorted, unique times, 0..1, monotonic
            t = vars.(fpXVar);  C = vars.(btcCol);
            ok = isfinite(t) & isfinite(C);
            [t, o] = sort(t(ok));  C = C(ok);  C = C(o);
            [t, iu] = unique(t);   C = C(iu);
            C = min(max(C, 0), 1);
            Craw = C;
            C = cummax(movmedian(C, fpSmooth));
            keep = t >= 0;  t = t(keep);  C = C(keep);  Craw = Craw(keep);
            if numel(t) < 5, continue, end
            if t(1) > 0, t = [0; t];  C = [0; C];  Craw = [0; Craw]; end

            % --- F-Phi (step injection), mean residence time, Lorenz coefficient
            intC = cumtrapz(t, C);
            tbar = trapz(t, 1 - C);                 % lower bound if C never reaches 1
            F    = C;
            Phi  = (t.*C - intC) / tbar;
            Ev   = (t - intC) / tbar;               % fraction of section 0..zD filled
            Lc   = 2*(trapz([Phi; 1], [F; 1]) - 0.5);
            Cend = C(end);

            % --- (a) BTC
            scatter(axB, t/tScale, Craw, 10, cols(i,:), mk, 'filled', 'MarkerFaceAlpha', 0.4, 'HandleVisibility','off')
            plot(axB, t/tScale, C, '-', 'Color', cols(i,:), 'LineWidth', 1.3, 'DisplayName', expKeys(i))

            % --- (b) F-Phi
            plot(axF, Phi, F, '-', 'Color', cols(i,:), 'LineWidth', 1.6, ...
                'DisplayName', sprintf('%s  Lc = %.3f', expKeys(i), Lc))

            % --- (c) predicted Ev (line) vs measured mean C over the section 0..zD (filled)
            plot(axE, t/tScale, Ev, '-', 'Color', cols(i,:), 'LineWidth', 1.6, ...
                'DisplayName', expKeys(i) + " E_v from F-Phi")
            tm = vars.(fpXVar);
            if z >= 1 && ismember(overallColFP, cols_i)
                yS = vars.(overallColFP);
            elseif ismember("C1Profile", cols_i)
                yS = sectionMeanC(vars.C1Profile, z, profColFP);
            else
                yS = NaN(size(tm));
            end
            okm = isfinite(tm) & isfinite(yS);
            scatter(axE, tm(okm)/tScale, yS(okm), 14, cols(i,:), mk, 'filled', ...
                'DisplayName', expKeys(i) + " mean C over 0..zD")
            effCol = "sweepEff" + fpEffTag + fpVariant;
            if z >= 1 && ismember(effCol, cols_i)
                y = vars.(effCol);  okm = isfinite(tm) & isfinite(y);
                scatter(axE, tm(okm)/tScale, y(okm), 14, cols(i,:), mk, ...
                    'DisplayName', expKeys(i) + " E_A (C > 0." + fpEffTag + ")")
            end

            fpSummary = [fpSummary; table(string(ds), expKeys(i), z, Lc, tbar, tbar/z, Cend, ...
                'VariableNames', {'dataSource','experiment','zD','Lc','tbar','tbar_over_zD','C_end'})]; %#ok<AGROW>
            if Cend < 0.95
                warning('%s (%s, zD = %.1f): BTC ends at C = %.2f -- tbar and Lc are lower bounds', ...
                    expKeys(i), ds, z, Cend);
            end
        end

        xlabel(axB, xLab, 'FontSize',12);  ylabel(axB, sprintf('C_D at z_D = %.1f [-]', z), 'FontSize',12)
        title(axB, 'BTC (markers raw, line cleaned)', 'FontSize',11)
        xlim(axB, fpXLim);  ylim(axB, [-0.02 1.02])

        xlabel(axF, '\Phi  storage capacity [-]', 'FontSize',12);  ylabel(axF, 'F  flow capacity [-]', 'FontSize',12)
        title(axF, 'F-\Phi (Lorenz coefficient in legend)', 'FontSize',11)
        xlim(axF, [0 1]);  ylim(axF, [0 1]);  axis(axF, 'square')

        xlabel(axE, xLab, 'FontSize',12);  ylabel(axE, 'E_v, mean C [-]', 'FontSize',12)
        if z >= 1
            title(axE, 'Predicted E_v (line) vs CT: mean C (filled), E_A (open)', 'FontSize',11)
        else
            title(axE, sprintf('Predicted E_v (line) vs CT mean C over z_D \\leq %.1f', z), 'FontSize',11)
        end
        xlim(axE, fpXLim);  ylim(axE, [-0.02 1.02])

        for ax = [axB axF axE]
            set(ax, 'FontSize',11);  grid(ax,'on')
            legend(ax, 'Location','southeast', 'FontSize',7, 'Interpreter','none')
        end

        title(tl, sprintf('Flow vs storage capacity from the BTC at z_D = %.1f (%s, x = %s)', z, ds, fpXVar), ...
            'Interpreter','none')
        saveFigBoth(fig, exportPath, sprintf('FPhi_zD%s_allExp_%s%s_%s', ...
            strrep(sprintf('%.1f', z), '.', 'p'), ds, fpVariant, fpXVar), closeAfterSave)
    end

    % --- summary: Lc and tbar/zD vs zD, one line per experiment
    fig = figure('Position',[50 50 1100 450]);
    tl  = tiledlayout(fig, 1, 2, 'TileSpacing','compact');
    axL = nexttile(tl);  hold(axL,'on')
    axT = nexttile(tl);  hold(axT,'on')
    for i = 1:nExp
        S = fpSummary(fpSummary.dataSource == string(ds) & fpSummary.experiment == expKeys(i), :);
        if isempty(S), continue, end
        S = sortrows(S, 'zD');
        mk = markers{mod(i-1,numel(markers))+1};
        plot(axL, S.zD, S.Lc, ['-' mk], 'Color', cols(i,:), 'MarkerFaceColor', cols(i,:), ...
            'LineWidth', 1.4, 'DisplayName', expKeys(i))
        plot(axT, S.zD, S.tbar_over_zD, ['-' mk], 'Color', cols(i,:), 'MarkerFaceColor', cols(i,:), ...
            'LineWidth', 1.4, 'DisplayName', expKeys(i))
    end
    yline(axT, 1, 'k--', 'HandleVisibility','off');
    xlabel(axL, 'z_D [-]', 'FontSize',12);  ylabel(axL, 'L_c [-]', 'FontSize',12)
    title(axL, 'Lorenz coefficient vs distance', 'FontSize',11)
    xlabel(axT, 'z_D [-]', 'FontSize',12);  ylabel(axT, 't̄ / z_D [-]', 'FontSize',12)
    title(axT, 'Mean residence time per section length (1 = uniform speed)', 'FontSize',11)
    for ax = [axL axT]
        set(ax, 'FontSize',11);  grid(ax,'on');  xlim(ax, [min(fpZD)-0.05 max(fpZD)+0.05])
        legend(ax, 'Location','best', 'FontSize',7, 'Interpreter','none')
    end
    title(tl, sprintf('F-\\Phi summary vs z_D (%s, x = %s)', ds, fpXVar), 'Interpreter','tex')
    saveFigBoth(fig, exportPath, sprintf('FPhi_summary_vs_zD_%s%s_%s', ds, fpVariant, fpXVar), closeAfterSave)
end

disp(fpSummary)
writetable(fpSummary, fullfile(exportPath, 'FPhi_summary.xlsx'));
%% Local functions

function out = loadMFMbyDataSource(fileMat, key, fitDataOf)
% MFM results for one experiment, one entry per CT data source:
%   out.rhoNorm = expProcFullData.(key).woEOS (+ exp_params), out.conc = ... .wEOS
    if ~isfile(fileMat), error('MFM results file not found: %s', fileMat); end
    S = load(fileMat, 'expProcFullData');
    if ~isfield(S.expProcFullData, key)
        error('Experiment %s not found in %s', key, fileMat);
    end
    e = S.expProcFullData.(key);
    out = struct();
    for ds = string(fieldnames(fitDataOf))'
        fd = fitDataOf.(ds);
        if isfield(e, fd)
            r = e.(fd);
            r.exp_params = e.exp_params;
            out.(ds) = r;
        else
            warning('%s: MFM variant %s missing in %s', key, fd, fileMat);
            out.(ds) = [];
        end
    end
end

function x = cellRow(col, r)
% row r of a table column that may be stored as cells
    if iscell(col), x = col{r}; else, x = col(r); end
end

function saveFigBoth(fig, exportPath, fname, closeIt)
    saveas(fig, fullfile(exportPath, fname), 'png');
    saveas(fig, fullfile(exportPath, fname), 'fig');
    if closeIt, close(fig); end
end

function out = ternaryStr(cond, a, b)
    if cond, out = a; else, out = b; end
end

function m = sectionMeanC(profCol, zD, cCol)
% SECTIONMEANC  Mean C over the section zDimLess <= zD for each frame, from the
% per-frame vertical profiles stored in varsAll.C1Profile (cell of tables or table).
nF = height(profCol);
if istable(profCol), nF = 1; end
m = NaN(nF, 1);
for k = 1:nF
    if iscell(profCol), pr = profCol{k}; else, pr = profCol; end
    if isempty(pr) || ~istable(pr) || ~ismember(cCol, string(pr.Properties.VariableNames)), continue, end
    sel = pr.zDimLess <= zD + 1e-9;
    if any(sel), m(k) = mean(pr.(cCol)(sel), 'omitnan'); end
end
end