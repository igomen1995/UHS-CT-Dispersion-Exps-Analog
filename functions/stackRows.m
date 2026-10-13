function T = stackRows(rows)
% Stack 1-row structs with possibly different fields into a table.
% Fields missing in a row are filled with NaN (numbers) or "" (text).
n = numel(rows);
names = {};
for r = 1:n, names = union(names, fieldnames(rows{r}), 'stable'); end
T = table();
for q = 1:numel(names)
    nm  = names{q};
    has = cellfun(@(s) isfield(s, nm), rows);
    if isstring(rows{find(has,1)}.(nm)), col = strings(n,1); else, col = nan(n,1); end
    for r = find(has)'
        col(r) = rows{r}.(nm);
    end
    T.(nm) = col;
end
end