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
%   4b MFM analog BTC with the fitted curve (16-84 %), vs time elapsed and vs t_D
%   5  MFM UHS BTC
%   5b MFM UHS BTC with the fitted curve (16-84 %), vs time elapsed and vs t_D
%   6  MFM analog + UHS BTC together
%   7  measured front width vs tD
%   7b front width vs tD: 2D contours (circles) + averaged profile (squares)
%   8  measured front envelope, all experiments together
%   8b front envelope per experiment: 2D-contour width vs averaged-profile width (grey)
%   8c contour width vs averaged-profile width (same scan), all experiments, 1:1 line
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

% experiment colours / names (same scheme as main_dimlessTranspNo and the paper figure):
% P900 (high M) blue, P725 (low M) green; Q1 light (loPe), Q5 dark (hiPe)
expColRules  = {"P900", [0.318 0.654 0.976], [0.090 0.306 0.525]; ...    % {key token, light, dark}
                "P725", [0.435 0.753 0.251], [0.059 0.361 0.102]};
expNameRules = {"P725", "XCT-loM";  "P900", "XCT-hiM"};
expPeRules   = {"Q1", "-loPe";  "Q5", "-hiPe"};
expCol  = zeros(nExp,3);  expName = expKeys;
for i = 1:nExp
    [expCol(i,:), expName(i)] = expStyle(expKeys(i), expColRules, expNameRules, expPeRules, cols(i,:));
end

%% 1) Z profile closest to (zD, CD) target
% frame selection by findProfileFrame (same rule as KL_profileAt in main_CTpostproc):
% the frame whose averaged profile crosses C = CD_target closest to zD = ZD_target
ZD_target = 0.5;
CD_target = 0.5;
for ds = dataSources
    fig = figure;  hold on
    legendEntries = strings(1,nExp);
    for i = 1:nExp
        vars   = expCTDataAll{i}.varsAll.(ds);
        best_l = findProfileFrame(vars, ZD_target, CD_target, "");
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

%% 1b) Z profile closest to (zD, CD) target, with the erfc fit of each curve
% Same frame as section 1 (findProfileFrame: averaged profile crossing C = CD_target closest
% to zD = ZD_target). On top of each profile (markers) the free erfc fit (line):
%   C(zD) = Ci + (Cj - Ci) * 0.5 erfc((zD - zD50)/wD)      (first ADE term)
% fitted here on the plotted profile, end slices (trimFrac1b of the core at each end) left out.
% Legend: experiment name, tD of the frame and the fitted width w = wD*L [cm].

ZD_target1b = 0.5;
CD_target1b = 0.5;
var1b       = "";          % "" = full image (CVert), "_xtrim" = x-trimmed (CVert_xtrim)
trimFrac1b  = 0.02;        % fraction of the core ignored at each end in the fit
fs1b        = 16;          % font size

for ds = dataSources
    fig = figure('Position',[100 100 950 650], 'NumberTitle','off', 'Name', ...
        sprintf('Z profiles through (zD, CD) = (%.1f, %.1f) with erfc fit (%s%s)', ZD_target1b, CD_target1b, ds, var1b));
    ax = axes(fig);  hold(ax,'on')
    h = gobjects(0);
    for i = 1:nExp
        vars   = expCTDataAll{i}.varsAll.(ds);
        best_l = findProfileFrame(vars, ZD_target1b, CD_target1b, var1b);
        if isnan(best_l), continue, end
        prof = cellRow(vars.C1Profile, best_l);
        if iscell(prof), prof = prof{1}; end
        zD = prof.zDimLess(:);  C = prof.("CVert" + var1b)(:);
        Ci = filedataExpAll{i}.C1init/100;  Cj = filedataExpAll{i}.C1j/100;
        Lcm = max(prof.zVertcm);

        [zD50, wD, Cfit] = fitErfcProfile(zD, C, Ci, Cj, trimFrac1b);

        h(end+1) = scatter(ax, zD, C, 8, expCol(i,:), 'filled', 'MarkerFaceAlpha',0.5, ...
            'DisplayName', sprintf('%s, t_D = %.2f', expName(i), vars.tDtotal(best_l))); %#ok<SAGROW>
        if isfinite(wD)
            h(end+1) = plot(ax, zD, Cfit, '-', 'Color',0.6*expCol(i,:), 'LineWidth',2.5, ...
                'DisplayName', sprintf('erfc fit: z_{D,50} = %.2f, w = %.2f cm', zD50, wD*Lcm)); %#ok<SAGROW>
        end
    end
    xlabel(ax, 'z_D [-]', 'FontSize',fs1b);  ylabel(ax, 'C_1 [-]', 'FontSize',fs1b)
    xlim(ax, [0 1]);  ylim(ax, [0 1.02]);  set(ax, 'FontSize',fs1b);  grid(ax,'on')
    legend(ax, h, 'Location','northeast', 'FontSize',fs1b-4, 'Interpreter','tex')
    fname = sprintf('CT_profile_zD_%s_CD_%s_%s%s_erfcFit', strrep(sprintf('%.1f',ZD_target1b),'.','p'), ...
        strrep(sprintf('%.1f',CD_target1b),'.','p'), ds, var1b);
    saveFigBoth(fig, exportPath, fname, closeAfterSave)
end

%% 1c) Mid-core profile with the C = 0.4 / 0.6 crossings (the width used for the mid-profile KL)
% Same frame as the mid-profile KL (findProfileFrame: averaged profile crossing C = CD_target
% closest to zD = ZD_target). Horizontal lines at the two levels, dots where each profile
% crosses them (same front-anchored crossing as profileWidth); the distance between the two
% dots of one colour is W_40-60. Prints frame, t_D, time elapsed, crossings, W and the
% mid-profile KL of that frame (for the figure caption).

ZD_target1c = 0.5;
CD_target1c = 0.5;
lv1c        = [0.4 0.6];       % levels (normalized Cn): lower, upper
var1c       = "_xtrim";        % "" = full (CVert), "_xtrim" = x-trimmed (CVert_xtrim), as the mid-profile KL
trim1c      = 0.02;            % fraction of the core ignored at each end (as profileWidth)
fs1c        = 16;
klTag1c     = "C40_60_contour";   % mid-profile KL method printed next to W

for ds = dataSources
    fig = figure('Position',[100 100 950 650], 'NumberTitle','off', 'Name', ...
        sprintf('Mid-core profiles with the C = %.1f / %.1f crossings (%s%s)', lv1c(1), lv1c(2), ds, var1c));
    ax = axes(fig);  hold(ax,'on')
    h = gobjects(0);  rows1c = {};
    for i = 1:nExp
        vars   = expCTDataAll{i}.varsAll.(ds);
        best_l = findProfileFrame(vars, ZD_target1c, CD_target1c, var1c);
        if isnan(best_l), continue, end
        prof = cellRow(vars.C1Profile, best_l);  if iscell(prof), prof = prof{1}; end
        zD = prof.zDimLess(:);  C = prof.("CVert" + var1c)(:);
        Ci = filedataExpAll{i}.C1init/100;  Cj = filedataExpAll{i}.C1j/100;
        Lcm = max(prof.zVertcm);

        h(end+1) = plot(ax, zD, C, '-', 'LineWidth',2.5, 'Color',expCol(i,:), ...
            'DisplayName', sprintf('%s, t_D = %.2f', expName(i), vars.tDtotal(best_l))); %#ok<SAGROW>

        zc = levelCrossings(zD, C, Ci, Cj, lv1c, trim1c);       % [z(lower) z(upper)] in zD
        Cl = Ci + (Cj - Ci)*lv1c;
        ok = isfinite(zc);
        scatter(ax, zc(ok), Cl(ok), 90, expCol(i,:), 'filled', 'MarkerEdgeColor','k', ...
            'LineWidth',0.8, 'HandleVisibility','off')

        % mid-profile KL of this frame and the arrival time used for it (KL_profileAt)
        KLf = NaN;  tauf = NaN;  tArr = NaN;
        rs = [];  if hasPost(i), rs = expCTDataAll{i}.resultsAll.(ds); end
        vName = "full";  if var1c == "_xtrim", vName = "xtrim"; end
        if ~isempty(rs) && isfield(rs, vName) && isfield(rs.(vName), 'KL_midProfile')
            mp = rs.(vName).KL_midProfile;
            if isfield(mp.methods, klTag1c), tArr = mp.methods.(klTag1c).tArr_min; end
            Tm = mp.T;
            q  = find(Tm.frame == best_l, 1);
            kc = "KL_" + klTag1c + "_cm2min";
            if ~isempty(q) && ismember(kc, string(Tm.Properties.VariableNames))
                KLf = Tm.(kc)(q);  tauf = Tm.tau_contour_min(q);
            end
        end
        fd    = filedataExpAll{i};
        tDarr = tArr*fd.Q/fd.Vtotal;                    % tD = Q t / Vtotal (t in min, Q in ml/min)
        tEl   = vars.secondsElapsed(best_l);
        names1c = ["experiment","frame","tD","t_elapsed_min","t_elapsed_hms", ...
                   "t_arr_min","tD_arr","tD_core","t_core_min", ...
                   "zD_C" + round(100*lv1c(1)), "zD_C" + round(100*lv1c(2)), "W_zD","W_cm","KL_cm2min"];
        rows1c{end+1,1} = table(expName(i), best_l, vars.tDtotal(best_l), tEl/60, ...
            string(sprintf('%02d:%02d:%02d', floor(tEl/3600), floor(mod(tEl,3600)/60), round(mod(tEl,60)))), ...
            tArr, tDarr, vars.tDtotal(best_l) - tDarr, tauf, ...
            zc(1), zc(2), zc(1) - zc(2), (zc(1) - zc(2))*Lcm, KLf, ...
            'VariableNames', names1c); %#ok<SAGROW>
    end
    yline(ax, Ci + (Cj - Ci)*lv1c, '--k', 'LineWidth',1.2, 'HandleVisibility','off');
    xlabel(ax, 'z_D [-]', 'FontSize',fs1c);  ylabel(ax, 'C_1 [-]', 'FontSize',fs1c)
    xlim(ax, [0 1]);  ylim(ax, [0 1.02]);  set(ax, 'FontSize',fs1c);  grid(ax,'on');  box(ax,'on')
    legend(ax, h, 'Location','northeast', 'FontSize',fs1c-2, 'Interpreter','tex')

    T1c = vertcat(rows1c{:});
    fprintf('\n1c) Mid-core profiles, %s%s: frame, time elapsed, C = %.1f / %.1f crossings, W and KL (%s):\n', ...
        ds, var1c, lv1c(1), lv1c(2), klTag1c);
    disp(T1c)
    writetable(T1c, fullfile(exportPath, sprintf('CT_profile_mid_W%02d_%02d_%s%s.xlsx', ...
        round(100*lv1c(1)), round(100*lv1c(2)), ds, var1c)));
    saveFigBoth(fig, exportPath, sprintf('CT_profile_mid_W%02d_%02d_%s%s', ...
        round(100*lv1c(1)), round(100*lv1c(2)), ds, var1c), closeAfterSave)
end
%% 2) Z profiles at a range of tD targets (all experiments, one figure per tD)

tD_target = 0.5:0.1:1.2;
var2      = "_xtrim";                % "" = full image (CVert), "_xtrim" = x-trimmed (CVert_xtrim)

for ds = dataSources
    for m = 1:numel(tD_target)
        fig = figure('Position',[100 100 900 600]);  hold on
        h = gobjects(0);

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            [minDist, l] = min(abs(vars.tDtotal - tD_target(m)));
            if minDist > 0.05
                warning('%s (%s): nearest scan is tD=%.3f (target %.2f)', ...
                    expKeys(i), ds, vars.tDtotal(l), tD_target(m));
            end
            prof = cellRow(vars.C1Profile, l);  if iscell(prof), prof = prof{1}; end
            h(end+1) = plot(prof.zDimLess, prof.("CVert" + var2), 'LineWidth',3, 'Color',expCol(i,:), ...
                'DisplayName', expName(i) + sprintf(", t_D = %.2f", vars.tDtotal(l))); %#ok<SAGROW>
        end
        xlabel('z_D [-]','FontSize',14);  ylabel('C_1 [-]','FontSize',14)
        xlim([0 1]);  ylim([0 1.02]);  set(gca,'FontSize',14);  grid on;  box on
        if tD_target(m) < 0.8, loc = 'northeast'; else, loc = 'southwest'; end
        legend(h, 'Interpreter','tex','FontSize',12,'Location',loc)
        title(sprintf('Z profiles (%s%s) @ t_D = %.1f', ds, var2, tD_target(m)), 'Interpreter','tex')

        fname = sprintf('Zprofiles_%s%s_tD%s', ds, var2, strrep(sprintf('%.1f',tD_target(m)),'.','p'));
        saveFigBoth(fig, exportPath, fname, closeAfterSave)
    end
end

%% 2b) Profile evolution with time, one figure per experiment

tD_evol = 0.3:0.1:1.2;         % t_D of the profiles drawn (nearest scan, within 0.05)
var2b   = "_xtrim";                  % "" = full image, "_xtrim" = x-trimmed

for ds = dataSources
    for i = 1:nExp
        vars = expCTDataAll{i}.varsAll.(ds);
        fig = figure('Position',[100 100 900 600]);  hold on
        h = gobjects(0);
        nT = numel(tD_evol);
        for m = 1:nT
            [minDist, l] = min(abs(vars.tDtotal - tD_evol(m)));
            if minDist > 0.05, continue, end
            prof = cellRow(vars.C1Profile, l);  if iscell(prof), prof = prof{1}; end
            f  = (m - 1)/max(nT - 1, 1);                         % 0 = early, 1 = late
            cm = (1 - f)*(0.25 + 0.75*expCol(i,:)) + f*(0.45*expCol(i,:));   % light -> dark
            h(end+1) = plot(prof.zDimLess, prof.("CVert" + var2b), 'LineWidth',2.5, 'Color',cm, ...
                'DisplayName', sprintf('t_D = %.2f', vars.tDtotal(l))); %#ok<SAGROW>
        end
        if isempty(h), close(fig); continue, end
        xlabel('z_D [-]','FontSize',14);  ylabel('C_1 [-]','FontSize',14)
        xlim([0 1]);  ylim([0 1.02]);  set(gca,'FontSize',14);  grid on;  box on
        legend(h, 'Interpreter','tex','FontSize',11,'Location','eastoutside')
        title(sprintf('%s: Z profiles vs time (%s%s)', expName(i), ds, var2b), 'Interpreter','none')
        saveFigBoth(fig, exportPath, sprintf('Zprofiles_evolution_%s_%s%s', expKeys(i), ds, var2b), closeAfterSave)
    end
end

%% 3) CT outlet BTC: time, tD_total, front-velocity-scaled tD_core
% one dot per scan (markers only, no line: no joins across gaps between scans / runs)
btcVar3      = "_xtrim";                       % "" = full image | "_xtrim" = x-trimmed (x_D 0.25-0.75)
CfieldOutlet = "CD1_zD1p0" + btcVar3;
mk3          = 3;                              % dot size [points]
mkLeg3       = 10;                             % dot size in the legend [points]
% {x column, x label, file tag, x limits ([] = auto)}
btcAxes = {'timeElapsed',            'time elapsed [hh:mm:ss]',                   'time',         []; ...
           'tDtotal',                't_D [-]',                                   'tD',           [0 1.2]; ...
           'tD_corr_contour_scaled', 't_{D,core} (v_{front}-scaled, contour arrival) [-]', 'tDcoreScaled', [0 1.2]};

