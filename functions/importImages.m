function images = importImages(dirImageFolder)
%importPCA Summary of this function goes here
%   Detailed explanation goes here
        % images
        dirImageFolder_noASO = dirImageFolder(~contains({dirImageFolder.name},'ASO'));
        imgPath = fullfile(dirImageFolder_noASO(1).folder);
        images = cell(1, numel(dirImageFolder_noASO)); 
        % to do, select only 180 useful data
        for k = 1:numel(dirImageFolder_noASO)
            I = imread(fullfile(imgPath, dirImageFolder_noASO(k).name));
            images{k} = double(I);
        end
end