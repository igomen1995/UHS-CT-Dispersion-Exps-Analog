function normalizedImage = normImage(image)
%CROPIMAGE Summary of this function goes here
% cropx and cropy contains two values, limits fo the image
%   Detailed explanation goes here
normalizedImage = image./max(max(image));
end

