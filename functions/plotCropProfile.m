function fig = plotCropProfile(image, cropx, pv_sort_parts, partsNoCore, titleStr, regionNames)
%PLOTCROPPROFILE Paper figure of the x-axis profile used for cropping.
%
%   fig = plotCropProfile(image, cropx, pv_sort_parts, partsNoCore, titleStr)
%   fig = plotCropProfile(..., regionNames)
%
%   Recomputes the same smoothed mean-intensity profile that
%   findcropCore_xAxis uses and plots it with:
%       - every material region shaded and labelled, colored by MATERIAL
%         (left and right air share a color, etc.), with everything
%         between the two core boundaries merged into one "Core" region
%       - markers ONLY at the material boundaries (transitions inside
%         the core are not shown)
%       - the final crop window (cropx) as red dashed lines
%
%   Inputs:
%       image         - 2-D projection passed to findCropWindow_xAxis.
%       cropx         - [xmin; xmax] crop window.
%       pv_sort_parts - full transition list (2nd output of
%                       findCropWindow_xAxis / findcropCore_xAxis).
%       partsNoCore   - same value used for detection (e.g. 4).
%       titleStr      - figure title ('' for none, typical for papers).
%       regionNames   - (optional) cellstr of partsNoCore+1 names, from
%                       the outside in, ending with the core. Default:
%                       {'Air','Core holder','Confining fluid','Sleeve','Core'}
%
%   Output:
%       fig - figure handle. Export for a paper with e.g.
%             exportgraphics(fig, 'cropProfile.pdf', 'ContentType', 'vector')
%
%   See also: findcropCore_xAxis, findCropWindow_xAxis

if nargin < 5, titleStr = ''; end
if nargin < 6 || isempty(regionNames)
    regionNames = {'Air','Core holder','Confining fluid','Sleeve','Core'};
end
regionNames = cellstr(regionNames);
nMat = partsNoCore + 1;
if numel(regionNames) ~= nMat
    error('plotCropProfile:names', ...
        'regionNames needs partsNoCore+1 = %d entries (outermost -> core).', nMat);
end

% ---- Same profile as findcropCore_xAxis --------------------------------
me_y = mean(image, 1);
nx   = numel(me_y);
x    = 1:nx;
sm_y = smooth(me_y, 'sgolay', 3);

% ---- Material boundaries (outer transitions only) -------------------------
pv = sortrows(pv_sort_parts, 1);
n  = size(pv, 1);
if n < 2*partsNoCore
    error('plotCropProfile:transitions', ...
        'Only %d transitions detected; need at least %d for %d outer regions per side.', ...
        n, 2*partsNoCore, partsNoCore);
end
bnd = pv([1:partsNoCore, n-partsNoCore+1:n], :);   % boundaries, no core-interior points
t   = bnd(:,1);

% Region spans: partsNoCore on the left, the core, partsNoCore on the right
b = [1; t; nx];
spans = zeros(2*partsNoCore+1, 3);      % [xStart xEnd materialIdx]
matIdx = [1:partsNoCore, nMat, partsNoCore:-1:1];
for s = 1:numel(matIdx)
    spans(s,:) = [b(s) b(s+1) matIdx(s)];
end

% Muted palette, one color per material
pal = [0.82 0.82 0.82;   % air
       0.55 0.62 0.72;   % core holder
       0.62 0.80 0.95;   % confining fluid
       0.96 0.80 0.55;   % sleeve
       0.72 0.88 0.66];  % core
if nMat > size(pal,1), pal = lines(nMat); end

% ---- Figure -------------------------------------------------------------
fig = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 26 11]);
tl  = tiledlayout(fig, 1, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
ax  = nexttile(tl);
hold(ax, 'on');

yl = [min(me_y) max(me_y)];
yl = yl + [-0.08 0.22] * diff(yl);      % extra headroom for labels

% Shaded material regions (one legend entry per material)
hMat = gobjects(nMat,1);
for s = 1:size(spans,1)
    m = spans(s,3);
    h = patch(ax, spans(s,[1 2 2 1]), yl([1 1 2 2]), pal(m,:), ...
        'FaceAlpha', 0.45, 'EdgeColor', 'none');
    if isa(hMat(m), 'matlab.graphics.GraphicsPlaceholder')
        h.DisplayName = regionNames{m};
        hMat(m) = h;
    else
        h.HandleVisibility = 'off';
    end

    % Region label: vertical for all regions except the core (horizontal)
    xc = mean(spans(s,1:2));
    if m == nMat
        text(ax, xc, yl(2) - 0.03*diff(yl), regionNames{m}, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
            'FontSize', 8, 'Color', [0.2 0.2 0.2]);
    else
        text(ax, xc, yl(2) - 0.02*diff(yl), regionNames{m}, 'Rotation', 90, ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', ...
            'FontSize', 8, 'Color', [0.2 0.2 0.2]);
    end
end

% Thin separators at the material boundaries only
for tt = t(:)'
    xline(ax, tt, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 0.5, ...
        'HandleVisibility', 'off');
end

% Profiles
plot(ax, x, me_y, 'Color', [0.6 0.6 0.6], 'LineWidth', 0.6, 'DisplayName', 'Raw profile');
plot(ax, x, sm_y, 'k-', 'LineWidth', 1.4, 'DisplayName', 'Smoothed profile');

% Material boundaries
plot(ax, bnd(:,1), bnd(:,2), 'o', 'Color', 'k', ...
    'MarkerFaceColor', 'w', 'MarkerSize', 4.5, 'LineWidth', 0.8, ...
    'DisplayName', 'Material boundaries');

% Crop window
xline(ax, cropx(1), 'r--', 'LineWidth', 1.8, ...
    'DisplayName', sprintf('Crop window (%d px)', cropx(2)-cropx(1)+1));
xline(ax, cropx(2), 'r--', 'LineWidth', 1.8, 'HandleVisibility', 'off');

hold(ax, 'off');

% ---- Styling ------------------------------------------------------------
xlim(ax, [1 nx]);
ylim(ax, yl);
xlabel(ax, 'x (pixel)');
ylabel(ax, 'Mean normalized intensity');
if ~isempty(titleStr), title(ax, titleStr, 'Interpreter', 'none'); end
set(ax, 'FontSize', 9, 'TickDir', 'out', 'LineWidth', 0.8, 'Layer', 'top');
box(ax, 'on');

% Legend placed in the tiled layout's south tile so it always fits inside
% the figure (the layout shrinks the axes to make room)
lgd = legend(ax, 'Orientation', 'horizontal', 'NumColumns', 5, ...
    'Box', 'off', 'FontSize', 8);
lgd.Layout.Tile = 'south';
end