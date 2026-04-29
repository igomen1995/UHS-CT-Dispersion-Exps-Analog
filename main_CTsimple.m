% Code description
% 
%
% Workflow
% Loop over one single full scan
% 1 - extract data, take time and angle, and all fileDataExp
% 2 - crop
% 3 - normalize Measured - Xe / He - Xe or run estimated density based on
% calibration, different gray image average or distribution correspond to a
% certain density
% 4 - save data

%% IMPORT input

addpath('functions/');

% Introduce name of input and desired output folder name

inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

filenameExp = inputFileConfig.inputFileName{:};

pathExportAll = inputFileConfig.exportPath{:}; % Path for OUTPUT
mkdir(pathExportAll); % Create directory for output

%% IMPORT data

filedataExp = import_inputCTExp(filenameExp); % import input to a local variable

% Capture min ref data folder
refInitFolderContent = dir(filedataExp.path+filedataExp.CT_data_ref_init); % Xe
refFinalFolderContent = dir(filedataExp.path+filedataExp.CT_data_ref_final); % He
expFolderContent = dir(filedataExp.path+filedataExp.CT_data_exp); % exp

refInitFolderContent = refInitFolderContent([refInitFolderContent.isdir] & ~startsWith({refInitFolderContent.name},'.'));
refInitFolderName = refInitFolderContent.name;
refFinalFolderContent = refFinalFolderContent([refFinalFolderContent.isdir] & ~startsWith({refFinalFolderContent.name},'.'));
refFinalFolderName = refFinalFolderContent.name;
expFolderContent = expFolderContent([expFolderContent.isdir] & ~startsWith({expFolderContent.name},'.'));
expFolderName = {expFolderContent.name}';

for i = 1:length(filedataExp.Key)
    % CF params
    expCTData.(filedataExp.Key(i)).CFparams = filedataExp(i,:);
    % CT init ref
    refInitFolderPathCT = fullfile(refInitFolderContent.folder, refInitFolderName);
        % pca
        pcaFiles = dir(fullfile(refInitFolderPathCT, '*.pca'));
        pcaPath = fullfile(pcaFiles(1).folder, pcaFiles(1).name);
        txt = fileread(pcaPath);
        % Make a function to read and save pca
        lines = splitlines(txt);
        currentSection = "";
        for j = 1:numel(lines)
            line = strtrim(lines{j});
            if startsWith(line,'[') && endsWith(line,']')
                currentSection = erase(line,["[", "]", "-"]);
                expCTData.(filedataExp.Key(i)).refInit.pca.(currentSection) = struct();
            elseif contains(line,'=')
                parts = split(line,'=');
                key = strtrim(parts{1});
                key = erase(key,["-","*"]);
                val = strtrim(parts{2});
                numVal = str2double(val);
                if ~isnan(numVal)
                    expCTData.(filedataExp.Key(i)).refInit.pca.(currentSection).(key) = numVal;
                else
                    expCTData.(filedataExp.Key(i)).refInit.pca.(currentSection).(key) = val;
                end
            end
        end
        % pcj make a function
        pcjFiles = dir(fullfile(refInitFolderPathCT, '*.pcj'));
        pcjPath = fullfile(pcjFiles(1).folder, pcjFiles(1).name);
        pcjText = fileread(pcjPath);
        lines = splitlines(pcjText);
        startIdx = find(strcmp(strtrim(lines),'[Data]'),1) + 1;
        dataLines = strtrim(lines(startIdx:end));
        dataLines = dataLines(dataLines ~= "");
        headerLine = dataLines(startsWith(dataLines,';'));
        dataLines = dataLines(~startsWith(dataLines,';')); 
        headerLineClean = erase(headerLine, ';');
        colNames = regexp(strtrim(headerLineClean), '\s+', 'split');
        colNames = matlab.lang.makeValidName(colNames{:});
        numRows = numel(dataLines);
        numCols = numel(colNames);
        data = zeros(numRows, numCols); 
        for k = 1:numRows
            values = regexp(strtrim(dataLines(k)), '\s+', 'split');
            data(k,:) = str2double(values{:});
        end
        expCTData.(filedataExp.Key(i)).refInit.pcj = array2table(data, 'VariableNames', colNames);
        % pcp
        pcpFiles = dir(fullfile(refInitFolderPathCT, '*.pcp'));
        pcpPath = fullfile(pcpFiles(1).folder, pcpFiles(1).name);
        pcpText = fileread(pcpPath);
        lines = splitlines(pcpText);
        lines = strtrim(lines);
        lines = lines(lines ~= "");
        headerLine = lines(2);     % column names
        dataLines  = lines(3:end);
        colNames = regexp(headerLine, '\s+', 'split');
        colNames = matlab.lang.makeValidName(colNames{:});
        numRows = numel(dataLines);
        numCols = numel(colNames);
        numericData = zeros(numRows, numCols-1);
        timeData = datetime.empty(numRows,0);
        for l = 1:numRows
            parts = regexp(dataLines(l), '\s+', 'split');
            parts = parts{:};
            numericData(l,:) = str2double(parts(1:end-2));
            timeData(l,1) = datetime( ...
                strjoin(parts(end-1:end),' '), ...
                'InputFormat','yyyy-MM-dd HH:mm:ss');
        end
        expCTData.(filedataExp.Key(i)).refInit.pcp = array2table(numericData, ...
            'VariableNames', colNames(1:end-1));
        expCTData.(filedataExp.Key(i)).refInit.pcp.Time = timeData;
        % CT images
        imgFiles = dir(fullfile(refInitFolderPathCT, '*.tif'));
        imgPath = fullfile(imgFiles(1).folder, imgFiles(1).name);
        images = cell(1, numel(imgFiles)); 
        % to do, select only 180 useful data
        for k = 1:numel(imgFiles)
            I = imread(fullfile(refInitFolderPathCT, imgFiles(k).name));
            images{k} = double(I);
        end
        expCTData.(filedataExp.Key(i)).refInit.RawCT = images;
    % CT crop and save for each ref (maybe dont save raw in the struct)
    
    % CT ref final
    % same procedure for all
    % CT exp
    % same procedure for all but have loops for each rotation
    % have final results in a full array with angle and time
    % create breakthrough curve in the end point with time
end


