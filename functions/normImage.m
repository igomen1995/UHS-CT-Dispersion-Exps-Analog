function normalizedImage = normImage(image)

%NORMIMAGE Normalize image intensities to the range [0, 1].
%
%   normalizedImage = normImage(image) scales all pixel values in the
%   input image by the maximum pixel intensity so that the largest value
%   becomes 1.
%
%   Inputs:
%       image - Input image matrix.
%
%   Output:
%       normalizedImage - Normalized image matrix with values ranging from
%                         0 to 1.
%
%   Example:
%       imgNorm = normImage(img);
%
%   Notes:
%       - The normalization is performed using:
%
%             image / max(image(:))
%
%       - If the maximum pixel value is zero, the output will contain NaN
%         values due to division by zero.
%
%   See also:
%       max

normalizedImage = image./max(max(image));
end