for ds = dataSources
    for a = 1:size(btcAxes,1)
        xVar = btcAxes{a,1};
        fig = figure('Position',[100 100 900 600]);  hold on
        hLeg = gobjects(0);

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            if ~all(ismember([string(xVar) CfieldOutlet], string(vars.Properties.VariableNames)))
                warning('%s (%s): column %s or %s missing, skipped', expKeys(i), ds, xVar, CfieldOutlet);
                continue
            end
            x = vars.(xVar);  y = vars.(CfieldOutlet);
            ok = ~ismissing(x) & isfinite(y);
            if ~any(ok), continue, end
            % markers only (plot accepts duration x, scatter does not on a held numeric axis)
            plot(x(ok), y(ok), 'o', 'LineStyle','none', 'MarkerSize',mk3, ...
                'MarkerFaceColor',expCol(i,:), 'MarkerEdgeColor',expCol(i,:), 'HandleVisibility','off')
            % legend entry: invisible larger marker (same x type, y = NaN)
            hLeg(end+1) = plot(x(find(ok,1)), NaN, 'o', 'LineStyle','none', 'MarkerSize',mkLeg3, ...
                'MarkerFaceColor',expCol(i,:), 'MarkerEdgeColor',expCol(i,:), 'DisplayName', expName(i)); %#ok<SAGROW>
        end
        if isempty(hLeg), close(fig); continue, end

        xlabel(btcAxes{a,2},'FontSize',14);  ylabel('C_1 at the outlet [-]','FontSize',14)
        ylim([-0.02 1.02]);  set(gca,'FontSize',14);  grid on;  box on
        if ~isempty(btcAxes{a,4}), xlim(btcAxes{a,4}); end
        legend(hLeg, 'Interpreter','none','FontSize',12,'Location','southeast')
        title(sprintf('Outlet BT curves from CT (%s%s)', ds, btcVar3), 'Interpreter','none')

        saveFigBoth(fig, exportPath, sprintf('BT_CT_%s%s_%s', ds, btcVar3, btcAxes{a,3}), closeAfterSave)
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

%% 4b) MFM analog BTC with the fitted curve (best method of main_Processing, shown 16-84 %)
% Same layout as the BTfitting plots of main_Processing: grey error bars, data markers,
% fitted curve (BT.C_fit_best) only where 0.16 <= C_fit <= 0.84. Two versions:
%   time elapsed [hh:mm:ss] with C in %  (as <case>_BTfitting in main_Processing)
%   t_D with C_D [-]                     (as <case>_BTfitting_dimless)

fitRange = [0.16 0.84];
fsBT     = 16;              % font size of everything in the 4b / 5b figures (axes, labels, legend)
% {x column, x label, C scale (100 = %, 1 = fraction), file tag}
btFitX = {'TimeElapsed', 'Time elapsed [hh:mm:ss]', 100, 'time'; ...
          mfmTimeVar,    't_D [-]',                  1,   'tD'};

for ds = dataSources
    for v = 1:size(btFitX,1)
        xVar = btFitX{v,1};  sc = btFitX{v,3};
        fig = figure('Position',[100 100 1000 650]);  hold on
        h = gobjects(0);  isDur = false;

        for i = 1:nExp
            mfm = MFM_CT_DataAll{i}.(ds);
            if isempty(mfm), continue, end
            BT = mfm.BT;  vn = BT.Properties.VariableNames;
            if ~ismember(xVar, vn)
                warning('%s (%s): MFM BT has no %s, skipped', expKeys(i), ds, xVar);  continue
            end
            x = BT.(xVar);

            % data and its uncertainty band, as main_Processing (fraction 0..1 here)
            if ds == "rhoNorm"
                C = BT.rho_norm;  Clo = C;  Chi = C;
                if ismember('drho_norm', vn), Clo = C - BT.drho_norm;  Chi = C + BT.drho_norm; end
            elseif sc == 100 && ismember('Ci', vn)              % time plot: C_1 in mol %, as main_Processing
                C = BT.Ci/100;  Clo = C;  Chi = C;
                if all(ismember({'CiMin','CiMax'}, vn)), Clo = BT.CiMin/100;  Chi = BT.CiMax/100; end
            else                                               % t_D plot: normalized C_D
                C = BT.CDi;  Clo = C;  Chi = C;
                if all(ismember({'CDiMin','CDiMax'}, vn)), Clo = BT.CDiMin;  Chi = BT.CDiMax; end
            end
            isDur = isduration(x);
            %errorbar(x, sc*C, sc*(C - Clo), sc*(Chi - C), 'LineStyle','none', ...
            %    'Color',[0.88 0.88 0.88], 'HandleVisibility','off')
            h(end+1) = scatter(x, sc*C, 6, cols(i,:), 'filled', ...
                'DisplayName', expName(i)); %#ok<SAGROW>

            % fitted curve, 16-84 % only
            if ~ismember('C_fit_best', vn)
                warning('%s (%s): no C_fit_best in the MFM BT, fit not drawn', expKeys(i), ds);  continue
            end
            Cf   = BT.C_fit_best/100;                                % stored in %
            cond = Cf >= fitRange(1) & Cf <= fitRange(2);
            h(end+1) = plot(x(cond), sc*Cf(cond), '-', 'Color',colsDark(i,:), 'LineWidth',3, ...
                'DisplayName', expName(i) + " fit"); %#ok<SAGROW>
        end

        if isempty(h), close(fig); continue, end
        if isDur, xtickformat('hh:mm:ss'), end
        xlabel(btFitX{v,2}, 'FontSize',fsBT)
        if sc == 100, ylabel('C_1 [mol %]','FontSize',fsBT);  ylim([0 105])
        else,         ylabel('C_D [-]','FontSize',fsBT);      ylim([0 1.05]);  xlim([0 2]); end
        set(gca,'FontSize',fsBT);  grid on
        lgd = legend(h, 'Interpreter','tex', 'FontSize',fsBT, 'Location','southeast');
        lgd.ItemTokenSize = [15 8];
        saveFigBoth(fig, exportPath, sprintf('BT_MFM_CT_fit_%s_%s', ds, btFitX{v,4}), closeAfterSave)
    end
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

%% 5b) MFM UHS BTC with the fitted curve (best method of main_Processing, shown 16-84 %)
% Same as 4b for the UHS experiment paired with each CT run (MFM_BTC_UHS_Key).
% Legend names: H2-CO2 -> UHS-hiM, H2-CH4 -> UHS-loM; Q1 -> -loPe, Q5 -> -hiPe.
% uhsRunSwap: for keys containing all tokens in {1}, use run {3} instead of {2}
% (here H2-CH4 Q1: R1 is replaced by R2 from the same expProcFullData.mat).

uhsRunSwap   = {["_H2_CH4_","_Q1_"], "_R1", "_R2"};    % {match tokens, from, to}; {} = none
uhsColRules  = {"H2_CO2", [0.318 0.654 0.976], [0.090 0.306 0.525]; ...   % {token, light Q1, dark}
                "H2_CH4", [0.435 0.753 0.251], [0.059 0.361 0.102]};
uhsNameRules = {"H2_CO2", "UHS-hiM";  "H2_CH4", "UHS-loM"};
uhsPeRules   = {"Q1", "-loPe";  "Q5", "-hiPe"};

% UHS data per CT run (with the run swap), colour and name
uhsData = cell(nExp,1);  uhsKey = strings(nExp,1);  uhsCol = zeros(nExp,3);  uhsName = strings(nExp,1);
for i = 1:nExp
    key = string(inputFileConfig.MFM_BTC_UHS_Key{i});  uhsData{i} = MFM_UHS_DataAll{i};
    if ~isempty(uhsRunSwap) && all(arrayfun(@(t) contains(key, t), uhsRunSwap{1})) && contains(key, uhsRunSwap{2})
        key2  = strrep(key, uhsRunSwap{2}, uhsRunSwap{3});
        fUHS  = fullfile(Root, regexprep(inputFileConfig.MFM_BTC_UHS_Path{i}, '^(\.\./)+', ''), 'expProcFullData.mat');
        try
            uhsData{i} = loadMFMbyDataSource(fUHS, key2, fitDataOf);
            fprintf('5b: %s replaced by %s\n', key, key2);  key = key2;
        catch ME
            warning('5b: %s not loaded (%s) -- %s left out', key2, ME.message, key);
            uhsData{i} = [];
        end
    end
    uhsKey(i) = key;
    [uhsCol(i,:), uhsName(i)] = expStyle(key, uhsColRules, uhsNameRules, uhsPeRules, cols(i,:));
end
% the same UHS experiment can be paired with several CT runs: plot it once
[~, uhsFirst] = unique(uhsKey, 'stable');

for ds = dataSources
    for v = 1:size(btFitX,1)
        xVar = btFitX{v,1};  sc = btFitX{v,3};
        fig = figure('Position',[100 100 1000 650]);  hold on
        h = gobjects(0);  isDur = false;

        for i = uhsFirst(:)'
            if isempty(uhsData{i}) || ~isfield(uhsData{i}, ds) || isempty(uhsData{i}.(ds)), continue, end
            mfm = uhsData{i}.(ds);
            BT = mfm.BT;  vn = BT.Properties.VariableNames;
            if ~ismember(xVar, vn)
                warning('%s (%s): MFM BT has no %s, skipped', uhsKey(i), ds, xVar);  continue
            end
            x = BT.(xVar);

            if ds == "rhoNorm"
                C = BT.rho_norm;  Clo = C;  Chi = C;
                if ismember('drho_norm', vn), Clo = C - BT.drho_norm;  Chi = C + BT.drho_norm; end
            elseif sc == 100 && ismember('Ci', vn)              % time plot: C_1 in mol %
                C = BT.Ci/100;  Clo = C;  Chi = C;
                if all(ismember({'CiMin','CiMax'}, vn)), Clo = BT.CiMin/100;  Chi = BT.CiMax/100; end
            else                                               % t_D plot: normalized C_D
                C = BT.CDi;  Clo = C;  Chi = C;
                if all(ismember({'CDiMin','CDiMax'}, vn)), Clo = BT.CDiMin;  Chi = BT.CDiMax; end
            end
            isDur = isduration(x);
            h(end+1) = scatter(x, sc*C, 6, uhsCol(i,:), 'filled', 'DisplayName', uhsName(i)); %#ok<SAGROW>

            if ~ismember('C_fit_best', vn)
                warning('%s (%s): no C_fit_best in the MFM BT, fit not drawn', uhsKey(i), ds);  continue
            end
            Cf   = BT.C_fit_best/100;
            cond = Cf >= fitRange(1) & Cf <= fitRange(2);
            h(end+1) = plot(x(cond), sc*Cf(cond), '-', 'Color',0.6*uhsCol(i,:), 'LineWidth',3, ...
                'DisplayName', uhsName(i) + " fit"); %#ok<SAGROW>
        end

        if isempty(h), close(fig); continue, end
        if isDur, xtickformat('hh:mm:ss'), end
        xlabel(btFitX{v,2}, 'FontSize',fsBT)
        if sc == 100, ylabel('C_1 [mol %]','FontSize',fsBT);  ylim([0 105])
        else,         ylabel('C_D [-]','FontSize',fsBT);      ylim([0 1.05]);  xlim([0 2]); end
        set(gca,'FontSize',fsBT);  grid on
        lgd = legend(h, 'Interpreter','tex', 'FontSize',fsBT, 'Location','southeast');
        lgd.ItemTokenSize = [15 8];
        saveFigBoth(fig, exportPath, sprintf('BT_MFM_UHS_fit_%s_%s', ds, btFitX{v,4}), closeAfterSave)
    end
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

%% 7b) Front width vs tD: 2D contours (circles) and averaged profile (squares) together
% Section 7 with the averaged-profile width (zDWidthProf_*, from main_CTpostproc /
% addProfileWidths) drawn on top as squares, same colour per experiment.

widthPairsCmp = {'10_90','20_80','30_70','40_60'};
widthVarCmp   = "_xtrim";           % "" = full image, "_xtrim" = x-trimmed

for ds = dataSources
    for p = 1:numel(widthPairsCmp)
        cField = "zDWidth_"     + widthPairsCmp{p} + widthVarCmp;   % 2D contours
        pField = "zDWidthProf_" + widthPairsCmp{p} + widthVarCmp;   % averaged profile
        fig = figure('Position',[100 100 1000 650]);  hold on
        nPlotted = 0;

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            vn   = string(vars.Properties.VariableNames);
            if ismember(cField, vn)
                scatter(vars.tDtotal, abs(vars.(cField)), 10, 'filled', 'o', ...
                    'MarkerFaceColor',cols(i,:), 'MarkerEdgeColor','none', ...
                    'DisplayName', expName(i) + " contours")
                nPlotted = nPlotted + 1;
            end
            if ismember(pField, vn)
                scatter(vars.tDtotal, abs(vars.(pField)), 26, 's', ...
                    'MarkerFaceColor',cols(i,:), 'MarkerEdgeColor',colsDark(i,:), 'LineWidth',0.8, ...
                    'DisplayName', expName(i) + " profile")
                nPlotted = nPlotted + 1;
            end
        end
        if nPlotted == 0, close(fig); continue, end

        xlabel('t_D [-]','FontSize',14);  ylabel('\DeltaZ_D [-]','FontSize',14)
        ylim([-0.02 1]);  xlim([0 1.2]);  set(gca,'FontSize',14);  grid on
        legend('Interpreter','none','FontSize',8,'Location','northeast','NumColumns',2)
        title(sprintf('Front width (%s): 2D contours (circles) vs averaged profile (squares) (%s%s)', ...
            strrep(widthPairsCmp{p},'_','-'), ds, widthVarCmp), 'Interpreter','tex')
        saveFigBoth(fig, exportPath, sprintf('width_contour_profile_%s_%s%s_tD', ...
            widthPairsCmp{p}, ds, widthVarCmp), closeAfterSave)
    end
end

%% 7c) Averaged-profile front width vs tD only (one figure per level pair)
% zDWidthProf_<lo>_<hi> (addProfileWidths, main_CTpostproc), one colour per experiment
% (expCol: P900 blue / P725 green, light = Q1, dark = Q5), legend XCT-loM-hiPe etc.
% No axes title: the description is the figure name.

widthPairsProf = {'10_90','20_80','30_70','40_60'};
widthVarProf   = "_xtrim";         % "" = full image, "_xtrim" = x-trimmed
widthUnitProf  = "";               % "" = zD [-], "_cm" = cm
fs7c           = 16;               % font size
mk7c           = 30;               % marker size

for ds = dataSources
    for p = 1:numel(widthPairsProf)
        pField  = "zDWidthProf_" + widthPairsProf{p} + widthVarProf + widthUnitProf;
        figName = sprintf('Averaged-profile front width %s vs t_D (%s%s)', ...
            strrep(widthPairsProf{p},'_','-'), ds, widthVarProf);
        fig = figure('Position',[100 100 1000 650], 'Name',figName, 'NumberTitle','off');
        ax  = axes(fig);  hold(ax,'on')
        nPlotted = 0;

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            if ~ismember(pField, string(vars.Properties.VariableNames)), continue, end
            w  = abs(vars.(pField));
            ok = isfinite(vars.tDtotal) & isfinite(w);
            if ~any(ok), continue, end
            scatter(ax, vars.tDtotal(ok), w(ok), mk7c, expCol(i,:), 'o', 'filled', ...
                'MarkerEdgeColor',0.6*expCol(i,:), 'LineWidth',0.5, 'DisplayName', expName(i))
            nPlotted = nPlotted + 1;
        end
        if nPlotted == 0, close(fig); continue, end

        set(ax, 'FontSize',fs7c, 'LabelFontSizeMultiplier',1, 'TitleFontSizeMultiplier',1)
        xlabel(ax, 't_D [-]', 'FontSize',fs7c)
        if widthUnitProf == "_cm"
            ylabel(ax, "W_{" + strrep(widthPairsProf{p},'_','-') + "}, averaged profile [cm]", 'FontSize',fs7c)
        else
            ylabel(ax, "\Deltaz_{D," + strrep(widthPairsProf{p},'_','-') + "}, averaged profile [-]", 'FontSize',fs7c)
            ylim(ax, [0 inf])
        end
        xlim(ax, [0 1.2]);  grid(ax,'on');  box(ax,'on')
        legend(ax, 'Location','northwest', 'FontSize',fs7c, 'Interpreter','none')
        saveFigBoth(fig, exportPath, sprintf('width_profile_%s_%s%s%s_tD', ...
            widthPairsProf{p}, ds, widthVarProf, widthUnitProf), closeAfterSave)
    end
end

%% 7d) Averaged-profile front width vs tD, with the frame of the KL-by-method value (red circle)
% Same as 7c (zDWidthProf_<lo>_<hi>, one colour per experiment), legend top right, plus, per
% experiment, the frame used for the XCT 1D-profile bar of section 17 / 17c (rotPos = rsRot +/- rsTol,
% front centre closest to zD = 0.5 within rsZD, rotZDsel) as a red open circle, as in section 15b.
% Legend: one entry per experiment + one red circle "theta = rsRot".
% Uses the settings of section 17 / 17c (rsRot, rsTol, rsZD, rsPair, rsVar): run it first, or the
% defaults below are used.

