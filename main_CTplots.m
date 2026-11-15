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
% Blocks (similar plots grouped; run the Load data block first)
%  Profiles
%   1   Z profile closest to (zD, CD) target
%   1b  same, with the erfc fit of each curve
%   1c  mid-core profile with the C = 0.4 / 0.6 crossings (width of the mid-profile KL)
%   1d  profiles of the 8f frames (theta = rsRot, centre in rsZD) with the C = 0.4 / 0.6 crossings
%   2   Z profiles at a range of t_D,total targets (all experiments, one figure per t_D)
%   2a  same at a range of t_D,res targets
%   2b  profile evolution with t_D,total, one figure per experiment
%   2ba profile evolution with t_D,res, one figure per experiment
%  CT breakthrough curves and front positions
%   3   CT outlet BTC vs time, t_D (tAxis) and front-velocity-scaled t_D,core
%   3b  CT BTCs at every zD level (one figure per experiment)
%   3c  front position of every C level, contours and profile, each vs its own t_D,res and scaled time
%   3d  same four panels for one C level, all experiments together (one figure per level)
%  MFM breakthrough curves
%   4   MFM analog BTC;  4b with the fitted curve (16-84 %)
%   5   MFM UHS BTC;     5b with the fitted curve (16-84 %)
%   6   MFM analog + UHS BTC together
%  Front width
%   7   measured (2D-contour) front width vs t_D
%   7b  2D contours (circles) + averaged profile (squares)
%   7c  averaged-profile width only (one figure per level pair)
%   7d  averaged-profile width with the frame of the KL-by-method value (red circle)
%  Front envelope and KL by method
%   8   front envelope (2D contours), all experiments
%   8a  front envelope from the averaged profile;  8a2 front centre with the front-velocity line
%   8b  envelope per experiment: 2D-contour vs averaged-profile width
%   8c  contour width vs averaged-profile width (same scan), 1:1 line;  8d split by M
%   8e  KL by method (mid-profile, contours, XCT BTC, MFM): bars and M-Pe quadrants
%   8f  KL by method without the XCT BTC: profile / contour KL at theta = rsRot (sets rs* settings)
%   8g  as 8f without the 2D contours: XCT profile, XCT MFM, UHS MFM
%   8h  XCT only (profile at theta = rsRot and XCT MFM), one figure per case (2 x 2 grid)
%  Front shape
%   9   front tilt / non-planarity vs t_D
%   10  front tilt vs rotation position, coloured by t_D
%  KL, BTC width and efficiencies
%   11  pointwise front KL vs t_D + BTC-CT and MFM reference KL
%   12  outlet BTC width (t_D,total 16-84 %) per experiment;  12a same in t_D,res
%   13  sweep, displacement and recovery efficiencies vs t_D
%   14  rhoNorm vs conc BTC at each zD
%   14a flow vs storage capacity (F-Phi) and predicted sweep vs measured
%   15  KL vs t_D from the 40-60 width of every frame (profile and 2D contours)
%   15b same, profile only, with the KL-by-method value of 8f (red circle)
%   15c same vs rotation position
%   16  mixing length vs sqrt(t - t_arr)
%   17  similarity plot C vs (z_D - t_D,res)/sqrt(t_D,res) at theta = 226 deg, with the ADE solution
%
% Sections 1d, 7d, 8f, 8g, 8h, 15b, 15c and 17 use the rs* frame settings of SETTINGS.

%% SETTINGS

Root = CT_setupPaths;

% frame of the KL-by-method value: theta = rsRot +/- rsTol, front centre closest to zD = 0.5
% within rsZD, width rsPair (rsVar) -- shared by 1d, 7d, 8f, 8g, 8h, 15b, 15c and 17
rsRot  = 226;            % rotation position [deg]
rsTol  = 1;              % tolerance [deg]
rsZD   = [0.2 0.8];      % front-centre zD window
rsPair = [0.40 0.60];    % level pair of the width
rsVar  = "_xtrim";       % "" = full image | "_xtrim"
rsStat = "wmean";        % "wmean" (inverse-variance weighted mean +/- its error) | "mean" (mean +/- std);
                         % only used if several frames are kept (rotZDsel keeps one)

inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

exportPath = 'results/';
if ~isfolder(exportPath), mkdir(exportPath); end

dataSources = ["rhoNorm","conc"];
fitDataOf   = struct('rhoNorm',"woEOS",    'conc',"wEOS");   % CT source -> MFM variant
mfmCol      = struct('rhoNorm','rho_norm', 'conc','CDi');    % MFM BT column per source
mfmTimeVar  = 'tD';           % MFM BT time axis ('tD' core-based, or 'tDtotal')

closeAfterSave = false;       % true: close each figure once saved

% time axis of every plot vs time (and colour scale by time):
%   "tDres" = t_D,res = t_D - t_D,arr = (t - t_arr) Q / V_total
%   "tD"    = t_D,total = Q t / V_total
% PROFILE and CONTOUR quantities are kept apart: each uses its own arrival, velocity and KL
%   profile  (averaged-profile widths / centre / BTCs, profile KL): column tD_res_prof, tauD (klAllFrames),
%            arrival of the averaged-profile levels, centre line of the profile C = 0.5 crossing
%   contours (2D-contour widths / centre / tilt / efficiencies, contour KL): column tD_res_cont,
%            tauD_cont, arrival of the contour levels, centre line of the C = 0.5 contour
%   (tD_res = tD_res_prof is kept as an alias)
% t_arr (tResRef), per source:
%   "levels"  t0 of level tResLevel (fit tResFit) of that source's level trajectories
%             (resultsAll.(ds).arrLevels of main_CTpostproc; default C = 0.01, curved ADE fit = the time
%             the front, C > 0, enters the rock)   [default]
%   "C50"     t0 = -b/v of that source's C = 0.5 centre line (contour: frontVel of main_CTpreproc;
%             profile: vFrontProf of main_CTpostproc)
%   "contour" first frame with a C = 0.01 contour (leading edge), both sources
%   "lines"   line volume before the core / Q, both sources
% The tag (tD / tDres_<tResRef>) is added to the file name of every figure that uses it.
tAxis     = "tDres";
tResRef   = "levels";         % "levels" | "C50" | "contour" | "lines"
tResLevel = 0.01;             % level of the "levels" arrival (as arrOpt.refLevel of main_CTpostproc)
tResFit   = "curve";          % "curve" (per-level ADE form) | "line" | "t0s" (joint two-origin fit)
if tAxis == "tDres"
    tXcolP = "tD_res_prof";  tXcolC = "tD_res_cont";  tXklP = "tauD";     tXklC = "tauD_cont";
    tXlbl  = 't_{D,res} [-]';  tXtag = "tDres";  tXlim = [0 1];
    if tResRef ~= "C50", tXtag = "tDres_" + tResRef; end
else
    tXcolP = "tDtotal";      tXcolC = "tDtotal";      tXklP = "tDtotal";  tXklC = "tDtotal";
    tXlbl  = 't_D [-]';        tXtag = "tD";     tXlim = [0 1.2];
end
tXcol = tXcolP;  tXkl = tXklP;    % default axis = profile (profiles, BTCs, profile KL)

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

% arrival time t_arr (tResRef) and centre line (velocity) per experiment, data source and SOURCE
% (profile / contours), never mixed:
%   varsAll.(ds).tD_res_prof / tD_res_cont = tD_total - t_arr Q/V_total   (tD_res = tD_res_prof)
%   resultsAll.(ds).tArr_plot_prof_min / _cont_min, tD_arr_plot_prof / _cont, tArr_plot_prof_ref / _cont_ref
%   resultsAll.(ds).cLine_prof / cLine_cont = struct(v [cm/min], t0 [min], src) of the C = 0.5 centre line
%   (tArr_plot_min / tD_arr_plot / tArr_plot_ref = profile values, kept for the older sections)
% klAllFrames uses the profile arrival for the profile KL and the contour arrival for the contour KL.
arrRows = {};
for i = 1:nExp
    fd = filedataExpAll{i};
    for ds = dataSources
        if ~isfield(expCTDataAll{i}.varsAll, ds), continue, end
        [tP_, sP_] = arrivalTime(expCTDataAll{i}, fd, ds, tResRef, "profile", tResLevel, tResFit);
        [tC_, sC_] = arrivalTime(expCTDataAll{i}, fd, ds, tResRef, "contour", tResLevel, tResFit);
        tDP_ = tP_*fd.Q/fd.Vtotal;  tDC_ = tC_*fd.Q/fd.Vtotal;
        expCTDataAll{i}.varsAll.(ds).tD_res_prof = expCTDataAll{i}.varsAll.(ds).tDtotal - tDP_;
        expCTDataAll{i}.varsAll.(ds).tD_res_cont = expCTDataAll{i}.varsAll.(ds).tDtotal - tDC_;
        expCTDataAll{i}.varsAll.(ds).tD_res      = expCTDataAll{i}.varsAll.(ds).tD_res_prof;
        rq = struct();  if isfield(expCTDataAll{i}, 'resultsAll') && isfield(expCTDataAll{i}.resultsAll, ds), rq = expCTDataAll{i}.resultsAll.(ds); end
        rq.tArr_plot_prof_min = tP_;  rq.tD_arr_plot_prof = tDP_;  rq.tArr_plot_prof_ref = sP_;
        rq.tArr_plot_cont_min = tC_;  rq.tD_arr_plot_cont = tDC_;  rq.tArr_plot_cont_ref = sC_;
        rq.tArr_plot_min      = tP_;  rq.tD_arr_plot      = tDP_;  rq.tArr_plot_ref      = sP_;
        rq.cLine_prof = centreLine(rq, "profile");
        rq.cLine_cont = centreLine(rq, "contour");
        expCTDataAll{i}.resultsAll.(ds) = rq;
        arrRows{end+1,1} = table(expKeys(i), ds, sP_, tP_, tDP_, rq.cLine_prof.v, sC_, tC_, tDC_, rq.cLine_cont.v, ...
            'VariableNames', {'experiment','dataSource','t_arr_prof_ref','t_arr_prof_min','tD_arr_prof','v_prof_cmmin', ...
            't_arr_cont_ref','t_arr_cont_min','tD_arr_cont','v_cont_cmmin'}); %#ok<SAGROW>
    end
end
fprintf('\nArrival time of t_D,res (tResRef = %s): profile and contours separately:\n', tResRef);
disp(vertcat(arrRows{:}))

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

%% 1d) Profiles of the section-8f frames (theta = rsRot, centre at zD in rsZD) with the C = 0.4 / 0.6 crossings
% Same plot as 1c, but for EVERY frame used for the XCT KL of section 8f (rotPos = rsRot +/- rsTol,
% front centre C = 0.5 at zD in rsZD). Horizontal lines at the two levels, dots where each profile
% crosses them (front-anchored, as profileWidth); the distance between the two dots of one curve
% is W_40-60. Several frames of one experiment: light (early) -> dark (late).
% Prints / saves per frame: run, theta, t_D, time elapsed, arrival, crossings, W and KL +/- dKL
% (profile and 2D contours, KL_allProfileWidths) -- the values behind the section-8f bars.
% frame settings rsRot, rsTol, rsZD, rsPair, rsVar, rsStat: SETTINGS (same frame as the 8f-8h bars)
ds17b   = "conc";              % data sources (as section 8f), e.g. dataSources for both
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

            % per-frame values (same frame and arrival as section 8f)
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
        close(fig);  warning('1d: no frame at theta = %g deg with the centre in zD [%.2f %.2f] (%s)', rsRot, rsZD, ds);
        continue
    end
    yline(ax, Ci + (Cj - Ci)*rsPair, '--k', 'LineWidth',1.2, 'HandleVisibility','off');
    xlabel(ax, 'z_D [-]', 'FontSize',fs17b);  ylabel(ax, 'C_1 [-]', 'FontSize',fs17b)
    xlim(ax, [0 1]);  ylim(ax, [0 1.02]);  set(ax, 'FontSize',fs17b);  grid(ax,'on');  box(ax,'on')
    legend(ax, h, 'Location','northeast', 'FontSize',fs17b-2, 'Interpreter','tex')

    T17b = vertcat(rows17b{:});
    fprintf(['\n1d) Profiles at theta = %g deg, centre zD %.2f-%.2f, %s%s: frame, time, C = %.1f / %.1f ' ...
             'crossings, W and KL (profile, contours):\n'], rsRot, rsZD, ds, rsVar, rsPair);
    disp(T17b)
    fn17b = sprintf('CT_profile_rot%d_zD%02d_%02d_W%s_%s%s', rsRot, round(100*rsZD), tagW17b, ds, rsVar);
    writetable(T17b, fullfile(exportPath, fn17b + ".xlsx"));
    saveFigBoth(fig, exportPath, fn17b, closeAfterSave)
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

%% 2a) Z profiles at a range of t_D,res targets (all experiments, one figure per t_D,res)
% Same as section 2, but the scans are picked by t_D,res = t_D - t_D,arr (column tD_res, arrival
% tResRef, default C50 = time the front centre enters the rock) instead of t_D,total, so every
% experiment is shown at the same time since its front entered the core.
% Note: t_D,res is on the Q t / V_total scale, so the front centre crosses the image in about
% 0.35-0.4 of t_D,res (set the targets accordingly).
tDres_target = 0.05:0.05:1.0;
var2a        = "_xtrim";             % "" = full image (CVert), "_xtrim" = x-trimmed (CVert_xtrim)
tolTD2a      = 0.03;                 % warning if the nearest scan is farther than this from the target
for ds = dataSources
    for m = 1:numel(tDres_target)
        fig = figure('Position',[100 100 900 600]);  hold on
        h = gobjects(0);
        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            if ~ismember("tD_res", string(vars.Properties.VariableNames))
                warning('%s (%s): no tD_res column (run the load block)', expKeys(i), ds);  continue
            end
            [minDist, l] = min(abs(vars.tD_res - tDres_target(m)));
            if minDist > tolTD2a
                warning('%s (%s): nearest scan is t_D,res = %.3f (target %.2f)', ...
                    expKeys(i), ds, vars.tD_res(l), tDres_target(m));
            end
            prof = cellRow(vars.C1Profile, l);  if iscell(prof), prof = prof{1}; end
            h(end+1) = plot(prof.zDimLess, prof.("CVert" + var2a), 'LineWidth',3, 'Color',expCol(i,:), ...
                'DisplayName', expName(i) + sprintf(", t_{D,res} = %.2f", vars.tD_res(l))); %#ok<SAGROW>
        end
        xlabel('z_D [-]','FontSize',14);  ylabel('C_1 [-]','FontSize',14)
        xlim([0 1]);  ylim([0 1.02]);  set(gca,'FontSize',14);  grid on;  box on
        if tDres_target(m) < 0.2, loc = 'northeast'; else, loc = 'southwest'; end   % front past mid-core
        legend(h, 'Interpreter','tex','FontSize',12,'Location',loc)
        title(sprintf('Z profiles (%s%s) @ t_{D,res} = %.2f (t_{arr}: %s)', ds, var2a, tDres_target(m), tResRef), ...
            'Interpreter','tex')
        fname = sprintf('Zprofiles_%s%s_%s%s', ds, var2a, tXtagRes(tResRef), ...
            strrep(sprintf('%.2f',tDres_target(m)),'.','p'));
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

