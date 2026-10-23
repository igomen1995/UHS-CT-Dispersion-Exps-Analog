function frameVars = populate_CTframeVars(image, resXmm, resYmm, ...
    run_name, imgNr, rotPos, timeStamp, timeElapsed, secondsElapsed, tDtotal)
% POPULATE_CTFRAMEVARS  Per-frame front geometry for one concentration
% image: concentration-level positions (zD), per-x widths between
% levels (contour-based, regridded onto a common x so different levels
% can be subtracted pointwise), front tilt/shape, and the scalar front
% positions/widths derived from the same traced contours. Diffusion-
% time-dependent metrics (tcore, KL_CT_*) live in a separate function.

    [ny, nx] = size(image);
    smoothWindow = 7;   % columns; widen/narrow if a single stray pixel still sets the tip

    levels = [0.01 0.1 0.16 0.3 0.4 0.5 0.6 0.7 0.84 0.9];
    imgSmooth = imgaussfilt(double(image), 20);
    frontByLevelRaw = contourFront(imgSmooth, levels);   % needs the zDMean fix added earlier
    
    frontC001 = frontByLevelRaw(levels == 0.01);
    frontC01  = frontByLevelRaw(levels == 0.1);
    frontC016 = frontByLevelRaw(levels == 0.16);
    frontC03  = frontByLevelRaw(levels == 0.3);
    frontC04  = frontByLevelRaw(levels == 0.4);
    frontC05  = frontByLevelRaw(levels == 0.5);
    frontC06  = frontByLevelRaw(levels == 0.6);
    frontC07  = frontByLevelRaw(levels == 0.7);
    frontC084 = frontByLevelRaw(levels == 0.84);
    frontC09  = frontByLevelRaw(levels == 0.9);

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
    xDimLess = xHorzcm/xHorzcm(end);

    % regrid each level's raw contour point cloud onto the SAME xD grid
    % used by the horizontal profile (xDimLess), so different levels can
    % be subtracted/compared pointwise -- contourc's raw output is not
    % aligned to pixel columns and generally differs in length level to
    % level, so this step is required before any per-x width makes sense
    zDC10 = regridContourZ(frontC01,  xDimLess);
    zDC16 = regridContourZ(frontC016, xDimLess);
    zDC30 = regridContourZ(frontC03,  xDimLess);
    zDC40 = regridContourZ(frontC04,  xDimLess);
    zDC50 = regridContourZ(frontC05,  xDimLess);
    zDC60 = regridContourZ(frontC06,  xDimLess);
    zDC70 = regridContourZ(frontC07,  xDimLess);
    zDC84 = regridContourZ(frontC084, xDimLess);
    zDC90 = regridContourZ(frontC09,  xDimLess);

    zDWidthContour_10_90 = zDC10 - zDC90;
    zDWidthContour_16_84 = zDC16 - zDC84;
    zDWidthContour_30_70 = zDC30 - zDC70;  
    zDWidthContour_40_60 = zDC40 - zDC60; 

    % scalar front position per level
    zDFront01 = frontC001.zDMean;
    zDFront10 = frontC01.zDMean;
    zDFront16 = frontC016.zDMean;
    zDFront30 = frontC03.zDMean;
    zDFront40 = frontC04.zDMean;
    zDFront50 = frontC05.zDMean;
    zDFront60 = frontC06.zDMean;
    zDFront70 = frontC07.zDMean;
    zDFront84 = frontC084.zDMean;
    zDFront90 = frontC09.zDMean;

    zDFront10_cm = zDFront10*Lcm;
    zDFront16_cm = zDFront16*Lcm;
    zDFront30_cm = zDFront30*Lcm;
    zDFront40_cm = zDFront40*Lcm;
    zDFront50_cm = zDFront50*Lcm;
    zDFront60_cm = zDFront60*Lcm;
    zDFront70_cm = zDFront70*Lcm;
    zDFront84_cm = zDFront84*Lcm;
    zDFront90_cm = zDFront90*Lcm;

    zDWidth_10_90 = zDFront10 - zDFront90;
    zDWidth_16_84 = zDFront16 - zDFront84;
    zDWidth_30_70 = zDFront30 - zDFront70;   
    zDWidth_40_60 = zDFront40 - zDFront60;   

    zDWidth_10_90_cm = zDWidth_10_90*Lcm;
    zDWidth_16_84_cm = zDWidth_16_84*Lcm;
    zDWidth_30_70_cm = zDWidth_30_70*Lcm;   
    zDWidth_40_60_cm = zDWidth_40_60*Lcm;  

    [zDFront10_min, zDFront10_max] = robustFrontMinMax(frontC01,  nx, ny, smoothWindow);
    [zDFront16_min, zDFront16_max] = robustFrontMinMax(frontC016, nx, ny, smoothWindow);
    [zDFront30_min, zDFront30_max] = robustFrontMinMax(frontC03,  nx, ny, smoothWindow);
    [zDFront40_min, zDFront40_max] = robustFrontMinMax(frontC04,  nx, ny, smoothWindow);
    [zDFront50_min, zDFront50_max] = robustFrontMinMax(frontC05,  nx, ny, smoothWindow);
    [zDFront60_min, zDFront60_max] = robustFrontMinMax(frontC06,  nx, ny, smoothWindow);
    [zDFront70_min, zDFront70_max] = robustFrontMinMax(frontC07,  nx, ny, smoothWindow);
    [zDFront84_min, zDFront84_max] = robustFrontMinMax(frontC084, nx, ny, smoothWindow);
    [zDFront90_min, zDFront90_max] = robustFrontMinMax(frontC09,  nx, ny, smoothWindow);

    zDFront10_min_cm = zDFront10_min*Lcm; zDFront10_max_cm = zDFront10_max*Lcm;
    zDFront16_min_cm = zDFront16_min*Lcm; zDFront16_max_cm = zDFront16_max*Lcm;
    zDFront30_min_cm = zDFront30_min*Lcm; zDFront30_max_cm = zDFront30_max*Lcm;
    zDFront40_min_cm = zDFront40_min*Lcm; zDFront40_max_cm = zDFront40_max*Lcm;
    zDFront50_min_cm = zDFront50_min*Lcm; zDFront50_max_cm = zDFront50_max*Lcm;
    zDFront60_min_cm = zDFront60_min*Lcm; zDFront60_max_cm = zDFront60_max*Lcm;
    zDFront70_min_cm = zDFront70_min*Lcm; zDFront70_max_cm = zDFront70_max*Lcm;
    zDFront84_min_cm = zDFront84_min*Lcm; zDFront84_max_cm = zDFront84_max*Lcm;
    zDFront90_min_cm = zDFront90_min*Lcm; zDFront90_max_cm = zDFront90_max*Lcm;

    % tilt/shape for C=0.5
    tiltStats  = getFrontTilt(frontC05);
    shapeStats = getFrontShapeMetrics(frontC05);

    % concentration interpolated at each zD level, zD=0 to zD=1
    zDlevels = 0:0.1:1;
    Cz = interp1(zDimLess, concVert, zDlevels, 'linear', 'extrap');

    % pack results
    frameVars.runName = run_name;
    frameVars.imgNr = imgNr;
    frameVars.rotPos = rotPos;
    frameVars.timeStamp = timeStamp;
    frameVars.timeElapsed = timeElapsed;
    frameVars.secondsElapsed = secondsElapsed;
    frameVars.tDtotal = tDtotal;

    frameVars.histImage = table(counts', edges(1:end-1)', edges(2:end)', ...
        'VariableNames',{'counts','minEdge','maxEdge'});
    frameVars.C1Profile = table(zVertcm', zDimLess', concVert', ...
        'VariableNames',{'zVertcm','zDimLess','CVert'});
    frameVars.C1Axial = table(xHorzcm', xDimLess', concHorz', ...
        zDC10', zDC16', zDC30', zDC40', zDC50', zDC60', zDC70', zDC84', zDC90', ...
        zDWidthContour_10_90', zDWidthContour_16_84', zDWidthContour_30_70', zDWidthContour_40_60', ...
        'VariableNames',{'xHorzcm','xDimLess','CHorz','zDContour10','zDContour16', ...
        'zDContour30','zDContour40','zDContour50','zDContour60','zDContour70', ...
        'zDContour84','zDContour90','zDWidthContour_10_90','zDWidthContour_16_84', ...
        'zDWidthContour_30_70','zDWidthContour_40_60'});

    frameVars.zDFront01 = zDFront01;
    frameVars.zDFront10 = zDFront10;
    frameVars.zDFront16 = zDFront16;
    frameVars.zDFront30 = zDFront30;
    frameVars.zDFront40 = zDFront40;
    frameVars.zDFront50 = zDFront50;
    frameVars.zDFront60 = zDFront60;
    frameVars.zDFront70 = zDFront70;
    frameVars.zDFront84 = zDFront84;
    frameVars.zDFront90 = zDFront90;

    frameVars.zDFront10_cm = zDFront10_cm;
    frameVars.zDFront16_cm = zDFront16_cm;
    frameVars.zDFront30_cm = zDFront30_cm;
    frameVars.zDFront40_cm = zDFront40_cm;
    frameVars.zDFront50_cm = zDFront50_cm;
    frameVars.zDFront60_cm = zDFront60_cm;
    frameVars.zDFront70_cm = zDFront70_cm;
    frameVars.zDFront84_cm = zDFront84_cm;
    frameVars.zDFront90_cm = zDFront90_cm;

    frameVars.zDWidth_10_90 = zDWidth_10_90;
    frameVars.zDWidth_16_84 = zDWidth_16_84;
    frameVars.zDWidth_30_70 = zDWidth_30_70;
    frameVars.zDWidth_40_60 = zDWidth_40_60;

    frameVars.zDWidth_10_90_cm = zDWidth_10_90_cm;
    frameVars.zDWidth_16_84_cm = zDWidth_16_84_cm;
    frameVars.zDWidth_30_70_cm = zDWidth_30_70_cm;
    frameVars.zDWidth_40_60_cm = zDWidth_40_60_cm;

    frameVars.zDFront10_min = zDFront10_min; frameVars.zDFront10_max = zDFront10_max;
    frameVars.zDFront16_min = zDFront16_min; frameVars.zDFront16_max = zDFront16_max;
    frameVars.zDFront30_min = zDFront30_min; frameVars.zDFront30_max = zDFront30_max;
    frameVars.zDFront40_min = zDFront40_min; frameVars.zDFront40_max = zDFront40_max;
    frameVars.zDFront50_min = zDFront50_min; frameVars.zDFront50_max = zDFront50_max;
    frameVars.zDFront60_min = zDFront60_min; frameVars.zDFront60_max = zDFront60_max;
    frameVars.zDFront70_min = zDFront70_min; frameVars.zDFront70_max = zDFront70_max;
    frameVars.zDFront84_min = zDFront84_min; frameVars.zDFront84_max = zDFront84_max;
    frameVars.zDFront90_min = zDFront90_min; frameVars.zDFront90_max = zDFront90_max;

    frameVars.zDFront10_min_cm = zDFront10_min_cm; frameVars.zDFront10_max_cm = zDFront10_max_cm;
    frameVars.zDFront16_min_cm = zDFront16_min_cm; frameVars.zDFront16_max_cm = zDFront16_max_cm;
    frameVars.zDFront30_min_cm = zDFront30_min_cm; frameVars.zDFront30_max_cm = zDFront30_max_cm;
    frameVars.zDFront40_min_cm = zDFront40_min_cm; frameVars.zDFront40_max_cm = zDFront40_max_cm;
    frameVars.zDFront50_min_cm = zDFront50_min_cm; frameVars.zDFront50_max_cm = zDFront50_max_cm;
    frameVars.zDFront60_min_cm = zDFront60_min_cm; frameVars.zDFront60_max_cm = zDFront60_max_cm;
    frameVars.zDFront70_min_cm = zDFront70_min_cm; frameVars.zDFront70_max_cm = zDFront70_max_cm;
    frameVars.zDFront84_min_cm = zDFront84_min_cm; frameVars.zDFront84_max_cm = zDFront84_max_cm;
    frameVars.zDFront90_min_cm = zDFront90_min_cm; frameVars.zDFront90_max_cm = zDFront90_max_cm;

    % per-zD concentration
    frameVars.CD1_zD0p0 = Cz(1);
    frameVars.CD1_zD0p1 = Cz(2);
    frameVars.CD1_zD0p2 = Cz(3);
    frameVars.CD1_zD0p3 = Cz(4);
    frameVars.CD1_zD0p4 = Cz(5);
    frameVars.CD1_zD0p5 = Cz(6);
    frameVars.CD1_zD0p6 = Cz(7);
    frameVars.CD1_zD0p7 = Cz(8);
    frameVars.CD1_zD0p8 = Cz(9);
    frameVars.CD1_zD0p9 = Cz(10);
    frameVars.CD1_zD1p0 = Cz(11);

    frameVars.frontTiltSlope = tiltStats.slope;
    frameVars.frontTiltR2 = tiltStats.R2;
    frameVars.frontArcLengthRatio = shapeStats.arcLengthRatio;