if ~exist('rsRot','var'), rsRot = 226; rsTol = 1; rsZD = [0.2 0.8]; rsPair = [0.40 0.60]; rsVar = "_xtrim"; end
widthPairs7d = {sprintf('%02d_%02d', round(100*rsPair))};   % e.g. {'40_60'}; more pairs: {'10_90','40_60'}
widthVar7d   = rsVar;              % "" = full image, "_xtrim" = x-trimmed (same as the bar)
widthUnit7d  = "";                 % "" = zD [-], "_cm" = cm
fs7d         = 16;                 % font size
mk7d         = 30;                 % marker size (dots and red circle)
colBar7d     = [0.85 0 0];         % colour of the red circle

for ds = "conc"
    for p = 1:numel(widthPairs7d)
        pField  = "zDWidthProf_" + widthPairs7d{p} + widthVar7d + widthUnit7d;
        figName = sprintf('Averaged-profile front width %s vs t_D, with the theta = %d deg frame (%s%s)', ...
            strrep(widthPairs7d{p},'_','-'), rsRot, ds, widthVar7d);
        fig = figure('Position',[100 100 1000 650], 'Name',figName, 'NumberTitle','off');
        ax  = axes(fig);  hold(ax,'on')
        h = gobjects(0);  hBar = gobjects(0);  rows7d = {};

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            if ~ismember(pField, string(vars.Properties.VariableNames)), continue, end
            w  = abs(vars.(pField));
            ok = isfinite(vars.tDtotal) & isfinite(w);
            if ~any(ok), continue, end
            h(end+1) = scatter(ax, vars.tDtotal(ok), w(ok), mk7d, expCol(i,:), 'o', 'filled', ...
                'MarkerEdgeColor',0.6*expCol(i,:), 'LineWidth',0.5, 'DisplayName', expName(i)); %#ok<SAGROW>

            % frame of the KL-by-method bar (same selection as 17 / 17c / 15b)
            Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, rsVar, rsPair);
            if isempty(Tk), continue, end
            fr = Tk.frame(rotZDsel(Tk, rsRot, rsTol, rsZD));
            fr = fr(ok(fr));
            if isempty(fr), continue, end
            hb = scatter(ax, vars.tDtotal(fr), w(fr), mk7d, 'o', 'MarkerEdgeColor',colBar7d, ...
                'MarkerFaceColor','none', 'LineWidth',2.5, 'DisplayName', sprintf('\\theta = %d°', rsRot));
            if isempty(hBar), hBar = hb; else, hb.HandleVisibility = 'off'; end
            rows7d{end+1,1} = table(repmat(expName(i),numel(fr),1), fr, vars.tDtotal(fr), vars.rotPos(fr), w(fr), ...
                'VariableNames', {'experiment','frame','tD','rotPos_deg', char(pField)}); %#ok<SAGROW>
        end
        if isempty(h), close(fig); continue, end

        set(ax, 'FontSize',fs7d, 'LabelFontSizeMultiplier',1, 'TitleFontSizeMultiplier',1)
        xlabel(ax, 't_D [-]', 'FontSize',fs7d)
        if widthUnit7d == "_cm"
            ylabel(ax, "W_{" + strrep(widthPairs7d{p},'_','-') + "}, averaged profile [cm]", 'FontSize',fs7d)
        else
            ylabel(ax, "\Deltaz_{D," + strrep(widthPairs7d{p},'_','-') + "}, averaged profile [-]", 'FontSize',fs7d)
            ylim(ax, [0 inf])
        end
        xlim(ax, [0 1.2]);  grid(ax,'on');  box(ax,'on')
        legend(ax, [h hBar], 'Location','northeast', 'FontSize',fs7d, 'Interpreter','tex')
        if ~isempty(rows7d)
            fprintf('\n7d) Frame of the KL-by-method value (theta = %g deg), width %s:\n', rsRot, pField);
            disp(vertcat(rows7d{:}))
        end
        saveFigBoth(fig, exportPath, sprintf('width_profile_%s_%s%s%s_tD_rot%d', ...
            widthPairs7d{p}, ds, widthVar7d, widthUnit7d, rsRot), closeAfterSave)
    end
end
%% 8) Measured front envelope, all experiments together
% front centre (C = 0.5) +/- half width per scan; legend XCT-loM-hiPe etc. (expName, expCol)

widthPairsEnv = {'10_90','30_70','40_60'};
envSrc8       = "zDWidth_";    % "zDWidth_" = 2D contours | "zDWidthProf_" = averaged profile
envVar8       = "";            % "" = full image | "_xtrim" = x-trimmed (width and front centre)

for ds = dataSources
    for p = 1:numel(widthPairsEnv)
        measField = envSrc8 + widthPairsEnv{p} + envVar8;
        cenField  = "zDFront50" + envVar8;
        fig = figure('Position',[100 100 1000 650]);  hold on

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            if ~all(ismember([measField cenField], string(vars.Properties.VariableNames))), continue, end

            tD = vars.tDtotal;
            centerMeas = vars.(cenField);
            halfMeas   = abs(vars.(measField))/2;
            validMeas  = isfinite(centerMeas) & isfinite(halfMeas);

            % one vertical segment per scan: front centre +/- half width
            xs = [tD(validMeas)'; tD(validMeas)'; nan(1,nnz(validMeas))];
            ys = [centerMeas(validMeas)' - halfMeas(validMeas)'; ...
                  centerMeas(validMeas)' + halfMeas(validMeas)'; nan(1,nnz(validMeas))];
            plot(xs(:), ys(:), '-', 'Color',[expCol(i,:) 0.6], 'LineWidth',1.5, 'HandleVisibility','off')
            scatter(tD(validMeas), centerMeas(validMeas), 18, 0.6*expCol(i,:), 'filled', ...
                'DisplayName', expName(i))
        end

        xlabel('t_D [-]','FontSize',14);  ylabel('z_D [-]','FontSize',14)
        ylim([-0.02 1.02]);  xlim([0 1.2]);  set(gca,'FontSize',14);  grid on
        legend('Interpreter','none','FontSize',12,'Location','southeast')
        title(sprintf('Measured front envelope (%s, centred on C=0.5) (%s%s)', ...
            strrep(widthPairsEnv{p},'_','-'), ds, envVar8), 'Interpreter','none')
        saveFigBoth(fig, exportPath, sprintf('frontEnvelope_CT_allExp_%s_%s%s_tD', ...
            widthPairsEnv{p}, ds, envVar8), closeAfterSave)
    end
end

%% 8a) Front envelope from the AVERAGED PROFILE, all experiments together
% Centre = front centre of the averaged profile (zDFrontProf50: erfc-fit z50, addProfileWidths),
% bar = centre +/- W/2 with W = averaged-profile width zDWidthProf_<lo>_<hi> (the width used for
% the profile KL). If the erfc centre is missing for a scan, the C = 0.5 contour centre is used.
% Legend XCT-loM-hiPe etc. (expName, expCol).

widthPairsEnvP = {'10_90','20_80','30_70','40_60'};
envVarP        = "_xtrim";      % "" = full image | "_xtrim" = x-trimmed (as the mid-profile KL)
fsEnvP         = 16;

for ds = dataSources
    for p = 1:numel(widthPairsEnvP)
        wField = "zDWidthProf_" + widthPairsEnvP{p} + envVarP;
        cField = "zDFrontProf50" + envVarP;          % profile centre
        cFall  = "zDFront50" + envVarP;              % fallback: C = 0.5 contour centre
        figName = sprintf('Averaged-profile front envelope %s (%s%s)', ...
            strrep(widthPairsEnvP{p},'_','-'), ds, envVarP);
        fig = figure('Position',[100 100 1000 650], 'Name',figName, 'NumberTitle','off');
        ax  = axes(fig);  hold(ax,'on')
        nPlotted = 0;

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            vn   = string(vars.Properties.VariableNames);
            if ~ismember(wField, vn), continue, end

            tD   = vars.tDtotal;
            half = abs(vars.(wField))/2;
            cen  = nan(size(tD));
            if ismember(cField, vn), cen = vars.(cField); end
            if ismember(cFall, vn)
                miss = ~isfinite(cen);  cen(miss) = vars.(cFall)(miss);
            end
            ok = isfinite(tD) & isfinite(cen) & isfinite(half);
            if ~any(ok), continue, end

            % one vertical segment per scan: centre +/- half width
            xs = [tD(ok)'; tD(ok)'; nan(1,nnz(ok))];
            ys = [cen(ok)' - half(ok)'; cen(ok)' + half(ok)'; nan(1,nnz(ok))];
            plot(ax, xs(:), ys(:), '-', 'Color',[expCol(i,:) 0.6], 'LineWidth',1.5, 'HandleVisibility','off')
            scatter(ax, tD(ok), cen(ok), 18, 0.6*expCol(i,:), 'filled', 'DisplayName', expName(i))
            nPlotted = nPlotted + 1;
        end
        if nPlotted == 0, close(fig); continue, end

        set(ax, 'FontSize',fsEnvP, 'LabelFontSizeMultiplier',1, 'TitleFontSizeMultiplier',1)
        xlabel(ax, 't_D [-]', 'FontSize',fsEnvP);  ylabel(ax, 'z_D [-]', 'FontSize',fsEnvP)
        ylim(ax, [-0.02 1.02]);  xlim(ax, [0 1.2]);  grid(ax,'on');  box(ax,'on')
        legend(ax, 'Interpreter','none', 'FontSize',fsEnvP, 'Location','southeast')
        saveFigBoth(fig, exportPath, sprintf('frontEnvelope_profile_allExp_%s_%s%s_tD', ...
            widthPairsEnvP{p}, ds, envVarP), closeAfterSave)
    end
end

%% 8a2) Front centre of the AVERAGED PROFILE vs tD, with the front-velocity line (no width bars)
% Dots = front centre of the averaged profile (zDFrontProf50: erfc-fit z50, addProfileWidths; where
% missing, the C = 0.5 contour centre zDFront50), as 8a but without the +/- W/2 bars.
% Line (dashed, same colour) = constant front velocity of each experiment, straight line in t_D:
%   vfSrc = "C50"   : through the C = 0.5 centre, column tD_corr_vFrontC50 (v_front and t0 of the
%                     C = 0.5 line from main_CTpreproc) -> lies on the dots
%   vfSrc = "column": through the leading edge, column tD_corr_contour_scaled (v_front with the
%                     C = 0.01 contour arrival) -> same slope, earlier (shifted left)
%   vfSrc = "fit"   : straight line fitted to the plotted centres with z_D in vfZDfit
% Legend: one entry per experiment (dots) + one dashed entry "u_front" (no value).
% Print: u_front [cm/min] as printed by main_CTpostproc (resultsAll.(ds).vFront_cmmin);
% fallback: slope [z_D per t_D] * L[in]*2.54 * Q / V_total (filedataExp.L is in inches).

envVarP2  = "_xtrim";           % "" = full image | "_xtrim" = x-trimmed (as the mid-profile KL)
vfSrc     = "C50";              % "C50" | "column" | "fit"
vfZDfit   = [0.1 0.9];          % zD range of the centres used when vfSrc = "fit"
fsEnvP2   = 16;
mkEnvP2   = 18;

for ds = dataSources
    cField = "zDFrontProf50" + envVarP2;          % profile centre
    cFall  = "zDFront50" + envVarP2;              % fallback: C = 0.5 contour centre
    figName = sprintf('Averaged-profile front centre with the u_front line (%s%s, %s)', ds, envVarP2, vfSrc);
    fig = figure('Position',[100 100 1000 650], 'Name',figName, 'NumberTitle','off');
    ax  = axes(fig);  hold(ax,'on')
    h = gobjects(0);  hLine = gobjects(0);  rows8a2 = {};

    for i = 1:nExp
        vars = expCTDataAll{i}.varsAll.(ds);
        vn   = string(vars.Properties.VariableNames);
        fd   = filedataExpAll{i};
        tD   = vars.tDtotal;
        cen  = nan(size(tD));
        if ismember(cField, vn), cen = vars.(cField); end
        if ismember(cFall, vn)
            miss = ~isfinite(cen);  cen(miss) = vars.(cFall)(miss);
        end
        ok = isfinite(tD) & isfinite(cen);
        if ~any(ok), continue, end
        h(end+1) = scatter(ax, tD(ok), cen(ok), mkEnvP2, expCol(i,:), 'filled', ...
            'MarkerEdgeColor',0.6*expCol(i,:), 'DisplayName', expName(i)); %#ok<SAGROW>

        % front-velocity line z_D = p(2) + p(1) t_D
        p = [NaN NaN];  srcUsed = vfSrc;
        colC50 = "tD_corr_vFrontC50" + envVarP2;
        if vfSrc == "C50" && ismember(colC50, vn)
            okc = isfinite(tD) & isfinite(vars.(colC50));
            if nnz(okc) >= 2, p = polyfit(tD(okc), vars.(colC50)(okc), 1); end
        elseif vfSrc == "column" && ismember("tD_corr_contour_scaled", vn)
            okc = isfinite(tD) & isfinite(vars.tD_corr_contour_scaled);
            if nnz(okc) >= 2, p = polyfit(tD(okc), vars.tD_corr_contour_scaled(okc), 1); end
        end
        if ~all(isfinite(p))                                  % "fit", or the column is missing
            if vfSrc ~= "fit"
                warning('8a2: %s (%s): column for vfSrc = "%s" missing -- line fitted to the centres', ...
                    expKeys(i), ds, vfSrc);
            end
            srcUsed = "fit";
            okf = ok & cen >= vfZDfit(1) & cen <= vfZDfit(2);
            if nnz(okf) >= 2, p = polyfit(tD(okf), cen(okf), 1); end
        end
        if ~all(isfinite(p)) || p(1) <= 0, continue, end
        tD0 = -p(2)/p(1);  tD1 = (1 - p(2))/p(1);          % line from z_D = 0 to z_D = 1

        % u_front (v_front) as printed by main_CTpostproc; fallback: slope with L converted from inches to cm
        vfPost = NaN;
        if hasPost(i) && isfield(expCTDataAll{i}, 'resultsAll') && isfield(expCTDataAll{i}.resultsAll, ds) ...
                && isfield(expCTDataAll{i}.resultsAll.(ds), 'vFront_cmmin')
            vfPost = expCTDataAll{i}.resultsAll.(ds).vFront_cmmin;
        end
        vfSlope = p(1) * fd.L*2.54 * fd.Q / fd.Vtotal;      % [cm/min] (L in inches, Q in ml/min, V in ml)
        vf = vfPost;  if ~isfinite(vf), vf = vfSlope; end

        plot(ax, [tD0 tD1], [0 1], '--', 'Color',0.6*expCol(i,:), 'LineWidth',2, 'HandleVisibility','off')
        if isempty(hLine)                                   % one legend entry for all lines
            hLine = plot(ax, NaN, NaN, '--', 'Color',[0.3 0.3 0.3], 'LineWidth',2, 'DisplayName','u_{front}');
        end
        rows8a2{end+1,1} = table(expName(i), string(srcUsed), p(1), tD0, tD1, vfPost, vfSlope, ...
            'VariableNames', {'experiment','line','slope_zD_per_tD','tD_at_zD0','tD_at_zD1', ...
            'ufront_postproc_cm_min','ufront_slope_cm_min'}); %#ok<SAGROW>
    end
    if isempty(h), close(fig); continue, end

    set(ax, 'FontSize',fsEnvP2, 'LabelFontSizeMultiplier',1, 'TitleFontSizeMultiplier',1)
    xlabel(ax, 't_D [-]', 'FontSize',fsEnvP2);  ylabel(ax, 'z_D front centre [-]', 'FontSize',fsEnvP2)
    ylim(ax, [-0.02 1.02]);  xlim(ax, [0 1.2]);  grid(ax,'on');  box(ax,'on')
    legend(ax, [h hLine], 'Interpreter','tex', 'FontSize',fsEnvP2-2, 'Location','southeast')
    if ~isempty(rows8a2)
        fprintf('\n8a2) Front velocity u_front per experiment (%s%s, line: %s):\n', ds, envVarP2, vfSrc);
        disp(vertcat(rows8a2{:}))
    end
    saveFigBoth(fig, exportPath, sprintf('frontCentre_profile_ufront_allExp_%s%s_%s_tD', ds, envVarP2, vfSrc), closeAfterSave)