%% 2ba) Profile evolution with t_D,res, one figure per experiment
% Same as 2b, but the scans are picked by t_D,res = t_D - t_D,arr (column tD_res, arrival tResRef,
% default C50 = time the front centre enters the rock), so the profiles of every experiment are
% drawn at the same times since the front entered the core.
% t_D,res is on the Q t / V_total scale: the front centre crosses the image in about 0.35-0.4.
tDres_evol = 0.05:0.05:1.00;      % t_D,res of the profiles drawn (nearest scan, within tolTD2ba)
var2ba     = "_xtrim";            % "" = full image, "_xtrim" = x-trimmed
tolTD2ba   = 0.025;               % max distance of the nearest scan to the target
for ds = dataSources
    for i = 1:nExp
        vars = expCTDataAll{i}.varsAll.(ds);
        if ~ismember("tD_res", string(vars.Properties.VariableNames))
            warning('%s (%s): no tD_res column (run the load block)', expKeys(i), ds);  continue
        end
        fig = figure('Position',[100 100 900 600]);  hold on
        h = gobjects(0);
        nT = numel(tDres_evol);
        for m = 1:nT
            [minDist, l] = min(abs(vars.tD_res - tDres_evol(m)));
            if minDist > tolTD2ba, continue, end
            prof = cellRow(vars.C1Profile, l);  if iscell(prof), prof = prof{1}; end
            f  = (m - 1)/max(nT - 1, 1);                         % 0 = early, 1 = late
            cm = (1 - f)*(0.25 + 0.75*expCol(i,:)) + f*(0.45*expCol(i,:));   % light -> dark
            h(end+1) = plot(prof.zDimLess, prof.("CVert" + var2ba), 'LineWidth',2.5, 'Color',cm, ...
                'DisplayName', sprintf('t_{D,res} = %.2f', vars.tD_res(l))); %#ok<SAGROW>
        end
        if isempty(h), close(fig); continue, end
        xlabel('z_D [-]','FontSize',14);  ylabel('C_1 [-]','FontSize',14)
        xlim([0 1]);  ylim([0 1.02]);  set(gca,'FontSize',14);  grid on;  box on
        legend(h, 'Interpreter','tex','FontSize',11,'Location','eastoutside')
        title(sprintf('%s: Z profiles vs t_{D,res} (%s%s, t_{arr}: %s)', expName(i), ds, var2ba, tResRef), ...
            'Interpreter','tex')
        saveFigBoth(fig, exportPath, sprintf('Zprofiles_evolution_%s_%s%s_%s', expKeys(i), ds, var2ba, ...
            tXtagRes(tResRef)), closeAfterSave)
    end
end

%% 3) CT outlet BTC: time, tD_total or tD_res (tAxis), front-velocity-scaled tD_core
% one dot per scan (markers only, no line: no joins across gaps between scans / runs)
btcVar3      = "_xtrim";                       % "" = full image | "_xtrim" = x-trimmed (x_D 0.25-0.75)
CfieldOutlet = "CD1_zD1p0" + btcVar3;
mk3          = 3;                              % dot size [points]
mkLeg3       = 10;                             % dot size in the legend [points]
% {x column, x label, file tag, x limits ([] = auto)}
btcAxes = {'timeElapsed',            'time elapsed [hh:mm:ss]',                   'time',         []; ...
           char(tXcol),              tXlbl,                                       char(tXtag),    tXlim; ...
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
zDaxes = {char(tXcol),              tXlbl,                                            tXlim; ...
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
            sprintf('BT_CT_allZD_%s_%s%s_%s', expKeys(i), ds, btcVariant, tXtag), closeAfterSave)
    end
end
%% 3c) Front position of every C level, contours and averaged profile, with their own arrival (one figure per experiment)
% Four panels, each source with its OWN arrival and velocity (never mixed; load block):
%   1) 2D contours, z_D vs t_D,res,cont = t_D - t_D,arr,cont        (contour level arrival, tD_res_cont)
%   2) 2D contours, z_D vs v_cont (t - t_arr,cont) / L_img          (contour C = 0.5 centre line, cLine_cont)
%   3) averaged profile, z_D vs t_D,res,prof = t_D - t_D,arr,prof   (profile level arrival, tD_res_prof)
%   4) averaged profile, z_D vs v_prof (t - t_arr,prof) / L_img     (profile C = 0.5 centre line, cLine_prof)
% Contours: mean z of the C contour (zDFront<CC><posVariant>). Profile: crossing of level C on the averaged
% profile CVert<posVariant>, searched outward from its C = 0.5 crossing (profLevels, as main_CTpostproc;
% low levels also before the centre is inside). Arrival tResRef (default: C = 0.01 level t0 of each source).
% In panels 2 and 4 a front moving at its centre-line velocity puts the C = 0.5 level on z_D = x.

CplotLevels = [0.01 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9];   % contour levels must be among Clevels of main_CTpreproc
posVariant  = "_xtrim";      % "" = full x-range | "_xtrim" (as the level arrivals of main_CTpostproc)
xLimPos     = [-0.1 1.2];    % x-range of all four panels
lvlCols = parula(numel(CplotLevels) + 1);  lvlCols = lvlCols(1:numel(CplotLevels),:);
posPanels = frontPosPanels(tResRef);       % {source, axis kind, x label}

for ds = dataSources
    for i = 1:nExp
        [X, ZD] = frontPosData(expCTDataAll{i}, filedataExpAll{i}, ds, CplotLevels, posVariant);
        fig = figure('Position',[50 50 1400 1000]);
        tl  = tiledlayout(fig, 2, 2, 'TileSpacing','compact');
        for a = 1:size(posPanels,1)
            ax = nexttile(tl);  hold(ax,'on')
            src = posPanels{a,1};  x = X.(src).(posPanels{a,2});  Z = ZD.(src);
            if all(~isfinite(x))
                text(ax, 0.5, 0.5, "no " + src + " arrival", 'Units','normalized', 'HorizontalAlignment','center');  continue
            end
            for m = 1:numel(CplotLevels)
                ok = isfinite(x) & isfinite(Z(:,m));
                if ~any(ok), continue, end
                scatter(ax, x(ok), Z(ok,m), 14, lvlCols(m,:), 'filled', 'DisplayName', sprintf('C = %.2f', CplotLevels(m)))
            end
            xline(ax, 0, '--k', 'LineWidth',1, 'HandleVisibility','off')            % arrival
            if posPanels{a,2} == "scaled"
                plot(ax, [0 1], [0 1], 'k:', 'LineWidth',1.5, 'HandleVisibility','off')  % centre line
            end
            legend(ax, 'Location','southeast', 'FontSize',8)
            xlabel(ax, posPanels{a,3}, 'FontSize',12);  ylabel(ax, "z_D [-] (" + src + ")", 'FontSize',12)
            xlim(ax, xLimPos);  ylim(ax, [-0.02 1.02]);  set(ax,'FontSize',11);  grid(ax,'on')
        end
        title(tl, sprintf('%s (%s): z_D of each C level, contours (top) and averaged profile (bottom), %s, t_{arr}: %s', ...
            strrep(expKeys(i),'_','\_'), ds, strrep(posVariant,'_',''), tResRef), 'Interpreter','tex')
        saveFigBoth(fig, exportPath, sprintf('frontPos_allC_%s_%s%s_%s', expKeys(i), ds, posVariant, tXtagRes(tResRef)), closeAfterSave)
    end
end

%% 3d) Front position of one C level, all experiments together, contours and profile (one figure per level)
% Same four panels as 3c (contours / averaged profile, each vs its own t_D,res and its own scaled time),
% one figure per level with every experiment.

CplotLevels = [0.01 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9];
posVariant  = "_xtrim";
xLimPos     = [-0.1 1.2];
posPanels   = frontPosPanels(tResRef);

for ds = dataSources
    X = cell(nExp,1);  ZD = cell(nExp,1);
    for i = 1:nExp
        [X{i}, ZD{i}] = frontPosData(expCTDataAll{i}, filedataExpAll{i}, ds, CplotLevels, posVariant);
    end
    for m = 1:numel(CplotLevels)
        fig = figure('Position',[50 50 1400 1000]);
        tl  = tiledlayout(fig, 2, 2, 'TileSpacing','compact');
        for a = 1:size(posPanels,1)
            ax = nexttile(tl);  hold(ax,'on');  src = posPanels{a,1};
            for i = 1:nExp
                x = X{i}.(src).(posPanels{a,2});  z = ZD{i}.(src)(:,m);
                ok = isfinite(x) & isfinite(z);
                if ~any(ok), continue, end
                scatter(ax, x(ok), z(ok), 14, expCol(i,:), 'filled', 'DisplayName', expName(i))
            end
            xline(ax, 0, '--k', 'LineWidth',1, 'HandleVisibility','off')
            if posPanels{a,2} == "scaled"
                plot(ax, [0 1], [0 1], 'k:', 'LineWidth',1.5, 'HandleVisibility','off')
            end
            xlabel(ax, posPanels{a,3}, 'FontSize',12);  ylabel(ax, "z_D [-] (" + src + ")", 'FontSize',12)
            xlim(ax, xLimPos);  ylim(ax, [-0.02 1.02]);  set(ax,'FontSize',11);  grid(ax,'on')
            legend(ax, 'Location','southeast', 'FontSize',8, 'Interpreter','none')
        end
        title(tl, sprintf('z_D at C = %.2f, all experiments: contours (top), averaged profile (bottom) (%s, %s, t_{arr}: %s)', ...
            CplotLevels(m), ds, strrep(posVariant,'_',''), tResRef), 'Interpreter','tex')
        saveFigBoth(fig, exportPath, sprintf('frontPos_C%02d_allExp_%s%s_%s', round(100*CplotLevels(m)), ds, ...
            posVariant, tXtagRes(tResRef)), closeAfterSave)
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
            scatter(vars.(tXcolC), vars.(measField), 8, 'filled', ...          % 2D contours -> contour t_arr
                'MarkerFaceColor',cols(i,:), 'MarkerEdgeColor','none', 'DisplayName', expKeys(i))
            nPlotted = nPlotted + 1;
        end
        if nPlotted == 0, close(fig); continue, end

        xlabel(tXlbl,'FontSize',14);  ylabel('\DeltaZ_D [-]','FontSize',14)
        ylim([-0.02 1]);  xlim(tXlim);  set(gca,'FontSize',14);  grid on
        legend('Interpreter','none','FontSize',8,'Location','northeast')
        title(sprintf('Measured front width (%s) from CT (%s)', strrep(widthPairs{p},'_','-'), ds), ...
            'Interpreter','none')
        saveFigBoth(fig, exportPath, sprintf('width_CT_%s_%s_%s', widthPairs{p}, ds, tXtag), closeAfterSave)
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
                scatter(vars.(tXcolC), abs(vars.(cField)), 10, 'filled', 'o', ...   % contours: contour t_arr
                    'MarkerFaceColor',cols(i,:), 'MarkerEdgeColor','none', ...
                    'DisplayName', expName(i) + " contours")
                nPlotted = nPlotted + 1;
            end
            if ismember(pField, vn)
                scatter(vars.(tXcolP), abs(vars.(pField)), 26, 's', ...   % profile: profile t_arr
                    'MarkerFaceColor',cols(i,:), 'MarkerEdgeColor',colsDark(i,:), 'LineWidth',0.8, ...
                    'DisplayName', expName(i) + " profile")
                nPlotted = nPlotted + 1;
            end
        end
        if nPlotted == 0, close(fig); continue, end

        xlabel(tXlbl,'FontSize',14);  ylabel('\DeltaZ_D [-]','FontSize',14)
        ylim([-0.02 1]);  xlim(tXlim);  set(gca,'FontSize',14);  grid on
        legend('Interpreter','none','FontSize',8,'Location','northeast','NumColumns',2)
        title(sprintf('Front width (%s): 2D contours (circles) vs averaged profile (squares) (%s%s)', ...
            strrep(widthPairsCmp{p},'_','-'), ds, widthVarCmp), 'Interpreter','tex')
        saveFigBoth(fig, exportPath, sprintf('width_contour_profile_%s_%s%s_%s', ...
            widthPairsCmp{p}, ds, widthVarCmp, tXtag), closeAfterSave)
    end
end

%% 7c) Averaged-profile front width vs tD only (one figure per level pair)
% zDWidthProf_<lo>_<hi> (addProfileWidths, main_CTpostproc), one colour per experiment
% (expCol: P900 blue / P725 green, light = Q1, dark = Q5), legend XCT-loM-hiPe etc.
% No axes title: the description is the figure name.

widthPairsProf = {'10_90','20_80','30_70','40_60'};
widthVarProf   = "_xtrim";         % "" = full image, "_xtrim" = x-trimmed
widthUnitProf  = "";               % "" = zD [-], "_cm" = cm
fs7cAx         = 20;               % font size: tick labels
fs7cLbl        = 24;               % font size: axis labels
fs7cLeg        = 20;               % font size: legend
mk7c           = 30;               % marker size
yLim7c         = [0 0.5];          % y-axis limits (zD units; [] = auto)
legMk7c        = 12;               % marker size in the legend [points]