end

function zOnGrid = regridContourZ(frontEntry, xDgrid)
% Put one level's raw, unordered contour point cloud onto a common xD
% grid via linear interpolation, so different levels can be compared or
% subtracted pointwise. NaN wherever that level's front doesn't reach
% that x yet (or the contour doesn't extend there).
    if frontEntry.isEmpty
        zOnGrid = nan(size(xDgrid));
        return
    end
    [xs, idx] = sort(frontEntry.xDContour);
    zs = frontEntry.zDContour(idx);
    [xs, uidx] = unique(xs, 'stable');   % interp1 needs strictly unique x
    zs = zs(uidx);
    zOnGrid = interp1(xs, zs, xDgrid, 'linear', NaN);
end

function [zMinVal, zMaxVal] = robustFrontMinMax(frontEntry, nx, ny, smoothWindow)
% Trailing (min) and leading (max) tip of one level's front, from a
% per-column profile smoothed along x before taking the extremum --
% unlike a raw min/max over the pooled contour point cloud, one noisy
% pixel can't single-handedly set the reported tip.
    if frontEntry.isEmpty
        zMinVal = NaN;
        zMaxVal = NaN;
        return
    end
    profile = contourProfileByColumn(frontEntry.xContour_px, frontEntry.zContour_px, nx, ny);
    zMaxSmooth = movmedian(profile.zDmax, smoothWindow, 'omitnan');
    zMinSmooth = movmedian(profile.zDmin, smoothWindow, 'omitnan');
    zMaxVal = max(zMaxSmooth, [], 'omitnan');
    zMinVal = min(zMinSmooth, [], 'omitnan');
end

function frontProfile = contourProfileByColumn(xContour_px, zContour_px, nx, ny)
% Bin raw contourc points into per-pixel-column x bins -- a column with
% more than one crossing (fold-back/overhang) keeps both its min and max
% instead of averaging them away.
    xBin = min(max(round(xContour_px), 1), nx);
    zMean = nan(nx,1); zMin = nan(nx,1); zMax = nan(nx,1); nPts = zeros(nx,1);
    for xc = 1:nx
        zc = zContour_px(xBin == xc);
        if ~isempty(zc)
            zMean(xc) = mean(zc);
            zMin(xc)  = min(zc);
            zMax(xc)  = max(zc);
            nPts(xc)  = numel(zc);
        end
    end
    frontProfile = table((1:nx)'/nx, zMean/ny, zMin/ny, zMax/ny, nPts, ...
        'VariableNames', {'xD','zDmean','zDmin','zDmax','nPts'});
end