end
%% 8b) Front envelope per experiment: 2D-contour width (colour) vs averaged-profile width (grey)
% Contour widths zDWidth_<lo>_<hi> (populate_CTframeVars) and averaged-profile widths
% zDWidthProf_<lo>_<hi> (addProfileWidths, written by main_CTpostproc into <Key>_postproc.mat).
% Both envelopes are centred on the same front centre (C = 0.5 contour, zDFront50), so the
% panels compare the WIDTHS only. One figure per experiment, one panel per level pair.

envPairs   = {'10_90','20_80','30_70','40_60'};
envVariant = "_xtrim";              % "" = full image, "_xtrim" = x-trimmed
greyProf   = [0.55 0.55 0.55];

% experiment colours / names (expCol, expName): see the Load data section

for ds = dataSources
    for i = 1:nExp
        vars   = expCTDataAll{i}.varsAll.(ds);
        cols_i = string(vars.Properties.VariableNames);
        if ~any(startsWith(cols_i, "zDWidthProf_"))
            warning('%s (%s): no zDWidthProf_* columns -- run main_CTpostproc (addProfileWidths) first', ...
                expKeys(i), ds);
            continue
        end

        fig = figure('Position',[60 60 1400 950]);
        tl  = tiledlayout(fig, 2, 2, 'TileSpacing','compact');
        tD  = vars.tDtotal;
        zc  = vars.("zDFront50" + envVariant);

        for p = 1:numel(envPairs)
            ax = nexttile(tl);  hold(ax,'on')
            cCol = "zDWidth_"     + envPairs{p} + envVariant;
            pCol = "zDWidthProf_" + envPairs{p} + envVariant;
            if ~all(ismember([cCol pCol], cols_i))
                text(ax, 0.5, 0.5, cCol + " / " + pCol + " not available", 'Units','normalized', ...
                    'HorizontalAlignment','center', 'Interpreter','none');  continue
            end
            % averaged profile (grey, wide, behind) and 2D contours (colour, on top)
            envSegments(ax, tD, zc, abs(vars.(cCol))/2, expCol(i,:), 1.8, 0.9, "2D contours")
            envSegments(ax, tD, zc, abs(vars.(pCol))/2, greyProf, 5, 0.5, "averaged profile")
            ok = isfinite(tD) & isfinite(zc);
            scatter(ax, tD(ok), zc(ok), 10, 0.6*expCol(i,:), 'filled', 'DisplayName','front centre (C = 0.5)')

            xlabel(ax, 't_D [-]', 'FontSize',13);  ylabel(ax, 'z_D [-]', 'FontSize',13)
            ylim(ax, [-0.02 1.02]);  xlim(ax, [0 1.2]);  set(ax, 'FontSize',12);  grid(ax,'on')
            title(ax, "width " + strrep(envPairs{p},'_','-'), 'FontSize',12)
            legend(ax, 'Location','southeast', 'FontSize',9)
        end
        title(tl, sprintf('%s (%s): front envelope, 2D contours (colour) vs averaged profile (grey)', ...
            expName(i), ds), 'Interpreter','none')
        saveFigBoth(fig, exportPath, sprintf('frontEnvelope_contour_vs_profile_%s_%s%s', ...
            expKeys(i), ds, envVariant), closeAfterSave)
    end
end

%% 8c) Contour width vs averaged-profile width, same frame, all experiments
% x = width between the 2D contours, y = width of the averaged profile, same scan (same t).
% A sharp, planar front gives the same width either way (1:1 line). Fingering / an uneven
% front stretches the contours (which follow the fingers) more than the x-averaged profile
% -> points move away from the 1:1 line; the distance from it measures the instability.

parPairs   = {'10_90','20_80','30_70','40_60'};
parVariant = "_xtrim";              % "" = full image, "_xtrim" = x-trimmed
parQmk     = {"Q1",'o'; "Q5",'o'};   % marker by flow rate (colour already light/dark)

for ds = dataSources
    fig = figure('Position',[60 60 1250 1100]);
    tl  = tiledlayout(fig, 2, 2, 'TileSpacing','compact');

    for p = 1:numel(parPairs)
        ax = nexttile(tl);  hold(ax,'on');  allW = [];
        for i = 1:nExp
            vars   = expCTDataAll{i}.varsAll.(ds);
            cols_i = string(vars.Properties.VariableNames);
            cCol = "zDWidth_"     + parPairs{p} + parVariant;
            pCol = "zDWidthProf_" + parPairs{p} + parVariant;
            if ~all(ismember([cCol pCol], cols_i)), continue, end
            wC = abs(vars.(cCol));  wP = abs(vars.(pCol));
            ok = isfinite(wC) & isfinite(wP) & wC > 0 & wP > 0;
            if ~any(ok), continue, end
            mk = 'o';
            for q = 1:size(parQmk,1)
                if contains(expKeys(i), "_" + parQmk{q,1} + "_"), mk = parQmk{q,2}; end
            end
            scatter(ax, wC(ok), wP(ok), 26, expCol(i,:), mk, 'filled', 'MarkerEdgeColor','k', ...
                'LineWidth',0.3, 'MarkerFaceAlpha',0.8, 'DisplayName', expName(i))
            allW = [allW; wC(ok); wP(ok)]; %#ok<AGROW>
        end
        if isempty(allW)
            text(ax, 0.5, 0.5, "no contour / profile widths for " + strrep(parPairs{p},'_','-'), ...
                'Units','normalized', 'HorizontalAlignment','center');  continue
        end
        lim = [0, 1.05*max(allW)];
        plot(ax, lim, lim, 'k-', 'LineWidth',1.2, 'DisplayName','1:1 (stable front)')
        xlim(ax, lim);  ylim(ax, lim);  axis(ax, 'square')
        xlabel(ax, '\Deltaz_D, 2D contours [-]', 'FontSize',13)
        ylabel(ax, '\Deltaz_D, averaged profile [-]', 'FontSize',13)
        title(ax, "width " + strrep(parPairs{p},'_','-'), 'FontSize',12)
        set(ax, 'FontSize',12);  grid(ax,'on')
        legend(ax, 'Location','northwest', 'FontSize',9, 'Interpreter','none')
    end
    title(tl, sprintf('Front width: 2D contours vs averaged profile, same scan (%s%s)', ds, parVariant), ...
        'Interpreter','none')
    saveFigBoth(fig, exportPath, sprintf('width_contour_vs_profile_allExp_%s%s', ds, parVariant), closeAfterSave)
end

%% 8d) Contour width vs averaged-profile width, split by viscosity ratio (high M / low M)
% Same as 8c, one set of figures per M group so the experiments do not overlap:
%   - one 2x2 figure per M group (all level pairs)
%   - one figure per M group AND level pair (individual images)
% Groups are picked from tokens in the experiment key (P900 = high M, P725 = low M).
% Axis limits are the same for every figure of one level pair (both M groups), so the
% high-M and low-M images can be compared directly. No axes title: the description is
% the figure name (window title).

parMGroups  = {"hiM", "P900", "high M (XCT-hiM)"; ...      % {file tag, key token, description}
               "loM", "P725", "low M (XCT-loM)"};
parPairs8d  = {'10_90','20_80','30_70','40_60'};
parVar8d    = "_xtrim";            % "" = full image, "_xtrim" = x-trimmed
parQmk8d    = {"Q1",'o'; "Q5",'o'}; % marker by flow rate (colour already light/dark)
fs8d        = 16;                  % font size (axes, labels, legend)
mk8d        = 45;                  % marker size (scatter area)