for ds = dataSources
    for p = 1:numel(widthPairsProf)
        pField  = "zDWidthProf_" + widthPairsProf{p} + widthVarProf + widthUnitProf;
        figName = sprintf('Averaged-profile front width %s vs t_D (%s%s)', ...
            strrep(widthPairsProf{p},'_','-'), ds, widthVarProf);
        fig = figure('Position',[100 100 1000 650], 'Name',figName, 'NumberTitle','off');
        ax  = axes(fig);  hold(ax,'on')
        hLeg = gobjects(0);

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            if ~ismember(pField, string(vars.Properties.VariableNames)), continue, end
            w  = abs(vars.(pField));
            ok = isfinite(vars.(tXcol)) & isfinite(w);
            if ~any(ok), continue, end
            scatter(ax, vars.(tXcol)(ok), w(ok), mk7c, expCol(i,:), 'o', 'filled', ...
                'MarkerEdgeColor',0.6*expCol(i,:), 'LineWidth',0.5, 'HandleVisibility','off')
            % legend entry: invisible larger marker (scatter legend icons stay small)
            hLeg(end+1) = plot(ax, NaN, NaN, 'o', 'LineStyle','none', 'MarkerSize',legMk7c, ...
                'MarkerFaceColor',expCol(i,:), 'MarkerEdgeColor',0.6*expCol(i,:), 'DisplayName', expName(i)); %#ok<SAGROW>
        end
        if isempty(hLeg), close(fig); continue, end

        set(ax, 'FontSize',fs7cAx, 'LabelFontSizeMultiplier',1, 'TitleFontSizeMultiplier',1)
        xlabel(ax, tXlbl, 'FontSize',fs7cLbl)
        if widthUnitProf == "_cm"
            ylabel(ax, "W_{" + strrep(widthPairsProf{p},'_','-') + "}, profile [cm]", 'FontSize',fs7cLbl)
            ylim(ax, [0 inf])
        else
            ylabel(ax, "\Deltaz_{D," + strrep(widthPairsProf{p},'_','-') + "}, profile [-]", 'FontSize',fs7cLbl)
            if isempty(yLim7c), ylim(ax, [0 inf]), else, ylim(ax, yLim7c), end
        end
        xlim(ax, tXlim);  grid(ax,'on');  box(ax,'on')
        legend(ax, hLeg, 'Location','northeast', 'FontSize',fs7cLeg, 'Interpreter','none')
        saveFigBoth(fig, exportPath, sprintf('width_profile_%s_%s%s%s_%s', ...
            widthPairsProf{p}, ds, widthVarProf, widthUnitProf, tXtag), closeAfterSave)
    end
end
%% 7d) Profile front width vs tD, with the frame of the KL-by-method value (red circle)
% Same as 7c (zDWidthProf_<lo>_<hi>, one colour per experiment, same fonts / legend), plus, per
% experiment, the frame used for the XCT 1D-profile bar of section 8f (rotPos = rsRot +/- rsTol,
% front centre closest to zD = 0.5 within rsZD, rotZDsel) as a red open circle, as in section 15b,
% drawn on top of all dots. Dots semi-transparent (alpha7d).
% Legend (top right): one entry per experiment + one red circle "theta = rsRot".
% Uses the settings of section 8f (rsRot, rsTol, rsZD, rsPair, rsVar): run it first, or the
% defaults below are used.

% frame settings rsRot, rsTol, rsZD, rsPair, rsVar, rsStat: SETTINGS (same frame as the 8f-8h bars)
widthPairs7d = {sprintf('%02d_%02d', round(100*rsPair))};   % e.g. {'40_60'}; more pairs: {'10_90','40_60'}
widthVar7d   = rsVar;              % "" = full image, "_xtrim" = x-trimmed (same as the bar)
widthUnit7d  = "";                 % "" = zD [-], "_cm" = cm
fs7dAx       = 20;                 % font size: tick labels
fs7dLbl      = 24;                 % font size: axis labels
fs7dLeg      = 20;                 % font size: legend
mk7d         = 120;                 % marker size (dots and red circle)
alpha7d      = 0.5;                % face transparency of the dots (1 = opaque, 0 = invisible)
legMk7d      = 12;                 % marker size in the legend [points]
yLim7d       = [0 0.5];            % y-axis limits (zD units; [] = auto)
colBar7d     = [0.85 0 0];         % colour of the red circle

for ds = "conc"
    for p = 1:numel(widthPairs7d)
        pField  = "zDWidthProf_" + widthPairs7d{p} + widthVar7d + widthUnit7d;
        figName = sprintf('Profile front width %s vs t_D, with the theta = %d deg frame (%s%s)', ...
            strrep(widthPairs7d{p},'_','-'), rsRot, ds, widthVar7d);
        fig = figure('Position',[100 100 1000 650], 'Name',figName, 'NumberTitle','off');
        ax  = axes(fig);  hold(ax,'on')
        hLeg = gobjects(0);  hBar = gobjects(0);  hRed = gobjects(0);  rows7d = {};

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            if ~ismember(pField, string(vars.Properties.VariableNames)), continue, end
            w  = abs(vars.(pField));
            ok = isfinite(vars.(tXcol)) & isfinite(w);
            if ~any(ok), continue, end
            scatter(ax, vars.(tXcol)(ok), w(ok), mk7d, expCol(i,:), 'o', 'filled', ...
                'MarkerEdgeColor',0.6*expCol(i,:), 'LineWidth',0.5, ...
                'MarkerFaceAlpha',alpha7d, 'MarkerEdgeAlpha',min(1, alpha7d + 0.3), ...
                'HandleVisibility','off')
            % legend entry: invisible larger marker (scatter legend icons stay small)
            hLeg(end+1) = plot(ax, NaN, NaN, 'o', 'LineStyle','none', 'MarkerSize',legMk7d, ...
                'MarkerFaceColor',expCol(i,:), 'MarkerEdgeColor',0.6*expCol(i,:), 'DisplayName', expName(i)); %#ok<SAGROW>

            % frame of the KL-by-method bar (same selection as 8f / 8g / 15b)
            Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, rsVar, rsPair);
            if isempty(Tk), continue, end
            fr = Tk.frame(rotZDsel(Tk, rsRot, rsTol, rsZD));
            fr = fr(ok(fr));
            if isempty(fr), continue, end
            hRed(end+1) = scatter(ax, vars.(tXcol)(fr), w(fr), mk7d, 'o', 'MarkerEdgeColor',colBar7d, ...
                'MarkerFaceColor','none', 'LineWidth',2.5, 'HandleVisibility','off'); %#ok<SAGROW>
            if isempty(hBar)                                     % one legend entry for all red circles
                hBar = plot(ax, NaN, NaN, 'o', 'LineStyle','none', 'MarkerSize',legMk7d, ...
                    'MarkerEdgeColor',colBar7d, 'MarkerFaceColor','none', 'LineWidth',2.5, ...
                    'DisplayName', sprintf('\\theta = %d°', rsRot));
            end
            rows7d{end+1,1} = table(repmat(expName(i),numel(fr),1), fr, vars.(tXcol)(fr), vars.rotPos(fr), w(fr), ...
                'VariableNames', {'experiment','frame',char(tXtag),'rotPos_deg', char(pField)}); %#ok<SAGROW>
        end
        if ~isempty(hRed), uistack(hRed, 'top'); end        % red circles above all dots
        if isempty(hLeg), close(fig); continue, end

        set(ax, 'FontSize',fs7dAx, 'LabelFontSizeMultiplier',1, 'TitleFontSizeMultiplier',1)
        xlabel(ax, tXlbl, 'FontSize',fs7dLbl)
        if widthUnit7d == "_cm"
            ylabel(ax, "W_{" + strrep(widthPairs7d{p},'_','-') + "}, profile [cm]", 'FontSize',fs7dLbl)
            ylim(ax, [0 inf])
        else
            ylabel(ax, "\Deltaz_{D," + strrep(widthPairs7d{p},'_','-') + "}, profile [-]", 'FontSize',fs7dLbl)
            if isempty(yLim7d), ylim(ax, [0 inf]), else, ylim(ax, yLim7d), end
        end
        xlim(ax, tXlim);  grid(ax,'on');  box(ax,'on')
        legend(ax, [hLeg hBar], 'Location','northeast', 'FontSize',fs7dLeg, 'Interpreter','tex')
        if ~isempty(rows7d)
            fprintf('\n7d) Frame of the KL-by-method value (theta = %g deg), width %s:\n', rsRot, pField);
            disp(vertcat(rows7d{:}))
        end
        saveFigBoth(fig, exportPath, sprintf('width_profile_%s_%s%s%s_%s_rot%d', ...
            widthPairs7d{p}, ds, widthVar7d, widthUnit7d, tXtag, rsRot), closeAfterSave)
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
        isCont8   = envSrc8 == "zDWidth_";                    % contours: contour centre and t_arr
        cenField  = ternaryStr(isCont8, "zDFront50", "zDFrontProfC50") + envVar8;
        tX8       = ternaryStr(isCont8, tXcolC, tXcolP);
        fig = figure('Position',[100 100 1000 650]);  hold on

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            if ~all(ismember([measField cenField], string(vars.Properties.VariableNames))), continue, end

            tD = vars.(tX8);
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

        xlabel(tXlbl,'FontSize',14);  ylabel('z_D [-]','FontSize',14)
        ylim([-0.02 1.02]);  xlim(tXlim);  set(gca,'FontSize',14);  grid on
        legend('Interpreter','none','FontSize',12,'Location','southeast')
        title(sprintf('Measured front envelope (%s, centred on C=0.5) (%s%s)', ...
            strrep(widthPairsEnv{p},'_','-'), ds, envVar8), 'Interpreter','none')
        saveFigBoth(fig, exportPath, sprintf('frontEnvelope_CT_allExp_%s_%s%s_%s', ...
            widthPairsEnv{p}, ds, envVar8, tXtag), closeAfterSave)
    end
end

%% 8a) Front envelope from the AVERAGED PROFILE, all experiments together
% Centre = front centre of the averaged profile (zDFrontProfC50: C = 0.5 crossing, no fit, addProfileWidths;
% fallback: erfc-fit z50 zDFrontProf50 -- profile only, never the contour centre),
% bar = centre +/- W/2 with W = averaged-profile width zDWidthProf_<lo>_<hi> (the width used for
% the profile KL); x = t_D with the profile arrival (tXcolP).
% Legend XCT-loM-hiPe etc. (expName, expCol).

widthPairsEnvP = {'10_90','20_80','30_70','40_60'};
envVarP        = "_xtrim";      % "" = full image | "_xtrim" = x-trimmed (as the mid-profile KL)
fsEnvP         = 16;

for ds = dataSources
    for p = 1:numel(widthPairsEnvP)
        wField = "zDWidthProf_" + widthPairsEnvP{p} + envVarP;
        cField = "zDFrontProfC50" + envVarP;         % profile centre: C = 0.5 crossing
        cFall  = "zDFrontProf50" + envVarP;          % fallback: erfc-fit centre of the same profile
        figName = sprintf('Averaged-profile front envelope %s (%s%s)', ...
            strrep(widthPairsEnvP{p},'_','-'), ds, envVarP);
        fig = figure('Position',[100 100 1000 650], 'Name',figName, 'NumberTitle','off');
        ax  = axes(fig);  hold(ax,'on')
        nPlotted = 0;

        for i = 1:nExp
            vars = expCTDataAll{i}.varsAll.(ds);
            vn   = string(vars.Properties.VariableNames);
            if ~ismember(wField, vn), continue, end

            tD   = vars.(tXcolP);
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
        xlabel(ax, tXlbl, 'FontSize',fsEnvP);  ylabel(ax, 'z_D [-]', 'FontSize',fsEnvP)
        ylim(ax, [-0.02 1.02]);  xlim(ax, tXlim);  grid(ax,'on');  box(ax,'on')
        legend(ax, 'Interpreter','none', 'FontSize',fsEnvP, 'Location','southeast')
        saveFigBoth(fig, exportPath, sprintf('frontEnvelope_profile_allExp_%s_%s%s_%s', ...
            widthPairsEnvP{p}, ds, envVarP, tXtag), closeAfterSave)
    end
end

%% 8a2) Front centre of the AVERAGED PROFILE vs tD, with the front-velocity line (no width bars)
% Dots = front centre of the averaged profile (zDFrontProfC50: C = 0.5 crossing; fallback erfc z50),
% as 8a but without the +/- W/2 bars; x = t_D with the profile arrival.
% Line (dashed, same colour) = constant front velocity of each experiment, straight line in t_D:
%   vfSrc = "profile": centre line of the profile C = 0.5 crossing (resultsAll.(ds).cLine_prof: v and t0
%                     of the C = 0.5 row of arrLevels.profile, else vFrontProf) -> profile only [default]
%   vfSrc = "C50"   : through the C = 0.5 centre, column tD_corr_vFrontC50 (v_front and t0 of the
%                     C = 0.5 line from main_CTpreproc) -> lies on the dots
%   vfSrc = "column": through the leading edge, column tD_corr_contour_scaled (v_front with the
%                     C = 0.01 contour arrival) -> same slope, earlier (shifted left)
%   vfSrc = "fit"   : straight line fitted to the plotted centres with z_D in vfZDfit
% Legend: one entry per experiment (dots) + one dashed entry "u_front" (no value).
% Print: u_front [cm/min] as printed by main_CTpostproc (resultsAll.(ds).vFront_cmmin);
% fallback: slope [z_D per t_D] * L[in]*2.54 * Q / V_total (filedataExp.L is in inches).

envVarP2  = "_xtrim";           % "" = full image | "_xtrim" = x-trimmed (as the mid-profile KL)
vfSrc     = "profile";          % "profile" | "C50" | "column" | "fit"
vfZDfit   = [0.1 0.9];          % zD range of the centres used when vfSrc = "fit"
fsEnvP2   = 16;
mkEnvP2   = 18;

