function images = importImages(dirImageFolder,k)
function images = importImages(dirImageFolder,k)

%IMPORTIMAGES Load a specific image from a directory listing.
%
%   image = importImages(dirImageFolder, k) loads the k-th image from a
%   directory structure returned by MATLAB's DIR function. Files whose
%   names contain the substring 'ASO' are automatically excluded from the
%   image list.
%
%   Inputs:
%       dirImageFolder - Structure array returned by DIR containing image
%                        files and directory information.
%       k              - Index of the image to be loaded.
%
%   Output:
%       image          - Image matrix converted to double precision.
%
%   Notes:
%       - Files containing 'ASO' in their name are ignored.
%       - The image is returned as a double array to facilitate subsequent
%         image processing operations.
%       - An error is generated if k exceeds the number of available
%         images.
%
%   Example:
%       files = dir('Projections/*.tif');
%       img = importImages(files, 25);
%
%   See also:
%       dir, imread, fullfile, double

        % images
        dirImageFolder_noASO = dirImageFolder(~contains({dirImageFolder.name},'ASO'));
        imgPath = fullfile(dirImageFolder_noASO(1).folder);
        images = cell(1, numel(dirImageFolder_noASO)); 
        % to do, select only 180 useful data
        if k > numel(dirImageFolder_noASO)
            error('Projection number (%d) is higher than total number of projections (%d)',k,numel(dirImageFolder_noASO))
        end
        I = imread(fullfile(imgPath, dirImageFolder_noASO(k).name));
        images = double(I);
end
        % images
        dirImageFolder_noASO = dirImageFolder(~contains({dirImageFolder.name},'ASO'));
        imgPath = fullfile(dirImageFolder_noASO(1).folder);
        images = cell(1, numel(dirImageFolder_noASO)); 
        % to do, select only 180 useful data
        if k > numel(dirImageFolder_noASO)
            error('Projection number (%d) is higher than total number of projections (%d)',k,numel(dirImageFolder_noASO))
        end

        % Load image
        I = imread(fullfile(imgPath, dirImageFolder_noASO(k).name));

        % Convert to double precision
        images = double(I);
end