for ds = dataSources
    % common axis limits per level pair, from all experiments of both groups
    inAll = find(contains(expKeys, "_" + string(parMGroups(:,2)') + "_"))';
    lim8d = cell(1, numel(parPairs8d));
    for p = 1:numel(parPairs8d)
        lim8d{p} = parityLim(expCTDataAll, ds, inAll, parPairs8d{p}, parVar8d);
    end

    for g = 1:size(parMGroups,1)
        inG = find(contains(expKeys, "_" + parMGroups{g,2} + "_"))';
        if isempty(inG)
            warning('8d: no experiments with %s in the key', parMGroups{g,2});  continue
        end

        % ---- 2x2 figure, all pairs (panel label = level pair)
        figName = sprintf('Front width: 2D contours vs averaged profile, same scan, %s (%s%s)', ...
            parMGroups{g,3}, ds, parVar8d);
        fig = figure('Position',[60 60 1250 1100], 'Name',figName, 'NumberTitle','off');
        tl  = tiledlayout(fig, 2, 2, 'TileSpacing','compact');
        for p = 1:numel(parPairs8d)
            ax = nexttile(tl);
            parityPanel(ax, expCTDataAll, ds, inG, parPairs8d{p}, parVar8d, parQmk8d, expKeys, ...
                expCol, expName, lim8d{p}, fs8d, mk8d);
            title(ax, "width " + strrep(parPairs8d{p},'_','-'), 'FontSize',fs8d)
        end
        saveFigBoth(fig, exportPath, sprintf('width_contour_vs_profile_%s_%s%s', ...
            parMGroups{g,1}, ds, parVar8d), closeAfterSave)

        % ---- one figure per pair, no title
        for p = 1:numel(parPairs8d)
            figName = sprintf('Front width %s: 2D contours vs averaged profile, %s (%s%s)', ...
                strrep(parPairs8d{p},'_','-'), parMGroups{g,3}, ds, parVar8d);
            fig = figure('Position',[100 100 700 650], 'Name',figName, 'NumberTitle','off');
            ax  = axes(fig);
            ok  = parityPanel(ax, expCTDataAll, ds, inG, parPairs8d{p}, parVar8d, parQmk8d, expKeys, ...
                expCol, expName, lim8d{p}, fs8d, mk8d);
            if ~ok, close(fig); continue, end
            saveFigBoth(fig, exportPath, sprintf('width_contour_vs_profile_%s_%s_%s%s', ...
                parMGroups{g,1}, parPairs8d{p}, ds, parVar8d), closeAfterSave)
        end
    end
end

%% 8e) KL by method for the four cases: bar chart and M-Pe quadrant chart
% Four KL estimates per XCT experiment, all with error bars:
%   XCT 1D profile    mid-profile KL (KL_profileAt, x-trimmed): front centre C = 0.5 at zD = 0.5
%   XCT 2D contours   same frames and tau, width between the 2D contours (klMidContMethod, "" = no bar)
%   XCT BTC zD = ...  CT breakthrough curve at each level in klBTCtags (zD = 0.5, 0.8, 1.0):
%                     a KL that decreases with zD means the front sharpens towards the outlet
%                     (end / boundary effect), it does not keep spreading as the ADE predicts
%   XCT MFM           MFM of the analog (He-Xe) experiment
%   UHS MFM           MFM of the paired UHS experiment (with the run swap of 5b: H2-CH4 Q1 -> R2)
% Figure 1: grouped bars, one group per case (loM-loPe, loM-hiPe, hiM-loPe, hiM-hiPe).
% Figure 2: same bars in a 2x2 M-Pe map: up = high Pe, down = low Pe, left = low M, right = high M;
%           each panel shows M and Pe (= u L / D0) of the XCT and the UHS experiment.
% Needs section 5b to have run before (uhsData, uhsKey); otherwise the configured UHS key is used.

klMidVariant = "xtrim";         % mid-profile variant: "xtrim" | "full"
klMidMethod  = "C40_60_contour";    % averaged profile, W_40-60
klMidStat    = "mean";              % same statistic as the contour bar
klMidContMethod = "contC40_60_contour";  % 2D-contour width at the same frames; "" = no bar
klMidContStat   = "mean";       % level pairs have no fit SE -> mean +/- std of the window frames
klBTCVariant = "xtrim";         % CT BTC variant: "xtrim" | "full"
%klBTCtags    = ["zD0p5","zD0p8","zD1p0"];   % CT BTC levels (one bar each, light -> dark along the core)
klBTCtags    = ["zD0p5","zD1p0"];   % CT BTC levels (one bar each, light -> dark along the core)
fsKL         = 16;              % font size
btcNames     = "XCT BTC z_D = " + strrep(extractAfter(klBTCtags,"zD"), "p", ".");
nB           = numel(klBTCtags);
%btcCols      = [linspace(0.85,0.35,nB)', linspace(0.70,0.08,nB)', linspace(0.95,0.45,nB)'];  % purple, light -> dark
btcCols      = [linspace(0.85,0.35,nB)', linspace(0.70,0.08,nB)', linspace(0.95,0.45,nB)'];  % purple, light -> dark
if nB == 1, btcCols = [0.35 0.08 0.45]; end
hasCont      = double(klMidContMethod ~= "");   % 1 = contour bar, 0 = none
klSrcNames   = ["XCT 1D profile", repmat("XCT 2D contours",1,hasCont), btcNames, "XCT MFM", "UHS MFM"];
klSrcCols    = [0.85 0.33 0.10; repmat([0.98 0.70 0.45],hasCont,1); btcCols; 0.35 0.35 0.35; 0.30 0.75 0.93];
nSrc         = numel(klSrcNames);
iCont        = 2*hasCont;              % column of the contour bar (0 = none)
iBTC0        = 1 + hasCont;            % BTC bars are columns iBTC0+1 ... iBTC0+nB
iMFMx = nSrc - 1;  iMFMu = nSrc;          % columns of the two MFM bars
% cases: {name, M token in key, Pe token in key, quadrant tile (1 = up-left ... 4 = down-right)}
klCases = {"XCT-loM-loPe", "P725", "Q1", 3; ...
           "XCT-loM-hiPe", "P725", "Q5", 1; ...
           "XCT-hiM-loPe", "P900", "Q1", 4; ...
           "XCT-hiM-hiPe", "P900", "Q5", 2};

if ~exist('uhsData','var'), uhsData = MFM_UHS_DataAll; end
if ~exist('uhsKey','var'),  uhsKey  = string(inputFileConfig.MFM_BTC_UHS_Key); end

for ds = dataSources
    nC = size(klCases,1);
    KL = nan(nC, nSrc);  dKL = nan(nC, nSrc);
    Mx = nan(nC,1);  Px = nan(nC,1);  Mu = nan(nC,1);  Pu = nan(nC,1);  uhsLbl = strings(nC,1);
    for c = 1:nC
        i = find(contains(expKeys, "_" + klCases{c,2} + "_") & contains(expKeys, "_" + klCases{c,3} + "_"), 1);
        if isempty(i), warning('8e: no experiment for %s', klCases{c,1}); continue, end
        if ~hasPost(i), warning('8e: %s has no postproc results', expKeys(i)); continue, end
        rs = expCTDataAll{i}.resultsAll.(ds);

        % XCT 1D profile (mid-profile)
        if isfield(rs, klMidVariant) && isfield(rs.(klMidVariant), 'KL_midProfile') && ...
                isfield(rs.(klMidVariant).KL_midProfile.methods, klMidMethod)
            r = rs.(klMidVariant).KL_midProfile.methods.(klMidMethod);
            if klMidStat == "mean"
                KL(c,1) = r.KL_cm2min_mean;  dKL(c,1) = r.KL_cm2min_std;
            else
                KL(c,1) = r.KL_cm2min_best;  dKL(c,1) = r.dKL_cm2min_best;
            end
        end
        % XCT 2D contours, same frames
        if hasCont
            if isfield(rs, klMidVariant) && isfield(rs.(klMidVariant), 'KL_midProfile') && ...
                    isfield(rs.(klMidVariant).KL_midProfile.methods, klMidContMethod)
                r = rs.(klMidVariant).KL_midProfile.methods.(klMidContMethod);
                if klMidContStat == "mean"
                    KL(c,iCont) = r.KL_cm2min_mean;  dKL(c,iCont) = r.KL_cm2min_std;
                else
                    KL(c,iCont) = r.KL_cm2min_best;  dKL(c,iCont) = r.dKL_cm2min_best;
                end
            else
                warning('8e: %s has no mid-profile method %s (re-run main_CTpostproc with the new KL_profileAt)', ...
                    expKeys(i), klMidContMethod);
            end
        end
        % XCT BTC at each zD level
        for b = 1:numel(klBTCtags)
            if isfield(rs, klBTCVariant) && isfield(rs.(klBTCVariant), 'KL_BTC_CT_byZD') && ...
                    isfield(rs.(klBTCVariant).KL_BTC_CT_byZD, klBTCtags(b))
                e = rs.(klBTCVariant).KL_BTC_CT_byZD.(klBTCtags(b));
                if isfield(e,'best') && isfield(e.best,'KL_cm2min')
                    KL(c,iBTC0+b) = e.best.KL_cm2min;
                    if isfield(e.best,'dKL_cm2min'), dKL(c,iBTC0+b) = e.best.dKL_cm2min; end
                end
            end
        end
        % XCT MFM and UHS MFM (best method of main_Processing, total uncertainty)
        mCT = MFM_CT_DataAll{i}.(ds);
        [KL(c,iMFMx), dKL(c,iMFMx), Mx(c), Px(c)] = mfmKL(mCT);
        mU = [];
        if ~isempty(uhsData{i}) && isfield(uhsData{i}, ds), mU = uhsData{i}.(ds); end
        [KL(c,iMFMu), dKL(c,iMFMu), Mu(c), Pu(c)] = mfmKL(mU);
        uhsLbl(c) = uhsKey(i);
    end
    dKL(~isfinite(dKL)) = 0;
    caseNames = string(klCases(:,1));
    srcTags = ["profile", repmat("contour",1,hasCont), "BTC_" + klBTCtags, "MFM_XCT", "MFM_UHS"];
    T8e = table(caseNames, 'VariableNames', {'case'});
    for s = 1:nSrc
        T8e.("KL_" + srcTags(s))  = KL(:,s);
        T8e.("dKL_" + srcTags(s)) = dKL(:,s);
    end
    T8e = [T8e, table(Mx, Px, uhsLbl, Mu, Pu, 'VariableNames', {'M_XCT','Pe_XCT','UHS_key','M_UHS','Pe_UHS'})];
    % trend of the BTC KL along the core: slope of KL vs zD (< 0: front sharpens towards the outlet)
    zDb = str2double(strrep(extractAfter(klBTCtags,"zD"), "p", "."));
    T8e.BTC_KL_slope_per_zD = nan(nC,1);
    for c = 1:nC
        y = KL(c, iBTC0 + (1:nB));  okb = isfinite(y);
        if nnz(okb) >= 2, pp = polyfit(zDb(okb), y(okb), 1);  T8e.BTC_KL_slope_per_zD(c) = pp(1); end
    end
    fprintf('\n8e) KL [cm2/min] by method (%s):\n', ds);  disp(T8e)
    writetable(T8e, fullfile(exportPath, "KL_byMethod_4cases_" + ds + ".xlsx"));
    yMax = 1.1*max(KL(:) + dKL(:), [], 'omitnan');  if ~(isfinite(yMax) && yMax > 0), yMax = 1; end

    % ---- Figure 1: grouped bars, one group per case
    fig = figure('Position',[80 80 1200 650], 'Name', "KL by method, four cases (" + ds + ")", 'NumberTitle','off');
    ax = axes(fig);  hold(ax,'on')
    klBars(ax, KL, dKL, klSrcCols, klSrcNames, caseNames, fsKL);
    ylim(ax, [0 yMax]);  ylabel(ax, 'K_L [cm^2/min]', 'FontSize',fsKL)
    legend(ax, 'Location','northwest', 'FontSize',fsKL)
    saveFigBoth(fig, exportPath, "KL_byMethod_4cases_" + ds, closeAfterSave)

    % ---- Figure 2: M-Pe quadrants
    fig = figure('Position',[60 60 1300 1000], 'Name', "KL by method in the M-Pe plane (" + ds + ")", 'NumberTitle','off');
    tl  = tiledlayout(fig, 2, 2, 'TileSpacing','compact', 'Padding','compact');
    for c = 1:nC
        ax = nexttile(tl, klCases{c,4});  hold(ax,'on')
        klBars(ax, KL(c,:), dKL(c,:), klSrcCols, klSrcNames, "", fsKL);
        set(ax, 'XTick', []);  ylim(ax, [0 yMax]);  ylabel(ax, 'K_L [cm^2/min]', 'FontSize',fsKL)
        title(ax, {caseNames(c), sprintf('XCT: M = %.2f, Pe = %.3g   UHS: M = %.2f, Pe = %.3g', ...
            Mx(c), Px(c), Mu(c), Pu(c))}, 'FontSize',fsKL-2, 'FontWeight','normal')
    end
    % one legend for all panels, below the grid, single row
    lgd = legend(ax, 'Orientation','horizontal', 'NumColumns',nSrc, 'FontSize',fsKL-2, 'Box','off');
    lgd.Layout.Tile = 'south';
    lgd.ItemTokenSize = [18 12];
    xlabel(tl, 'viscosity ratio M  \rightarrow  (left: low M, right: high M)', 'FontSize',fsKL)
    xlabel(tl, 'viscosity ratio M  \rightarrow  (left: low M, right: high M)', 'FontSize',fsKL)
    ylabel(tl, 'Pe  \rightarrow  (bottom: low Pe, top: high Pe)', 'FontSize',fsKL)
    saveFigBoth(fig, exportPath, "KL_byMethod_MPe_quadrants_" + ds, closeAfterSave)
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

%% 15) KL vs tD from the 40-60 width of every frame: averaged profile and 2D contours (x-trimmed)
% KL = W^2/(4 k^2 tau) for every frame (KL_allProfileWidths, same as main_CTpostproc),
% tau = t - t_arr (contour arrival of the mid-profile KL; fallback: line volume).
% Filled circles = averaged profile (zDWidthProf_40_60_xtrim), open squares = 2D contours
% (zDWidth_40_60_xtrim); error bars dKL (slice spacing + frame interval, see KL_allProfileWidths).
% Frames just after arrival (small tau) give very large, uncertain KL -> log y-axis by default.
 
klfPair  = [0.40 0.60];        % level pair of the width
klfVar   = "_xtrim";           % "_xtrim" or "" (full image)
klfXVar  = "tDtotal";          % "tDtotal" (t_D,total) or "tauD" (t_D since arrival)
klfLogY  = false;               % log K_L axis
klfYLim  = [];                 % [] = auto, e.g. [0.1 100]
klfErr   = true;               % error bars
fs15     = 16;  mk15 = 45;
tagW15   = sprintf('%02d_%02d', round(100*klfPair));
 
for ds = "conc"
    figName = sprintf('KL vs t_D from W%s per frame, profile and contours (%s%s)', tagW15, ds, klfVar);
    fig = figure('Position',[100 100 1100 700], 'Name',figName, 'NumberTitle','off');
    ax  = axes(fig);  hold(ax,'on');  h = gobjects(0);
    for i = 1:nExp
        Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, klfVar, klfPair);
        if isempty(Tk), continue, end
        x  = Tk.(klfXVar);
        yP = Tk.("KL_prof_" + tagW15 + "_cm2min");  dP = Tk.("dKL_prof_" + tagW15 + "_cm2min");
        yC = Tk.("KL_cont_" + tagW15 + "_cm2min");  dC = Tk.("dKL_cont_" + tagW15 + "_cm2min");
        okP = isfinite(x) & isfinite(yP) & yP > 0;
        okC = isfinite(x) & isfinite(yC) & yC > 0;
        cLt = 0.5*expCol(i,:) + 0.5;                        % lighter colour for the error bars
        % if klfErr
        %     errorbar(ax, x(okP), yP(okP), min(dP(okP), 0.99*yP(okP)), dP(okP), 'LineStyle','none', ...
        %         'Color',cLt, 'HandleVisibility','off')
        %     errorbar(ax, x(okC), yC(okC), min(dC(okC), 0.99*yC(okC)), dC(okC), 'LineStyle','none', ...
        %         'Color',cLt, 'HandleVisibility','off')
        % end
        if any(okP)
            h(end+1) = scatter(ax, x(okP), yP(okP), mk15, expCol(i,:), 'o', 'filled', ...
                'MarkerEdgeColor',0.6*expCol(i,:), 'DisplayName', expName(i)); %#ok<SAGROW>
        end
        % if any(okC)
        %     h(end+1) = scatter(ax, x(okC), yC(okC), mk15, expCol(i,:), 's', 'LineWidth',1.5, ...
        %         'DisplayName', expName(i) + ", contours"); %#ok<SAGROW>
        % end
    end
    if isempty(h), close(fig); continue, end
    set(ax, 'FontSize',fs15, 'LabelFontSizeMultiplier',1);  grid(ax,'on');  box(ax,'on')
    if klfLogY, set(ax, 'YScale','log'); end
    if ~isempty(klfYLim), ylim(ax, klfYLim); end
    if klfXVar == "tauD", xlabel(ax, 't_D - t_{D,arrival} [-]', 'FontSize',fs15)
    else,                 xlabel(ax, 't_D [-]', 'FontSize',fs15); end
    ylabel(ax, sprintf('K_L from W_{%d-%d} [cm^2/min]', round(100*klfPair)), 'FontSize',fs15)
    legend(ax, h, 'Location','northeast', 'FontSize',fs15-4, 'NumColumns',1, 'Interpreter','none')
    saveFigBoth(fig, exportPath, sprintf('KL_vs_%s_W%s_profile_contour_%s%s', klfXVar, tagW15, ds, klfVar), closeAfterSave)
end

%% 15b) KL vs tD from the 40-60 profile width of every frame, with the KL-by-method value (section 17 / 17c)
% Same as section 15 (averaged profile only), plus, per experiment, the bar value of the XCT
% 1D-profile KL of section 17 / 17c (one KL per experiment, rsStat of the frames at rotPos = rsRot
% +/- rsTol with the front centre at zD in rsZD) as a red open circle with its error bar, at the
% mean t_D of those frames. Legend: one entry per experiment + one red circle "theta = rsRot".
% Uses the settings of section 17 / 17c (rsRot, rsTol, rsZD, rsPair, rsVar, rsStat): run it first,
% or the defaults below are used.

if ~exist('rsRot','var'), rsRot = 226; rsTol = 1; rsZD = [0.2 0.8]; rsPair = [0.40 0.60]; rsVar = "_xtrim"; rsStat = "wmean"; end
klfPair  = rsPair;             % level pair of the width (same as the bar)
klfVar   = rsVar;              % "_xtrim" or "" (same as the bar)
klfXVar  = "tDtotal";          % "tDtotal" (t_D,total) or "tauD" (t_D since arrival)
klfLogY  = false;              % log K_L axis
klfYLim  = [];                 % [] = auto, e.g. [0 10]
klfErr   = false;              % error bars on the per-frame points
fs15     = 16;  mk15 = 45;
mkBar    = mk15;                % size of the red circle (bar value)
colBar   = [0.85 0 0];         % its colour
tagW15   = sprintf('%02d_%02d', round(100*klfPair));

for ds = "conc"
    figName = sprintf('KL vs t_D from W%s per frame, with the KL-by-method value at theta = %d deg (%s%s)', ...
        tagW15, rsRot, ds, klfVar);
    fig = figure('Position',[100 100 1100 700], 'Name',figName, 'NumberTitle','off');
    ax  = axes(fig);  hold(ax,'on');  h = gobjects(0);  hBar = gobjects(0);  rows15b = {};
    for i = 1:nExp
        Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, klfVar, klfPair);
        if isempty(Tk), continue, end
        x  = Tk.(klfXVar);
        yP = Tk.("KL_prof_" + tagW15 + "_cm2min");  dP = Tk.("dKL_prof_" + tagW15 + "_cm2min");
        okP = isfinite(x) & isfinite(yP) & yP > 0;
        cLt = 0.5*expCol(i,:) + 0.5;                        % lighter colour for the error bars
        if klfErr
            errorbar(ax, x(okP), yP(okP), min(dP(okP), 0.99*yP(okP)), dP(okP), 'LineStyle','none', ...
                'Color',cLt, 'HandleVisibility','off')
        end
        if any(okP)
            h(end+1) = scatter(ax, x(okP), yP(okP), mk15, expCol(i,:), 'o', 'filled', ...
                'MarkerEdgeColor',0.6*expCol(i,:), 'DisplayName', expName(i)); %#ok<SAGROW>
        end

        % frames of the KL-by-method bar and the bar value (same selection and statistic as 17 / 17c)
        sel = rotZDsel(Tk, rsRot, rsTol, rsZD) & okP;
        if ~any(sel), continue, end
        [KLb, dKLb] = aggKL(yP(sel), dP(sel), rsStat);
        xb = mean(x(sel));
        % errorbar(ax, xb, KLb, dKLb, 'LineStyle','none', 'Color',colBar, 'LineWidth',2, ...
        %     'CapSize',12, 'HandleVisibility','off')
        hb = scatter(ax, xb, KLb, mkBar, 'o', 'MarkerEdgeColor',colBar, 'MarkerFaceColor','none', ...
            'LineWidth',2.5, 'DisplayName', sprintf('\\theta = %d°', rsRot));
        if isempty(hBar), hBar = hb; else, hb.HandleVisibility = 'off'; end
        rows15b{end+1,1} = table(expName(i), nnz(sel), xb, min(x(sel)), max(x(sel)), KLb, dKLb, ...
            'VariableNames', {'experiment','nFrames', char(klfXVar + "_mean"), char(klfXVar + "_min"), ...
            char(klfXVar + "_max"), 'KL_bar_cm2min', 'dKL_bar_cm2min'}); %#ok<SAGROW>
    end
    if isempty(h), close(fig); continue, end
    set(ax, 'FontSize',fs15, 'LabelFontSizeMultiplier',1);  grid(ax,'on');  box(ax,'on')
    if klfLogY, set(ax, 'YScale','log'); end
    if ~isempty(klfYLim), ylim(ax, klfYLim); end
    if klfXVar == "tauD", xlabel(ax, 't_D - t_{D,arrival} [-]', 'FontSize',fs15)
    else,                 xlabel(ax, 't_D [-]', 'FontSize',fs15); end
    ylabel(ax, sprintf('K_L from W_{%d-%d} [cm^2/min]', round(100*klfPair)), 'FontSize',fs15)
    legend(ax, [h hBar], 'Location','northeast', 'FontSize',fs15-4, 'NumColumns',1, 'Interpreter','tex')
    if ~isempty(rows15b)
        fprintf('\n15b) KL-by-method value (profile, theta = %g deg, centre zD %.2f-%.2f, %s) per experiment:\n', ...
            rsRot, rsZD, rsStat);
        disp(vertcat(rows15b{:}))
    end
    saveFigBoth(fig, exportPath, sprintf('KL_vs_%s_W%s_profile_rot%d_bar_%s%s', klfXVar, tagW15, rsRot, ds, klfVar), closeAfterSave)
end

%% 15c) KL vs rotation position from the 40-60 profile width of every frame, with the KL-by-method value
% Same as section 15b, but x = rotation position theta [deg] instead of t_D: every frame's KL from
% the averaged-profile width (filled dots, one colour per experiment) and, per experiment, the bar
% value of the XCT 1D-profile KL of section 17 / 17c (rsStat of the frames at theta = rsRot +/- rsTol
% with the front centre at zD in rsZD) as a red open circle at theta = rsRot.
% Legend: one entry per experiment + one red circle "theta = rsRot".
% Uses the settings of section 17 / 17c (rsRot, rsTol, rsZD, rsPair, rsVar, rsStat): run it first,
% or the defaults below are used.

if ~exist('rsRot','var'), rsRot = 226; rsTol = 1; rsZD = [0.2 0.8]; rsPair = [0.40 0.60]; rsVar = "_xtrim"; rsStat = "wmean"; end
klfPair  = rsPair;             % level pair of the width (same as the bar)
klfVar   = rsVar;              % "_xtrim" or "" (same as the bar)
klfXVar  = "rotPos_deg";       % x-axis: rotation position [deg]
klfLogY  = false;              % log K_L axis
klfYLim  = [];                 % [] = auto, e.g. [0 10]
klfErr   = false;              % error bars on the per-frame points
fs15     = 16;  mk15 = 45;
mkBar    = mk15;                % size of the red circle (bar value)
colBar   = [0.85 0 0];         % its colour
tagW15   = sprintf('%02d_%02d', round(100*klfPair));

