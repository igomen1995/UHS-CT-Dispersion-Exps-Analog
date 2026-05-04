function pcj = importPCJ(dirPCJFiles)
%importPCA Summary of this function goes here
%   Detailed explanation goes here
        % pcj
        pcjPath = fullfile(dirPCJFiles(1).folder, dirPCJFiles(1).name);
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
        pcj = array2table(data, 'VariableNames', colNames);
end