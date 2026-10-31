function vars = addProfileWidths(vars, Ci, Cj, levelPairs, L_cm, doErfc)
% ADDPROFILEWIDTHS  Per-frame front widths of the AVERAGED vertical profile
% (C1Profile.CVert and CVert_xtrim), stored as columns of vars next to the contour
% widths zDWidth_* so that they are saved with time and fitted by the same function
% (fitKL_frontWidth with prefix "zDWidthProf" / "zDWidthProfErfc").
%
% Any existing profile-width columns are deleted first and rebuilt.
%
% Columns (sfx = "" full image, "_xtrim" x-trimmed; lo/hi = level pair, e.g. 10_90):
%   zDWidthProf_<lo>_<hi><sfx>      width between the Cn = lo and Cn = hi crossings [-]
%   zDWidthProf_<lo>_<hi><sfx>_cm   same in cm
%   zDWidthProfErfc_10_90<sfx>[_cm] erfc-fit width as its 10-90 equivalent, 2 erfcinv(0.2) w,
%                                   so that W^2/(4k^2) = w^2/4 in fitKL_frontWidth
%   zDFrontProf50<sfx>              front centre z50 of the erfc fit [-, from the injection end]
%   wProfErfc<sfx>_cm, dwProfErfc<sfx>_cm   erfc width w and its standard error [cm]
%   rmseProfErfc<sfx>, r2ProfErfc<sfx>      goodness of the erfc fit (normalized C)
%   (the fitted curve of any frame: Cn = 0.5 erfc((z - z50)/w), z from the injection end)
%   sigmaProf<sfx>_cm, skewProf<sfx>, kurtProf<sfx>   moments of -dC/dz around the front
% doErfc = false (default true) skips the erfc fit: erfc columns are NaN, much faster.
%
% Widths are NaN for frames where the levels are not both crossed inside the core.

if nargin < 4 || isempty(levelPairs), levelPairs = [0.1 0.9; 0.2 0.8; 0.3 0.7; 0.4 0.6]; end
if nargin < 6 || isempty(doErfc), doErfc = true; end
n  = height(vars);
nP = size(levelPairs,1);

% delete any previous profile-width columns
old = startsWith(string(vars.Properties.VariableNames), ...
    ["zDWidthProf","zDFrontProf","wProfErfc","dwProfErfc","rmseProfErfc","r2ProfErfc", ...
     "sigmaProf","skewProf","kurtProf"]);
vars(:, old) = [];

kErfc = 2*erfcinv(0.2);                    % 10-90 width of erfc((z - z50)/w) is kErfc*w
for sfx = ["", "_xtrim"]
    cCol = "CVert" + sfx;
    W = nan(n,nP);  z50 = nan(n,1);  w = nan(n,1);  dw = nan(n,1);  rm = nan(n,1);  r2 = nan(n,1);
    sg = nan(n,1);  sk = nan(n,1);  ku = nan(n,1);  tags = strings(1,nP);
    for r = 1:n
        pr = getProf(vars.C1Profile, r);
        if isempty(pr) || ~ismember(cCol, string(pr.Properties.VariableNames)), continue, end
        P = profileWidth(pr.zVertcm, pr.(cCol), Ci, Cj, levelPairs, [], doErfc);
        W(r,:) = P.W;  z50(r) = P.z50_erfc;  w(r) = P.w_erfc;  dw(r) = P.dw_erfc;
        rm(r) = P.rmse_erfc;  r2(r) = P.r2_erfc;
        sg(r) = P.sigma;  sk(r) = P.skew;  ku(r) = P.kurt;
    end
    for p = 1:nP
        tags(p) = sprintf("%02d_%02d", round(100*levelPairs(p,1)), round(100*levelPairs(p,2)));
        vars.("zDWidthProf_" + tags(p) + sfx)         = W(:,p)/L_cm;
        vars.("zDWidthProf_" + tags(p) + sfx + "_cm") = W(:,p);
    end
    vars.("zDWidthProfErfc_10_90" + sfx)         = kErfc*w/L_cm;
    vars.("zDWidthProfErfc_10_90" + sfx + "_cm") = kErfc*w;
    vars.("zDFrontProf50" + sfx)   = z50/L_cm;
    vars.("wProfErfc" + sfx + "_cm")  = w;
    vars.("dwProfErfc" + sfx + "_cm") = dw;
    vars.("rmseProfErfc" + sfx) = rm;
    vars.("r2ProfErfc" + sfx)   = r2;
    vars.("sigmaProf" + sfx + "_cm")  = sg;
    vars.("skewProf" + sfx) = sk;
    vars.("kurtProf" + sfx) = ku;
end
end

function pr = getProf(col, l)
if iscell(col), pr = col{l}; elseif istable(col), pr = col(l,:); else, pr = col(l); end
if iscell(pr), pr = pr{1}; end
if isstruct(pr), pr = struct2table(pr); end
end