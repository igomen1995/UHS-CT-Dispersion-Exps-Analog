function croppedImage = cropImage(image,cropx, cropy)
%CROPIMAGE Summary of this function goes here
% cropx and cropy contains two values, limits fo the image
%   Detailed explanation goes here
croppedImage = image(cropx(1):cropx(2),cropy(1):cropy(2));
end