for ds = dataSources
    cField = "zDFrontProfC50" + envVarP2;         % profile centre: C = 0.5 crossing
    cFall  = "zDFrontProf50" + envVarP2;          % fallback: erfc-fit centre of the same profile
    figName = sprintf('Averaged-profile front centre with the u_front line (%s%s, %s)', ds, envVarP2, vfSrc);
    fig = figure('Position',[100 100 1000 650], 'Name',figName, 'NumberTitle','off');
    ax  = axes(fig);  hold(ax,'on')
    h = gobjects(0);  hLine = gobjects(0);  rows8a2 = {};

    for i = 1:nExp
        vars = expCTDataAll{i}.varsAll.(ds);
        vn   = string(vars.Properties.VariableNames);
        fd   = filedataExpAll{i};
        tD   = vars.(tXcolP);
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
        rP = expCTDataAll{i}.resultsAll.(ds);
        if vfSrc == "profile" && isfield(rP, 'cLine_prof') && isfinite(rP.cLine_prof.v)
            % z = v (t - t0) with t = t_arr,x + x V/Q (x = t_D axis) and z_D = z / L_img
            okL = isfinite(cen) & cen > 0.05 & ismember(cField + "_cm", vn);
            Limg = NaN;  if any(okL), Limg = median(vars.(cField + "_cm")(okL) ./ cen(okL), 'omitnan'); end
            if ~isfinite(Limg), Limg = fd.L*2.54; end
            tA0 = 0;  if tAxis == "tDres", tA0 = rP.tArr_plot_prof_min; end
            p = [rP.cLine_prof.v*fd.Vtotal/(fd.Q*Limg), rP.cLine_prof.v*(tA0 - rP.cLine_prof.t0)/Limg];
        elseif vfSrc == "C50" && ismember(colC50, vn)
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
        if vfSrc == "profile" && isfield(rP, 'cLine_prof')
            vfPost = rP.cLine_prof.v;                          % profile centre line
        elseif hasPost(i) && isfield(rP, 'vFront_cmmin')
            vfPost = rP.vFront_cmmin;                          % contour centre line (preproc)
        end
        vfSlope = p(1) * fd.L*2.54 * fd.Q / fd.Vtotal;      % [cm/min] (L in inches, Q in ml/min, V in ml)
        vf = vfPost;  if ~isfinite(vf), vf = vfSlope; end

        plot(ax, [tD0 tD1], [0 1], '--', 'Color',0.6*expCol(i,:), 'LineWidth',2, 'HandleVisibility','off')
        if isempty(hLine)                                   % one legend entry for all lines
            hLine = plot(ax, NaN, NaN, '--', 'Color',[0.3 0.3 0.3], 'LineWidth',2, 'DisplayName','u_{front}');
        end
        rows8a2{end+1,1} = table(expName(i), string(srcUsed), p(1), tD0, tD1, vfPost, vfSlope, ...
            'VariableNames', {'experiment','line','slope_zD_per_tD', char(tXtag + "_at_zD0"), char(tXtag + "_at_zD1"), ...
            'ufront_postproc_cm_min','ufront_slope_cm_min'}); %#ok<SAGROW>
    end
    if isempty(h), close(fig); continue, end

    set(ax, 'FontSize',fsEnvP2, 'LabelFontSizeMultiplier',1, 'TitleFontSizeMultiplier',1)
    xlabel(ax, tXlbl, 'FontSize',fsEnvP2);  ylabel(ax, 'z_D front centre [-]', 'FontSize',fsEnvP2)
    ylim(ax, [-0.02 1.02]);  xlim(ax, tXlim);  grid(ax,'on');  box(ax,'on')
    legend(ax, [h hLine], 'Interpreter','tex', 'FontSize',fsEnvP2-2, 'Location','southeast')
    if ~isempty(rows8a2)
        fprintf('\n8a2) Front velocity u_front per experiment (%s%s, line: %s):\n', ds, envVarP2, vfSrc);
        disp(vertcat(rows8a2{:}))
    end
    saveFigBoth(fig, exportPath, sprintf('frontCentre_profile_ufront_allExp_%s%s_%s_%s', ds, envVarP2, vfSrc, tXtag), closeAfterSave)
end

%% 8a2a) Front center of the 2D CONTOURS in dimensions: z [cm] vs t_res [min], with the u_front line
% Dots and line from the SAME quantity, the C = 0.5 2D-contour center over the full image
% (zDFront50_cm, populate_CTframeVars), which is what main_CTpreproc fits for v_front (frontVel):
%   y = z = zDFront50_cm [cm]
%   x = t_res = t - t_arr [min] (t_arr = tResRef arrival of the load block, resultsAll.(ds).tArr_plot_min,
%                               the same origin as the t_D,res axis; C50 = time the center enters the rock)
% Filled dots = frames used in the v_front fit (0.03 < z_D < 0.97, as frontVel); open = the rest.
% Here the slopes ARE the front velocities, so faster (higher Q) fronts are steeper: unlike 8a2,
% where t_D = Q t / V divides the velocity by Q and the slopes collapse.
% Line (dashed, same color): z = v_front t + b of main_CTpreproc (resultsAll.(ds).vFront), shifted to
% t_res; fallback (no vFront): the same fit done here on the plotted dots.
% ufLineA = true also draws z = u_int t_res, u_int = Q/(A phi) (dotted, piston flow).
% Printed: v_front, u_int = Q/(A phi) and v_front/u_int (> 1: center faster than piston flow).

ufLineA   = false;              % true: also the piston-flow line z = u_int t_res (dotted)
var8a2a   = "_xtrim";           % contour centre "" (full image) | "_xtrim" (as the contour levels of
                                % main_CTpostproc); t_arr and line from the CONTOUR levels (cLine_cont)
fsA       = 16;
mkA       = 18;

for ds = dataSources
    figName = sprintf('Contour front center z [cm] vs t_res [min] with the u_front line (%s, t_arr %s)', ds, tResRef);
    fig = figure('Position',[100 100 1000 650], 'Name',figName, 'NumberTitle','off');
    ax  = axes(fig);  hold(ax,'on')
    h = gobjects(0);  hLine = gobjects(0);  hU = gobjects(0);  rowsA = {};  zMax = 0;

    for i = 1:nExp
        vars = expCTDataAll{i}.varsAll.(ds);
        vn   = string(vars.Properties.VariableNames);
        fd   = filedataExpAll{i};
        cz8 = "zDFront50" + var8a2a;
        if ~all(ismember([cz8 + "_cm", cz8], vn))
            warning('8a2a: %s (%s): %s_cm / %s missing', expKeys(i), ds, cz8, cz8);  continue
        end
        rA   = struct();
        if isfield(expCTDataAll{i}, 'resultsAll') && isfield(expCTDataAll{i}.resultsAll, ds)
            rA = expCTDataAll{i}.resultsAll.(ds);
        end
        if ~isfield(rA, 'tArr_plot_cont_min') || ~isfinite(rA.tArr_plot_cont_min)
            warning('8a2a: %s (%s): no contour t_arr (run the load block)', expKeys(i), ds);  continue
        end
        tArr = rA.tArr_plot_cont_min;                            % contour arrival

        t    = vars.secondsElapsed/60;                           % [min since start]
        tRes = t - tArr;                                         % t_res [min]
        z    = vars.(cz8 + "_cm");                               % contour center [cm]
        zD   = vars.(cz8);
        ok   = isfinite(tRes) & isfinite(z);
        if ~any(ok), continue, end
        inFit = ok & zD > 0.03 & zD < 0.97;                     % frames of the frontVel fit
        h(end+1) = scatter(ax, tRes(inFit), z(inFit), mkA, expCol(i,:), 'filled', ...
            'MarkerEdgeColor',0.6*expCol(i,:), 'DisplayName', expName(i)); %#ok<SAGROW>
        scatter(ax, tRes(ok & ~inFit), z(ok & ~inFit), mkA, 0.6*expCol(i,:), 'HandleVisibility','off')

        % length of the column: z where z_D = 1 (zDFront50_cm / zDFront50), fallback core length
        rL   = z(ok & zD > 0.05) ./ zD(ok & zD > 0.05);
        Limg = median(rL, 'omitnan');  if ~isfinite(Limg), Limg = fd.L*2.54; end
        zMax = max(zMax, Limg);

        % front-velocity line z = v t + b (t in min since the start), shifted to t_res = t - t_arr
        v = NaN;  b = NaN;  srcUsed = "contour centre line";
        if var8a2a == "_xtrim" && isfield(rA, 'cLine_cont') && isfinite(rA.cLine_cont.v)
            v = rA.cLine_cont.v;  b = -v*rA.cLine_cont.t0;  srcUsed = rA.cLine_cont.src;
        elseif var8a2a == "" && isfield(rA, 'vFront') && isstruct(rA.vFront) && isfinite(rA.vFront.v_front_cmmin) && rA.vFront.v_front_cmmin > 0
            v = rA.vFront.v_front_cmmin;  b = rA.vFront.intercept_cm;  srcUsed = "preproc vFront";
        elseif nnz(inFit) >= 5
            srcUsed = "fit here";
            p = polyfit(t(inFit), z(inFit), 1);  v = p(1);  b = p(2);
        end
        uInt = fd.Q/(fd.phi*pi*(fd.D*2.54/2)^2);                % interstitial velocity [cm/min]
        if isfinite(v) && v > 0
            tRes0 = -b/v - tArr;  tRes1 = (Limg - b)/v - tArr;    % z = 0 and z = L
            plot(ax, [tRes0 tRes1], [0 Limg], '--', 'Color',0.6*expCol(i,:), 'LineWidth',2, 'HandleVisibility','off')
            if isempty(hLine)
                hLine = plot(ax, NaN, NaN, '--', 'Color',[0.3 0.3 0.3], 'LineWidth',2, 'DisplayName','u_{front}');
            end
        else
            tRes0 = NaN;  tRes1 = NaN;
        end
        if ufLineA
            plot(ax, [0 Limg/uInt], [0 Limg], ':', 'Color',0.6*expCol(i,:), 'LineWidth',2, 'HandleVisibility','off')
            if isempty(hU)
                hU = plot(ax, NaN, NaN, ':', 'Color',[0.3 0.3 0.3], 'LineWidth',2, 'DisplayName','u_{int} = Q/(A\phi)');
            end
        end
        rowsA{end+1,1} = table(expName(i), srcUsed, tArr, Limg, v, uInt, v/uInt, tRes0, tRes1, nnz(inFit), ...
            'VariableNames', {'experiment','line','t_arr_min','L_cm','v_front_cmmin','u_int_cmmin', ...
            'v_front_over_u_int','tres_at_z0_min','tres_at_L_min','n_fit'}); %#ok<SAGROW>
    end
    if isempty(h), close(fig); continue, end

    set(ax, 'FontSize',fsA, 'LabelFontSizeMultiplier',1, 'TitleFontSizeMultiplier',1)
    xlabel(ax, 't_{res} [min]', 'FontSize',fsA);  ylabel(ax, 'z front center [cm]', 'FontSize',fsA)
    ylim(ax, [-0.02 1.02]*zMax);  xlim(ax, [0 inf]);  grid(ax,'on');  box(ax,'on')
    legend(ax, [h hLine hU], 'Interpreter','tex', 'FontSize',fsA-2, 'Location','southeast')
    if ~isempty(rowsA)
        fprintf('\n8a2a) Contour front center in dimensions (%s, t_arr %s): v_front vs u_int = Q/(A phi):\n', ds, tResRef);
        disp(vertcat(rowsA{:}))
    end
    saveFigBoth(fig, exportPath, sprintf('frontCenter_contour_ufront_dim_allExp_%s%s_%s', ds, var8a2a, tXtagRes(tResRef)), closeAfterSave)
end
%% 8b) Front envelope per experiment: 2D-contour width (colour) vs averaged-profile width (grey)
% Contour widths zDWidth_<lo>_<hi> (populate_CTframeVars) and averaged-profile widths
% zDWidthProf_<lo>_<hi> (addProfileWidths, written by main_CTpostproc into <Key>_postproc.mat).
% Each envelope with its own source: contours on the C = 0.5 contour centre (zDFront50) vs t_D with the
% contour arrival; profile on the profile C = 0.5 crossing (zDFrontProfC50) vs t_D with the profile arrival.
% One figure per experiment, one panel per level pair.

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
        tDc = vars.(tXcolC);  zc  = vars.("zDFront50" + envVariant);          % contours
        tDp = vars.(tXcolP);  zcP = nan(height(vars),1);                       % profile
        if ismember("zDFrontProfC50" + envVariant, cols_i), zcP = vars.("zDFrontProfC50" + envVariant); end

        for p = 1:numel(envPairs)
            ax = nexttile(tl);  hold(ax,'on')
            cCol = "zDWidth_"     + envPairs{p} + envVariant;
            pCol = "zDWidthProf_" + envPairs{p} + envVariant;
            if ~all(ismember([cCol pCol], cols_i))
                text(ax, 0.5, 0.5, cCol + " / " + pCol + " not available", 'Units','normalized', ...
                    'HorizontalAlignment','center', 'Interpreter','none');  continue
            end
            % averaged profile (grey, wide, behind) and 2D contours (colour, on top)
            envSegments(ax, tDp, zcP, abs(vars.(pCol))/2, greyProf, 5, 0.5, "averaged profile")
            envSegments(ax, tDc, zc, abs(vars.(cCol))/2, expCol(i,:), 1.8, 0.9, "2D contours")
            ok = isfinite(tDc) & isfinite(zc);
            scatter(ax, tDc(ok), zc(ok), 10, 0.6*expCol(i,:), 'filled', 'DisplayName','contour centre (C = 0.5)')

            xlabel(ax, tXlbl, 'FontSize',13);  ylabel(ax, 'z_D [-]', 'FontSize',13)
            ylim(ax, [-0.02 1.02]);  xlim(ax, tXlim);  set(ax, 'FontSize',12);  grid(ax,'on')
            title(ax, "width " + strrep(envPairs{p},'_','-'), 'FontSize',12)
            legend(ax, 'Location','southeast', 'FontSize',9)
        end
        title(tl, sprintf('%s (%s): front envelope, 2D contours (colour) vs averaged profile (grey)', ...
            expName(i), ds), 'Interpreter','none')
        saveFigBoth(fig, exportPath, sprintf('frontEnvelope_contour_vs_profile_%s_%s%s_%s', ...
            expKeys(i), ds, envVariant, tXtag), closeAfterSave)
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
klMidMethod  = "C40_60_levels";     % averaged profile, W_40-60, t_arr = profile level arrival (main_CTpostproc)
klMidStat    = "mean";              % same statistic as the contour bar
klMidContMethod = "contC40_60_contour";  % 2D-contour width at the same frames, t_arr = first C = 0.01
                                         % contour (a contour arrival); "" = no bar
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

