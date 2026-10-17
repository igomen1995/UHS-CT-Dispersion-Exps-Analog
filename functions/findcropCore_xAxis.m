function [out, pv_sort_parts, dbg] = findcropCore_xAxis(image, pixDistTol, partsNoCore)
%FINDCROPCORE_XAXIS Identify core boundaries along the x-axis.
%
%   out = findcropCore_xAxis(image, pixDistTol, partsNoCore) analyzes the
%   average grayscale profile of a scan image to detect transitions between
%   different materials (e.g., air, core holder, confining fluid, sleeve,
%   and core). The detected boundaries are used to estimate the x-axis
%   limits of the core region for cropping.
%
%   [out, pv_sort_parts, dbg] = findcropCore_xAxis(...) also returns every
%   intermediate stage in dbg (for plotTransitionStages). The detection itself
%   is unchanged.
%
%   Method:
%       1. Compute the mean grayscale intensity for each image column.
%       2. Smooth the intensity profile using a Savitzky-Golay filter.
%       3. Detect peaks and valleys in the smoothed profile.
%       4. Identify significant transitions based on the minimum pixel
%          separation threshold.
%       5. Remove external regions and return the boundary locations
%          corresponding to the core section.
%
%   Inputs:
%       image       - Input 2-D grayscale image.
%       pixDistTol  - Minimum pixel distance between consecutive detected
%                     features. Used to filter insignificant transitions.
%       partsNoCore - Index of the first core transition in pv_sort_parts
%                     (counted from each side). The outer partsNoCore-1
%                     transitions on each side are removed.
%
%   Outputs:
%       out           - [x, value] transitions belonging to the core
%                       (pv_sort_parts(partsNoCore:end-partsNoCore+1,:)).
%       pv_sort_parts - all transitions after the spacing filter and merge.
%       dbg           - struct with every stage:
%           .x, .me_y, .sm_y   column index, raw mean profile, smoothed profile
%           .pv_sort           [x, value] of ALL peaks and valleys, sorted by x
%           .pvType            +1 peak, -1 valley (per row of pv_sort)
%           .keep              logical, passed the spacing filter (per pv_sort row)
%           .keptIdx           rows of pv_sort that passed
%           .partOfKept        part number (row of pv_sort_parts) of each kept row
%           .merged            logical per pv_sort_parts row: made from 2 kept points
%           .coreIdx           rows of pv_sort_parts returned in out
%           .pixDistTol, .partsNoCore
%
%   Example:
%       limits = findcropCore_xAxis(img, 50, 4);
%
%   See also:
%       mean, smooth, findpeaks, plotTransitionStages

% Compute average grayscale profile along image columns
me_y = mean(image); % mean of each column -> profile of average gray value along x

% Column coordinates
x = 1:1:length(me_y);

% Smooth profile to reduce noise
sm_y = smooth(me_y,'sgolay',3);

% Detect peaks and valleys
[peaks_y, peaks_x] = findpeaks(sm_y,x);
[valleys_y, valleys_x] = findpeaks(-sm_y,x);

% Combine peaks and valleys into a single array
pv = [peaks_x, valleys_x;peaks_y',(valleys_y*(-1))']';
pvType = [ones(numel(peaks_x),1); -ones(numel(valleys_x),1)];
pv_x = pv(:,1);
pv_y = pv(:,2);

% Sort by x location
[pv_x_sort,idx_sort] = sort(pv_x);
pv_y_sort = pv_y(idx_sort);
pvType    = pvType(idx_sort);
pv_sort = [pv_x_sort,pv_y_sort];

% Distance between consecutive features
dx_fwd = [pv_sort(2:end,1)-pv_sort(1:end-1,1);Inf];
dx_bwd = [Inf; pv_sort(2:end,1) - pv_sort(1:end-1,1)];

% Retain only well-separated transition
keep = (dx_fwd > pixDistTol) | (dx_bwd > pixDistTol);
kept = pv_sort(keep,:);

% Merge consecutive kept transitions that are still closer than
% pixDistTol (the two endpoints of a short cluster) into one point
pv_sort_parts = zeros(0,2);
nK = size(kept,1);
partOfKept = zeros(nK,1);
merged = false(0,1);
ii = 1;
while ii <= nK
    if ii < nK && (kept(ii+1,1) - kept(ii,1)) <= pixDistTol
        xm = round(mean(kept(ii:ii+1,1)));
        pv_sort_parts(end+1,:) = [xm, sm_y(xm)]; %#ok<AGROW>
        partOfKept(ii:ii+1) = size(pv_sort_parts,1);
        merged(end+1,1) = true; %#ok<AGROW>
        ii = ii + 2;
    else
        pv_sort_parts(end+1,:) = kept(ii,:); %#ok<AGROW>
        partOfKept(ii) = size(pv_sort_parts,1);
        merged(end+1,1) = false; %#ok<AGROW>
        ii = ii + 1;
    end
end

% Remove external non-core regions
coreIdx = partsNoCore:(size(pv_sort_parts,1)-partsNoCore+1);
out = pv_sort_parts(coreIdx,:);

if nargout > 2
    dbg = struct('x', x, 'me_y', me_y(:)', 'sm_y', sm_y(:)', ...
        'pv_sort', pv_sort, 'pvType', pvType, 'keep', keep, ...
        'keptIdx', find(keep), 'partOfKept', partOfKept, 'merged', merged, ...
        'pv_sort_parts', pv_sort_parts, 'coreIdx', coreIdx, ...
        'pixDistTol', pixDistTol, 'partsNoCore', partsNoCore);
end
end