function Iair = findIair(imagek1, medWin)
%FINDIAIR Unattenuated (air) intensity I0 from a projection that shows air.
%
%   Iair = findIair(imagek1) returns the maximum intensity of the projection
%   imagek1 (e.g. frame k = 1, where air is visible at the left edge), after a
%   3x3 median filter so that a single hot pixel cannot set the value.
%
%   Iair = findIair(imagek1, medWin) uses a medWin x medWin median
%   (medWin = 1 disables it: plain maximum).
%
%   Use one Iair per scan (Xe, He, each experiment run), each from its own
%   frame k = 1, and pass it to normImage for every projection of that scan.
%
%   See also: normImage, medfilt2

    if nargin < 2 || isempty(medWin), medWin = 3; end
    imagek1 = double(imagek1);
    if medWin > 1
        imagek1 = medfilt2(imagek1, [medWin medWin], 'symmetric');
    end
    Iair = max(imagek1(:));
end