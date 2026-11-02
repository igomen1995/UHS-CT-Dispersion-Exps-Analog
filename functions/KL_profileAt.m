function S = KL_profileAt(vars, variantSuffix, zDtarget, CDtarget, zDwin, tArr, Ci, Cj, ...
    levelPairs, L_cm, plotFile, sigmaArrival)
% KL_PROFILEAT  KL from single averaged profiles at a fixed time: the frame whose profile
% passes through (zD, C) = (zDtarget, CDtarget) (e.g. front centre at mid-core:
% zDtarget = 0.5, CDtarget = 0.5), plus every frame within +/- zDwin of it.
%
% Uses the per-frame profile widths stored in vars by addProfileWidths (the same columns
% that fitKL_frontWidth fits against time); they are computed here if missing.
% Frame selection: findProfileFrame (same rule as the profile plot in main_CTplots).
% Per frame and arrival time (tau = t - t_arr), first ADE term (Lake & Johns / Peters):
%   C10_90 ... : KL = W^2/(4 k^2 tau)      zDWidthProf_<lo>_<hi><sfx>_cm   (averaged profile)
%   contC10_90 : KL = W^2/(4 k^2 tau)      zDWidth_<lo>_<hi><sfx>_cm       (2D contours, same frames,
%                                           populate_CTframeVars: mean contour positions)
%   erfc       : KL = w^2/(4 tau)          wProfErfc<sfx>_cm, dKL = 2 KL dw/w
%   sigma      : KL = sigma^2/(2 tau)      sigmaProf<sfx>_cm
% One value per method: the closest frame ("best") and the mean +/- std over the
% window frames (pointwise-KL statistics, as in main_CTpostproc).
%
% INPUTS
%   tArr          struct of arrival times [min], e.g. struct('contour', tC, 'lines', tL)
%   levelPairs    [low high] rows, used only if the width columns must be computed here
%   plotFile      "" = no figure
%   sigmaArrival  arrival used by the "sigma" alias (default "contour")
%
% OUTPUT S
%   zDtarget, CDtarget, zDwin, nFrames, bestFrame, tD_best, z50D_best, T (one row per frame)
%   methods.<method>_<arrival>  (erfc_contour, C10_90_lines, sigma_contour, ...):
%       KL_cm2min_best, dKL_cm2min_best, KL_cm2min_mean, KL_cm2min_std, tArr_min, label
%   aliases: methods.contour = erfc_contour, methods.lines = erfc_lines,
%            methods.sigma = sigma_<sigmaArrival>

if nargin < 9  || isempty(levelPairs), levelPairs = [0.1 0.9; 0.2 0.8; 0.3 0.7; 0.4 0.6]; end
if nargin < 11, plotFile = ""; end
if nargin < 12 || isempty(sigmaArrival), sigmaArrival = "contour"; end
sfx  = string(variantSuffix);
arrs = string(fieldnames(tArr))';

if ~ismember("r2ProfErfc" + sfx, string(vars.Properties.VariableNames))
    vars = addProfileWidths(vars, Ci, Cj, levelPairs, L_cm);
end

% level pairs present as columns
allCols = string(vars.Properties.VariableNames);
tok  = regexp(allCols, "^zDWidthProf_(\d+)_(\d+)" + sfx + "_cm$", 'tokens', 'once');
hasP = ~cellfun(@isempty, tok);
pairCols = allCols(hasP);  tok = tok(hasP);
tags = strings(1,numel(tok));  kP = nan(1,numel(tok));
for p = 1:numel(tok)
    tt = string(tok{p});                                  % [lo hi] as strings
    tags(p) = "C" + tt(1) + "_" + tt(2);
    kP(p)   = erfcinv(2*str2double(tt(1))/100) - erfcinv(2*str2double(tt(2))/100);
end
% contour widths of the same frames (2D contours, populate_CTframeVars)
tokC = regexp(allCols, "^zDWidth_(\d+)_(\d+)" + sfx + "_cm$", 'tokens', 'once');
hasC = ~cellfun(@isempty, tokC);
cPairCols = allCols(hasC);  tokC = tokC(hasC);
ctags = strings(1,numel(tokC));  kC = nan(1,numel(tokC));
for p = 1:numel(tokC)
    tt = string(tokC{p});
    ctags(p) = "contC" + tt(1) + "_" + tt(2);
    kC(p)    = erfcinv(2*str2double(tt(1))/100) - erfcinv(2*str2double(tt(2))/100);
