function sat = satImage(image,minRefimage, maxRefimage)
%CROPIMAGE Summary of this function goes here
% cropx and cropy contains two values, limits fo the image
%   Detailed explanation goes here
sat = (image - minRefimage)./ (maxRefimage-minRefimage);
end

