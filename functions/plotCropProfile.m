function [fig, B] = plotCropProfile(image, cropx, B, ttl, opts)
%PLOTCROPPROFILE Column profile of a projection with the material layers shaded.
%
%   [fig, B] = plotCropProfile(image, cropx, B, ttl) plots the column-mean
%   profile of the projection (raw and smoothed), shades the layers crossed by
%   the X-rays (outside -> in)
%
%       Air | Carbon fibre | Al liner | Confining fluid | Sleeve | Core
%
%   on both sides, marks their boundaries and the crop window. B is the
%   boundary struct returned by findCropWindow_layers (2nd output), so the
%   figure shows exactly the boundaries used for the crop. The heat-shrink tube
%   between sleeve and core is not resolved and is included in the sleeve.
%
%   [fig, B] = plotCropProfile(image, cropx, [], ttl, opts) detects the
%   boundaries here with findLayerBoundaries_xAxis(image, [], opts).
%
%   Inputs
%       image - 2-D projection (normalized, e.g. normImage(image, Iair))
%       cropx - [xmin; xmax] crop window (findCropWindow_layers, 1st output)
%       B     - boundaries (findCropWindow_layers, 2nd output), or [] to detect
%       ttl   - figure title ('' for none)
%       opts  - optional, passed to findLayerBoundaries_xAxis when B = []
%
%   Outputs
%       fig - figure handle
%       B   - boundary struct used
%
%   See also: findCropWindow_layers, findLayerBoundaries_xAxis

    if nargin < 3, B    = [];       end
    if nargin < 4, ttl  = '';       end
    if nargin < 5, opts = struct(); end
    if ~isstruct(B)
        B = findLayerBoundaries_xAxis(image, [], opts);
    end

    p  = B.profile;
    N  = numel(p);
    x  = 1:N;
    ps = smoothdata(p, 'gaussian', 15);
    yl = [0, 1.2*max(p)];

    cols = [0.93 0.93 0.93;    % air
            0.72 0.74 0.78;    % carbon fibre
            0.82 0.86 0.92;    % aluminium liner
            0.80 0.90 0.98;    % confining fluid
            0.98 0.90 0.78;    % sleeve
            0.86 0.94 0.84];   % core

    fig = figure('Color','w', 'Position',[100 100 1000 430]);
    ax  = axes(fig); hold(ax,'on'); box(ax,'off');
    hReg = gobjects(1,6);

    % outer layers, both sides
    for k = 1:5
        spans = [B.edgesL(k),   B.edgesL(k+1);     % left:  edge -> inward
                 B.edgesR(k+1), B.edgesR(k)];      % right: inward -> edge
        for s = 1:2
            a = spans(s,1);  c = spans(s,2);
            if any(isnan([a c])) || c - a < 1, continue; end
            hReg(k) = patch(ax, [a c c a], [yl(1) yl(1) yl(2) yl(2)], cols(k,:), ...
                'EdgeColor','none', 'DisplayName', B.names{k});
            labelRegion(ax, a, c, yl, B.names{k}, N);
        end
    end
    % core
    a = B.edgesL(6);  c = B.edgesR(6);
    if all(~isnan([a c])) && c > a
        hReg(6) = patch(ax, [a c c a], [yl(1) yl(1) yl(2) yl(2)], cols(6,:), ...
            'EdgeColor','none', 'DisplayName', B.names{6});
        labelRegion(ax, a, c, yl, B.names{6}, N);
    end

    % profile, boundaries, crop
    hRaw = plot(ax, x, p,  'k-', 'LineWidth',0.5, 'DisplayName','Profile');
    xb = [B.edgesL(2:end), B.edgesR(2:end)];
    xb = xb(~isnan(xb) & xb > 1 & xb < N);
    hB = plot(ax, xb, interp1(x, ps, xb), 'o', 'MarkerSize',3, 'MarkerFaceColor','w', ...
        'MarkerEdgeColor','k', 'DisplayName','Boundary');
    hC = xline(ax, cropx, '--', 'Color',[0.9 0.1 0.1], 'LineWidth',1.5, ...
        'DisplayName', sprintf('Crop window (%d px)', cropx(2)-cropx(1)+1));

    xlim(ax, [1 N]); ylim(ax, yl);
    xlabel(ax, 'x (pixel)','FontSize',12); 
    ylabel(ax, 'Normalized intensity','FontSize',12);
    set(ax, 'Layer','top', 'TickDir','out');
    % if ~isempty(ttl), title(ax, ttl, 'Interpreter','none'); end

    hLeg = [hReg(isgraphics(hReg)), hRaw, hB, hC(1)];
    hL = legend(ax, hLeg, 'Location','southoutside', 'NumColumns',4, 'Box','off','FontSize',12);
    drawnow;                                   % let MATLAB place legend and axes
    ap = ax.Position;
    hL.Units = ax.Units;
    hL.Position(1) = ap(1) + (ap(3) - hL.Position(3))/2;   % centre under the axes
    ax.Position = ap;                          % keep the axes where they were
    hold(ax,'off');

    if any(isnan([B.edgesL B.edgesR]))
        warning('plotCropProfile:boundaryNotFound', ...
            'Some layer boundaries were not found (NaN); those regions are not shaded.');
    end
end

function labelRegion(ax, a, c, yl, name, N)
% vertical label for narrow regions, horizontal for wide ones (e.g. the core)
    xm = (a + c)/2;
    if (c - a) < 0.02*N                        % too narrow (air): label outside, left of the axes
        shiftPx = 0.5;                           % extra gap to the left [screen pixels]
        u = ax.Units;  ax.Units = 'pixels';  axW = ax.Position(3);  ax.Units = u;
        dx = shiftPx * N / axW;                % screen px -> data units
        text(ax, 1 - dx, yl(2), name, 'Rotation',90, ...
            'HorizontalAlignment','right', 'VerticalAlignment','bottom', ...
            'FontSize',12, 'Clipping','off');
    elseif (c - a) < 0.15*N
        text(ax, xm, yl(2) - 0.02*diff(yl), name, 'Rotation',90, ...
            'HorizontalAlignment','right', 'VerticalAlignment','middle', 'FontSize',12);
    else
        text(ax, xm, yl(2) - 0.05*diff(yl), name, ...
            'HorizontalAlignment','center', 'VerticalAlignment','top', 'FontSize',12);
    end
end