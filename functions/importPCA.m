function pca = importPCA(dirPCAFiles)
%importPCA Summary of this function goes here
%   Detailed explanation goes here
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