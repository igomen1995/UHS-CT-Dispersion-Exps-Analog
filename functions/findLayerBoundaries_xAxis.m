function B = findLayerBoundaries_xAxis(image, coreTrans, opts)
%FINDLAYERBOUNDARIES_XAXIS Material boundaries in a projection of the core holder.
%
%   B = findLayerBoundaries_xAxis(image)            detects ALL boundaries, core edge included
%   B = findLayerBoundaries_xAxis(image, coreTrans) takes the core edge from coreTrans
%   B = findLayerBoundaries_xAxis(image, [], opts)  with options
%
%   Finds, on each side of the core, the boundaries between the layers crossed by
%   the X-ray (outside -> in):
%
%       Air | Carbon fibre | Al liner | Confining fluid | Sleeve | Core
%
%   (the heat-shrink tube between sleeve and core is too thin to resolve and is
%   included in the sleeve). In a projection of concentric shells each pixel sees
%   ALL layers outside the radius its ray reaches, so a boundary shows up as a
%   corner (kink) or a turning point of the profile. Each side is scanned from the
%   image edge inward:
%
%     Air -> carbon fibre  : end of the flat bright plateau at the image edge
%                            (may be absent on one side: then Air has zero width)
%     Al liner -> fluid    : FIRST clear local MINIMUM of the intensity from the edge
%                            (the ray grazing the inner wall of the Al liner has the
%                            longest path through it)
%     Fluid -> sleeve      : first clear local MAXIMUM after that minimum
%                            (the Viton starts absorbing, the intensity turns down)
%     Sleeve -> core       : sharpest corner of the (unsmoothed) intensity within
%                            sleeveMaxPx after the fluid maximum = largest jump
%                            between the slopes fitted over cornerPx px before and
%                            after each x (the ray grazing the inner wall of the
%                            sleeve). Tested on synthetic shells: ~4 px inside the
%                            true edge, independent of whether the core attenuates
%                            more or less than the Viton.
%                            If coreTrans is given, its first/last x is used instead.
%     Carbon fibre -> Al   : strongest upward kink of the attenuation
%                            A = -ln(I/I_air) between air and the Al minimum (the
%                            denser Al starts adding path length, so dA/dx jumps up)
%
%   Inputs
%       image     - 2-D projection (raw or normalized; only the shape matters)
%       coreTrans - (optional) [] to detect the core edge here, or the core
%                   transitions of findCropWindow_xAxis (3rd output)
%       opts      - optional struct:
%                   .airTol       (0.02) air = within 2% of the brightest edge level
%                   .smoothPx     (15)   Gaussian smoothing of the profile [px]
%                   .cornerPx     (10)   half-window of the slope-jump corner detector [px]
%                   .guardPx      (40)   min distance of a feature from the previous
%                                        boundary [px]
%                   .minProm      (0.01) min prominence of the Al min / fluid max, as a
%                                        fraction of the profile range on that side
%                   .sleeveMaxPx  (300)  search window for the core edge after the
%                                        fluid maximum [px]
%
%   Output B (struct)
%       .names    {'Air','Carbon fibre','Al liner','Confining fluid','Sleeve','Core'}
%       .edgesL   1x6 x-positions of the left edges, from the image edge inward:
%                 region k (k = 1..5) spans edgesL(k)..edgesL(k+1); core starts at edgesL(6)
%       .edgesR   1x6 same for the right side, from the image edge inward:
%                 region k spans edgesR(k+1)..edgesR(k); core ends at edgesR(6)
%       .coreX    [first last] core pixel (NaN if not found)
%       .profile  column-mean profile used
%       .airLevel brightest edge level (air)
%       NaN in an edge = that boundary was not found.
%
%   See also: findCropWindow_layers, findCropWindow_xAxis, plotCropProfile

    if nargin < 2, coreTrans = []; end
    if nargin < 3, opts = struct(); end
    opts = setDefault(opts, 'airTol',       0.02);
    opts = setDefault(opts, 'smoothPx',     15);
    opts = setDefault(opts, 'cornerPx',     10);
    opts = setDefault(opts, 'guardPx',      40);
    opts = setDefault(opts, 'minProm',      0.01);
    opts = setDefault(opts, 'sleeveMaxPx',  300);

    p = mean(double(image), 1);
    N = numel(p);
    airLevel = max([p(1:min(5,N)), p(max(1,N-4):N)]);           % brightest image edge = air

    if isempty(coreTrans)
        eL = [];  eR = [];
    else
        eL = coreTrans(1,1);  eR = N - coreTrans(end,1) + 1;    % first core pixel from each edge
    end
    bL = oneSide(p,         eL, airLevel, opts);
    bR = oneSide(fliplr(p), eR, airLevel, opts);

    B.names    = {'Air','CH: carbon fiber','CH: Al liner','Confining fluid','Sleeve','Core'};
    B.edgesL   = [0, bL] + 0.5;                % between pixel b and b+1
    B.edgesR   = N + 0.5 - [0, bR];            % mirrored back to image columns
    B.coreX    = [bL(5) + 1, N - bR(5)];       % first and last core pixel
    B.profile  = p;
    B.airLevel = airLevel;
