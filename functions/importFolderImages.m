function images = importFolderImages(dirImageFolder)
%importPCA Summary of this function goes here
%   Detailed explanation goes here
        % images
        imgPath = fullfile(dirImageFolder(1).folder);
        images = cell(1, numel(dirImageFolder)); 
        % to do, select only 180 useful data
        for k = 1:numel(dirImageFolder)
            I = imread(fullfile(imgPath, dirImageFolder(k).name));
            images{k} = double(I);
        end
end