for ds = "conc"
    figName = sprintf('KL vs theta from W%s per frame, with the KL-by-method value at theta = %d deg (%s%s)', ...
        tagW15, rsRot, ds, klfVar);
    fig = figure('Position',[100 100 1100 700], 'Name',figName, 'NumberTitle','off');
    ax  = axes(fig);  hold(ax,'on');  h = gobjects(0);  hBar = gobjects(0);  rows15b = {};
    for i = 1:nExp
        Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, klfVar, klfPair);
        if isempty(Tk), continue, end
        x  = Tk.(klfXVar);
        yP = Tk.("KL_prof_" + tagW15 + "_cm2min");  dP = Tk.("dKL_prof_" + tagW15 + "_cm2min");
        okP = isfinite(x) & isfinite(yP) & yP > 0;
        cLt = 0.5*expCol(i,:) + 0.5;                        % lighter colour for the error bars
        if klfErr
            errorbar(ax, x(okP), yP(okP), min(dP(okP), 0.99*yP(okP)), dP(okP), 'LineStyle','none', ...
                'Color',cLt, 'HandleVisibility','off')
        end
        if any(okP)
            h(end+1) = scatter(ax, x(okP), yP(okP), mk15, expCol(i,:), 'o', 'filled', ...
                'MarkerEdgeColor',0.6*expCol(i,:), 'DisplayName', expName(i)); %#ok<SAGROW>
        end

        % frames of the KL-by-method bar and the bar value (same selection and statistic as 17 / 17c)
        sel = rotZDsel(Tk, rsRot, rsTol, rsZD) & okP;
        if ~any(sel), continue, end
        [KLb, dKLb] = aggKL(yP(sel), dP(sel), rsStat);
        xb = rsRot;                                          % bar value at its rotation position
        % errorbar(ax, xb, KLb, dKLb, 'LineStyle','none', 'Color',colBar, 'LineWidth',2, ...
        %     'CapSize',12, 'HandleVisibility','off')
        hb = scatter(ax, xb, KLb, mkBar, 'o', 'MarkerEdgeColor',colBar, 'MarkerFaceColor','none', ...
            'LineWidth',2.5, 'DisplayName', sprintf('\\theta = %d°', rsRot));
        if isempty(hBar), hBar = hb; else, hb.HandleVisibility = 'off'; end
        rows15b{end+1,1} = table(expName(i), nnz(sel), rsRot, mean(Tk.tDtotal(sel)), min(Tk.tDtotal(sel)), ...
            max(Tk.tDtotal(sel)), KLb, dKLb, 'VariableNames', {'experiment','nFrames','theta_deg', ...
            'tD_mean','tD_min','tD_max','KL_bar_cm2min','dKL_bar_cm2min'}); %#ok<SAGROW>
    end
    if isempty(h), close(fig); continue, end
    set(ax, 'FontSize',fs15, 'LabelFontSizeMultiplier',1);  grid(ax,'on');  box(ax,'on')
    if klfLogY, set(ax, 'YScale','log'); end
    if ~isempty(klfYLim), ylim(ax, klfYLim); end
    xlabel(ax, '\theta (rotation position) [°]', 'FontSize',fs15)
    xlim(ax, [0 360]);  xticks(ax, 0:45:360)
    ylabel(ax, sprintf('K_L from W_{%d-%d} [cm^2/min]', round(100*klfPair)), 'FontSize',fs15)
    legend(ax, [h hBar], 'Location','northeast', 'FontSize',fs15-4, 'NumColumns',1, 'Interpreter','tex')
    if ~isempty(rows15b)
        fprintf('\n15c) KL-by-method value (profile, theta = %g deg, centre zD %.2f-%.2f, %s) per experiment:\n', ...
            rsRot, rsZD, rsStat);
        disp(vertcat(rows15b{:}))
    end
    saveFigBoth(fig, exportPath, sprintf('KL_vs_%s_W%s_profile_rot%d_bar_%s%s', "theta", tagW15, rsRot, ds, klfVar), closeAfterSave)
end
 
%% 16) Mixing length vs square root of time (dimensional): averaged profile and 2D contours
% Mixing length = width W between the two levels of mlPair [cm], x = sqrt(t - t_arr) [min^0.5]
% (t_arr = contour arrival, as section 15). The ADE first term gives W = 2 k sqrt(KL tau): a
% straight line through the origin, slope a = 2 k sqrt(KL) -> KL = a^2/(4 k^2) (printed, and
% in the legend when mlFit = true). mlMode = "W2_vs_t" plots W^2 vs tau instead (slope 4 k^2 KL).
 
mlPair  = [0.40 0.60];         % level pair of the mixing length
mlVar   = "_xtrim";
mlMode  = "W_vs_sqrtt";        % "W_vs_sqrtt" | "W2_vs_t"
mlFit   = true;                % straight line through the origin per experiment and source
mlZDr   = [0.1 0.9];           % front-centre zD range of the frames used in the fit
fs16    = 16;  mk16 = 45;
tagW16  = sprintf('%02d_%02d', round(100*mlPair));
k16     = erfcinv(2*mlPair(1)) - erfcinv(2*mlPair(2));
 
for ds = dataSources
    figName = sprintf('Mixing length W%s vs time (%s, %s%s)', tagW16, mlMode, ds, mlVar);
    fig = figure('Position',[100 100 1100 700], 'Name',figName, 'NumberTitle','off');
    ax  = axes(fig);  hold(ax,'on');  h = gobjects(0);  rows16 = {};
    for i = 1:nExp
        Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, mlVar, mlPair);
        if isempty(Tk), continue, end
        tau = Tk.tau_min;
        src = {"profile", Tk.("W_prof_" + tagW16 + "_cm"), 'o', true; ...
               "contours", Tk.("W_cont_" + tagW16 + "_cm"), 's', false};
        for s = 1:size(src,1)
            W  = src{s,2};
            ok = isfinite(tau) & tau > 0 & isfinite(W) & W > 0;
            if ~any(ok), continue, end
            if mlMode == "W2_vs_t", x = tau;  y = W.^2;  else, x = sqrt(tau);  y = W; end
            if src{s,4}
                h(end+1) = scatter(ax, x(ok), y(ok), mk16, expCol(i,:), src{s,3}, 'filled', ...
                    'MarkerEdgeColor',0.6*expCol(i,:), 'DisplayName', expName(i) + ", " + src{s,1}); %#ok<SAGROW>
            else
                h(end+1) = scatter(ax, x(ok), y(ok), mk16, expCol(i,:), src{s,3}, 'LineWidth',1.5, ...
                    'DisplayName', expName(i) + ", " + src{s,1}); %#ok<SAGROW>
            end
            % straight line through the origin on the frames with the centre inside mlZDr
            okF = ok & Tk.zD_center_C50 >= mlZDr(1) & Tk.zD_center_C50 <= mlZDr(2);
            KLs = NaN;  a = NaN;
            if mlFit && nnz(okF) >= 2
                a = sum(x(okF).*y(okF))/sum(x(okF).^2);              % least squares, y = a x
                if mlMode == "W2_vs_t", KLs = a/(4*k16^2); else, KLs = a^2/(4*k16^2); end
                xf = [0 max(x(ok))];
                lsty = '-';  if ~src{s,4}, lsty = '--'; end
                h(end+1) = plot(ax, xf, a*xf, lsty, 'Color',0.6*expCol(i,:), 'LineWidth',2, ...
                    'DisplayName', sprintf('fit: K_L = %.3g cm^2/min', KLs)); %#ok<SAGROW>
            end
            rows16{end+1,1} = table(expName(i), string(src{s,1}), nnz(okF), a, KLs, ...
                'VariableNames', {'experiment','source','nFit','slope','KL_cm2min'}); %#ok<SAGROW>
        end
    end
    if isempty(h), close(fig); continue, end
    set(ax, 'FontSize',fs16, 'LabelFontSizeMultiplier',1);  grid(ax,'on');  box(ax,'on')
    if mlMode == "W2_vs_t"
        xlabel(ax, 't - t_{arrival} [min]', 'FontSize',fs16)
        ylabel(ax, sprintf('W_{%d-%d}^2 [cm^2]', round(100*mlPair)), 'FontSize',fs16)
    else
        xlabel(ax, '(t - t_{arrival})^{1/2} [min^{1/2}]', 'FontSize',fs16)
        ylabel(ax, sprintf('mixing length W_{%d-%d} [cm]', round(100*mlPair)), 'FontSize',fs16)
    end
    xlim(ax, [0 inf]);  ylim(ax, [0 inf])
    legend(ax, h, 'Location','northwest', 'FontSize',fs16-5, 'NumColumns',2, 'Interpreter','tex')
    T16 = vertcat(rows16{:});
    fprintf('\n16) Mixing length %s, %s%s: KL from the slope (centre zD in [%.1f %.1f]):\n', ...
        mlMode, ds, mlVar, mlZDr);
    disp(T16)
    saveFigBoth(fig, exportPath, sprintf('mixingLength_W%s_%s_%s%s', tagW16, mlMode, ds, mlVar), closeAfterSave)
end
 
%% 17) KL by method WITHOUT the XCT BTC: one XCT profile / contour KL per experiment at theta = 270 deg
% XCT 1D profile  : KL from the averaged-profile width W_40-60 (x-trimmed) of the frames at
%                   rotPos = rsRot (+/- rsTol) with the front centre (C = 0.5) at zD in rsZD,
%                   combined into ONE value per experiment (rsStat)
% XCT 2D contours : same frames, 2D-contour width W_40-60
% XCT MFM, UHS MFM: as section 8e
% Replaces the mid-profile KL of 8e. Figure 1: grouped bars per case; figure 2: M-Pe quadrants.
% The frames used are printed and saved (KL_byMethod_rot270_frames_<ds>.xlsx); section 18 plots
% their profiles. Needs 5b for the UHS run swap (otherwise the configured UHS key is used).
 
rsRot   = 226;                 % rotation position [deg]
rsTol   = 1;                   % tolerance [deg]
rsZD    = [0.2 0.8];           % front-centre zD range
rsPair  = [0.40 0.60];
rsVar   = "_xtrim";
rsStat  = "wmean";             % "wmean" (inverse-variance weighted mean +/- its error, not below
                               % the scatter) | "mean" (mean +/- std; one frame: its own dKL)
fs17    = 16;
tagW17  = sprintf('%02d_%02d', round(100*rsPair));
rsSrcNames = [sprintf("XCT 1D profile (\\theta = %d°)", rsRot), sprintf("XCT 2D contours (\\theta = %d°)", rsRot), ...
              "XCT MFM", "UHS MFM"];
rsSrcCols  = [0.85 0.33 0.10; 0.98 0.70 0.45; 0.35 0.35 0.35; 0.30 0.75 0.93];
% cases: {name, M token in key, Pe token in key, quadrant tile (1 = up-left ... 4 = down-right)}
rsCases = {"XCT-loM-loPe", "P725", "Q1", 3; ...
           "XCT-loM-hiPe", "P725", "Q5", 1; ...
           "XCT-hiM-loPe", "P900", "Q1", 4; ...
           "XCT-hiM-hiPe", "P900", "Q5", 2};
if ~exist('uhsData','var'), uhsData = MFM_UHS_DataAll; end
if ~exist('uhsKey','var'),  uhsKey  = string(inputFileConfig.MFM_BTC_UHS_Key); end
 
for ds = "conc"
    nC = size(rsCases,1);  nS = numel(rsSrcNames);
    KL = nan(nC,nS);  dKL = nan(nC,nS);  nFr = zeros(nC,1);  tDr = strings(nC,1);
    Mx = nan(nC,1);  Px = nan(nC,1);  Mu = nan(nC,1);  Pu = nan(nC,1);  frRows = {};
    for c = 1:nC
        i = find(contains(expKeys, "_" + rsCases{c,2} + "_") & contains(expKeys, "_" + rsCases{c,3} + "_"), 1);
        if isempty(i), warning('17: no experiment for %s', rsCases{c,1}); continue, end
        Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, rsVar, rsPair);
        if ~isempty(Tk)
            sel = rotZDsel(Tk, rsRot, rsTol, rsZD);
            Ts  = Tk(sel, :);
            nFr(c) = height(Ts);
            if nFr(c) == 0
                warning('17: %s (%s) has no frame at theta = %g +/- %g with the centre in zD [%.2f %.2f]', ...
                    expKeys(i), ds, rsRot, rsTol, rsZD);
            else
                tDr(c) = sprintf('%.2f-%.2f', min(Ts.tDtotal), max(Ts.tDtotal));
                [KL(c,1), dKL(c,1)] = aggKL(Ts.("KL_prof_" + tagW17 + "_cm2min"), Ts.("dKL_prof_" + tagW17 + "_cm2min"), rsStat);
                [KL(c,2), dKL(c,2)] = aggKL(Ts.("KL_cont_" + tagW17 + "_cm2min"), Ts.("dKL_cont_" + tagW17 + "_cm2min"), rsStat);
                Ts = addvars(Ts, repmat(rsCases{c,1}, height(Ts), 1), 'Before',1, 'NewVariableNames','case');
                frRows{end+1,1} = Ts; %#ok<SAGROW>
            end
        end
        [KL(c,3), dKL(c,3), Mx(c), Px(c)] = mfmKL(MFM_CT_DataAll{i}.(ds));
        mU = [];
        if ~isempty(uhsData{i}) && isfield(uhsData{i}, ds), mU = uhsData{i}.(ds); end
        [KL(c,4), dKL(c,4), Mu(c), Pu(c)] = mfmKL(mU);
    end
    dKL(~isfinite(dKL)) = 0;
    caseNames = string(rsCases(:,1));
    T17 = table(caseNames, nFr, tDr, KL(:,1), dKL(:,1), KL(:,2), dKL(:,2), KL(:,3), dKL(:,3), KL(:,4), dKL(:,4), ...
        Mx, Px, Mu, Pu, 'VariableNames', {'case','nFrames','tD_range', ...
        'KL_profile','dKL_profile','KL_contour','dKL_contour','KL_MFM_XCT','dKL_MFM_XCT', ...
        'KL_MFM_UHS','dKL_MFM_UHS','M_XCT','Pe_XCT','M_UHS','Pe_UHS'});
    fprintf('\n17) KL [cm2/min] by method, XCT at theta = %g deg, centre zD %.2f-%.2f, W%s%s (%s):\n', ...
        rsRot, rsZD, tagW17, rsVar, ds);
    disp(T17)
    writetable(T17, fullfile(exportPath, sprintf('KL_byMethod_rot%d_noBTC_%s.xlsx', rsRot, ds)));
    if ~isempty(frRows)
        Tfr = vertcat(frRows{:});
        fprintf('  frames used:\n');  disp(Tfr(:, {'case','frame','run','rotPos_deg','tDtotal','tauD','zD_center_C50', ...
            char("W_prof_" + tagW17 + "_cm"), char("KL_prof_" + tagW17 + "_cm2min"), char("dKL_prof_" + tagW17 + "_cm2min"), ...
            char("KL_cont_" + tagW17 + "_cm2min"), char("dKL_cont_" + tagW17 + "_cm2min")}))
        writetable(Tfr, fullfile(exportPath, sprintf('KL_byMethod_rot%d_frames_%s.xlsx', rsRot, ds)));
    end
    yMax = 1.1*max(KL(:) + dKL(:), [], 'omitnan');  if ~(isfinite(yMax) && yMax > 0), yMax = 1; end
 
    % ---- Figure 1: grouped bars, one group per case
    fig = figure('Position',[80 80 1200 650], 'NumberTitle','off', ...
        'Name', sprintf('KL by method, theta = %d deg, no BTC (%s)', rsRot, ds));
    ax = axes(fig);  hold(ax,'on')
    klBars(ax, KL, dKL, rsSrcCols, rsSrcNames, caseNames, fs17);
    ylim(ax, [0 yMax]);  ylabel(ax, 'K_L [cm^2/min]', 'FontSize',fs17)
    legend(ax, 'Location','northwest', 'FontSize',fs17, 'Interpreter','tex')
    saveFigBoth(fig, exportPath, sprintf('KL_byMethod_rot%d_noBTC_4cases_%s', rsRot, ds), closeAfterSave)
 
    % ---- Figure 2: M-Pe quadrants
    fig = figure('Position',[60 60 1300 1000], 'NumberTitle','off', ...
        'Name', sprintf('KL by method in the M-Pe plane, theta = %d deg, no BTC (%s)', rsRot, ds));
    tl  = tiledlayout(fig, 2, 2, 'TileSpacing','compact', 'Padding','compact');
    for c = 1:nC
        ax = nexttile(tl, rsCases{c,4});  hold(ax,'on')
        klBars(ax, KL(c,:), dKL(c,:), rsSrcCols, rsSrcNames, "", fs17);
        set(ax, 'XTick', []);  ylim(ax, [0 yMax]);  ylabel(ax, 'K_L [cm^2/min]', 'FontSize',fs17)
        title(ax, {caseNames(c), sprintf('XCT: M = %.2f, Pe = %.3g   UHS: M = %.2f, Pe = %.3g', ...
            Mx(c), Px(c), Mu(c), Pu(c))}, 'FontSize',fs17-2, 'FontWeight','normal')
    end
    lgd = legend(ax, 'Orientation','horizontal', 'NumColumns',nS, 'FontSize',fs17-2, 'Box','off', 'Interpreter','tex');
    lgd.Layout.Tile = 'south';  lgd.ItemTokenSize = [18 12];
    xlabel(tl, 'viscosity ratio M  \rightarrow  (left: low M, right: high M)', 'FontSize',fs17)
    ylabel(tl, 'Pe  \rightarrow  (bottom: low Pe, top: high Pe)', 'FontSize',fs17)
    saveFigBoth(fig, exportPath, sprintf('KL_byMethod_rot%d_noBTC_MPe_quadrants_%s', rsRot, ds), closeAfterSave)
