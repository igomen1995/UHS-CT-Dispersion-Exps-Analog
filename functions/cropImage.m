function croppedImage = cropImage(image,cropx, cropy)
%CROPIMAGE Crop a 2-D image using user-defined x and y limits.
%
%   croppedImage = cropImage(image, cropx, cropy) returns a cropped
%   section of the input image specified by the x- and y-coordinate
%   limits.
%
%   Inputs:
%       image  - Input 2-D image matrix.
%       cropx  - Two-element vector [xmin xmax] defining the column range.
%       cropy  - Two-element vector [ymin ymax] defining the row range.
%
%   Output:
%       croppedImage - Cropped image matrix.
%
%   Example:
%       imgCrop = cropImage(img, [100 300], [50 250]);
%
%   Notes:
%       - cropx and cropy must contain valid indices within the image
%         dimensions.
%       - No bounds checking is performed.

croppedImage = image(cropy(1):cropy(2),cropx(1):cropx(2));
end

