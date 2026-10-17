function [fig, T] = plotTransitionStages(image, dbg, cropx, ttl, opts)
%PLOTTRANSITIONSTAGES Show every transition findcropCore_xAxis finds and what it does with it.
%
%   [fig, T] = plotTransitionStages(image, dbg, cropx, ttl, opts)
%
%   Top panel: column-mean profile (raw, and the sgolay-smoothed one used for
%   detection) with every peak/valley marked by its fate:
%       x  gray     removed by the spacing filter (both neighbours <= pixDistTol)
%       o  orange   kept, then merged with its neighbour (diamond = merged point)
%       o  red      part n of pv_sort_parts, outer -> removed by partsNoCore
%       o  green    part n of pv_sort_parts, returned as core transition
%   Numbers = row n of pv_sort_parts (what partsNoCore counts).
%   Peaks are labelled above, valleys below. The physical layers
%   (findLayerBoundaries_xAxis) are shaded behind, if available.
%
%   Bottom panel: curvature of the attenuation, d2A/dx2 with A = -ln(profile).
%   Layer boundaries in a projection are mostly KINKS (slope changes), which
%   show up here as spikes but are NOT peaks/valleys of the profile, so
%   findpeaks cannot see them (e.g. air->carbon fibre, carbon fibre->alumina).
%
%   Inputs
%       image - 2-D projection used for the detection
%       dbg   - 4th output of findCropWindow_xAxis (or 3rd of findcropCore_xAxis)
%       cropx - [xmin; xmax] crop window ([] to skip)
%       ttl   - title ('' for none)
%       opts  - optional struct: .showLayers (true), .curvSmoothPx (15)
%
%   Outputs
%       fig - figure handle
%       T   - table, one row per peak/valley: x, value, type, part, fate
%
%   See also: findcropCore_xAxis, findCropWindow_xAxis, findLayerBoundaries_xAxis

    if nargin < 3, cropx = []; end
    if nargin < 4, ttl   = ''; end
    if nargin < 5, opts  = struct(); end
    if ~isfield(opts,'showLayers'),   opts.showLayers   = true; end
    if ~isfield(opts,'curvSmoothPx'), opts.curvSmoothPx = 15;   end

    x     = dbg.x;
    N     = numel(x);
    P     = dbg.pv_sort;
    nP    = size(P,1);
    parts = dbg.pv_sort_parts;
    nParts = size(parts,1);
    isCore = false(nParts,1);
    isCore(dbg.coreIdx(dbg.coreIdx >= 1 & dbg.coreIdx <= nParts)) = true;

    % ---- fate of every peak/valley ---------------------------------------
    part = zeros(nP,1);
    part(dbg.keptIdx) = dbg.partOfKept;
    fate = strings(nP,1);
    for r = 1:nP
        if part(r) == 0
            fate(r) = "removed: spacing";
        elseif dbg.merged(part(r))
            fate(r) = sprintf("merged into part %d", part(r));
        elseif isCore(part(r))
            fate(r) = sprintf("part %d: CORE", part(r));
        else
            fate(r) = sprintf("part %d: outer (removed by partsNoCore)", part(r));
        end
    end
    typ = repmat("valley", nP, 1);  typ(dbg.pvType > 0) = "peak";
    T = table(P(:,1), P(:,2), typ, part, fate, ...
        'VariableNames', {'x','value','type','part','fate'});

    % ---- figure -----------------------------------------------------------
    fig = figure('Color','w', 'Position',[80 80 1200 640]);
    tl  = tiledlayout(fig, 3, 1, 'TileSpacing','compact', 'Padding','compact');
    ax  = nexttile(tl, [2 1]); hold(ax,'on'); box(ax,'off');
    rg  = max(dbg.me_y) - min(dbg.me_y);
    yl  = [min(dbg.me_y) - 0.08*rg, max(dbg.me_y) + 0.15*rg];

    % physical layers behind
    if opts.showLayers && any(isCore)
        try
            B = findLayerBoundaries_xAxis(image, parts(isCore,:));
            cols = [0.93 0.93 0.93; 0.80 0.81 0.84; 0.85 0.88 0.93; ...
                    0.84 0.92 0.98; 0.98 0.92 0.82; 0.89 0.95 0.87];
            for k = 1:6
                if k < 6
                    spans = [B.edgesL(k), B.edgesL(k+1); B.edgesR(k+1), B.edgesR(k)];
                else
                    spans = [B.edgesL(6), B.edgesR(6)];
                end
                for s = 1:size(spans,1)
                    a = spans(s,1); c = spans(s,2);
                    if any(isnan([a c])) || c - a < 1, continue; end
                    patch(ax, [a c c a], yl([1 1 2 2]), cols(k,:), 'EdgeColor','none', ...
                        'HandleVisibility','off');
                    labelRegion(ax, a, c, yl, B.names{k}, N);
                end
            end
        catch me
            warning('plotTransitionStages: layers not shaded (%s)', me.message);
        end
    end

    plot(ax, x, dbg.me_y, '-', 'Color',[0.75 0.75 0.75], 'DisplayName','column mean');
    plot(ax, x, dbg.sm_y, 'k-', 'LineWidth',1, 'DisplayName','sgolay (used for detection)');

    isRem = part == 0;
    plot(ax, P(isRem,1), P(isRem,2), 'x', 'Color',[0.5 0.5 0.5], 'MarkerSize',5, ...
        'DisplayName', sprintf('removed by spacing (<= %g px)', dbg.pixDistTol));
    mrg = part > 0 & ismember(part, find(dbg.merged));
    if any(mrg)
        plot(ax, P(mrg,1), P(mrg,2), 'o', 'Color',[0.95 0.55 0.1], 'MarkerSize',5, ...
            'DisplayName','kept, then merged');
        plot(ax, parts(dbg.merged,1), parts(dbg.merged,2), 'd', 'Color',[0.95 0.55 0.1], ...
            'MarkerFaceColor',[0.95 0.55 0.1], 'MarkerSize',6, 'HandleVisibility','off');
    end
    plot(ax, parts(~isCore,1), parts(~isCore,2), 'o', 'Color',[0.85 0.15 0.15], ...
        'MarkerFaceColor',[0.85 0.15 0.15], 'MarkerSize',6, ...
        'DisplayName', sprintf('outer parts (removed, partsNoCore = %d)', dbg.partsNoCore));
    plot(ax, parts(isCore,1), parts(isCore,2), 'o', 'Color',[0.1 0.6 0.2], ...
        'MarkerFaceColor',[0.1 0.6 0.2], 'MarkerSize',6, 'DisplayName','core transitions (coreTrans)');

    % part numbers: above for peaks, below for valleys
    dy = 0.04*diff(yl);
    for n = 1:nParts
        isPeak = parts(n,2) >= dbg.sm_y(max(1,parts(n,1)-5)) && ...
                 parts(n,2) >= dbg.sm_y(min(N,parts(n,1)+5));
        text(ax, parts(n,1), parts(n,2) + dy*(2*isPeak-1), num2str(n), ...
            'HorizontalAlignment','center', 'FontSize',10, 'FontWeight','bold', ...
            'Color', ifelse(isCore(n), [0.1 0.5 0.15], [0.7 0.1 0.1]));
    end

    if ~isempty(cropx)
        xline(ax, cropx(1), 'b--', 'LineWidth',1.2, 'DisplayName','crop window');
        xline(ax, cropx(2), 'b--', 'LineWidth',1.2, 'HandleVisibility','off');
    end
    xlim(ax, [1 N]); ylim(ax, yl);
        ylabel(ax, 'Normalized intensity', 'FontSize',12);
    set(ax, 'Layer','top', 'TickDir','out', 'FontSize',10);
    plot(ax, [1 N N], [yl(2) yl(2) yl(1)], 'k-', 'LineWidth', ax.LineWidth, ...
        'Clipping','off', 'HandleVisibility','off');          % top/right frame, no ticks
    % if ~isempty(ttl), title(ax, ttl, 'Interpreter','none'); end
    hL = legend(ax, 'NumColumns',3, 'Box','off', 'FontSize',12);
    hL.Layout.Tile = 'south';                                  % centered under the figure

    % ---- curvature of attenuation ---------------------------------------
    ax2 = nexttile(tl); hold(ax2,'on'); box(ax2,'off');
    p   = dbg.me_y / max(dbg.me_y);
    A   = -log(max(p, eps));
    As  = smoothdata(A, 'gaussian', opts.curvSmoothPx);
    d2  = gradient(gradient(As));
    yline(ax2, 0, 'Color',[0.6 0.6 0.6]);
    plot(ax2, x, d2, 'k-');
    for n = 1:nParts
        xline(ax2, parts(n,1), ':', 'Color', ifelse(isCore(n), [0.1 0.6 0.2], [0.85 0.15 0.15]));
    end
    edge = round(0.02*N);                        % ignore the frame ends for limits
    lim  = max(abs(d2(edge:end-edge)));
    xlim(ax2, [1 N]); ylim(ax2, 1.1*[-lim lim]);
    xlabel(ax2, 'x (pixel)', 'FontSize',12); ylabel(ax2, 'd^2A/dx^2', 'FontSize',12);
    set(ax2, 'TickDir','out', 'FontSize',10);
    plot(ax2, [1 N N], 1.1*[lim lim -lim], 'k-', 'LineWidth', ax2.LineWidth, ...
        'Clipping','off', 'HandleVisibility','off');          % top/right frame, no ticks
    linkaxes([ax ax2], 'x');
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end

function labelRegion(ax, a, c, yl, name, N)
% same labels as plotCropProfile
    xm = (a + c)/2;
    if (c - a) < 0.02*N                        % too narrow (air): label outside, at the top
        text(ax, a-0.5, yl(2), name, 'HorizontalAlignment','right', ...
            'VerticalAlignment','middle', 'Rotation',90, 'FontSize',12, 'Clipping','off');
    elseif (c - a) < 0.15*N
        text(ax, xm, yl(2) - 0.02*diff(yl), name, 'Rotation',90, ...
            'HorizontalAlignment','right', 'VerticalAlignment','middle', 'FontSize',12);
    else
        text(ax, xm, yl(2) - 0.05*diff(yl), name, ...
            'HorizontalAlignment','center', 'VerticalAlignment','top', 'FontSize',12);
    end
end