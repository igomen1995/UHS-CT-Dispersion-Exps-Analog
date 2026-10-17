function [cropx, pv_sort_parts, coreTrans, dbg] = findCropWindow_xAxis(image, pixDistTol, partsNoCore, cropWidth)
%FINDCROPWINDOW_XAXIS Per-image core crop window with a FIXED width.
%
%   [cropx, pv_sort_parts, coreTrans] = findCropWindow_xAxis(image, ...
%       pixDistTol, partsNoCore, cropWidth)
%   detects the core center in THIS single projection image (via
%   findcropCore_xAxis) and returns a crop window of exactly cropWidth
%   pixels, centered on that core. Use this per projection/angle when the
%   rotation axis is not centered in the frame, so the apparent core
%   position shifts from image to image but the output array size stays
%   constant (needed to stack projections into one HDF5 dataset).
%
%   [..., dbg] = findCropWindow_xAxis(...) also returns all detection stages
%   (see findcropCore_xAxis), for plotTransitionStages.
%
%   Inputs:
%       image       - single 2-D projection (raw or normalized).
%       pixDistTol  - passed through to findcropCore_xAxis.
%       partsNoCore - passed through to findcropCore_xAxis.
%       cropWidth   - fixed crop width in pixels, same for every call.
%
%   Outputs:
%       cropx         - [xmin; xmax], exactly cropWidth pixels wide,
%                       clamped to stay inside the image.
%       pv_sort_parts - full untrimmed [x, value] transition list
%                       (all materials), for plotting with plotCropProfile.
%       coreTrans     - trimmed transition list belonging to the core.
%       dbg           - all intermediate stages (findcropCore_xAxis).
%
%   See also: findcropCore_xAxis, plotCropProfile, plotTransitionStages

[coreTrans, pv_sort_parts, dbg] = findcropCore_xAxis(image, pixDistTol, partsNoCore);

xLeft   = coreTrans(1,1);
xRight  = coreTrans(end,1);
xCenter = (xLeft + xRight)/2;

imgWidth = size(image,2);

if (xRight - xLeft + 1) > cropWidth
    warning('findCropWindow_xAxis:coreWiderThanCrop', ...
        'Detected core width (%d px) exceeds cropWidth (%d px); core will be clipped.', ...
        round(xRight - xLeft + 1), cropWidth);
end

xmin = round(xCenter - cropWidth/2);
xmax = xmin + cropWidth - 1;

% clamp to image bounds, preserving the fixed width
if xmin < 1
    xmin = 1;
    xmax = cropWidth;
elseif xmax > imgWidth
    xmax = imgWidth;
    xmin = imgWidth - cropWidth + 1;
end

cropx = [xmin; xmax];
end