end

%% 17b) Profiles of the section-17 frames (theta = rsRot, centre at zD in rsZD) with the C = 0.4 / 0.6 crossings
% Same plot as 1c, but for EVERY frame used for the XCT KL of section 17 (rotPos = rsRot +/- rsTol,
% front centre C = 0.5 at zD in rsZD). Horizontal lines at the two levels, dots where each profile
% crosses them (front-anchored, as profileWidth); the distance between the two dots of one curve
% is W_40-60. Several frames of one experiment: light (early) -> dark (late).
% Prints / saves per frame: run, theta, t_D, time elapsed, arrival, crossings, W and KL +/- dKL
% (profile and 2D contours, KL_allProfileWidths) -- the values averaged into the section-17 bars.
% Uses the settings of section 17 (rsRot, rsTol, rsZD, rsPair, rsVar): run 17 first, or set them here.

if ~exist('rsRot','var'), rsRot = 270; rsTol = 1; rsZD = [0.3 0.7]; rsPair = [0.40 0.60]; rsVar = "_xtrim"; end
ds17b   = "conc";              % data sources (as section 17), e.g. dataSources for both
trim17b = 0.02;                % fraction of the core ignored at each end (as profileWidth)
fs17b   = 16;
tagW17b = sprintf('%02d_%02d', round(100*rsPair));

for ds = ds17b
    fig = figure('Position',[100 100 950 650], 'NumberTitle','off', 'Name', ...
        sprintf('Profiles at theta = %d deg, centre zD %.1f-%.1f, with the C = %.1f / %.1f crossings (%s%s)', ...
        rsRot, rsZD, rsPair, ds, rsVar));
    ax = axes(fig);  hold(ax,'on')
    h = gobjects(0);  rows17b = {};  Ci = 0;  Cj = 1;
    for i = 1:nExp
        Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, rsVar, rsPair);
        if isempty(Tk), continue, end
        Ts = sortrows(Tk(rotZDsel(Tk, rsRot, rsTol, rsZD), :), 'tDtotal');
        if isempty(Ts), continue, end
        vars = expCTDataAll{i}.varsAll.(ds);
        fd   = filedataExpAll{i};
        Ci = fd.C1init/100;  Cj = fd.C1j/100;
        nF = height(Ts);
        for q = 1:nF
            l    = Ts.frame(q);
            prof = cellRow(vars.C1Profile, l);  if iscell(prof), prof = prof{1}; end
            zD = prof.zDimLess(:);  C = prof.("CVert" + rsVar)(:);
            Lcm = max(prof.zVertcm);

            cq = expCol(i,:);                                % one frame: experiment colour
            if nF > 1                                        % several: light (early) -> dark (late)
                f  = (q - 1)/(nF - 1);
                cq = (1 - f)*(0.3 + 0.7*expCol(i,:)) + f*(0.6*expCol(i,:));
            end
            h(end+1) = plot(ax, zD, C, '-', 'LineWidth',2.5, 'Color',cq, 'DisplayName', ...
                sprintf('%s, t_D = %.2f, \\theta = %.0f°', expName(i), Ts.tDtotal(q), Ts.rotPos_deg(q))); %#ok<SAGROW>

            zc = levelCrossings(zD, C, Ci, Cj, rsPair, trim17b);     % [z(lower) z(upper)] in zD
            Cl = Ci + (Cj - Ci)*rsPair;  ok = isfinite(zc);
            scatter(ax, zc(ok), Cl(ok), 90, cq, 'filled', 'MarkerEdgeColor','k', ...
                'LineWidth',0.8, 'HandleVisibility','off')

            % per-frame values (same frame and arrival as section 17)
            tEl  = vars.secondsElapsed(l);
            tArr = Ts.t_min(q) - Ts.tau_min(q);
            rows17b{end+1,1} = table(expName(i), l, Ts.run(q), Ts.rotPos_deg(q), Ts.tDtotal(q), tEl/60, ...
                string(sprintf('%02d:%02d:%02d', floor(tEl/3600), floor(mod(tEl,3600)/60), round(mod(tEl,60)))), ...
                tArr, Ts.tD_arrival(q), Ts.tauD(q), Ts.tau_min(q), Ts.zD_center_C50(q), ...
                zc(1), zc(2), zc(1) - zc(2), (zc(1) - zc(2))*Lcm, Ts.("W_prof_" + tagW17b + "_cm")(q), ...
                Ts.("KL_prof_" + tagW17b + "_cm2min")(q), Ts.("dKL_prof_" + tagW17b + "_cm2min")(q), ...
                Ts.("W_cont_" + tagW17b + "_cm")(q), ...
                Ts.("KL_cont_" + tagW17b + "_cm2min")(q), Ts.("dKL_cont_" + tagW17b + "_cm2min")(q), ...
                'VariableNames', ["experiment","frame","run","rotPos_deg","tD","t_elapsed_min","t_elapsed_hms", ...
                "t_arr_min","tD_arr","tD_core","t_core_min","zD_center", ...
                "zD_C" + round(100*rsPair(1)), "zD_C" + round(100*rsPair(2)), "W_zD","W_cm_plot","W_prof_cm", ...
                "KL_prof_cm2min","dKL_prof_cm2min","W_cont_cm","KL_cont_cm2min","dKL_cont_cm2min"]); %#ok<SAGROW>
        end
    end
    if isempty(h)
        close(fig);  warning('17b: no frame at theta = %g deg with the centre in zD [%.2f %.2f] (%s)', rsRot, rsZD, ds);
        continue
    end
    yline(ax, Ci + (Cj - Ci)*rsPair, '--k', 'LineWidth',1.2, 'HandleVisibility','off');
    xlabel(ax, 'z_D [-]', 'FontSize',fs17b);  ylabel(ax, 'C_1 [-]', 'FontSize',fs17b)
    xlim(ax, [0 1]);  ylim(ax, [0 1.02]);  set(ax, 'FontSize',fs17b);  grid(ax,'on');  box(ax,'on')
    legend(ax, h, 'Location','northeast', 'FontSize',fs17b-2, 'Interpreter','tex')

    T17b = vertcat(rows17b{:});
    fprintf(['\n17b) Profiles at theta = %g deg, centre zD %.2f-%.2f, %s%s: frame, time, C = %.1f / %.1f ' ...
             'crossings, W and KL (profile, contours):\n'], rsRot, rsZD, ds, rsVar, rsPair);
    disp(T17b)
    fn17b = sprintf('CT_profile_rot%d_zD%02d_%02d_W%s_%s%s', rsRot, round(100*rsZD), tagW17b, ds, rsVar);
    writetable(T17b, fullfile(exportPath, fn17b + ".xlsx"));
    saveFigBoth(fig, exportPath, fn17b, closeAfterSave)
end

%% 17c) KL by method WITHOUT the XCT BTC and WITHOUT the 2D contours: XCT profile, XCT MFM, UHS MFM
% Same as section 17, three bars per case:
% XCT 1D profile  : KL from the averaged-profile width W_40-60 (x-trimmed) of the frames at
%                   rotPos = rsRot (+/- rsTol) with the front centre (C = 0.5) at zD in rsZD,
%                   combined into ONE value per experiment (rsStat)
% XCT MFM, UHS MFM: as section 8e
% Figure 1: grouped bars per case; figure 2: M-Pe quadrants. Files ..._noBTC_noCont_...
% Needs 5b for the UHS run swap (otherwise the configured UHS key is used).
 
rsRot   = 226;                 % rotation position [deg]
rsTol   = 1;                   % tolerance [deg]
rsZD    = [0.2 0.8];           % front-centre zD range
rsPair  = [0.40 0.60];
rsVar   = "_xtrim";
rsStat  = "wmean";             % "wmean" (inverse-variance weighted mean +/- its error, not below
                               % the scatter) | "mean" (mean +/- std; one frame: its own dKL)
fs17    = 16;
tagW17  = sprintf('%02d_%02d', round(100*rsPair));
rsSrcNames = [sprintf("XCT 1D profile (\\theta = %d°)", rsRot), "XCT MFM", "UHS MFM"];
rsSrcCols  = [0.85 0.33 0.10; 0.35 0.35 0.35; 0.30 0.75 0.93];
% cases: {name, M token in key, Pe token in key, quadrant tile (1 = up-left ... 4 = down-right)}
rsCases = {"XCT-loM-loPe", "P725", "Q1", 3; ...
           "XCT-loM-hiPe", "P725", "Q5", 1; ...
           "XCT-hiM-loPe", "P900", "Q1", 4; ...
           "XCT-hiM-hiPe", "P900", "Q5", 2};
if ~exist('uhsData','var'), uhsData = MFM_UHS_DataAll; end
if ~exist('uhsKey','var'),  uhsKey  = string(inputFileConfig.MFM_BTC_UHS_Key); end
 
for ds = "conc"
    nC = size(rsCases,1);  nS = numel(rsSrcNames);
    KL = nan(nC,nS);  dKL = nan(nC,nS);  nFr = zeros(nC,1);  tDr = strings(nC,1);
    Mx = nan(nC,1);  Px = nan(nC,1);  Mu = nan(nC,1);  Pu = nan(nC,1);  frRows = {};
    for c = 1:nC
        i = find(contains(expKeys, "_" + rsCases{c,2} + "_") & contains(expKeys, "_" + rsCases{c,3} + "_"), 1);
        if isempty(i), warning('17: no experiment for %s', rsCases{c,1}); continue, end
        Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, rsVar, rsPair);
        if ~isempty(Tk)
            sel = rotZDsel(Tk, rsRot, rsTol, rsZD);
            Ts  = Tk(sel, :);
            nFr(c) = height(Ts);
            if nFr(c) == 0
                warning('17: %s (%s) has no frame at theta = %g +/- %g with the centre in zD [%.2f %.2f]', ...
                    expKeys(i), ds, rsRot, rsTol, rsZD);
            else
                tDr(c) = sprintf('%.2f-%.2f', min(Ts.tDtotal), max(Ts.tDtotal));
                [KL(c,1), dKL(c,1)] = aggKL(Ts.("KL_prof_" + tagW17 + "_cm2min"), Ts.("dKL_prof_" + tagW17 + "_cm2min"), rsStat);
                Ts = addvars(Ts, repmat(rsCases{c,1}, height(Ts), 1), 'Before',1, 'NewVariableNames','case');
                frRows{end+1,1} = Ts; %#ok<SAGROW>
            end
        end
        [KL(c,2), dKL(c,2), Mx(c), Px(c)] = mfmKL(MFM_CT_DataAll{i}.(ds));
        mU = [];
        if ~isempty(uhsData{i}) && isfield(uhsData{i}, ds), mU = uhsData{i}.(ds); end
        [KL(c,3), dKL(c,3), Mu(c), Pu(c)] = mfmKL(mU);
    end
    dKL(~isfinite(dKL)) = 0;
    caseNames = string(rsCases(:,1));
    T17 = table(caseNames, nFr, tDr, KL(:,1), dKL(:,1), KL(:,2), dKL(:,2), KL(:,3), dKL(:,3), ...
        Mx, Px, Mu, Pu, 'VariableNames', {'case','nFrames','tD_range', ...
        'KL_profile','dKL_profile','KL_MFM_XCT','dKL_MFM_XCT', ...
        'KL_MFM_UHS','dKL_MFM_UHS','M_XCT','Pe_XCT','M_UHS','Pe_UHS'});
    fprintf('\n17c) KL [cm2/min] by method (no contours), XCT at theta = %g deg, centre zD %.2f-%.2f, W%s%s (%s):\n', ...
        rsRot, rsZD, tagW17, rsVar, ds);
    disp(T17)
    writetable(T17, fullfile(exportPath, sprintf('KL_byMethod_rot%d_noBTC_noCont_%s.xlsx', rsRot, ds)));
    if ~isempty(frRows)
        Tfr = vertcat(frRows{:});
        fprintf('  frames used:\n');  disp(Tfr(:, {'case','frame','run','rotPos_deg','tDtotal','tauD', ...
            't_min','tau_min','zD_center_C50', ...
            char("W_prof_" + tagW17 + "_cm"), char("KL_prof_" + tagW17 + "_cm2min"), char("dKL_prof_" + tagW17 + "_cm2min")}))
        writetable(Tfr, fullfile(exportPath, sprintf('KL_byMethod_rot%d_noCont_frames_%s.xlsx', rsRot, ds)));
    end
    yMax = 1.1*max(KL(:) + dKL(:), [], 'omitnan');  if ~(isfinite(yMax) && yMax > 0), yMax = 1; end
 
    % ---- Figure 1: grouped bars, one group per case
    fig = figure('Position',[80 80 1200 650], 'NumberTitle','off', ...
        'Name', sprintf('KL by method, theta = %d deg, no BTC, no contours (%s)', rsRot, ds));
    ax = axes(fig);  hold(ax,'on')
    klBars(ax, KL, dKL, rsSrcCols, rsSrcNames, caseNames, fs17);
    ylim(ax, [0 yMax]);  ylabel(ax, 'K_L [cm^2/min]', 'FontSize',fs17)
    legend(ax, 'Location','northwest', 'FontSize',fs17, 'Interpreter','tex')
    saveFigBoth(fig, exportPath, sprintf('KL_byMethod_rot%d_noBTC_noCont_4cases_%s', rsRot, ds), closeAfterSave)
 
    % ---- Figure 2: M-Pe quadrants
    fig = figure('Position',[60 60 1300 1000], 'NumberTitle','off', ...
        'Name', sprintf('KL by method in the M-Pe plane, theta = %d deg, no BTC, no contours (%s)', rsRot, ds));
    tl  = tiledlayout(fig, 2, 2, 'TileSpacing','compact', 'Padding','compact');
    for c = 1:nC
        ax = nexttile(tl, rsCases{c,4});  hold(ax,'on')
        klBars(ax, KL(c,:), dKL(c,:), rsSrcCols, rsSrcNames, "", fs17);
        set(ax, 'XTick', []);  ylim(ax, [0 yMax]);  ylabel(ax, 'K_L [cm^2/min]', 'FontSize',fs17)
        title(ax, {caseNames(c), sprintf('XCT: M = %.2f, Pe = %.3g   UHS: M = %.2f, Pe = %.3g', ...
            Mx(c), Px(c), Mu(c), Pu(c))}, 'FontSize',fs17-2, 'FontWeight','normal')
    end
    lgd = legend(ax, 'Orientation','horizontal', 'NumColumns',nS, 'FontSize',fs17-2, 'Box','off', 'Interpreter','tex');
    lgd.Layout.Tile = 'south';  lgd.ItemTokenSize = [18 12];
    xlabel(tl, 'viscosity ratio M  \rightarrow  (left: low M, right: high M)', 'FontSize',fs17)
    ylabel(tl, 'Pe  \rightarrow  (bottom: low Pe, top: high Pe)', 'FontSize',fs17)
    saveFigBoth(fig, exportPath, sprintf('KL_byMethod_rot%d_noBTC_noCont_MPe_quadrants_%s', rsRot, ds), closeAfterSave)
end
 
%% 18) Profiles used for the theta = 270 deg KL (section 17), as section 1
% Every frame of section 17 (rotPos = rsRot +/- rsTol, front centre at zD in rsZD), averaged
% x-trimmed profile vs zD, with the two levels of rsPair (dashed) and the crossings (dots) whose
% distance is the width W used for KL. Several frames of one experiment: light -> dark with t_D.
% Uses the settings of section 17 (rsRot, rsTol, rsZD, rsPair, rsVar): run 17 first, or set them here.
 
