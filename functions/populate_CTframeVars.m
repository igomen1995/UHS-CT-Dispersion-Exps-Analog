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
    zDFront10 = frontLevel1D(zDimLess, concVert, 0.1);
    zDFront16 = frontLevel1D(zDimLess, concVert, 0.16);
    zDFront30 = frontLevel1D(zDimLess, concVert, 0.3);
    zDFront40 = frontLevel1D(zDimLess, concVert, 0.4);
    zDFront50 = frontLevel1D(zDimLess, concVert, 0.5);
    zDFront60 = frontLevel1D(zDimLess, concVert, 0.6);
    zDFront70 = frontLevel1D(zDimLess, concVert, 0.7);
    zDFront84 = frontLevel1D(zDimLess, concVert, 0.84);
    zDFront90 = frontLevel1D(zDimLess, concVert, 0.9);
    
    zDWidth_10_90 = zDFront10 - zDFront90;
    zDWidth_16_84 = zDFront16 - zDFront84;
    zDWidth_30_70 = zDFront30 - zDFront70;
    zDWidth_40_60 = zDFront40 - zDFront60;
    
    zDWidthDiff_10_90 = widthDiff(D, secondsElapsed, 0.1, 0.9) / zVertcm(end);
    zDWidthDiff_16_84 = widthDiff(D, secondsElapsed, 0.16, 0.84) / zVertcm(end);
    zDWidthDiff_30_70 = widthDiff(D, secondsElapsed, 0.3, 0.7) / zVertcm(end);
    zDWidthDiff_40_60 = widthDiff(D, secondsElapsed, 0.4, 0.6) / zVertcm(end);

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
