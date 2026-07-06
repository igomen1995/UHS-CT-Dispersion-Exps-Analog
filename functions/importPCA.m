function pca = importPCA(dirPCAFiles)

%IMPORTPCA Import PCA configuration parameters from a text file.
%
%   pca = importPCA(dirPCAFiles) reads a PCA configuration file and
%   converts its contents into a nested MATLAB structure. The configuration
%   file is expected to contain section headers enclosed in square brackets
%   and key-value pairs separated by an equals sign (=).
%
%   File Format Example:
%
%       [Acquisition]
%       Voltage = 120
%       Current = 80
%
%       [Reconstruction]
%       VoxelSize = 0.05
%       Filter = Ram-Lak
%
%   The imported structure will be:
%
%       pca.Acquisition.Voltage
%       pca.Acquisition.Current
%       pca.Reconstruction.VoxelSize
%       pca.Reconstruction.Filter
%
%   Inputs:
%       dirPCAFiles - Structure array returned by DIR containing the PCA
%                     configuration file. The first file in the structure
%                     is imported.
%
%   Output:
%       pca - MATLAB structure containing all imported sections and
%             parameters from the PCA file.
%
%   Notes:
%       - Numeric values are automatically converted to doubles.
%       - Non-numeric values are stored as character strings.
%       - Section names are cleaned by removing brackets and hyphens.
%       - Parameter names are cleaned by removing hyphens and asterisks.
%
%   Example:
%       pca = importPCA(dir('*.pca'));
%
%   See also:
%       fileread, splitlines, str2double, struct

        % pca
        pcaPath = fullfile(dirPCAFiles(1).folder, dirPCAFiles(1).name);
        txt = fileread(pcaPath);
        % Make a function to read and save pca
        lines = splitlines(txt);
        currentSection = "";
        for j = 1:length(lines)
            line = strtrim(lines{j});
            if startsWith(line,'[') && endsWith(line,']')
                currentSection = erase(line,["[", "]", "-"]);
                pca.(currentSection) = struct();
            elseif contains(line,'=')
                parts = split(line,'=');
                key = strtrim(parts{1});
                key = erase(key,["-","*"]);
                val = strtrim(parts{2});
                numVal = str2double(val);
                if ~isnan(numVal)
                    pca.(currentSection).(key) = numVal;
                else
                    pca.(currentSection).(key) = val;
                end
            end
        end
end