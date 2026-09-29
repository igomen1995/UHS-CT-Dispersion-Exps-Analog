function frameVars = populate_CTframeVars(image, resXmm, resYmm, ...
    imgNr, rotPos, timeStamp, timeElapsed, secondsElapsed, volInjected, tDtotal, D, uint)
% POPULATE_CTFRAMEVARS Compute profile, histogram, and front-tracking metrics
% for one concentration image. Works identically whether "image" is the
% raw rhoNorm image or the REFPROP-converted composition image.

    % histogram
    numBins = 100;
    [counts, edges] = histcounts(image, numBins);

    % vertical (Z) profile
    concVert = mean(image');
    pixelVert = 1:length(concVert);
    zVertcm = pixelVert*resYmm/10;
    zDimLess = zVertcm/zVertcm(end);

    % horizontal (X) profile
    concHorz = mean(image);
    pixelHorz = 1:length(concHorz);
    xHorzcm = pixelHorz*resXmm/10;

    % fronts
    dCdz = gradient(concVert, zVertcm);
    w_spatial = -dCdz;   % pulse: C decreases with z (inlet at z=0)
    frontStats = weightedMoments(zVertcm, w_spatial);
    
    zDMean   = frontStats.mean / zVertcm(end);
    sigmaD   = frontStats.sigma / zVertcm(end);
    skewFront = frontStats.skewness;
    kurtFront = frontStats.kurtosis;
    
    % per-scan CT-derived dispersion coefficient, directly comparable to D
    KL_CT_cm2s = frontStats.sigma^2 / (2*secondsElapsed); % cm2/s
    KL_CT = KL_CT_cm2s*60;    % cm2/min

    % Diff theory
    D_cm2min = D;

    % widths for any C1,C2 pair, all from the same sigma
    widthFromSigma = @(C1,C2) 2*sigmaD*(erfcinv(2*C1) - erfcinv(2*C2));

    zDWidth_10_90 = widthFromSigma(0.1, 0.9);
    zDWidth_16_84 = widthFromSigma(0.16, 0.84);
    zDWidth_30_70 = widthFromSigma(0.3, 0.7);
    zDWidth_40_60 = widthFromSigma(0.4, 0.6);
    
    zDWidthDiff_10_90 = widthDiff(D, secondsElapsed, 0.1, 0.9) / zVertcm(end);
    zDWidthDiff_16_84 = widthDiff(D, secondsElapsed, 0.16, 0.84) / zVertcm(end);
    zDWidthDiff_30_70 = widthDiff(D, secondsElapsed, 0.3, 0.7) / zVertcm(end);
    zDWidthDiff_40_60 = widthDiff(D, secondsElapsed, 0.4, 0.6) / zVertcm(end);

    % theoretical (advective) front location, from interstitial velocity
    zDFront_theory = (uint * secondsElapsed/60) / zVertcm(end); % uint in cm2/min

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
    frameVars.histImage = table(counts', edges(1:end-1)', edges(2:end)', ...
        'VariableNames',{'counts','minEdge','maxEdge'});
    frameVars.C1Profile = table(zVertcm', zDimLess', concVert', ...
        'VariableNames',{'zVertcm','zDimLess','CVert'});
    frameVars.C1Axial = table(xHorzcm', concHorz', ...
        'VariableNames',{'xHorzcm','CHorz'});

    frameVars.zDMean = zDMean;              
    frameVars.zDFront_theory = zDFront_theory;
    frameVars.sigmaD = sigmaD;
    frameVars.KL_CT = KL_CT;
    frameVars.Diff = D_cm2min;
    frameVars.skewFront = skewFront;
    frameVars.kurtFront = kurtFront;

    frameVars.zDWidth_10_90 = zDWidth_10_90;
    frameVars.zDWidth_16_84 = zDWidth_16_84;
    frameVars.zDWidth_30_70 = zDWidth_30_70;
    frameVars.zDWidth_40_60 = zDWidth_40_60;

    frameVars.zDWidthDiff_10_90 = zDWidthDiff_10_90;
    frameVars.zDWidthDiff_16_84 = zDWidthDiff_16_84;
    frameVars.zDWidthDiff_30_70 = zDWidthDiff_30_70;
    frameVars.zDWidthDiff_40_60 = zDWidthDiff_40_60;

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
