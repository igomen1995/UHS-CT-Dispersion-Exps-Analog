function [cropx, B, coreTrans] = findCropWindow_layers(image, cropWidth, opts)
%FINDCROPWINDOW_LAYERS Fixed-width core crop window from the layer (kink) detection.
%
%   [cropx, B, coreTrans] = findCropWindow_layers(image, cropWidth, opts)
%   finds the core edges with findLayerBoundaries_xAxis (sleeve -> core corner,
%   found after the Al-liner minimum and the fluid maximum on each side, so it
%   does not depend on counting peaks/valleys) and returns a crop window of
%   exactly cropWidth pixels centred on the core. Same outputs and clamping as
%   findCropWindow_xAxis, so the two can be swapped.
%
%   Inputs
%       image     - single 2-D projection (raw or normalized)
%       cropWidth - fixed crop width [px]
%       opts      - optional, passed to findLayerBoundaries_xAxis
%
%   Outputs
%       cropx     - [xmin; xmax], exactly cropWidth pixels wide, inside the image
%       B         - all layer boundaries (findLayerBoundaries_xAxis)
%       coreTrans - [xLeft value; xRight value], first and last core pixel
%                   (same convention as findCropWindow_xAxis' 3rd output)
%
%   See also: findLayerBoundaries_xAxis, findCropWindow_xAxis, plotCropProfile

    if nargin < 3, opts = struct(); end

    B = findLayerBoundaries_xAxis(image, [], opts);
    xLeft  = B.coreX(1);
    xRight = B.coreX(2);
    if any(isnan([xLeft xRight]))
        error('findCropWindow_layers:noCore', ...
            'Core edge not found (left %g, right %g). Check the profile with plotCropProfile.', ...
            xLeft, xRight);
    end
    coreTrans = [xLeft, B.profile(xLeft); xRight, B.profile(xRight)];

    if (xRight - xLeft + 1) > cropWidth
        warning('findCropWindow_layers:coreWiderThanCrop', ...
            'Detected core width (%d px) exceeds cropWidth (%d px); core will be clipped.', ...
            round(xRight - xLeft + 1), cropWidth);
    end

    imgWidth = size(image, 2);
    xmin = round((xLeft + xRight)/2 - cropWidth/2);
    xmax = xmin + cropWidth - 1;
    if xmin < 1
        xmin = 1;  xmax = cropWidth;
    elseif xmax > imgWidth
        xmax = imgWidth;  xmin = imgWidth - cropWidth + 1;
    end
    cropx = [xmin; xmax];
end