%% 8f) KL by method WITHOUT the XCT BTC: one XCT profile / contour KL per experiment at theta = rsRot
% XCT 1D profile  : KL from the averaged-profile width W_40-60 (x-trimmed) of the frames at
%                   rotPos = rsRot (+/- rsTol) with the front centre (C = 0.5) at zD in rsZD,
%                   combined into ONE value per experiment (rsStat)
% XCT 2D contours : same frames, 2D-contour width W_40-60
% XCT MFM, UHS MFM: as section 8e
% Replaces the mid-profile KL of 8e. Figure 1: grouped bars per case; figure 2: M-Pe quadrants.
% The frames used are printed and saved (KL_byMethod_rot<rsRot>_frames_<ds>.xlsx); section 1d
% plot their profiles. Needs 5b for the UHS run swap (otherwise the configured UHS key is used).
 
% frame settings rsRot, rsTol, rsZD, rsPair, rsVar, rsStat: SETTINGS (same frame as the 8f-8h bars)
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
        if isempty(i), warning('8f: no experiment for %s', rsCases{c,1}); continue, end
        Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, rsVar, rsPair);
        if ~isempty(Tk)
            sel = rotZDsel(Tk, rsRot, rsTol, rsZD);
            Ts  = Tk(sel, :);
            nFr(c) = height(Ts);
            if nFr(c) == 0
                warning('8f: %s (%s) has no frame at theta = %g +/- %g with the centre in zD [%.2f %.2f]', ...
                    expKeys(i), ds, rsRot, rsTol, rsZD);
            else
                tDr(c) = sprintf('%.2f-%.2f', min(Ts.tDtotal), max(Ts.tDtotal));
                [KL(c,1), dKL(c,1)] = aggKL(Ts.("KL_prof_" + tagW17 + "_cm2min"), Ts.("dKL_prof_" + tagW17 + "_cm2min"), rsStat);
                TsC = Tk(rotZDselSrc(Tk, "cont", rsRot, rsTol, rsZD), :);    % contour frame: contour centre
                [KL(c,2), dKL(c,2)] = aggKL(TsC.("KL_cont_" + tagW17 + "_cm2min"), TsC.("dKL_cont_" + tagW17 + "_cm2min"), rsStat);
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
    fprintf('\n8f) KL [cm2/min] by method, XCT at theta = %g deg, centre zD %.2f-%.2f, W%s%s (%s):\n', ...
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

%% 8g) KL by method WITHOUT the XCT BTC and WITHOUT the 2D contours: XCT profile, XCT MFM, UHS MFM
% Same as 8f, three bars per case:
% XCT 1D profile  : KL from the averaged-profile width W_40-60 (x-trimmed) of the frames at
%                   rotPos = rsRot (+/- rsTol) with the front centre (C = 0.5) at zD in rsZD,
%                   combined into ONE value per experiment (rsStat)
% XCT MFM, UHS MFM: as section 8e
% Figure 1: grouped bars per case; figure 2: M-Pe quadrants. Files ..._noBTC_noCont_...
% Needs 5b for the UHS run swap (otherwise the configured UHS key is used).
 
% frame settings rsRot, rsTol, rsZD, rsPair, rsVar, rsStat: SETTINGS (same frame as the 8f-8h bars)
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
        if isempty(i), warning('8g: no experiment for %s', rsCases{c,1}); continue, end
        Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, rsVar, rsPair);
        if ~isempty(Tk)
            sel = rotZDsel(Tk, rsRot, rsTol, rsZD);
            Ts  = Tk(sel, :);
            nFr(c) = height(Ts);
            if nFr(c) == 0
                warning('8g: %s (%s) has no frame at theta = %g +/- %g with the centre in zD [%.2f %.2f]', ...
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
    fprintf('\n8g) KL [cm2/min] by method (no contours), XCT at theta = %g deg, centre zD %.2f-%.2f, W%s%s (%s):\n', ...
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

%% 8h) KL by method, XCT only (profile at theta = rsRot and XCT MFM), one figure per case
% Same as 8g without the UHS MFM bar, and every case saved as its own figure (no M / Pe title),
% to be arranged later in a 2 x 2 grid: low Pe bottom, high Pe top, low M left, high M right
% (the grid position is in the file name: ..._<row>-<col>_<case>, row 1 = top).
% All four figures share the same y-axis limits so the bars can be compared across the grid.
% Uses the frame selection of 8g (rotZDsel: theta = rsRot +/- rsTol, centre closest to zD = 0.5
% within rsZD) and mfmKL for the MFM KL.

% frame settings rsRot, rsTol, rsZD, rsPair, rsVar, rsStat: SETTINGS (same frame as the 8f-8h bars)
fs17e   = 20;                  % font size (ticks, labels, legend)
leg17e  = "all";               % legend: "all" figures | "first" (top-left only) | "none"
yLim17e = [];                  % common y limits; [] = 0 to 1.1 x max over the four cases
tagW17  = sprintf('%02d_%02d', round(100*rsPair));
srcNames17e = ["XCT 1D profile" + newline + sprintf("(\\theta = %d°)", rsRot), "XCT MFM"];   % 2-line legend entry
srcCols17e  = [0.85 0.33 0.10; 0.35 0.35 0.35];
% cases: {name, M token in key, Pe token in key, grid position [row col] (row 1 = top = high Pe)}
cases17e = {"XCT-loM-loPe", "P725", "Q1", [2 1]; ...
            "XCT-loM-hiPe", "P725", "Q5", [1 1]; ...
            "XCT-hiM-loPe", "P900", "Q1", [2 2]; ...
            "XCT-hiM-hiPe", "P900", "Q5", [1 2]};

for ds = "conc"
    nC = size(cases17e,1);  nS = numel(srcNames17e);
    KL = nan(nC,nS);  dKL = nan(nC,nS);  tDf = nan(nC,1);
    for c = 1:nC
        i = find(contains(expKeys, "_" + cases17e{c,2} + "_") & contains(expKeys, "_" + cases17e{c,3} + "_"), 1);
        if isempty(i), warning('8h: no experiment for %s', cases17e{c,1}); continue, end
        Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, rsVar, rsPair);
        if ~isempty(Tk)
            Ts = Tk(rotZDsel(Tk, rsRot, rsTol, rsZD), :);
            if height(Ts) > 0
                [KL(c,1), dKL(c,1)] = aggKL(Ts.("KL_prof_" + tagW17 + "_cm2min"), Ts.("dKL_prof_" + tagW17 + "_cm2min"), rsStat);
                tDf(c) = Ts.tDtotal(1);
            else
                warning('8h: %s (%s) has no frame at theta = %g +/- %g with the centre in zD [%.2f %.2f]', ...
                    expKeys(i), ds, rsRot, rsTol, rsZD);
            end
        end
        [KL(c,2), dKL(c,2)] = mfmKL(MFM_CT_DataAll{i}.(ds));
    end
    dKL(~isfinite(dKL)) = 0;
    caseNames = string(cases17e(:,1));
    T17e = table(caseNames, tDf, KL(:,1), dKL(:,1), KL(:,2), dKL(:,2), ...
        'VariableNames', {'case','tD_frame','KL_profile','dKL_profile','KL_MFM_XCT','dKL_MFM_XCT'});
    fprintf('\n8h) KL [cm2/min], XCT profile (theta = %g deg) and XCT MFM (%s):\n', rsRot, ds);
    disp(T17e)
    writetable(T17e, fullfile(exportPath, sprintf('KL_byMethod_rot%d_XCTonly_%s.xlsx', rsRot, ds)));

    yl = yLim17e;
    if isempty(yl)
        yMax = 1.1*max(KL(:) + dKL(:), [], 'omitnan');  if ~(isfinite(yMax) && yMax > 0), yMax = 1; end
        yl = [0 yMax];
    end

    for c = 1:nC
        pos = cases17e{c,4};
        fig = figure('Position',[100 100 850 550], 'NumberTitle','off', ...
            'Name', sprintf('KL by method, %s, theta = %d deg, XCT only (%s)', caseNames(c), rsRot, ds));
        ax = axes(fig);  hold(ax,'on')
        klBars(ax, KL(c,:), dKL(c,:), srcCols17e, srcNames17e, "", fs17e);
        set(ax, 'XTick', [], 'FontSize',fs17e, 'LabelFontSizeMultiplier',1);
        ylim(ax, yl);  ylabel(ax, 'K_L [cm^2/min]', 'FontSize',fs17e)
        if leg17e == "all" || (leg17e == "first" && isequal(pos, [1 1]))
            legend(ax, 'Location','northeast', 'FontSize',fs17e-4, 'Interpreter','tex')
        end
        saveFigBoth(fig, exportPath, sprintf('KL_byMethod_rot%d_XCTonly_%d-%d_%s_%s', rsRot, pos(1), pos(2), ...
            strrep(caseNames(c), '-', ''), ds), closeAfterSave)
    end
end
%% 9) Front tilt and shape diagnostics

for ds = dataSources
    fig = figure('Position',[100 100 650 2200]);
    panels = {char(tXcolC),'frontTiltSlope',   tXlbl,                        'front tilt slope [z_D/x_D]', 'Front tilt vs t_D', false; ...
              'rotPos', 'frontTiltSlope',      'rotation position [\circ]', 'front tilt slope [z_D/x_D]', 'Front tilt vs rotation position', false; ...
              char(tXcolC),'frontArcLengthRatio', tXlbl,                      'arc length ratio [-]',       'Front non-planarity vs t_D', true; ...
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
    saveFigBoth(fig, exportPath, sprintf('frontTiltShape_%s_%s', ds, tXtag), closeAfterSave)
end

%% 10) Front tilt vs rotation position, coloured by tD

for ds = dataSources
    fig = figure('Position',[100 100 1000 850]);
    tl = tiledlayout(fig, 'flow', 'TileSpacing','compact');

    for i = 1:nExp
        vars = expCTDataAll{i}.varsAll.(ds);
        ax = nexttile(tl);
        scatter(ax, vars.rotPos, vars.frontTiltSlope, 25, vars.(tXcolC), 'filled')   % contour tilt
        colormap(ax, parula);  clim(ax, tXlim)
        cb = colorbar(ax);  cb.Label.String = tXlbl;
        xlabel(ax,'rotation position [\circ]','FontSize',11)
        ylabel(ax,'front tilt slope [z_D/x_D]','FontSize',11)
        title(ax, expKeys(i), 'Interpreter','none','FontSize',11)
        grid(ax,'on');  xlim(ax,[0 360])
    end
    title(tl, sprintf('Front tilt vs rotation position, coloured by t_D (%s)', ds), 'Interpreter','none')
    saveFigBoth(fig, exportPath, sprintf('frontTilt_rotPos_%scolor_%s', tXtag, ds), closeAfterSave)
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
                tFitArr = fd.Vlinesbefore/fd.Q;                            % arrival of the fits
                if isfield(rs, 'tArr_fitKL_min') && isfinite(rs.tArr_fitKL_min), tFitArr = rs.tArr_fitKL_min; end
                tD_pts = (Sm.t_fit + tFitArr)*fd.Q / fd.Vtotal;           % back to tD_total
                if tAxis == "tDres"                                       % t_D,res, arrival of the source
                    if startsWith(nm, "width_"), tD_pts = tD_pts - rs.tD_arr_plot_cont;   % 2D contours
                    else,                        tD_pts = tD_pts - rs.tD_arr_plot_prof;   % profile (sigma, profW)
                    end
                end
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

    xlabel(tXlbl,'FontSize',14);  ylabel('K_L [cm^2/min]','FontSize',14)
    xlim(tXlim);  ylim([0 10]);  set(gca,'FontSize',14);  grid on
    legend('Interpreter','none','FontSize',7,'Location','best','NumColumns',2)
    title(sprintf('K_L: pointwise front (markers), BTC CT (--), MFM analog (:), MFM UHS (-.) (%s)', ds), ...
        'Interpreter','none','FontSize',10)
    saveFigBoth(fig, exportPath, sprintf('KL_compare_%s_%s', ds, tXtag), closeAfterSave)
end

%% 12) Outlet BTC width (t_D,total 16 - 84 %), one row per experiment
% Outlet = zD = 1 of the full image (BTCMetrics of main_CTpostproc). Section 12a: same in t_D,res.

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

