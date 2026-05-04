%%%%%%%%%%%%%  Function threshold %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Purpose:  
%      Compute threshold filter at each pixel in an image
%      to convert a gray image to a binary-valued image
%
% Input Variables:
%      f       MxN input 2D gray-scale image to be filtered
%      
% Returned Results:
%     fbin     new image cantaining the filtered results
%
% Processing Flow:
%      1.  Set a new image full of ZEROS
%      2.  For each pixel,
%             compute the threshold, and assing 0 values if
%             gray image pixel value is smaller or equal than 127,
%             otherwise assign 1
%
%  Restrictions/Notes:
%      This function takes an 8-bit GRAY image as input.  
%
%  The following functions are called:
%      zero
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function fbin = thresh_range(f,min,max)

[M, N] = size(f);

% Compute the zero matrix to allocate values of threshold
fzero = zero(M,N);

for x = 1 : M        
    for y = 1 : N
        if f(x,y) > min && f(x,y) < max 
           fzero(x,y) = f(x,y);
        else
           fzero(x,y) = 0;
        end
    end
end

fbin = fzero;