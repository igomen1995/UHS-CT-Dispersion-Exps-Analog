function zD = frontLevel1D(z, CVert, level)
% FRONTLEVELD  Find the Z position where the vertical
% concentration profile crosses a given level, via 1D interpolation.
% Assumes CVert is monotonic-ish over the crossing region (true for a
% displacement front); uses the crossing closest to where the profile
% actually passes through "level" if there are multiple due to noise.

    % find where CVert crosses "level" (sign change of CVert-level)
    d = CVert(:) - level;
    signChange = find(d(1:end-1).*d(2:end) < 0);

    if isempty(signChange)
        zD = NaN;   % level never reached in this profile
        return
    end

    idx = signChange(round(end/2));

    % linear interpolation between the two bracketing points
    z1 = z(idx);   c1 = CVert(idx);
    z2 = z(idx+1); c2 = CVert(idx+1);
    zD = z1 + (level - c1)*(z2 - z1)/(c2 - c1);
end