%% 12a) Outlet BTC width (t_D,res 16 - 84 %), one row per experiment
% Same as 12, with the times shifted to t_D,res = t_D - t_D,arr (arrival tResRef, default C50 =
% time the front centre enters the rock; resultsAll.(ds).tD_arr_plot, set in the load block).
% Outlet = zD = 1 of the full image (BTCMetrics of main_CTpostproc, in t_D,total).
% Also printed / saved as a table (t_D,res at 16 / 50 / 84 % and the width 84 - 16).
for ds = dataSources
    fig = figure('Position',[100 100 1000 650]);  hold on
    yLabels = strings(nExp,1);  rows12a = {};
    for i = 1:nExp
        yLabels(i) = expName(i);
        if ~hasPost(i), continue, end
        rs = expCTDataAll{i}.resultsAll.(ds);
        if ~isfield(rs,'full') || ~isfield(rs.full,'BTCMetrics'), continue, end
        met = rs.full.BTCMetrics;
        if ~isstruct(met) || ~all(isfield(met, {'tD16','tD50','tD84'})), continue, end
        if ~isfield(rs, 'tD_arr_plot') || ~isfinite(rs.tD_arr_plot)
            warning('%s (%s): no t_D,arr (run the load block)', expKeys(i), ds);  continue
        end
        tA  = rs.tD_arr_plot;
        r16 = met.tD16 - tA;  r50 = met.tD50 - tA;  r84 = met.tD84 - tA;
        plot([r16 r84], [i i], '-', 'Color',[expCol(i,:) 0.8], 'LineWidth',3, 'HandleVisibility','off')
        scatter(r50, i, 40, 0.6*expCol(i,:), 'filled', 'DisplayName', expName(i))
        rows12a{end+1,1} = table(expName(i), string(rs.tArr_plot_ref), tA, r16, r50, r84, r84 - r16, ...
            'VariableNames', {'experiment','t_arr_ref','tD_arr','tDres16','tDres50','tDres84','width_16_84'}); %#ok<SAGROW>
    end
    xlabel('t_{D,res} [-]','FontSize',14);  ylabel('Experiment','FontSize',14)
    set(gca,'FontSize',14, 'TickLabelInterpreter','none')
    yticks(1:nExp);  yticklabels(yLabels);  ylim([0.5, nExp+0.5]);  xlim([0 1]);  grid on
    title(sprintf('Outlet BTC width (16-84%%), centred on t_{D,res} at 50%% (%s, t_{arr}: %s)', ds, tResRef), ...
        'Interpreter','tex')
    saveFigBoth(fig, exportPath, sprintf('BTCwidth_outlet_%s_%s', ds, tXtagRes(tResRef)), closeAfterSave)
    if ~isempty(rows12a)
        T12a = vertcat(rows12a{:});
        fprintf('\n12a) Outlet BTC in t_D,res (%s, t_arr %s):\n', ds, tResRef);  disp(T12a)
        writetable(T12a, fullfile(exportPath, sprintf('BTCwidth_outlet_%s_%s.xlsx', ds, tXtagRes(tResRef))));
    end
end

%% 13) Sweep, displacement and recovery efficiencies vs tD (all experiments together)

CeffLevels = 0.1:0.1:0.9;     % thresholds C* (all traced in main_CTpreproc)   % thresholds C* (must be among Clevels in main_CTpreproc)
effVariant = "";              % "" = full image, "_xtrim" = x-trimmed image
effXVar    = char(tXcolC);    % x-axis (tAxis, contour arrival: thresholds of the image = contours)
effXLabel  = tXlbl;
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
            sprintf('efficiencies_C%s_allExp_%s%s_%s', tag, ds, effVariant, tTagOf(effXVar)), closeAfterSave)
    end
end

%% 14) rhoNorm vs conc BTC at each zD: left = lower Q, right = higher Q, both pressures superposed

zDcompare  = 0:0.1:1.0;
cmpVariant = "";            % "" = full x-range, "_xtrim" = x-trimmed columns
cmpXVar    = char(tXcol);   % x-axis (tAxis); or 'tD_corr_lines', 'tD_corr_contour_scaled'
cmpXLabel  = tXlbl;
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
        cmpVariant, tTagOf(cmpXVar)), closeAfterSave)
end

%% 14a) Flow capacity vs storage capacity (F-Phi) from the BTC at several zD, and predicted sweep vs measured

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
% tau = t - t_arr (tResRef arrival, same origin as the t_D,res axis; see klAllFrames).
% Filled circles = averaged profile (zDWidthProf_40_60_xtrim), open squares = 2D contours
% (zDWidth_40_60_xtrim); error bars dKL (slice spacing + frame interval, see KL_allProfileWidths).
% Frames just after arrival (small tau) give very large, uncertain KL -> log y-axis by default.
 
klfPair  = [0.40 0.60];        % level pair of the width
klfVar   = "_xtrim";           % "_xtrim" or "" (full image)
klfXVar  = tXkl;               % profile KL: "tauD" (t_D,res, profile arrival) or "tDtotal"
klfXVarC = tXklC;              % contour KL: "tauD_cont" (t_D,res, contour arrival) or "tDtotal"
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
        x  = Tk.(klfXVar);  xC = Tk.(klfXVarC);             % each source on its own t_D,res
        yP = Tk.("KL_prof_" + tagW15 + "_cm2min");  dP = Tk.("dKL_prof_" + tagW15 + "_cm2min");
        yC = Tk.("KL_cont_" + tagW15 + "_cm2min");  dC = Tk.("dKL_cont_" + tagW15 + "_cm2min");
        okP = isfinite(x)  & isfinite(yP) & yP > 0;
        okC = isfinite(xC) & isfinite(yC) & yC > 0;
        cLt = 0.5*expCol(i,:) + 0.5;                        % lighter colour for the error bars
        % if klfErr
        %     errorbar(ax, x(okP), yP(okP), min(dP(okP), 0.99*yP(okP)), dP(okP), 'LineStyle','none', ...
        %         'Color',cLt, 'HandleVisibility','off')
        %     errorbar(ax, xC(okC), yC(okC), min(dC(okC), 0.99*yC(okC)), dC(okC), 'LineStyle','none', ...
        %         'Color',cLt, 'HandleVisibility','off')
        % end
        if any(okP)
            h(end+1) = scatter(ax, x(okP), yP(okP), mk15, expCol(i,:), 'o', 'filled', ...
                'MarkerEdgeColor',0.6*expCol(i,:), 'DisplayName', expName(i)); %#ok<SAGROW>
        end
        % if any(okC)
        %     h(end+1) = scatter(ax, xC(okC), yC(okC), mk15, expCol(i,:), 's', 'LineWidth',1.5, ...
        %         'DisplayName', expName(i) + ", contours"); %#ok<SAGROW>
        % end
    end
    if isempty(h), close(fig); continue, end
    set(ax, 'FontSize',fs15, 'LabelFontSizeMultiplier',1);  grid(ax,'on');  box(ax,'on')
    if klfLogY, set(ax, 'YScale','log'); end
    if ~isempty(klfYLim), ylim(ax, klfYLim); end
    if klfXVar == "tauD", xlabel(ax, 't_{D,res} [-]', 'FontSize',fs15)
    else,                 xlabel(ax, 't_D [-]', 'FontSize',fs15); end
    ylabel(ax, sprintf('K_L from W_{%d-%d} [cm^2/min]', round(100*klfPair)), 'FontSize',fs15)
    legend(ax, h, 'Location','northeast', 'FontSize',fs15-4, 'NumColumns',1, 'Interpreter','none')
    saveFigBoth(fig, exportPath, sprintf('KL_vs_%s_W%s_profile_contour_%s%s', tTagOf(klfXVar), tagW15, ds, klfVar), closeAfterSave)
end

%% 15b) KL vs tD from the 40-60 profile width of every frame, with the KL-by-method value (section 8f / 8g)
% Same as section 15 (profile only), plus, per experiment, the bar value of the XCT 1D-profile KL
% of section 8f / 8g (the frame at rotPos = rsRot +/- rsTol with the front centre closest to
% zD = 0.5 within rsZD) as a red open circle, drawn on top of all dots. Dots semi-transparent.
% Legend (top right): one entry per experiment + one red circle "theta = rsRot". Format as 7c / 7d.
% Uses the settings of section 8f (rsRot, rsTol, rsZD, rsPair, rsVar, rsStat): run it first,
% or the defaults below are used.

% frame settings rsRot, rsTol, rsZD, rsPair, rsVar, rsStat: SETTINGS (same frame as the 8f-8h bars)
klfPair  = rsPair;             % level pair of the width (same as the bar)
klfVar   = rsVar;              % "_xtrim" or "" (same as the bar)
klfXVar  = tXkl;               % from tAxis: "tauD" (t_D,res) or "tDtotal" (t_D,total)
klfLogY  = false;              % log K_L axis
klfYLim  = [];                 % [] = auto, e.g. [0 2]
klfXLim  = [0 0.8];            % x-axis limits ([] = auto)
klfErr   = false;              % error bars on the per-frame points
fs15Ax   = 20;                 % font size: tick labels
fs15Lbl  = 24;                 % font size: axis labels
fs15Leg  = 20;                 % font size: legend
mk15     = 120;                 % marker size (dots and red circle)
alpha15  = 0.5;                % face transparency of the dots (1 = opaque, 0 = invisible)
legMk15  = 12;                 % marker size in the legend [points]
colBar   = [0.85 0 0];         % colour of the red circle
tagW15   = sprintf('%02d_%02d', round(100*klfPair));

for ds = "conc"
    figName = sprintf('KL vs t_D from W%s per frame, with the KL-by-method value at theta = %d deg (%s%s)', ...
        tagW15, rsRot, ds, klfVar);
    fig = figure('Position',[100 100 1000 650], 'Name',figName, 'NumberTitle','off');
    ax  = axes(fig);  hold(ax,'on')
    hLeg = gobjects(0);  hBar = gobjects(0);  hRed = gobjects(0);  rows15b = {};

    for i = 1:nExp
        Tk = klAllFrames(expCTDataAll{i}, filedataExpAll{i}, hasPost(i), ds, klfVar, klfPair);
        if isempty(Tk), continue, end
        x  = Tk.(klfXVar);
        yP = Tk.("KL_prof_" + tagW15 + "_cm2min");  dP = Tk.("dKL_prof_" + tagW15 + "_cm2min");
        okP = isfinite(x) & isfinite(yP) & yP > 0;
        if ~any(okP), continue, end
        if klfErr
            errorbar(ax, x(okP), yP(okP), min(dP(okP), 0.99*yP(okP)), dP(okP), 'LineStyle','none', ...
                'Color',0.5*expCol(i,:) + 0.5, 'HandleVisibility','off')
        end
        scatter(ax, x(okP), yP(okP), mk15, expCol(i,:), 'o', 'filled', ...
            'MarkerEdgeColor',0.6*expCol(i,:), 'LineWidth',0.5, ...
            'MarkerFaceAlpha',alpha15, 'MarkerEdgeAlpha',min(1, alpha15 + 0.3), ...
            'HandleVisibility','off')
        % legend entry: invisible larger marker (scatter legend icons stay small)
        hLeg(end+1) = plot(ax, NaN, NaN, 'o', 'LineStyle','none', 'MarkerSize',legMk15, ...
            'MarkerFaceColor',expCol(i,:), 'MarkerEdgeColor',0.6*expCol(i,:), 'DisplayName', expName(i)); %#ok<SAGROW>

        % frame of the KL-by-method bar and its value (same selection and statistic as 8f / 8g)
        sel = rotZDsel(Tk, rsRot, rsTol, rsZD) & okP;
        if ~any(sel), continue, end
        [KLb, dKLb] = aggKL(yP(sel), dP(sel), rsStat);
        xb = mean(x(sel));
        hRed(end+1) = scatter(ax, xb, KLb, mk15, 'o', 'MarkerEdgeColor',colBar, 'MarkerFaceColor','none', ...
            'LineWidth',2.5, 'HandleVisibility','off'); %#ok<SAGROW>
        if isempty(hBar)                                     % one legend entry for all red circles
            hBar = plot(ax, NaN, NaN, 'o', 'LineStyle','none', 'MarkerSize',legMk15, ...
                'MarkerEdgeColor',colBar, 'MarkerFaceColor','none', 'LineWidth',2.5, ...
                'DisplayName', sprintf('\\theta = %d°', rsRot));
        end
        rows15b{end+1,1} = table(expName(i), nnz(sel), xb, KLb, dKLb, ...
            'VariableNames', {'experiment','nFrames', char(klfXVar), 'KL_bar_cm2min', 'dKL_bar_cm2min'}); %#ok<SAGROW>
    end
    if ~isempty(hRed), uistack(hRed, 'top'); end        % red circles above all dots
    if isempty(hLeg), close(fig); continue, end

    set(ax, 'FontSize',fs15Ax, 'LabelFontSizeMultiplier',1, 'TitleFontSizeMultiplier',1)
    if klfLogY, set(ax, 'YScale','log'); end
    if ~isempty(klfYLim), ylim(ax, klfYLim); end
    if ~isempty(klfXLim), xlim(ax, klfXLim); end
    if klfXVar == "tauD", xlabel(ax, 't_{D,res} [-]', 'FontSize',fs15Lbl)
    else,                 xlabel(ax, 't_D [-]', 'FontSize',fs15Lbl); end
    ylabel(ax, sprintf('K_L from W_{%d-%d}, profile [cm^2/min]', round(100*klfPair)), 'FontSize',fs15Lbl)
    grid(ax,'on');  box(ax,'on')
    legend(ax, [hLeg hBar], 'Location','northeast', 'FontSize',fs15Leg, 'Interpreter','tex')
    if ~isempty(rows15b)
        fprintf('\n15b) KL-by-method value (profile, theta = %g deg, centre zD closest to 0.5 in %.2f-%.2f) per experiment:\n', ...
            rsRot, rsZD);
        disp(vertcat(rows15b{:}))
    end
    saveFigBoth(fig, exportPath, sprintf('KL_vs_%s_W%s_profile_rot%d_bar_%s%s', tTagOf(klfXVar), tagW15, rsRot, ds, klfVar), closeAfterSave)
end
%% 15c) KL vs rotation position from the 40-60 profile width of every frame, with the KL-by-method value
% Same as section 15b, but x = rotation position theta [deg] instead of t_D: every frame's KL from
% the averaged-profile width (filled dots, one colour per experiment) and, per experiment, the bar
% value of the XCT 1D-profile KL of section 8f (rsStat of the frames at theta = rsRot +/- rsTol
% with the front centre at zD in rsZD) as a red open circle at theta = rsRot.
% Legend: one entry per experiment + one red circle "theta = rsRot".
% Uses the settings of section 8f (rsRot, rsTol, rsZD, rsPair, rsVar, rsStat): run it first,
% or the defaults below are used.

% frame settings rsRot, rsTol, rsZD, rsPair, rsVar, rsStat: SETTINGS (same frame as the 8f-8h bars)
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

        % frames of the KL-by-method bar and the bar value (same selection and statistic as 8f / 8g)
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
% (t_arr = tResRef arrival via klAllFrames, as section 15). The ADE first term gives W = 2 k sqrt(KL tau): a
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
        % each source with its own arrival (tau) and front centre (frame window)
        src = {"profile",  Tk.("W_prof_" + tagW16 + "_cm"), 'o', true,  Tk.tau_min,      Tk.zD_center_C50; ...
               "contours", Tk.("W_cont_" + tagW16 + "_cm"), 's', false, Tk.tau_cont_min, Tk.zD_center_cont};
        for s = 1:size(src,1)
            W  = src{s,2};  tau = src{s,5};  zcS = src{s,6};
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
            okF = ok & zcS >= mlZDr(1) & zcS <= mlZDr(2);
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

