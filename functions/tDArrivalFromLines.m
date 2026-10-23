function [tD_arrival,t_arrival_min] = tDArrivalFromLines(Vlinesbefore, Q, Vtotal)
% TDARRIVALFROMLINES  Dimensionless arrival time predicted purely from
% the inlet-line dead volume and the injection rate -- when the
% displacing fluid is expected to reach the core inlet, with no CT image
% involved.
%
% Vlinesbefore : dead volume of inlet lines [mL]
% Q            : injection rate [mL/min]
% Vtotal       : total pore volume [mL]

tLines_min = Vlinesbefore / Q;
tD_arrival = tLines_min * Q / Vtotal;   % == Vlinesbefore/Vtotal; Q cancels algebraically,
                                         % left explicit so the dependence on rate is visible

t_arrival_min = Vlinesbefore / Q;

end