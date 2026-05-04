function pcp = importPCP(dirPCPFiles)
%importPCA Summary of this function goes here
%   Detailed explanation goes here
        % pcp
        pcpPath = fullfile(dirPCPFiles(1).folder, dirPCPFiles(1).name);
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
        pcp = array2table(numericData, ...
            'VariableNames', colNames(1:end-1));
        pcp.Time = timeData;
end