if ~exist('rsRot','var'), rsRot = 270; rsTol = 5; rsZD = [0.4 0.6]; rsPair = [0.40 0.60]; rsVar = "_xtrim"; end
trim18 = 0.02;                 % fraction of the core ignored at each end (as profileWidth)
fs18   = 16;
 
for ds = dataSources
    fig = figure('Position',[100 100 1000 650], 'NumberTitle','off', 'Name', ...
        sprintf('Profiles at theta = %d deg with the centre at zD %.1f-%.1f (%s%s)', rsRot, rsZD, ds, rsVar));
    ax = axes(fig);  hold(ax,'on');  h = gobjects(0);
    for i = 1:nExp
        Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, rsVar, rsPair);
        if isempty(Tk), continue, end
        Ts = sortrows(Tk(rotZDsel(Tk, rsRot, rsTol, rsZD), :), 'tDtotal');
        if isempty(Ts), continue, end
        vars = expCTDataAll{i}.varsAll.(ds);
        Ci = filedataExpAll{i}.C1init/100;  Cj = filedataExpAll{i}.C1j/100;
        nF = height(Ts);
        for q = 1:nF
            prof = cellRow(vars.C1Profile, Ts.frame(q));  if iscell(prof), prof = prof{1}; end
            zD = prof.zDimLess(:);  C = prof.("CVert" + rsVar)(:);
            cq = expCol(i,:);                                % one frame: experiment colour
            if nF > 1                                        % several: light (early) -> dark (late)
                f  = (q - 1)/(nF - 1);
                cq = (1 - f)*(0.3 + 0.7*expCol(i,:)) + f*(0.6*expCol(i,:));
            end
            h(end+1) = plot(ax, zD, C, '-', 'LineWidth',2.5, 'Color',cq, 'DisplayName', ...
                sprintf('%s, t_D = %.2f, \\theta = %.0f°', expName(i), Ts.tDtotal(q), Ts.rotPos_deg(q))); %#ok<SAGROW>
            zc = levelCrossings(zD, C, Ci, Cj, rsPair, trim18);
            Cl = Ci + (Cj - Ci)*rsPair;  ok = isfinite(zc);
            scatter(ax, zc(ok), Cl(ok), 90, cq, 'filled', 'MarkerEdgeColor','k', 'LineWidth',0.8, ...
                'HandleVisibility','off')
        end
    end
    if isempty(h)
        close(fig);  warning('18: no frame at theta = %g deg with the centre in zD [%.2f %.2f] (%s)', rsRot, rsZD, ds);
        continue
    end
    yline(ax, rsPair, '--k', 'LineWidth',1.2, 'HandleVisibility','off');
    xline(ax, rsZD, ':k', 'LineWidth',1, 'HandleVisibility','off');
    set(ax, 'FontSize',fs18, 'LabelFontSizeMultiplier',1);  grid(ax,'on');  box(ax,'on')
    xlabel(ax, 'z_D [-]', 'FontSize',fs18);  ylabel(ax, 'C_1 [-]', 'FontSize',fs18)
    xlim(ax, [0 1]);  ylim(ax, [0 1.02])
    legend(ax, h, 'Location','northeast', 'FontSize',fs18-4, 'Interpreter','tex')
    saveFigBoth(fig, exportPath, sprintf('CT_profiles_rot%d_zD%02d_%02d_%s%s', rsRot, round(100*rsZD), ds, rsVar), closeAfterSave)
end
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

function envSegments(ax, tD, zc, half, col, lw, alpha, name)
% one vertical segment per scan: centre +/- half width
ok = isfinite(tD) & isfinite(zc) & isfinite(half);
if ~any(ok), return, end
t = tD(ok)';  c = zc(ok)';  h = half(ok)';
xs = [t; t; nan(1,numel(t))];
ys = [c - h; c + h; nan(1,numel(t))];
plot(ax, xs(:), ys(:), '-', 'Color',[col alpha], 'LineWidth',lw, 'DisplayName',name)
end

function [col, name] = expStyle(key, colRules, nameRules, peRules, colDefault)
% colour (light for Q1, dark otherwise) and short name from tokens in the experiment key
col = colDefault;  name = string(key);  nm = "";
isQ1 = contains(key, "_Q1_");
for r = 1:size(colRules,1)
    if contains(key, "_" + colRules{r,1} + "_")
        if isQ1, col = colRules{r,2}; else, col = colRules{r,3}; end
    end
end
for r = 1:size(nameRules,1)
    if contains(key, "_" + nameRules{r,1} + "_"), nm = nameRules{r,2}; end
end
for r = 1:size(peRules,1)
    if contains(key, "_" + peRules{r,1} + "_"), nm = nm + peRules{r,2}; end
end
if nm ~= "", name = nm; end
end

function n = fieldOrVarNames(x)
% field names of a struct or variable names of a table
    if istable(x), n = x.Properties.VariableNames; elseif isstruct(x), n = fieldnames(x); else, n = {}; end
end

function ok = parityPanel(ax, expCTDataAll, ds, idx, pair, variant, qmk, expKeys, expCol, expName, lim, fs, mkSz)
% Contour width (x) vs averaged-profile width (y), same scan, for the experiments idx,
% 1:1 line drawn first (under the dots). lim = axis limits ([] = from these data),
% fs = font size, mkSz = marker size. ok = false if there is nothing to plot.
if nargin < 11, lim = [];  end
if nargin < 12 || isempty(fs),   fs = 12;   end
if nargin < 13 || isempty(mkSz), mkSz = 26; end
hold(ax,'on');  allW = [];
cCol = "zDWidth_"     + pair + variant;
pCol = "zDWidthProf_" + pair + variant;
h11 = plot(ax, [0 1], [0 1], 'k', 'LineStyle','--', 'LineWidth',1.2, ...
    'DisplayName','1:1');               % end points set below
for i = idx
    vars   = expCTDataAll{i}.varsAll.(ds);
    cols_i = string(vars.Properties.VariableNames);
    if ~all(ismember([cCol pCol], cols_i)), continue, end
    wC = abs(vars.(cCol));  wP = abs(vars.(pCol));
    sel = isfinite(wC) & isfinite(wP) & wC > 0 & wP > 0;
    if ~any(sel), continue, end
    mk = 'o';
    for q = 1:size(qmk,1)
        if contains(expKeys(i), "_" + qmk{q,1} + "_"), mk = qmk{q,2}; end
    end
    scatter(ax, wC(sel), wP(sel), mkSz, expCol(i,:), mk, 'filled', 'MarkerEdgeColor',expCol(i,:), ...
        'LineWidth',0.3, 'MarkerFaceAlpha',0.8, 'DisplayName', expName(i))
    allW = [allW; wC(sel); wP(sel)]; %#ok<AGROW>
end
ok = ~isempty(allW);
if ~ok
    delete(h11)
    text(ax, 0.5, 0.5, "no contour / profile widths for " + strrep(pair,'_','-'), ...
        'Units','normalized', 'HorizontalAlignment','center', 'FontSize',fs);
    return
end
if isempty(lim), lim = [0, 1.05*max(allW)]; end
set(h11, 'XData', lim, 'YData', lim)
xlim(ax, lim);  ylim(ax, lim);  axis(ax, 'square')
xlabel(ax, '\Deltaz_D, 2D contours [-]', 'FontSize',fs)
ylabel(ax, '\Deltaz_D, averaged profile [-]', 'FontSize',fs)
set(ax, 'FontSize',fs);  grid(ax,'on')
legend(ax, 'Location','northwest', 'FontSize',fs, 'Interpreter','none')
end

function lim = parityLim(expCTDataAll, ds, idx, pair, variant)
% common axis limits [0, 1.05*max width] of one level pair over the experiments idx
cCol = "zDWidth_"     + pair + variant;
pCol = "zDWidthProf_" + pair + variant;
mx = 0;
for i = idx
    vars   = expCTDataAll{i}.varsAll.(ds);
    cols_i = string(vars.Properties.VariableNames);
    if ~all(ismember([cCol pCol], cols_i)), continue, end
    wC = abs(vars.(cCol));  wP = abs(vars.(pCol));
    sel = isfinite(wC) & isfinite(wP) & wC > 0 & wP > 0;
    if any(sel), mx = max([mx; wC(sel); wP(sel)]); end
end
if mx > 0, lim = [0, 1.05*mx]; else, lim = []; end
end

function [zD50, wD, Cfit] = fitErfcProfile(zD, C, Ci, Cj, trimFrac)
% free erfc fit C = Ci + (Cj - Ci) 0.5 erfc((zD - zD50)/wD) of one profile (injection end at
% zD = 0, as the CT profiles); end slices left out of the fit, curve returned on all zD
zD50 = NaN;  wD = NaN;  Cfit = nan(size(zD));
ok = isfinite(zD) & isfinite(C) & zD >= trimFrac & zD <= 1 - trimFrac;
if nnz(ok) < 10, return, end
f = @(b, x) Ci + (Cj - Ci)*0.5*erfc((x - b(1))/b(2));
Cn = (C(ok) - Ci)/(Cj - Ci);
[~, k] = min(abs(Cn - 0.5));  z0 = zD(ok);  z0 = z0(k);           % start: C = 0.5 position
try
    b = nlinfit(zD(ok), C(ok), f, [z0, 0.1]);
catch
    b = fminsearch(@(b) sum((f(b, zD(ok)) - C(ok)).^2), [z0, 0.1], optimset('Display','off'));
end
if b(2) > 0
    zD50 = b(1);  wD = b(2);  Cfit = f(b, zD);
end
end

function [KL, dKL, M, Pe] = mfmKL(m)
% KL +/- total uncertainty (best method of main_Processing), M = mu2/mu1 and Pe = u L / D0
% of one MFM experiment (struct with .results and .exp_params); NaN where missing
KL = NaN;  dKL = NaN;  M = NaN;  Pe = NaN;
if isempty(m), return, end
pick = @(s, names) firstNum(s, names);
if isfield(m, 'results')
    KL  = pick(m.results, {'KL_cm2min'});
    dKL = pick(m.results, {'totUncertKL_cm2min','dKL_cm2min'});
end
if isfield(m, 'exp_params')
    ep = m.exp_params;
    M  = pick(ep, {'mu2'}) / pick(ep, {'mu1'});
    Pe = pick(ep, {'Pe_upump_L_D0'});
end
end

function v = firstNum(s, names)
% first finite numeric value among the given fields / table columns
v = NaN;
if istable(s), n = s.Properties.VariableNames; elseif isstruct(s), n = fieldnames(s); else, return, end
for k = 1:numel(names)
    if ismember(names{k}, n)
        x = s.(names{k});  if iscell(x), x = x{1}; end
        if isnumeric(x) && ~isempty(x) && isfinite(x(1)), v = double(x(1)); return, end
    end
end
end

function klBars(ax, KL, dKL, cols, srcNames, groupNames, fs)
% grouped bars (rows = groups, columns = sources) with error bars
nG = size(KL,1);  nS = size(KL,2);
if nG == 1, b = bar(ax, [KL; nan(1,nS)], 'grouped');  else, b = bar(ax, KL, 'grouped'); end
for s = 1:nS
    b(s).FaceColor = cols(s,:);  b(s).EdgeColor = 'none';  b(s).DisplayName = srcNames(s);
    xe = b(s).XEndPoints(1:nG);
    errorbar(ax, xe, KL(:,s)', dKL(:,s)', 'k', 'LineStyle','none', 'LineWidth',1.2, ...
        'CapSize',8, 'HandleVisibility','off')
end
if nG == 1, xlim(ax, [0.5 1.5]); end
if ~isempty(groupNames) && all(groupNames ~= "")
    set(ax, 'XTick', 1:nG, 'XTickLabel', groupNames, 'TickLabelInterpreter','none')
end
set(ax, 'FontSize',fs);  grid(ax,'on');  box(ax,'on')
end

function zc = levelCrossings(zD, C, Ci, Cj, lv, trimFrac)
% zD where the profile crosses the normalized levels lv = [lower upper], searched outward
% from the front centre (steepest Cn = 0.5 crossing), end slices left out (as profileWidth);
% returns [z(lower) z(upper)] in zD from the injection end (NaN if not crossed)
zc = [NaN NaN];
ok = isfinite(zD) & isfinite(C) & zD >= trimFrac & zD <= 1 - trimFrac;
z = zD(ok);  Cn = movmedian((C(ok) - Ci)/(Cj - Ci), 5);
[z, o] = sort(z);  Cn = Cn(o);
if numel(z) < 10, return, end
k50 = find(Cn(1:end-1) >= 0.5 & Cn(2:end) < 0.5);
if isempty(k50), return, end
g = -gradient(Cn, z);  [~, b] = max(g(k50));  k0 = k50(b);
j = find(Cn(k0+1:end) < lv(1), 1);                       % lower level: downstream
if ~isempty(j), j = k0 + j;  zc(1) = z(j-1) + (Cn(j-1) - lv(1))*(z(j) - z(j-1))/(Cn(j-1) - Cn(j)); end
j = find(Cn(1:k0) > lv(2), 1, 'last');                   % upper level: upstream
if ~isempty(j) && j < numel(Cn), zc(2) = z(j) + (Cn(j) - lv(2))*(z(j+1) - z(j))/(Cn(j) - Cn(j+1)); end
end

function Tk = klAllFrames(ctData, fd, hasPostI, ds, variant, pair)
% KL per frame from the width of the level pair (KL_allProfileWidths) for one experiment.
% Arrival: contour arrival stored with the mid-profile KL (main_CTpostproc), else line volume.
Tk = table();
vars = ctData.varsAll.(ds);
tag  = sprintf('%02d_%02d', round(100*pair));
if ~ismember("zDWidthProf_" + tag + variant + "_cm", string(vars.Properties.VariableNames))
    warning('klAllFrames: zDWidthProf_%s%s_cm missing for %s -- run main_CTpostproc first', tag, variant, fd.Key);
    return
end
tArr  = fd.Vlinesbefore/fd.Q;                         % fallback: line volume before the core [min]
vName = "full";  if variant == "_xtrim", vName = "xtrim"; end
if hasPostI && isfield(ctData, 'resultsAll') && isfield(ctData.resultsAll, ds)
    rs = ctData.resultsAll.(ds);
    if isfield(rs, vName) && isfield(rs.(vName), 'KL_midProfile') && ...
            isfield(rs.(vName).KL_midProfile.methods, 'erfc_contour')
        tc = rs.(vName).KL_midProfile.methods.erfc_contour.tArr_min;
        if isfinite(tc), tArr = tc; end
    end
end
Tk = KL_allProfileWidths(vars, variant, pair, tArr, tArr*fd.Q/fd.Vtotal);
end
 
function sel = rotZDsel(Tk, rot, tol, zDr, z0)
% frames at rotation rot +/- tol [deg] (wrapped) with the front centre (C = 0.5) inside zDr;
% of those, ONLY the one frame whose centre is closest to z0 (default: middle of zDr, i.e. 0.5
% for zDr = [0.2 0.8]) is kept -> one frame per experiment, no averaging.
% z0 = NaN keeps all frames in the window (previous behaviour, averaged by aggKL).
if nargin < 5 || isempty(z0), z0 = mean(zDr); end
dRot = mod(Tk.rotPos_deg - rot + 180, 360) - 180;
sel  = abs(dRot) <= tol & Tk.zD_center_C50 >= zDr(1) & Tk.zD_center_C50 <= zDr(2);
if isfinite(z0) && nnz(sel) > 1
    idx = find(sel);
    [~, b] = min(abs(Tk.zD_center_C50(idx) - z0));
    sel = false(size(sel));  sel(idx(b)) = true;
end
end

function [v, dv] = aggKL(x, dx, stat)
% one KL from several frames: "wmean" inverse-variance weighted mean +/- max(its error, std/sqrt(n));
% "mean" mean +/- std. A single frame keeps its own dKL.
v = NaN;  dv = NaN;
ok = isfinite(x) & x > 0;  x = x(ok);  dx = dx(ok);
if isempty(x), return, end
if numel(x) == 1, v = x;  dv = dx;  return, end
if stat == "wmean" && all(isfinite(dx) & dx > 0)
    w  = 1./dx.^2;
    v  = sum(w.*x)/sum(w);
    dv = max(1/sqrt(sum(w)), std(x)/sqrt(numel(x)));
else
    v = mean(x);  dv = std(x);
end
end