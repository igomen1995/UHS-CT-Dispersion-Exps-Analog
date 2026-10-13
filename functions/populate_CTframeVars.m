function frameVars = populate_CTframeVars(image, resXmm, resYmm, ...
    imgNr, rotPos, timeStamp, timeElapsed, secondsElapsed, volInjected, tDtotal, D, uint, Vlinesbefore, Cmin, Cmax)
% POPULATE_CTFRAMEVARS Compute profile, histogram, and front-tracking metrics
% for one concentration image. Works identically whether "image" is the
% raw rhoNorm image or the REFPROP-converted composition image.

    if nargin < 13 || isempty(Vlinesbefore), Vlinesbefore = 0; end
    if nargin < 14 || isempty(Cmin), Cmin = 0.1; end
    if nargin < 15 || isempty(Cmax), Cmax = 0.9; end

    % histogram
    numBins = 100;
    [counts, edges] = histcounts(image, numBins);

    % vertical (Z) profile
    concVert = mean(image');
    pixelVert = 1:length(concVert);
    zVertcm = pixelVert*resYmm/10;
    zDimLess = zVertcm/zVertcm(end);
    Lcm = zVertcm(end);

    % horizontal (X) profile
    concHorz = mean(image);
    pixelHorz = 1:length(concHorz);
    xHorzcm = pixelHorz*resXmm/10;

    % time the injected fluid has spent in the core (excludes inlet lines) ---
    tmin   = secondsElapsed/60;          % min since injection start
    Q      = volInjected / tmin;         % mL/min
    tLines = Vlinesbefore / Q;           % min, travel time through the inlet lines
    tcore  = max(tmin - tLines, 0);      % min since He reached the core inlet

    % geometric (crossing-based) front positions, consistent with
    % contour-map delineation, naturally NaN when a level isn't reached ---
    levels = [0.1 0.16 0.3 0.4 0.5 0.6 0.7 0.84 0.9];
    zLevels = nan(size(levels));
    for L = 1:length(levels)
        zLevels(L) = frontLevel1D(zDimLess, concVert, levels(L));
    end
    zAt = containers.Map(num2cell(levels), num2cell(zLevels));

    zDFront50 = zAt(0.5);   % single, well-defined center, consistent across all width pairs

    zDWidth_10_90 = zAt(0.1) - zAt(0.9);
    zDWidth_16_84 = zAt(0.16) - zAt(0.84);
    zDWidth_30_70 = zAt(0.3) - zAt(0.7);
    zDWidth_40_60 = zAt(0.4) - zAt(0.6);
    
    % theoretical (diffusion-only) widths and erfc constants k, on core time
    [k_10_90, w] = widthDiff(D, tcore*60, 0.1,  0.9 );  zDWidthDiff_10_90 = w/Lcm;
    [k_16_84, w] = widthDiff(D, tcore*60, 0.16, 0.84);  zDWidthDiff_16_84 = w/Lcm;
    [k_30_70, w] = widthDiff(D, tcore*60, 0.3,  0.7 );  zDWidthDiff_30_70 = w/Lcm;
    [k_40_60, w] = widthDiff(D, tcore*60, 0.4,  0.6 );  zDWidthDiff_40_60 = w/Lcm;

    % KL from real width measurement: W = 2*k*sqrt(KL*t) -> KL = W^2/(4*k^2*t)
    KL_CT_10_90 = (zDWidth_10_90*Lcm)^2 / (4*k_10_90^2*tcore);   % cm^2/min
    KL_CT_16_84 = (zDWidth_16_84*Lcm)^2 / (4*k_16_84^2*tcore);
    KL_CT_30_70 = (zDWidth_30_70*Lcm)^2 / (4*k_30_70^2*tcore);
    KL_CT_40_60 = (zDWidth_40_60*Lcm)^2 / (4*k_40_60^2*tcore);

    % theoretical (advective) front location, from interstitial velocity
    zDFront_theory = (uint * tcore) / Lcm;   % uint in cm/min

    % --- moment-based sigma/KL
    dCdz = gradient(concVert, zVertcm);
    w_spatial = -dCdz;
    frontStats = weightedMoments(zVertcm, w_spatial);
    
    zDMean    = frontStats.mean / Lcm;
    sigmaD    = frontStats.sigma / Lcm;
    skewFront = frontStats.skewness;
    kurtFront = frontStats.kurtosis;
    KL_CT_sigma = frontStats.sigma^2 / (2*tcore);   % cm^2/min

    frontInCore = (concVert(1) > 0) && (concVert(end) < 1);
    
    % tilt and shape geometry consistent with controur shape C = 0.5
    imgSmooth = imgaussfilt(double(image), 20);
    frontC05 = contourFront(imgSmooth, 0.5);
    tiltStats = getFrontTilt(frontC05);
    shapeStats = getFrontShapeMetrics(frontC05);

    % concentration interpolated at each zD level, zD=0 to zD=1
    zDlevels = 0:0.1:1;
    Cz = interp1(zDimLess, concVert, zDlevels, 'linear', 'extrap');

    % pack results
    frameVars.imgNr = imgNr;
    frameVars.rotPos = rotPos;
    frameVars.timeStamp = timeStamp;
    frameVars.timeElapsed = timeElapsed;
    frameVars.secondsElapsed = secondsElapsed;
    frameVars.volInjected = volInjected;
    frameVars.tDtotal = tDtotal;
    frameVars.tLines_min = tLines;
    frameVars.tcore_min = tcore;
    frameVars.histImage = table(counts', edges(1:end-1)', edges(2:end)', ...
        'VariableNames',{'counts','minEdge','maxEdge'});
    frameVars.C1Profile = table(zVertcm', zDimLess', concVert', ...
        'VariableNames',{'zVertcm','zDimLess','CVert'});
    frameVars.C1Axial = table(xHorzcm', concHorz', ...
        'VariableNames',{'xHorzcm','CHorz'});

    frameVars.zDFront50 = zDFront50;         % geometric center (crossing-based)

    frameVars.frontInCore = frontInCore;
    frameVars.zDMean = zDMean;
    frameVars.zDFront_theory = zDFront_theory;
    frameVars.sigmaD = sigmaD;
    frameVars.KL_CT_sigma = KL_CT_sigma;
    frameVars.skewFront = skewFront;
    frameVars.kurtFront = kurtFront;

    frameVars.frontTiltSlope = tiltStats.slope;
    frameVars.frontTiltR2 = tiltStats.R2;
    frameVars.frontArcLengthRatio = shapeStats.arcLengthRatio;

    frameVars.zDWidth_10_90 = zDWidth_10_90;   % geometric, NaN per-level automatically
    frameVars.zDWidth_16_84 = zDWidth_16_84;
    frameVars.zDWidth_30_70 = zDWidth_30_70;
    frameVars.zDWidth_40_60 = zDWidth_40_60;

    frameVars.zDWidthDiff_10_90 = zDWidthDiff_10_90;
    frameVars.zDWidthDiff_16_84 = zDWidthDiff_16_84;
    frameVars.zDWidthDiff_30_70 = zDWidthDiff_30_70;
    frameVars.zDWidthDiff_40_60 = zDWidthDiff_40_60;

    frameVars.KL_CT_10_90 = KL_CT_10_90;
    frameVars.KL_CT_16_84 = KL_CT_16_84;
    frameVars.KL_CT_30_70 = KL_CT_30_70;
    frameVars.KL_CT_40_60 = KL_CT_40_60;

    % per-zD concentration
    frameVars.CD1_zD0p0 = Cz(1);   % zD=0.0 -> inlet, was CD1inlet
    frameVars.CD1_zD0p1 = Cz(2);
    frameVars.CD1_zD0p2 = Cz(3);
    frameVars.CD1_zD0p3 = Cz(4);
    frameVars.CD1_zD0p4 = Cz(5);
    frameVars.CD1_zD0p5 = Cz(6);
    frameVars.CD1_zD0p6 = Cz(7);
    frameVars.CD1_zD0p7 = Cz(8);
    frameVars.CD1_zD0p8 = Cz(9);
    frameVars.CD1_zD0p9 = Cz(10);
    frameVars.CD1_zD1p0 = Cz(11);  % zD=1.0 -> outlet, was CD1
  
end