end

% -------------------------------------------------------------------------
function b = oneSide(q, e, airLevel, o)
% q: profile ordered from the image edge toward the centre.
% e: first core pixel ([] = detect it).
% b(1..5) = last pixel of Air, Carbon fibre, Al liner, Fluid, Sleeve.
    b    = nan(1,5);
    half = floor(numel(q)/2);
    qs   = smoothdata(q, 'gaussian', o.smoothPx);

    % 1) air: flat bright plateau touching the edge (zero width if absent)
    thr = (1 - o.airTol) * airLevel;
    if max(q(1:min(5,numel(q)))) >= thr
        k = find(qs < thr, 1, 'first');
        b(1) = max(k - 1, 0);
    else
        b(1) = 0;
    end

    seg = qs(1:half);
    rng = max(seg(b(1)+1:end)) - min(seg(b(1)+1:end));

    % 3) Al liner -> fluid: first clear local minimum from the edge
    iMin = find(islocalmin(seg, 'MinProminence', o.minProm*rng));
    iMin = iMin(iMin > b(1) + o.guardPx);
    if isempty(iMin), return; end
    b(3) = iMin(1);

    % 4) fluid -> sleeve: first clear local maximum after it
    iMax = find(islocalmax(seg, 'MinProminence', o.minProm*rng));
    iMax = iMax(iMax > b(3) + o.guardPx/2);
    if ~isempty(iMax), b(4) = iMax(1); end

    % 5) sleeve -> core
    if ~isempty(e)
        b(5) = e - 1;
    elseif ~isnan(b(4))
        % sharpest corner = largest jump between the least-squares slopes of
        % the cornerPx pixels before and after each x (abs: works whether the
        % core attenuates more or less than the sleeve)
        w  = o.cornerPx;
        t  = (1:w) - (w+1)/2;
        kS = t / sum(t.^2);                        % LS slope kernel
        lo = max(b(4) + o.guardPx, w + 1);
        hi = min([b(4) + o.sleeveMaxPx, half, numel(q) - w]);
        if hi > lo
            sj = zeros(1, hi - lo + 1);
            for ii = lo:hi
                sj(ii-lo+1) = abs(kS*q(ii+1:ii+w).' - kS*q(ii-w:ii-1).');
            end
            [~, k] = max(sj);
            b(5) = lo + k - 2;                     % corner = first core pixel -> last sleeve pixel
        end
    end

    % 2) carbon fibre -> Al liner: strongest upward kink of A = -ln(I/I_air)
    A  = -log(max(qs, eps) / airLevel);
    d2 = smoothdata(gradient(gradient(A)), 'gaussian', o.smoothPx);
    lo = b(1) + o.guardPx;
    hi = b(3) - o.guardPx;
    if hi > lo
        [~, k] = max(d2(lo:hi));
        b(2) = lo + k - 1;
    end
end

function s = setDefault(s, f, v)
    if ~isfield(s, f) || isempty(s.(f)), s.(f) = v; end
end