function frameVars = populate_CTframeVars(image, resXmm, resYmm, ...
    run_name, imgNr, rotPos, timeStamp, timeElapsed, secondsElapsed, tDtotal, ...
    levels, xDRangeAvg)

    if nargin < 12 || isempty(xDRangeAvg), xDRangeAvg = [0 1]; end
    
    [ny, nx] = size(image);
    smoothWindow = 7;   % columns; widen/narrow if a single stray pixel still sets the tip
    
    imgSmooth = imgaussfilt(double(image), 20);
    frontByLevelRaw = contourFront(imgSmooth, levels);   % frontByLevelRaw(i) <-> levels(i), same order
    
    % histogram
    numBins = 100;
    [counts, edges] = histcounts(image, numBins);
    
    % horizontal (X) profile
    concHorz = mean(image);
    pixelHorz = 1:length(concHorz);
    xHorzcm = pixelHorz*resXmm/10;
    xDimLess = xHorzcm/xHorzcm(end);
    
    % vertical (Z) profile
    concVert = mean(image');
    pixelVert = 1:length(concVert);
    zVertcm = pixelVert*resYmm/10;
    zDimLess = zVertcm/zVertcm(end);
    Lcm = zVertcm(end);
    
    xMaskTrim = xDimLess >= xDRangeAvg(1) & xDimLess <= xDRangeAvg(2);
    if ~any(xMaskTrim)
        warning('populate_CTframeVars: xDRangeAvg selects no columns -- falling back to full x-range for CVert_xtrim.');
        xMaskTrim = true(size(xDimLess));
    end
    concVert_xtrim = mean(image(:, xMaskTrim), 2)';

    % concentration interpolated at fixed zD = 0:0.1:1 (unrelated to `levels`)
    zDlevels = 0:0.1:1;
    Cz = interp1(zDimLess, concVert, zDlevels, 'linear', 'extrap');
    Cz_xtrim = interp1(zDimLess, concVert_xtrim, zDlevels, 'linear', 'extrap');
    
    % pack remaining results
    frameVars.runName       = run_name;
    frameVars.imgNr         = imgNr;
    frameVars.rotPos        = rotPos;
    frameVars.timeStamp     = timeStamp;
    frameVars.timeElapsed   = timeElapsed;
    frameVars.secondsElapsed = secondsElapsed;
    frameVars.tDtotal       = tDtotal;
    
    frameVars.histImage = table(counts', edges(1:end-1)', edges(2:end)', ...
        'VariableNames',{'counts','minEdge','maxEdge'});
    frameVars.C1Profile = table(zVertcm', zDimLess', concVert', concVert_xtrim', ...
        'VariableNames',{'zVertcm','zDimLess','CVert','CVert_xtrim'});
    
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
    
    frameVars.CD1_zD0p0_xtrim = Cz_xtrim(1);
    frameVars.CD1_zD0p1_xtrim = Cz_xtrim(2);
    frameVars.CD1_zD0p2_xtrim = Cz_xtrim(3);
    frameVars.CD1_zD0p3_xtrim = Cz_xtrim(4);
    frameVars.CD1_zD0p4_xtrim = Cz_xtrim(5);
    frameVars.CD1_zD0p5_xtrim = Cz_xtrim(6);
    frameVars.CD1_zD0p6_xtrim = Cz_xtrim(7);
    frameVars.CD1_zD0p7_xtrim = Cz_xtrim(8);
    frameVars.CD1_zD0p8_xtrim = Cz_xtrim(9);
    frameVars.CD1_zD0p9_xtrim = Cz_xtrim(10);
    frameVars.CD1_zD1p0_xtrim = Cz_xtrim(11);
    
    % per-level pass -- everything that used to be one hand-written line per level
    nLevels = numel(levels);
    levelTag = strings(1,nLevels);
    
    zDFront          = nan(1,nLevels);
    zDFront_cm       = nan(1,nLevels);
    zDFront_xtrim    = nan(1,nLevels);
    zDFront_xtrim_cm = nan(1,nLevels);
    zDFront_min      = nan(1,nLevels);
    zDFront_max      = nan(1,nLevels);
    zDFront_min_cm   = nan(1,nLevels);
    zDFront_max_cm   = nan(1,nLevels);
    zDContourOnGrid  = nan(length(xDimLess), nLevels);
    
    for i = 1:nLevels
        lvl = levels(i);
        levelTag(i) = sprintf('%02d', round(lvl*100));
        entry = frontByLevelRaw(i);
    
        zDFront(i)    = contourZMeanInROI(entry, ny, [0 1]);
        zDFront_cm(i) = zDFront(i)*Lcm;
    
        zDFront_xtrim(i)    = contourZMeanInROI(entry, ny, xDRangeAvg);
        zDFront_xtrim_cm(i) = zDFront_xtrim(i)*Lcm;
    
        [zMinVal, zMaxVal] = robustFrontMinMax(entry, nx, ny, smoothWindow);
        zDFront_min(i)    = zMinVal;       zDFront_max(i)    = zMaxVal;
        zDFront_min_cm(i) = zMinVal*Lcm;   zDFront_max_cm(i) = zMaxVal*Lcm;
    
        zDContourOnGrid(:,i) = regridContourZ(entry, xDimLess);
    end
    
    % write the per-level scalars into frameVars under the old field-naming
    % convention (zDFront10, zDFront10_cm, zDFront10_xtrim, ... zDFront10_max_cm)
    for i = 1:nLevels
        tag = levelTag(i);
        frameVars.("zDFront"+tag)             = zDFront(i);
        frameVars.("zDFront"+tag+"_cm")       = zDFront_cm(i);
        frameVars.("zDFront"+tag+"_xtrim")    = zDFront_xtrim(i);
        frameVars.("zDFront"+tag+"_xtrim_cm") = zDFront_xtrim_cm(i);
        frameVars.("zDFront"+tag+"_min")      = zDFront_min(i);
        frameVars.("zDFront"+tag+"_max")      = zDFront_max(i);
        frameVars.("zDFront"+tag+"_min_cm")   = zDFront_min_cm(i);
        frameVars.("zDFront"+tag+"_max_cm")   = zDFront_max_cm(i);
    end
    
    % symmetric width pairs (10/90, 16/84, 20/80, 30/70, 40/60, ...) -- found
    % automatically from whichever levels are symmetric about 0.5, instead of
    % a hand-picked list of pairs
    widthTags = {};
    zDWidthContourAll = struct();
    for i = 1:nLevels
        L = levels(i);
        if L >= 0.5 - 1e-9
            continue   % build each pair once, starting from the lower level
        end
        j = find(abs(levels - (1-L)) < 1e-9, 1);
        if isempty(j)
            continue   % no traced partner level at (1-L) -- skip, no pair possible
        end
        widthTag = levelTag(i) + "_" + levelTag(j);
    
        frameVars.("zDWidth_"+widthTag)       = zDFront(i)    - zDFront(j);
        frameVars.("zDWidth_"+widthTag+"_cm") = zDFront_cm(i) - zDFront_cm(j);
        
        frameVars.("zDWidth_"+widthTag+"_xtrim")    = zDFront_xtrim(i)    - zDFront_xtrim(j);
        frameVars.("zDWidth_"+widthTag+"_xtrim_cm") = zDFront_xtrim_cm(i) - zDFront_xtrim_cm(j);
        
        widthTags{end+1} = widthTag; %#ok<AGROW>
        zDWidthContourAll.(matlab.lang.makeValidName(widthTag)) = zDContourOnGrid(:,i) - zDContourOnGrid(:,j);
    end
    
    % C1Axial table -- xD profile plus every traced level's regridded z and
    % every width pair's regridded profile, built dynamically so adding a
    % level never requires touching this table by hand
    C1AxialVars  = {xHorzcm', xDimLess', concHorz'};
    C1AxialNames = {'xHorzcm','xDimLess','CHorz'};
    for i = 1:nLevels
        C1AxialVars{end+1}  = zDContourOnGrid(:,i); %#ok<AGROW>
        C1AxialNames{end+1} = "zDContour" + levelTag(i); %#ok<AGROW>
    end
    for t = 1:numel(widthTags)
        wt = widthTags{t};
        C1AxialVars{end+1}  = zDWidthContourAll.(matlab.lang.makeValidName(wt)); %#ok<AGROW>
        C1AxialNames{end+1} = "zDWidthContour_" + wt; %#ok<AGROW>
    end
    frameVars.C1Axial = table(C1AxialVars{:}, 'VariableNames', C1AxialNames);
    
    % tilt/shape, still specifically from the C=0.5 contour
    idx50 = find(abs(levels - 0.5) < 1e-9, 1);
    if ~isempty(idx50)
        tiltStats  = getFrontTilt(frontByLevelRaw(idx50));
        shapeStats = getFrontShapeMetrics(frontByLevelRaw(idx50));
        frameVars.frontTiltSlope      = tiltStats.slope;
        frameVars.frontTiltR2         = tiltStats.R2;
        frameVars.frontArcLengthRatio = shapeStats.arcLengthRatio;
    else
        frameVars.frontTiltSlope      = NaN;
        frameVars.frontTiltR2         = NaN;
        frameVars.frontArcLengthRatio = NaN;
        warning('populate_CTframeVars: C=0.5 not in levels -- tilt/shape set to NaN.');
    end

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

function [zDMean, zMean_px, nPts] = contourZMeanInROI(entry, ny, xDRange)
% CONTOURZMEANINROI  Mean zD (and pixel equivalent) of a traced contour,
% restricted to points whose xD AND zD both fall inside the given window.
% Pass xDRange=[0 1], zDRange=[0 1] to recover the old full-image mean.
if entry.isEmpty
    zDMean = NaN; zMean_px = NaN; nPts = 0;
    return
end
inROI = entry.xDContour >= xDRange(1) & entry.xDContour <= xDRange(2);
nPts = nnz(inROI);
if nPts == 0
    zDMean = NaN; zMean_px = NaN;
    return
end
zDMean   = mean(entry.zDContour(inROI));
zMean_px = zDMean * ny;
end