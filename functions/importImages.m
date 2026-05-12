function images = importImages(dirImageFolder,k)
%importPCA Summary of this function goes here
%   Detailed explanation goes here
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