function pcj = importPCJ(dirPCJFiles)

%IMPORTPCJ Import tabular data from a PCJ file.
%
%   pcj = importPCJ(dirPCJFiles) reads a PCJ file and converts the data
%   contained in its [Data] section into a MATLAB table.
%
%   The function assumes the PCJ file follows the standard format:
%
%       [Data]
%       ; Col1 Col2 Col3
%       1.0  2.0  3.0
%       4.0  5.0  6.0
%
%   The header line, identified by a leading semicolon (;), is used to
%   define the table variable names. Data rows are interpreted as
%   whitespace-separated numeric values.
%
%   Inputs:
%       dirPCJFiles - Structure array returned by DIR containing the PCJ
%                     file. The first file in the structure is imported.
%
%   Output:
%       pcj - MATLAB table containing the numerical data stored in the
%             PCJ file.
%
%   Notes:
%       - The function searches for the [Data] section and ignores
%         preceding metadata.
%       - Variable names are converted to valid MATLAB identifiers using
%         MATLAB.LANG.MAKEVALIDNAME.
%       - All imported values are converted to double precision.
%
%   Example:
%       pcj = importPCJ(dir('*.pcj'));
%
%   See also:
%       fileread, splitlines, array2table, matlab.lang.makeValidName

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