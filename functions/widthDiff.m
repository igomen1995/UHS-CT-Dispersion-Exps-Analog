function width = widthDiff(D, t, C1, C2)
% THEORETICALWIDTH  Ogata-Banks erfc-based mixing-zone width between two
% concentration levels C1 < C2, at dispersion coefficient D and time t.
%
% delta = 2*sqrt(D*t) * [erfcinv(2*C1) - erfcinv(2*C2)]
% For C1=0.1, C2=0.9: constant = 3.625 (matches the 10-90% formula)
% t in seconds, D in cm2/min
    
    D = D/60; %cm2/min to cm2/s
    k = erfcinv(2*C1) - erfcinv(2*C2);
    width = 2*k*sqrt(D*t);
end