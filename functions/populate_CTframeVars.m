function frameVars = populate_CTframeVars(image, resXmm, resYmm, ...
    imgNr, rotPos, timeStamp, timeElapsed, secondsElapsed, volInjected, tDtotal, D)
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
    ny = size(image,1);
    levels = [0.1 0.16 0.3 0.4 0.5 0.6 0.7 0.84 0.9];
    imgSmooth = imgaussfilt(image, 20);
    fronts = contourFront(imgSmooth, levels);
    zDat = @(lvl) fronts([fronts.level] == lvl).zMean_px / ny;
    zDFront50 = zDat(0.5);   % the tracked center point
    
    widthPairs = [0.1 0.9; 0.16 0.84; 0.3 0.7; 0.4 0.6];
    zDWidth_10_90 = zDat(0.1) - zDat(0.9);
    zDWidth_16_84 = zDat(0.16) - zDat(0.84);
    zDWidth_30_70 = zDat(0.3) - zDat(0.7);
    zDWidth_40_60 = zDat(0.4) - zDat(0.6);

    zDWidthDiff_10_90 = widthDiff(D, secondsElapsed, 0.1, 0.9) / zVertcm(end);
    zDWidthDiff_16_84 = widthDiff(D, secondsElapsed, 0.16, 0.84) / zVertcm(end);
    zDWidthDiff_30_70 = widthDiff(D, secondsElapsed, 0.3, 0.7) / zVertcm(end);
    zDWidthDiff_40_60 = widthDiff(D, secondsElapsed, 0.4, 0.6) / zVertcm(end);

    % C=0.5 contour geometry - dimensionless
    f50 = fronts([fronts.level] == 0.5);
    front50_xD = f50.xDContour;
    front50_zD = f50.zDContour;

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

    frameVars.zDFront50 = zDFront50;
    frameVars.front50_xD = front50_xD;
    frameVars.front50_zD = front50_zD;

    frameVars.zDWidth_10_90 = zDWidth_10_90;
    frameVars.zDWidth_16_84 = zDWidth_16_84;
    frameVars.zDWidth_30_70 = zDWidth_30_70;
    frameVars.zDWidth_40_60 = zDWidth_40_60;

    frameVars.zDWidthDiff_10_90 = zDWidthDiff_10_90;
    frameVars.zDWidthDiff_16_84 = zDWidthDiff_16_84;
    frameVars.zDWidthDiff_30_70 = zDWidthDiff_30_70;
    frameVars.zDWidthDiff_40_60 = zDWidthDiff_40_60;

    frameVars.CD1inlet = concVert(1); % inlet-side value -> BTlinesBefore
    frameVars.CD1 = concVert(end);  % outlet-side value -> BTcore    
end
