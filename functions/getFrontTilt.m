function tilt = getFrontTilt(frontC)
% frontC: one element of contourFront's output struct array (already traced)
    if frontC.isEmpty
        tilt = struct('slope',NaN,'R2',NaN,'isEmpty',true);
        return
    end
    p = polyfit(frontC.xDContour, frontC.zDContour, 1);
    zD_fit = polyval(p, frontC.xDContour);
    SSres = sum((frontC.zDContour - zD_fit).^2);
    SStot = sum((frontC.zDContour - mean(frontC.zDContour)).^2);
    R2 = 1 - SSres/SStot;
    tilt = struct('slope',p(1),'R2',R2,'isEmpty',false);
end