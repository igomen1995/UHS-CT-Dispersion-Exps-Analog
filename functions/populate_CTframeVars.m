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
    zFront10 = frontZmean(image, 0.08, 0.12, resYmm);
    zFront90 = frontZmean(image, 0.88, 0.92, resYmm);
    zWidth = zFront10 - zFront90; % cm
    zWidthDiff = widthDiff(D, secondsElapsed, 0.1, 0.9); % cm
    [zFront50, front50_xcm, front50_zcm] = front50Evol(image, 0.48, 0.52, resXmm, resYmm);

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
    frameVars.zFront10 = zFront10;
    frameVars.zFront50 = zFront50;
    frameVars.zFront90 = zFront90;
    frameVars.front50_xcm = front50_xcm;
    frameVars.front50_zcm = front50_zcm;
    frameVars.zWidth = zWidth;
    frameVars.zWidthDiff = zWidthDiff;
    frameVars.CD1inlet = concVert(1); % inlet-side value -> BTlinesBefore
    frameVars.CD1 = concVert(end);     % outlet-side value -> BTcore
    
end