%% 17) Similarity plot at theta = rsRot: C vs (z_D - t_D,res)/sqrt(t_D,res), with the ADE solution
% For a 1D ADE front moving at velocity v with dispersion KL (step injection, first term):
%   C(z, t) = 0.5 erfc( (z - v tau) / (2 sqrt(KL tau)) ),  tau = t - t0
% In units of the image length L_img (z_D = z / L_img, t_D,res = v tau / L_img, Pe = v L_img / KL):
%   C = 0.5 erfc( eta sqrt(Pe) / 2 ),   eta = (z_D - t_D,res) / sqrt(t_D,res)
% so every profile of one experiment collapses onto ONE curve of eta whose steepness is set by Pe.
% A profile that does not collapse (wider at early / late times) means the width does not grow
% as sqrt(t), i.e. not Fickian.
%   v, t0     : straight line through the front centres (zDFrontProf50, fallback zDFront50) with the
%               centre in ssZDc -> t_D,res = v (t - t0)/L_img  (t_D,res = 0 when the centre crosses z_D = 0)
%               (own fit: NOT the tD_res column of the load block, which is Q t / V_total based)
%   profiles  : every frame at theta = ssRot +/- ssTol with the centre in ssZDc, averaged x-trimmed
%               profile, normalized Cn = (C - Ci)/(Cj - Ci)
%   theory    : solid  = KL of the theta = ssRot bar (section 8f, profile W_40-60, rotZDsel frame)
%               dotted = KL of the XCT MFM (ssTheoryMFM)
% ssScaled = true: x = eta sqrt(Pe)/2 with the bar Pe -> all experiments on the single curve 0.5 erfc(x)
% Figures: one per experiment (profiles coloured by t_D) + all experiments together.

ssRot       = rsRot;          % rotation position [deg] (SETTINGS)
ssTol       = rsTol;          % tolerance [deg] (SETTINGS)
ssVar       = "_xtrim";       % "" = full image | "_xtrim" = x-trimmed
ssZDc       = [0.1 0.9];      % front-centre zD range: frames plotted and centres used for v, t0
ssPair      = rsPair;         % width of the KL bar (SETTINGS, as 8g)
ssRotZD     = rsZD;           % zD window of the bar frame (SETTINGS, as 8g)
ssScaled    = false;          % false: x = eta (theory differs per experiment); true: eta sqrt(Pe)/2
ssTheoryMFM = true;           % also the ADE curve with the MFM KL (dotted)
ssXLim      = [];             % [] = auto (eta: [-1.5 1.5]; scaled: [-3 3])
ssTrim      = 0.02;           % fraction of the core left out at each end of every profile
fs19Ax = 20;  fs19Lbl = 24;  fs19Leg = 16;  lw19 = 1.5;

if isempty(ssXLim), if ssScaled, ssXLim = [-3 3]; else, ssXLim = [-1.5 1.5]; end, end
if ssScaled, xLbl19 = '\eta \surd{Pe} / 2 = (z_D - t_{D,res}) / (2 \surd{t_{D,res}/Pe})  [-]';
else,        xLbl19 = '\eta = (z_D - t_{D,res}) / \surd{t_{D,res}}  [-]'; end
tagW19 = sprintf('%02d_%02d', round(100*ssPair));

for ds = "conc"
    allExp = {};  rows19 = {};
    for i = 1:nExp
        vars = expCTDataAll{i}.varsAll.(ds);
        vn   = string(vars.Properties.VariableNames);
        fd   = filedataExpAll{i};
        Ci = fd.C1init/100;  Cj = fd.C1j/100;
        t  = vars.secondsElapsed/60;                              % [min]
        cen = nan(height(vars),1);
        if ismember("zDFrontProfC50" + ssVar, vn), cen = vars.("zDFrontProfC50" + ssVar); end   % profile C = 0.5 crossing
        if ismember("zDFrontProf50" + ssVar, vn)                                              % fallback: erfc centre
            miss = ~isfinite(cen);  cen(miss) = vars.("zDFrontProf50" + ssVar)(miss);
        end

        % front velocity and time origin from the centres: z_D,c = b (t - t0)
        okc = isfinite(t) & isfinite(cen) & cen >= ssZDc(1) & cen <= ssZDc(2);
        if nnz(okc) < 3, warning('17: %s: too few front centres', expKeys(i)); continue, end
        p  = polyfit(t(okc), cen(okc), 1);   b = p(1);   t0 = -p(2)/p(1);
        tauD = b*(t - t0);                                         % t_D,res [-] (image length)

        % frames at theta = ssRot with the centre inside ssZDc
        dAng = abs(mod(vars.rotPos - ssRot + 180, 360) - 180);
        fr   = find(dAng <= ssTol & tauD > 0 & okc);
        if isempty(fr), warning('17: %s: no frame at theta = %g deg', expKeys(i), ssRot); continue, end
        pr1  = cellRow(vars.C1Profile, fr(1));  if iscell(pr1), pr1 = pr1{1}; end
        Limg = max(pr1.zVertcm);                                   % [cm]
        v    = b*Limg;                                             % [cm/min]

        % KL of the bar (theta = ssRot frame, profile W_40-60) and of the XCT MFM -> Pe = v L_img / KL
        KLb = NaN;
        Tk = klAllFrames(expCTDataAll{i}, fd, hasPost(i), ds, ssVar, ssPair);
        if ~isempty(Tk)
            sk = rotZDsel(Tk, ssRot, ssTol, ssRotZD);
            if any(sk), KLb = Tk.("KL_prof_" + tagW19 + "_cm2min")(find(sk,1)); end
        end
        KLm = NaN;
        mCT = MFM_CT_DataAll{i}.(ds);
        if ~isempty(mCT) && isfield(mCT, 'results'), KLm = firstNum(mCT.results, {'KL_cm2min'}); end
        PeB = v*Limg/KLb;  PeM = v*Limg/KLm;

        % profiles in the similarity variable
        prf = struct('x',{},'C',{},'tD',{});
        for l = fr(:)'
            pr = cellRow(vars.C1Profile, l);  if iscell(pr), pr = pr{1}; end
            zD = pr.zDimLess(:);  Cn = (pr.("CVert" + ssVar)(:) - Ci)/(Cj - Ci);
            keep = isfinite(zD) & isfinite(Cn) & zD >= ssTrim & zD <= 1 - ssTrim;
            eta  = (zD(keep) - tauD(l))/sqrt(tauD(l));
            x = eta;  if ssScaled, x = eta*sqrt(PeB)/2; end
            prf(end+1) = struct('x',x, 'C',Cn(keep), 'tD',vars.(tXcol)(l)); %#ok<SAGROW>
        end
        allExp{end+1} = struct('i',i, 'prf',prf, 'PeB',PeB, 'PeM',PeM); %#ok<SAGROW>
        rows19{end+1,1} = table(expName(i), numel(fr), b, v, t0, Limg, KLb, PeB, KLm, PeM, ...
            'VariableNames', {'experiment','nFrames','b_zD_per_min','v_front_cmmin','t0_min','L_img_cm', ...
            'KL_bar_cm2min','Pe_bar','KL_MFM_cm2min','Pe_MFM'}); %#ok<SAGROW>

        % ---- one figure per experiment: profiles coloured by t_D + ADE curves
        fig = figure('Position',[100 100 1000 650], 'NumberTitle','off', 'Name', ...
            sprintf('%s: similarity plot at theta = %d deg (%s%s)', expName(i), ssRot, ds, ssVar));
        ax = axes(fig);  hold(ax,'on')
        tDs = [prf.tD];  cmap = parula(256);
        tDl = [min(tDs) max(tDs)];  if diff(tDl) <= 0, tDl = tDl + [-0.05 0.05]; end
        for q = 1:numel(prf)
            cq = interp1(linspace(tDl(1), tDl(2), 256), cmap, prf(q).tD);
            plot(ax, prf(q).x, prf(q).C, '-', 'Color',cq, 'LineWidth',lw19, 'HandleVisibility','off')
        end
        colormap(ax, cmap);  clim(ax, tDl);  cb = colorbar(ax);
        cb.Label.String = tXlbl;  cb.FontSize = fs19Ax;  cb.Label.FontSize = fs19Lbl;
        xs = linspace(ssXLim(1), ssXLim(2), 400);
        if ssScaled, yB = 0.5*erfc(xs); else, yB = 0.5*erfc(xs*sqrt(PeB)/2); end
        hB = plot(ax, xs, yB, 'k-', 'LineWidth',3, 'DisplayName', ...
            sprintf('ADE, K_L(\\theta = %d°) = %.3g cm^2/min (Pe = %.3g)', ssRot, KLb, PeB));
        hT = hB;
        if ssTheoryMFM && isfinite(PeM)
            if ssScaled, yM = 0.5*erfc(xs*sqrt(PeM/PeB)); else, yM = 0.5*erfc(xs*sqrt(PeM)/2); end
            hT(end+1) = plot(ax, xs, yM, 'k:', 'LineWidth',3, 'DisplayName', ...
                sprintf('ADE, K_L MFM = %.3g cm^2/min (Pe = %.3g)', KLm, PeM));
        end
        set(ax, 'FontSize',fs19Ax, 'LabelFontSizeMultiplier',1);  grid(ax,'on');  box(ax,'on')
        xlabel(ax, xLbl19, 'FontSize',fs19Lbl);  ylabel(ax, 'C_D [-]', 'FontSize',fs19Lbl)
        xlim(ax, ssXLim);  ylim(ax, [-0.02 1.02])
        legend(ax, hT, 'Location','northeast', 'FontSize',fs19Leg, 'Interpreter','tex')
        saveFigBoth(fig, exportPath, sprintf('similarity_rot%d_%s_%s%s%s', ssRot, expKeys(i), ds, ssVar, ...
            ternaryStr(ssScaled, "_scaled", "")), closeAfterSave)
    end
    if isempty(allExp), continue, end
    T19 = vertcat(rows19{:});
    fprintf('\n17) Similarity plot at theta = %g deg (%s%s): front velocity, time origin and Pe of the ADE curves:\n', ...
        ssRot, ds, ssVar);
    disp(T19)

    % ---- all experiments together
    fig = figure('Position',[100 100 1000 650], 'NumberTitle','off', 'Name', ...
        sprintf('Similarity plot at theta = %d deg, all experiments (%s%s)', ssRot, ds, ssVar));
    ax = axes(fig);  hold(ax,'on');  hL = gobjects(0);
    xs = linspace(ssXLim(1), ssXLim(2), 400);
    for e = 1:numel(allExp)
        E = allExp{e};  i = E.i;
        for q = 1:numel(E.prf)
            plot(ax, E.prf(q).x, E.prf(q).C, '-', 'Color',[expCol(i,:) 0.5], 'LineWidth',lw19, 'HandleVisibility','off')
        end
        hL(end+1) = plot(ax, NaN, NaN, '-', 'Color',expCol(i,:), 'LineWidth',3, 'DisplayName', expName(i)); %#ok<SAGROW>
        if ~ssScaled                                           % one ADE curve per experiment
            plot(ax, xs, 0.5*erfc(xs*sqrt(E.PeB)/2), '--', 'Color',0.6*expCol(i,:), 'LineWidth',2.5, ...
                'HandleVisibility','off')
        end
    end
    if ssScaled
        hL(end+1) = plot(ax, xs, 0.5*erfc(xs), 'k-', 'LineWidth',3, 'DisplayName','ADE: 0.5 erfc(x)');
    else
        hL(end+1) = plot(ax, NaN, NaN, '--', 'Color',[0.3 0.3 0.3], 'LineWidth',2.5, ...
            'DisplayName', sprintf('ADE, K_L(\\theta = %d°)', ssRot));
    end
    set(ax, 'FontSize',fs19Ax, 'LabelFontSizeMultiplier',1);  grid(ax,'on');  box(ax,'on')
    xlabel(ax, xLbl19, 'FontSize',fs19Lbl);  ylabel(ax, 'C_D [-]', 'FontSize',fs19Lbl)
    xlim(ax, ssXLim);  ylim(ax, [-0.02 1.02])
    legend(ax, hL, 'Location','northeast', 'FontSize',fs19Leg, 'Interpreter','tex')
    saveFigBoth(fig, exportPath, sprintf('similarity_rot%d_allExp_%s%s%s', ssRot, ds, ssVar, ...
        ternaryStr(ssScaled, "_scaled", "")), closeAfterSave)
end
%% Local functions

function tag = tTagOf(col)
% short time-axis tag for file names: tDtotal -> "tD", tD_res / tauD -> "tDres"
switch string(col)
    case "tDtotal",                             tag = "tD";
    case {"tD_res","tD_res_prof","tD_res_cont","tauD","tauD_cont"}, tag = "tDres";
    case "tD_corr_contour",                     tag = "tDres_contour";
    otherwise,                                  tag = string(col);
end
end

function [tArr, src] = arrivalTime(ctData, fd, ds, ref, lvlSrc, lvl, fitKind)
% arrival time [min] of one experiment / data source / SOURCE (lvlSrc = "profile" | "contour"):
%   "levels"  t0 of level lvl of that source's level trajectories (resultsAll.(ds).arrLevels.(lvlSrc) of
%             main_CTpostproc): fitKind "curve" (per-level ADE form) | "line" | "t0s" (joint two-origin)
%   "C50"     t0 = -b/v of that source's C = 0.5 centre line: contour = vFront (main_CTpreproc),
%             profile = vFrontProf.xtrim (main_CTpostproc, fallback t0_C50prof_min)
%   "contour" first C = 0.01 contour (resultsAll.(ds).tD_arrival_contour), both sources
%   "lines"   line volume before the core / Q, both sources
% fallback: levels -> C50 -> contour -> lines (with a warning); src = arrival actually used
if nargin < 5 || isempty(lvlSrc),  lvlSrc  = "profile"; end
if nargin < 6 || isempty(lvl),     lvl     = 0.01; end
if nargin < 7 || isempty(fitKind), fitKind = "curve"; end
ref = string(ref);  lvlSrc = string(lvlSrc);
tL  = fd.Vlinesbefore/fd.Q;  tC = NaN;  t50 = NaN;  tLv = NaN;
rA  = struct();
if isfield(ctData, 'resultsAll') && isfield(ctData.resultsAll, ds), rA = ctData.resultsAll.(ds); end
if isfield(rA, 'tD_arrival_contour') && isfinite(rA.tD_arrival_contour)
    tC = rA.tD_arrival_contour*fd.Vtotal/fd.Q;