end
wTags = [tags ctags];  wK = [kP kC];  wCols = [pairCols cPairCols];   % every width-based method
mets  = [wTags "erfc" "sigma"];

emptyM = struct('KL_cm2min_best',NaN, 'dKL_cm2min_best',NaN, 'KL_cm2min_mean',NaN, ...
    'KL_cm2min_std',NaN, 'tArr_min',NaN, 'label',"");
S = struct('zDtarget',zDtarget, 'CDtarget',CDtarget, 'zDwin',zDwin, 'nFrames',0, ...
    'bestFrame',NaN, 'tD_best',NaN, 'z50D_best',NaN, 'T',table(), 'methods',struct());
for m = mets
    for a = arrs
        M = emptyM;  M.tArr_min = tArr.(a);  M.label = labelOf(m, a);
        S.methods.(m + "_" + a) = M;
    end
end

[lBest, lWin, zCross] = findProfileFrame(vars, zDtarget, CDtarget, sfx, zDwin);
if isnan(lBest)
    warning('KL_profileAt: no CVert%s profile crosses C = %.2f', sfx, CDtarget);
    S = addAliases(S, sigmaArrival);  return
end

% one row per window frame, from the stored columns
lWin  = lWin(:);
t_min = vars.secondsElapsed(lWin)/60;
w     = vars.("wProfErfc"  + sfx + "_cm")(lWin);
dw    = vars.("dwProfErfc" + sfx + "_cm")(lWin);
sg    = vars.("sigmaProf"  + sfx + "_cm")(lWin);
z50cmCol = "zDFrontProf50" + sfx + "_cm";             % front centre in cm (addProfileWidths)
if ismember(z50cmCol, string(vars.Properties.VariableNames))
    z50cm = vars.(z50cmCol)(lWin);
else
    z50cm = vars.("zDFrontProf50" + sfx)(lWin)*L_cm;    % older columns: zD on the core length
end
T = table(lWin, vars.tDtotal(lWin), t_min, zCross(lWin), vars.("zDFrontProf50" + sfx)(lWin), w, dw, ...
    vars.("rmseProfErfc" + sfx)(lWin), vars.("r2ProfErfc" + sfx)(lWin), sg, ...
    vars.("skewProf" + sfx)(lWin), vars.("kurtProf" + sfx)(lWin), ...
    'VariableNames', {'frame','tDtotal','t_min','zD_cross','z50D_erfc','w_erfc_cm','dw_erfc_cm', ...
    'rmse_erfc','r2_erfc','sigma_z_cm','skew_front','kurt_front'});
for p = 1:numel(wTags), T.("W_" + wTags(p) + "_cm") = abs(vars.(wCols(p))(lWin)); end
for a = arrs
    tau = t_min - tArr.(a);  tau(~(tau > 0)) = NaN;
    T.("tau_" + a + "_min") = tau;
    for p = 1:numel(wTags)
        T.("KL_" + wTags(p) + "_" + a + "_cm2min") = T.("W_" + wTags(p) + "_cm").^2 ./ (4*wK(p)^2*tau);
    end
    KLe = w.^2 ./ (4*tau);
    T.("KL_erfc_"  + a + "_cm2min") = KLe;
    T.("dKL_erfc_" + a + "_cm2min") = 2*KLe.*dw./w;
    T.("KL_sigma_" + a + "_cm2min") = sg.^2 ./ (2*tau);
    T.("Pe_front_" + a) = z50cm.^2 ./ (KLe.*tau);                 % v z/KL with v = z50/tau
end
S.T = T;  S.nFrames = height(T);  S.bestFrame = lBest;
qb = find(T.frame == lBest, 1);
S.tD_best = T.tDtotal(qb);  S.z50D_best = T.z50D_erfc(qb);

