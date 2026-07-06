function out = findcropCore_xAxis(image,pixDistTol,partsNoCore)

%FINDCROPCORE_XAXIS Identify core boundaries along the x-axis.
%
%   out = findcropCore_xAxis(image, pixDistTol, partsNoCore) analyzes the
%   average grayscale profile of a scan image to detect transitions between
%   different materials (e.g., air, core holder, confining fluid, sleeve,
%   and core). The detected boundaries are used to estimate the x-axis
%   limits of the core region for cropping.
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
%       partsNoCore - Number of non-core regions expected on each side of
%                     the core. For a typical scan containing:
%                         air -> core holder -> confining fluid
%                         -> sleeve -> core
%                     the value is usually 4.
%
%   Output:
%       out - Array containing the detected transition points associated
%             with the core boundaries. The first column contains pixel
%             locations and the second column contains the corresponding
%             peak/valley intensity values.
%
%   Example:
%       limits = findcropCore_xAxis(img, 50, 4);
%
%   See also:
%       mean, smooth, findpeaks

% Compute average grayscale profile along image columns
me_y = mean(image); % gets mean in columns, so it gives a profile of average gray value in an array of x pixels

% Column coordinates
x = 1:1:length(me_y);

% Smooth profile to reduce noise
sm_y = smooth(me_y,'sgolay',3);

% Detect peaks and valleys
[peaks_y, peaks_x] = findpeaks(sm_y,x);
[valleys_y, valleys_x] = findpeaks(-sm_y,x);

% Combine peaks and valleys into a single array
pv = [peaks_x, valleys_x;peaks_y',(valleys_y*(-1))']';
pv_x = pv(:,1);
pv_y = pv(:,2);

% Sort by x location
[pv_x_sort,idx_sort] = sort(pv_x);
pv_y_sort = pv_y(idx_sort);
pv_sort = [pv_x_sort,pv_y_sort];

% Distance between consecutive features
dx_sort = pv_x_sort(2:end)-pv_x_sort(1:end-1);

% Retain only well-separated transition
pv_sort_parts = pv_sort(dx_sort > pixDistTol,:);

% Remove external non-core regions
out = pv_sort_parts(partsNoCore:(end-partsNoCore+1),:);

end