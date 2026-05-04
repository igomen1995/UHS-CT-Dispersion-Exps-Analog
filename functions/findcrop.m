function out = findcrop(image,pixDistTol,partsNoCore)
%This function finds the core part of the image to crop
% by differentiating the different parts of the scan:
% air, coreholder (CH), conf, sleeve, core
% Parts no core in this case would be 4
% 
% 1 - mean(image)
% 2 - smooth(image)
% 3 - find main peaks and valleys, abrupt change means a change in media scanned
% 4 - extract array (min, max) pixel of core to crop in x direction

me_y = mean(image); % gets mean in columns, so it gives a profile of average gray value in an array of x pixels
x = 1:1:length(me_y);

sm_y = smooth(me_y,'sgolay',3);
[peaks_y, peaks_x] = findpeaks(sm_y,x);
[valleys_y, valleys_x] = findpeaks(-sm_y,x);
pv = [peaks_x, valleys_x;peaks_y',(valleys_y*(-1))']';
pv_x = pv(:,1);
pv_y = pv(:,2);
[pv_x_sort,idx_sort] = sort(pv_x);
pv_y_sort = pv_y(idx_sort);
pv_sort = [pv_x_sort,pv_y_sort];

dx_sort = pv_x_sort(2:end)-pv_x_sort(1:end-1);

pv_sort_parts = pv_sort(dx_sort > pixDistTol,:);

out = pv_sort_parts(partsNoCore:(end-partsNoCore+1),:);

end