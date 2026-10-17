function B = findLayerBoundaries_xAxis(image, coreTrans, opts)
%FINDLAYERBOUNDARIES_XAXIS Material boundaries in a projection of the core holder.
%
%   B = findLayerBoundaries_xAxis(image, coreTrans) finds, on each side of the
%   core, the boundaries between the layers crossed by the X-ray (outside -> in):
%
%       Air | Carbon fibre | Alumina | Confining fluid | Sleeve | Core
%
%   (the heat-shrink tube between sleeve and core is too thin to resolve and is
%   included in the sleeve). In a projection of concentric shells each pixel sees
%   ALL layers outside the radius its ray reaches, so boundaries are not simply the
%   peaks/valleys of the profile. They are found from what each layer does to the
%   profile:
%
%     Air -> carbon fibre   : end of the flat bright plateau at the image edge
%                             (may be absent on one side: then Air has zero width)
%     Carbon fibre -> alumina: strongest upward kink of the attenuation
%                             A = -ln(I/I_air) (the denser alumina starts adding
%                             path length, so dA/dx jumps up)
%     Alumina -> fluid      : last clear local MINIMUM of the intensity before the
%                             sleeve (the ray grazing the inner wall of the alumina
%                             has the longest path through it)
%     Fluid -> sleeve       : last clear local MAXIMUM before the core (the Viton
%                             starts absorbing, the intensity turns down)
%     Sleeve -> core        : core edge from findcropCore_xAxis (coreTrans)
%
%   Inputs
%       image     - 2-D projection (raw or normalized; only the shape matters)
%       coreTrans - core transitions from findCropWindow_xAxis (3rd output);
%                   coreTrans(1,1) / coreTrans(end,1) = left / right core edge
%       opts      - optional struct:
%                   .airTol   (0.02) air = within 2% of the brightest edge level
%                   .smoothPx (15)   Gaussian smoothing window of the profile [px]
%                   .guardPx  (40)   min distance of a detected feature from its
%                                    neighbouring boundary [px]
%                   .minProm  (0.01) min prominence of the local max/min, as a
%                                    fraction of the profile range on that side
%
%   Output B (struct)
%       .names    {'Air','Carbon fibre','Alumina','Confining fluid','Sleeve','Core'}
%       .edgesL   1x6 x-positions of the left edges, from the image edge inward:
%                 region k (k = 1..5) spans edgesL(k)..edgesL(k+1); core starts at edgesL(6)
%       .edgesR   1x6 same for the right side, from the image edge inward:
%                 region k spans edgesR(k+1)..edgesR(k); core ends at edgesR(6)
%       .profile  column-mean profile used
%       .airLevel brightest edge level (air)
%       NaN in an edge = that boundary was not found.
%
%   See also: findCropWindow_xAxis, findcropCore_xAxis, plotCropProfile

    if nargin < 3, opts = struct(); end
    opts = setDefault(opts, 'airTol',   0.02);
    opts = setDefault(opts, 'smoothPx', 15);
    opts = setDefault(opts, 'guardPx',  40);
    opts = setDefault(opts, 'minProm',  0.01);

    p = mean(double(image), 1);
    N = numel(p);
    airLevel = max([p(1:min(5,N)), p(max(1,N-4):N)]);           % brightest image edge = air

    bL = oneSide(p,          coreTrans(1,1),           airLevel, opts);
    bR = oneSide(fliplr(p),  N - coreTrans(end,1) + 1, airLevel, opts);

    B.names    = {'Air','Core holder: carbon fiber','Core holder: Al','Confining fluid','Sleeve','Core'};
    B.edgesL   = [0, bL] + 0.5;                % between pixel b and b+1
    B.edgesR   = N + 0.5 - [0, bR];            % mirrored back to image columns
    B.profile  = p;
    B.airLevel = airLevel;
end

% -------------------------------------------------------------------------
function b = oneSide(q, e, airLevel, o)
% q: profile ordered from the image edge toward the centre; e: first core pixel.
% b(1..5) = last pixel of Air, Carbon fibre, Alumina, Fluid, Sleeve.
    b  = nan(1,5);
    qs = smoothdata(q, 'gaussian', o.smoothPx);

    % 1) air: flat bright plateau touching the edge (zero width if absent)
    thr = (1 - o.airTol) * airLevel;
    if max(q(1:min(5,numel(q)))) >= thr
        k = find(qs < thr, 1, 'first');
        b(1) = max(k - 1, 0);
    else
        b(1) = 0;
    end

    % 5) sleeve -> core: core edge from the crop algorithm
    b(5) = e - 1;

    seg = qs(1:e);
    rng = max(seg(b(1)+1:end)) - min(seg(b(1)+1:end));

    % 4) fluid -> sleeve: last clear local maximum before the core
    iMax = find(islocalmax(seg, 'MinProminence', o.minProm*rng));
    iMax = iMax(iMax > b(1) + o.guardPx & iMax < e - o.guardPx);
    if ~isempty(iMax), b(4) = iMax(end); end

    % 3) alumina -> fluid: last clear local minimum before the sleeve
    if ~isnan(b(4))
        iMin = find(islocalmin(seg(1:b(4)), 'MinProminence', o.minProm*rng));
        iMin = iMin(iMin > b(1) + o.guardPx & iMin < b(4) - 1);
        if ~isempty(iMin), b(3) = iMin(end); end
    end

    % 2) carbon fibre -> alumina: strongest upward kink of A = -ln(I/I_air)
    if ~isnan(b(3))
        A  = -log(max(qs, eps) / airLevel);
        d2 = smoothdata(gradient(gradient(A)), 'gaussian', o.smoothPx);
        lo = b(1) + o.guardPx;
        hi = b(3) - o.guardPx;
        if hi > lo
            [~, k] = max(d2(lo:hi));
            b(2) = lo + k - 1;
        end
    end
end

function s = setDefault(s, f, v)
    if ~isfield(s, f) || isempty(s.(f)), s.(f) = v; end
end