for m = mets
    for a = arrs
        v = T.("KL_" + m + "_" + a + "_cm2min");  okv = isfinite(v) & v > 0;
        M = S.methods.(m + "_" + a);
        M.KL_cm2min_best = v(qb);
        if m == "erfc", M.dKL_cm2min_best = T.("dKL_erfc_" + a + "_cm2min")(qb); end
        M.KL_cm2min_mean = mean(v(okv));
        M.KL_cm2min_std  = std(v(okv));
        S.methods.(m + "_" + a) = M;
    end
end
S = addAliases(S, sigmaArrival);

% ---- figure: closest profile + erfc fit, KL per frame for every method (first arrival)
if strlength(plotFile) > 0
    pr = getProf(vars.C1Profile, lBest);
    Pb = profileWidth(pr.zVertcm, pr.("CVert" + sfx), Ci, Cj, levelPairs);   % for drawing only
    fig = figure('Visible','off', 'Position',[80 80 1300 500]);
    tl  = tiledlayout(fig, 1, 2, 'TileSpacing','compact');
    ax = nexttile(tl);  hold(ax,'on')
    Lim = max(pr.zVertcm);                                       % image length (zD of the profiles)
    plot(ax, Pb.zz/Lim, Pb.Cn, 'k.', 'DisplayName', sprintf('profile, t_D = %.2f', S.tD_best))
    wb = T.w_erfc_cm(qb);  zb = z50cm(qb);
    if isfinite(wb)
        plot(ax, Pb.zz/Lim, 0.5*erfc((Pb.zz - zb)/wb), 'r-', 'LineWidth',2, ...
            'DisplayName', sprintf('erfc fit: w = %.3g cm', wb))
    end
    xline(ax, zDtarget, ':k', 'HandleVisibility','off');
    xlabel(ax, 'z_D from the injection end [-]');  ylabel(ax, 'C_D [-]');  xlim(ax,[0 1]);  grid(ax,'on')
    legend(ax, 'Location','northeast', 'FontSize',8)
    title(ax, sprintf('Profile through (z_D, C) = (%.2f, %.2f), CVert%s', zDtarget, CDtarget, sfx), ...
        'Interpreter','none')

    ax = nexttile(tl);  hold(ax,'on')
    a = arrs(1);  cols = lines(numel(mets));
    for j = 1:numel(mets)
        plot(ax, T.tDtotal, T.("KL_" + mets(j) + "_" + a + "_cm2min"), '-o', 'Color',cols(j,:), ...
            'MarkerFaceColor',cols(j,:), 'MarkerSize',4, 'DisplayName', mets(j))
    end
    xline(ax, S.tD_best, ':k', 'HandleVisibility','off');
    xlabel(ax, 't_D [-]');  ylabel(ax, 'K_L [cm^2/min]');  grid(ax,'on')
    legend(ax, 'Location','best', 'FontSize',8, 'Interpreter','none')
    title(ax, sprintf('K_L per frame, t_{arr} = %s (%d frames)', a, S.nFrames))
    saveas(fig, plotFile + ".png");  savefig(fig, plotFile + ".fig");  close(fig)
end
end

% ========================================================================
function S = addAliases(S, sigmaArrival)
al = {'contour','erfc_contour'; 'lines','erfc_lines'; 'sigma', char("sigma_" + sigmaArrival)};
for k = 1:size(al,1)
    if isfield(S.methods, al{k,2}), S.methods.(al{k,1}) = S.methods.(al{k,2}); end
end
end

function s = labelOf(m, a)
switch m
    case "erfc",  s = "w^2/(4\tau), t_{arr} " + a;
    case "sigma", s = "\sigma_z^2/(2\tau), t_{arr} " + a;
    otherwise
        if startsWith(m, "contC")
            s = "contour W_{" + strrep(extractAfter(m,"contC"),"_","-") + "}^2/(4k^2\tau), t_{arr} " + a;
        else
            s = "W_{" + strrep(extractAfter(m,"C"),"_","-") + "}^2/(4k^2\tau), t_{arr} " + a;
        end
end
end

function pr = getProf(col, l)
if iscell(col), pr = col{l}; elseif istable(col), pr = col(l,:); else, pr = col(l); end
if iscell(pr), pr = pr{1}; end
if isstruct(pr), pr = struct2table(pr); end
end