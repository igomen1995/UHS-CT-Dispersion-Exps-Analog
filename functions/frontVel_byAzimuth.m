function azimResults = frontVel_byAzimuth(vars, levelTag, variantSuffix)
% FRONTVELBYAZIMUTHPOOLED  Mean front velocity per fixed angle (0-180,
% mirrored 181-360), pooling the direct AND opposite-side readings from
% every frame across every run in `vars`. Each frame contributes two
% (time, z) points -- one tagged with the azimuth it views directly
% (rotPos), one tagged with the azimuth on its opposite side
% (rotPos+180) -- grouped by that TRUE azimuth and fit the same way
% frontVel does (polyfit, trimmed to 0.03<zD<0.97), instead of a
% per-timestamp velocity.
%
% vars          : varsAll.(dataSource), all runs pooled together
% levelTag      : level tag string, e.g. "50" for C=0.5
% variantSuffix : "" for the full-image azimuth split, "_xtrim" for the
%                 wall-margin-trimmed one

if nargin < 3, variantSuffix = ""; end

directCol   = "zDFront" + levelTag + "_azimDirect" + variantSuffix;
directColCm = directCol + "_cm";
oppCol      = "zDFront" + levelTag + "_azimOpp" + variantSuffix;
oppColCm    = oppCol + "_cm";
if ~all(ismember([directCol, directColCm, oppCol, oppColCm], string(vars.Properties.VariableNames)))
    error('frontVelByAzimuthPooled: level %s (variant "%s") has no azimDirect/azimOpp columns.', levelTag, variantSuffix);
end

t_min = vars.secondsElapsed/60;

% long format: every frame -> two rows, each tagged with its TRUE azimuth
azimuth_deg = [mod(vars.rotPos,360); mod(vars.rotPos+180,360)];
t_all       = [t_min; t_min];
zD_all      = [vars.(directCol);   vars.(oppCol)];
zCm_all     = [vars.(directColCm); vars.(oppColCm)];

azimuth_bin = round(azimuth_deg);   % exact for a 2-deg grid
uniqueAz = unique(azimuth_bin(~isnan(azimuth_bin)));

azimResults = table();
for a = 1:numel(uniqueAz)
    az = uniqueAz(a);
    mask = azimuth_bin == az;
    if nnz(mask) < 2
        continue   % frontVel itself requires >=5 valid points after its own zD trim
    end
    fit = frontVel(t_all(mask), zCm_all(mask), zD_all(mask));
    azimResults = [azimResults; table(az, fit.v_front_cmmin, fit.intercept_cm, fit.R2, fit.nValidPts, ...
        'VariableNames', {'azimuth_deg','v_front_cmmin','intercept_cm','R2','nValidPts'})]; %#ok<AGROW>
end
end