function out = flatScalars(s, prefix, out)
% Add the scalar numeric/logical/text fields of s (recursing into
% sub-structs) to struct out, as prefix_fieldname.
if istable(s) && height(s) == 1, s = table2struct(s); end
if ~isstruct(s) || numel(s) ~= 1, return; end
fn = fieldnames(s);
for q = 1:numel(fn)
    v = s.(fn{q});
    name = matlab.lang.makeValidName([prefix fn{q}]);
    if (isnumeric(v) || islogical(v)) && isscalar(v)
        out.(name) = double(v);
    elseif (ischar(v) && isrow(v)) || (isstring(v) && isscalar(v))
        out.(name) = string(v);
    elseif isstruct(v) || (istable(v) && height(v) == 1)
        out = flatScalars(v, [name '_'], out);
    end
end
end