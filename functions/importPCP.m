function pcp = importPCP(dirPCPFiles)

%IMPORTPCP Import time-series data from a PCP file.
%
%   pcp = importPCP(dirPCPFiles) reads a PCP file and converts its contents
%   into a MATLAB table. Numeric columns are imported as double arrays,
%   while the final date and time columns are combined into a MATLAB
%   datetime variable.
%
%   Expected File Structure:
%
%       <metadata line>
%       Col1 Col2 Col3 Date Time
%       1.0  2.0  3.0  2024-01-01 12:00:00
%       4.0  5.0  6.0  2024-01-01 12:01:00
%
%   Inputs:
%       dirPCPFiles - Structure array returned by DIR containing the PCP
%                     file. The first file in the structure is imported.
%
%   Output:
%       pcp - MATLAB table containing the imported data. Numeric variables
%             are stored in their corresponding columns, and an additional
%             variable named 'Time' contains the associated timestamps.
%
%   Notes:
%       - Empty lines are automatically removed.
%       - Column names are converted to valid MATLAB variable names.
%       - The last two entries of each row are assumed to contain the date
%         and time information.
%       - Timestamps are imported using the format:
%             yyyy-MM-dd HH:mm:ss
%
%   Example:
%       pcp = importPCP(dir('*.pcp'));
%
%   See also:
%       fileread, datetime, array2table, matlab.lang.makeValidName

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