end
if lvlSrc == "contour"
    if isfield(rA, 'vFront') && isstruct(rA.vFront) && isfinite(rA.vFront.v_front_cmmin) && rA.vFront.v_front_cmmin > 0
        t50 = -rA.vFront.intercept_cm/rA.vFront.v_front_cmmin;
    elseif isfield(rA, 't0_C50line_min'), t50 = rA.t0_C50line_min;
    end
else
    if isfield(rA, 'vFrontProf') && isfield(rA.vFrontProf, 'xtrim'), t50 = rA.vFrontProf.xtrim.t0_min;
    elseif isfield(rA, 't0_C50prof_min'), t50 = rA.t0_C50prof_min;
    end
end
if isfield(rA, 'arrLevels') && isfield(rA.arrLevels, lvlSrc)
    A  = rA.arrLevels.(lvlSrc);
    rL = A.perLevel(abs(A.perLevel.C - lvl) < 1e-9, :);
    switch string(fitKind)
        case "curve", if height(rL) > 0, tLv = rL.t0_curve_min(1); end
        case "line",  if height(rL) > 0, tLv = rL.t0_line_min(1);  end
        case "t0s",   tLv = A.joint.t0s_joint2(1);
    end
end
lvTag = "levels_" + lvlSrc + "_" + string(fitKind) + sprintf("_C%02d", round(100*lvl));
switch ref
    case "levels",  tArr = tLv;  src = lvTag;
    case "C50",     tArr = t50;  src = "C50_" + lvlSrc;
    case "contour", tArr = tC;   src = "contour";
    case "lines",   tArr = tL;   src = "lines";
    otherwise,      error('arrivalTime: unknown reference "%s" (levels | C50 | contour | lines)', ref);
end
if ~isfinite(tArr) && startsWith(src, "levels")
    warning('%s (%s, %s): no level arrival (run main_CTpostproc with arrivalLevels) -> C50 line', fd.Key, ds, lvlSrc);
    tArr = t50;  src = "C50_" + lvlSrc;
end
if ~isfinite(tArr) && startsWith(src, "C50")
    warning('%s (%s, %s): no C = 0.5 centre line -> contour arrival', fd.Key, ds, lvlSrc);
    tArr = tC;  src = "contour";
end
if ~isfinite(tArr) && src == "contour"
    warning('%s (%s): no contour arrival -> line volume', fd.Key, ds);
    tArr = tL;  src = "lines";
end
end

function L = centreLine(rA, lvlSrc)
% C = 0.5 centre line z = v (t - t0) of one source (profile / contour), never mixed:
%   1) the C = 0.5 row of resultsAll.(ds).arrLevels.(lvlSrc).perLevel (x-trimmed straight line)
%   2) fallback: contour = vFront (main_CTpreproc, full image); profile = vFrontProf.xtrim (main_CTpostproc)
L = struct('v',NaN, 't0',NaN, 'src',"none");
lvlSrc = string(lvlSrc);
if isfield(rA, 'arrLevels') && isfield(rA.arrLevels, lvlSrc)
    P = rA.arrLevels.(lvlSrc).perLevel;  r = P(abs(P.C - 0.5) < 1e-9, :);
    if height(r) > 0 && isfinite(r.v_line_cmmin(1)) && r.v_line_cmmin(1) > 0
        L = struct('v',r.v_line_cmmin(1), 't0',r.t0_line_min(1), 'src',"arrLevels_" + lvlSrc + "_C50");  return
    end
end
if lvlSrc == "contour" && isfield(rA, 'vFront') && isstruct(rA.vFront) && rA.vFront.v_front_cmmin > 0
    L = struct('v',rA.vFront.v_front_cmmin, 't0',-rA.vFront.intercept_cm/rA.vFront.v_front_cmmin, 'src',"vFront");
elseif lvlSrc == "profile" && isfield(rA, 'vFrontProf') && isfield(rA.vFrontProf, 'xtrim') && rA.vFrontProf.xtrim.v_front_cmmin > 0
    L = struct('v',rA.vFrontProf.xtrim.v_front_cmmin, 't0',rA.vFrontProf.xtrim.t0_min, 'src',"vFrontProf_xtrim");
end
end

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
% KL per frame from the width of the level pair (KL_allProfileWidths), KL = W^2/(4 k^2 tau), with
% each source on its OWN arrival (never mixed):
%   profile  columns (KL_prof_*, tau_min, tauD, tD_arrival, zD_center_C50 = profile C = 0.5 crossing):
%            tau = t - resultsAll.(ds).tArr_plot_prof_min (profile arrival of the load block)
%   contour  columns (KL_cont_*, dKL_cont_*, tau_cont_min, tauD_cont, tD_arrival_cont,
%            zD_center_cont = C = 0.5 contour centre): tau = t - tArr_plot_cont_min (contour arrival)
% Fallback for both: tArr_plot_min -> tArr_profKL_min (main_CTpostproc) -> line volume.
Tk = table();
vars = ctData.varsAll.(ds);
tag  = sprintf('%02d_%02d', round(100*pair));
if ~ismember("zDWidthProf_" + tag + variant + "_cm", string(vars.Properties.VariableNames))
    warning('klAllFrames: zDWidthProf_%s%s_cm missing for %s -- run main_CTpostproc first', tag, variant, fd.Key);
    return
end
tP = fd.Vlinesbefore/fd.Q;  rs = struct();
if isfield(ctData, 'resultsAll') && isfield(ctData.resultsAll, ds), rs = ctData.resultsAll.(ds); end
if isfield(rs, 'tArr_plot_prof_min') && isfinite(rs.tArr_plot_prof_min), tP = rs.tArr_plot_prof_min;
elseif isfield(rs, 'tArr_plot_min') && isfinite(rs.tArr_plot_min),      tP = rs.tArr_plot_min;
elseif hasPostI && isfield(rs, 'tArr_profKL_min') && isfinite(rs.tArr_profKL_min), tP = rs.tArr_profKL_min;
end
tC = tP;
if isfield(rs, 'tArr_plot_cont_min') && isfinite(rs.tArr_plot_cont_min), tC = rs.tArr_plot_cont_min; end
Tk = KL_allProfileWidths(vars, variant, pair, tP, tP*fd.Q/fd.Vtotal);             % profile arrival
Tc = KL_allProfileWidths(vars, variant, pair, tC, tC*fd.Q/fd.Vtotal);             % contour arrival
if ~isequal(Tk.frame, Tc.frame), error('klAllFrames: frames of the two arrivals differ (%s)', fd.Key); end
for c_ = ["KL_cont_" + tag + "_cm2min", "dKL_cont_" + tag + "_cm2min"]
    Tk.(c_) = Tc.(c_);                                                             % contour KL, contour tau
end
Tk.tau_cont_min    = Tc.tau_min;
Tk.tauD_cont       = Tc.tauD;
Tk.tD_arrival_cont = Tc.tD_arrival;
zcC = nan(height(vars),1);
if ismember("zDFront50" + variant, string(vars.Properties.VariableNames)), zcC = vars.("zDFront50" + variant); end
Tk.zD_center_cont  = zcC(Tk.frame);
end

function sel = rotZDselSrc(Tk, src, rot, tol, zDr, z0)
% rotZDsel with the front centre of one source: src = "prof" (zD_center_C50, profile crossing) |
% "cont" (zD_center_cont, C = 0.5 contour)
if nargin < 6, z0 = []; end
if src == "cont" && ismember('zD_center_cont', Tk.Properties.VariableNames)
    Tk.zD_center_C50 = Tk.zD_center_cont;
end
sel = rotZDsel(Tk, rot, tol, zDr, z0);
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

function [KL, dKL, M, Pe] = mfmKL(m)
% KL +/- total uncertainty (best method of main_Processing) of one MFM experiment, and
% M = mu2/mu1 from REFPROP at the NOMINAL T and P (exp_params.T_C, P_psig; as main_DataExtract
% but not at the run-average MFM temperature), Pe = exp_params.Pe_upump_L_D0 (nominal)
KL = NaN;  dKL = NaN;  M = NaN;  Pe = NaN;
if isempty(m), return, end
if isfield(m, 'results')
    KL  = firstNum(m.results, {'KL_cm2min'});
    dKL = firstNum(m.results, {'totUncertKL_cm2min','dKL_cm2min'});
end
[M, Pe] = nominalMPe(m);
end

function [M, Pe] = nominalMPe(m, RP)
% M = mu2/mu1 from REFPROP at the nominal T and P of one MFM experiment, Pe = Pe_upump_L_D0
persistent RPp
M = NaN;  Pe = NaN;
if isempty(m) || ~isfield(m, 'exp_params'), return, end
if nargin < 2 || isempty(RP)
    if isempty(RPp), RPp = initREFPROP(); end         % started once, reused
    RP = RPp;
end
ep = m.exp_params;
Pe    = firstNum(ep, {'Pe_upump_L_D0'});
T_K   = firstNum(ep, {'T_C'}) + 273.15;
P_kPa = (firstNum(ep, {'P_psig'}) + 14.7)*6.89476;
if ~(isfinite(T_K) && isfinite(P_kPa)), return, end
% fluid names passed exactly as in main_DataExtract: upper(filedataExp.Fluid1(i))
p1 = getFluidProps_REFPROP(RP, upper(ep.Fluid1(1)), T_K, P_kPa);
p2 = getFluidProps_REFPROP(RP, upper(ep.Fluid2(1)), T_K, P_kPa);
M  = p2.mu / p1.mu;
end

function P = frontPosPanels(ref)
% panels of 3c / 3d: {source, x kind ("res" = t_D,res | "scaled" = v (t - t_arr)/L_img), x label}
P = {"contour", "res",    't_{D,res,cont} = t_D - t_{D,arr,cont} [-]'; ...
     "contour", "scaled", 'v_{cont} (t - t_{arr,cont}) / L_{img} [-]'; ...
     "profile", "res",    't_{D,res,prof} = t_D - t_{D,arr,prof} [-]'; ...
     "profile", "scaled", 'v_{prof} (t - t_{arr,prof}) / L_{img} [-]'};
if string(ref) ~= "levels"
    P(:,3) = cellfun(@(s) [s '  (t_{arr}: ' char(ref) ')'], P(:,3), 'UniformOutput', false);
end
end

function [X, ZD] = frontPosData(ctData, fd, ds, levels, variant)
% level positions z_D (frames x levels) and the two x axes of each source, each with its own arrival
% (resultsAll.(ds).tArr_plot_<src>_min) and centre-line velocity (cLine_<src>) from the load block:
%   X.(src).res = t_D - t_D,arr,src,   X.(src).scaled = v_src (t - t_arr,src) / L_img
vars = ctData.varsAll.(ds);  vn = string(vars.Properties.VariableNames);  n = height(vars);
rq   = ctData.resultsAll.(ds);  t = vars.secondsElapsed/60;
ZD.contour = nan(n, numel(levels));
for m = 1:numel(levels)
    c_ = "zDFront" + sprintf('%02d', round(100*levels(m))) + variant;
    if ismember(c_, vn), ZD.contour(:,m) = vars.(c_); end
end
[Zp, ZD.profile] = profLevels(vars.C1Profile, "CVert" + variant, fd.C1init/100, fd.C1j/100, levels);
% image length of each source [cm]
LC = NaN;  c50 = "zDFront50" + variant;
if all(ismember([c50, c50 + "_cm"], vn))
    okL = vars.(c50) > 0.05;  LC = median(vars.(c50 + "_cm")(okL) ./ vars.(c50)(okL), 'omitnan');
end
k50 = find(abs(levels - 0.5) < 1e-9, 1);  LP = NaN;
if ~isempty(k50), okL = ZD.profile(:,k50) > 0.05;  LP = median(Zp(okL,k50) ./ ZD.profile(okL,k50), 'omitnan'); end
if ~isfinite(LC), LC = fd.L*2.54; end
if ~isfinite(LP), LP = LC; end
src = ["contour","profile"];  tag = ["cont","prof"];  Ls = [LC LP];
for k = 1:2
    tA = NaN;  v = NaN;
    if isfield(rq, "tArr_plot_" + tag(k) + "_min"), tA = rq.("tArr_plot_" + tag(k) + "_min"); end
    if isfield(rq, "cLine_" + tag(k)), v = rq.("cLine_" + tag(k)).v; end
    X.(src(k)).res    = vars.tDtotal - tA*fd.Q/fd.Vtotal;
    X.(src(k)).scaled = v*(t - tA)/Ls(k);
end
end

function [Z, ZD] = profLevels(profCol, cCol, Ci, Cj, levels, trimFrac, nSmooth)
% Position of every level C on the averaged profile of every frame, as profileWidth / main_CTpostproc:
% Cn = (C - Ci)/(Cj - Ci), 2 % of the column dropped at each end, injection end first, 5-slice moving
% median; anchor = the Cn = 0.5 down-crossing with the steepest drop; levels < 0.5 searched downstream
% of it, levels > 0.5 upstream. Before the centre is inside (no Cn = 0.5 crossing), the anchor is the
% highest Cn in the first 20 % of the column (inlet side), so the low levels are found from their first
% appearance; levels >= 0.5 stay NaN. Z [cm from the injection end], ZD = Z / image length.
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
        elseif c < 0.5
            j = find(Cm(k50+1:end) < c, 1);  zc = NaN;
            if ~isempty(j), j = k50 + j;  zc = interpLev(zz, Cm, j-1, c); end
        else
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

function tag = tXtagRes(ref)
% file-name tag of t_D,res for arrival ref: "C50" -> "tDres", others -> "tDres_<ref>"
if string(ref) == "C50", tag = "tDres"; else, tag = "tDres_" + string(ref); end
end