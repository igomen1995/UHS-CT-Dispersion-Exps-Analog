function sat = satImage(image,minRefimage, maxRefimage)

%SATIMAGE Compute normalized saturation from reference images.
%
%   sat = satImage(image, minRefImage, maxRefImage) calculates the
%   normalized saturation (or concentration) image using a linear
%   interpolation between two reference images representing the minimum
%   and maximum states.
%
%   The saturation is computed as:
%
%       sat = (image - minRefImage) ./ ...
%             (maxRefImage - minRefImage)
%
%   Inputs:
%       image       - CT image acquired during the experiment.
%       minRefImage - Reference image corresponding to the minimum
%                     saturation/concentration state.
%       maxRefImage - Reference image corresponding to the maximum
%                     saturation/concentration state.
%
%   Output:
%       sat         - Normalized saturation image. Values typically range
%                     between 0 and 1, where:
%                         0 = minimum reference state
%                         1 = maximum reference state
%
%   Example:
%       sat = satImage(expImage, dryCoreImage, brineCoreImage);
%
%   Notes:
%       - All input images must have identical dimensions.
%       - Values outside the range [0,1] may occur due to image noise,
%         registration errors, or experimental uncertainties.
%       - No clipping or bounds checking is applied.
%
%   See also:
%       normImage

sat = (image - minRefimage)./ (maxRefimage-minRefimage);
end

