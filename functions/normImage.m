function normalizedImage = normImage(image, I0)
%NORMIMAGE Normalize a projection by the unattenuated intensity I0.
%
%   normalizedImage = normImage(image, I0) returns image ./ I0, i.e. the
%   transmission I/I0. I0 is the air (unattenuated) intensity of the scan,
%   e.g. from findIair on frame k = 1. I0 can be a scalar, or a column
%   vector with one value per detector row.
%
%   normalizedImage = normImage(image) keeps the old behaviour and divides
%   by the maximum of THIS image, image ./ max(image(:)).
%
%   Inputs:
%       image - projection (any numeric type; converted to double).
%       I0    - (optional) unattenuated intensity, scalar or [nRows x 1].
%
%   Output:
%       normalizedImage - double image; air ~ 1, attenuating material < 1.
%                         Values slightly above 1 can occur in air (noise).
%
%   Example:
%       I0      = findIair(importImages(files, 1));     % air of frame k = 1
%       imgNorm = normImage(importImages(files, k), I0);
%
%   Notes:
%       - The image is converted to double first, so integer images
%         (uint16) are not rounded to 0/1 by the division.
%       - If I0 (or the maximum) is zero, the output contains Inf/NaN.
%
%   See also: findIair, max

    image = double(image);
    if nargin < 2 || isempty(I0)
        I0 = max(image(:));                 % old behaviour: maximum of this image
    end
    normalizedImage = image ./ double(I0);
end