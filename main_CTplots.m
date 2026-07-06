% Code description
% 
%
% Workflow
% Loop over one single full scan
% 1 - extract data, take time and angle, and all fileDataExp
% 2 - crop
% 3 - normalize Measured - Xe / He - Xe or run estimated density based on
% calibration, different gray image average or distribution correspond to a
% certain density
% 4 - save data

%% IMPORT input

addpath('functions/');

% Introduce name of input and desired output folder name

inputFileConfigName = 'inputCTExpConfig.xlsx';
inputFileConfig = readtable(inputFileConfigName);

%% Find where to plot profile
% Plot Z Profile

colours = {[0.318 0.654 0.976],[0.09 0.306 0.525], [0.435 0.753 0.251],[0.059 0.361 0.102] }; %light blue, dark blue, light green, dark green

Z_target = 4;
C_target = 0.5;

Z_found = [];
C_found = [];
idx_found = [];
l_found = [];

figure
legendEntries = cell(1, height(inputFileConfig));

for i = 1:height(inputFileConfig)
    filenameExp = inputFileConfig.inputFileName{i};
    pathExportAll = inputFileConfig.exportPath{i}; % Path for OUTPUT
    filedataExp = import_inputCTExp(filenameExp); % import input to a local variable

    expCTDataname = fullfile(pathExportAll, filedataExp.Key + ".mat");
    expCTDataTemp = load(expCTDataname);
    expCTData.(filedataExp.Key) = expCTDataTemp.expCTDataSave;

    vars = expCTData.(filedataExp.Key).concVarsAll;

    best_dist = inf;
    best_Z = NaN;
    best_C = NaN;
    best_idx = NaN;
    best_l = NaN;

    for l = 1:height(vars)

        C1Profile = vars.C1Profile{l};

        Z = C1Profile(:,1);
        C = C1Profile(:,2);

        dist = (Z - Z_target).^2 + (C - C_target).^2;

        [min_dist, idx] = min(dist);

        if min_dist < best_dist
            best_dist = min_dist;
            best_Z = Z(idx);
            best_C = C(idx);
            best_idx = idx;
            best_l = l;
        end
    end

    Z_found(i) = best_Z;
    C_found(i) = best_C;
    idx_found(i) = best_idx;
    l_found(i) = best_l;

    % what profile to plot
    C1Profile_plot = vars.C1Profile{l_found(i)};
    tD = vars.tDcorr(l_found(i));
    legendEntries{i} = filedataExp.Key;

    % plot
    plot(C1Profile_plot(:,1), C1Profile_plot(:,2),'LineWidth',3,'Color',colours{:,i})
    xlabel('Z Distance [cm]','FontSize',14)
    % plot(C1Profile_plot(:,1)/C1Profile_plot(end,1), C1Profile_plot(:,2),'LineWidth',3)
    % xlabel('Z_D [-]','FontSize',14)
    ylabel('C_1 average [-]','FontSize',14)
    set(gca, 'FontSize', 14)
    grid on
    hold on

end
legend(legendEntries, 'Interpreter','none','FontSize',9.8)

%% plot BT dimension time
colours = {[0.318 0.654 0.976],[0.09 0.306 0.525], [0.435 0.753 0.251],[0.059 0.361 0.102] }; %light blue, dark blue, light green, dark green

figure
legendEntries = cell(1, height(inputFileConfig));

for i = 1:height(inputFileConfig)
    filenameExp = inputFileConfig.inputFileName{i};
    pathExportAll = inputFileConfig.exportPath{i}; % Path for OUTPUT
    filedataExp = import_inputCTExp(filenameExp); % import input to a local variable

    expCTDataname = fullfile(pathExportAll, filedataExp.Key + ".mat");
    expCTDataTemp = load(expCTDataname);
    expCTData.(filedataExp.Key) = expCTDataTemp.expCTDataSave;

    vars = expCTData.(filedataExp.Key).BTcore;

    legendEntries{i} = filedataExp.Key;

    % plot
    plot(vars.timeElapsed, vars.C1,'LineWidth',3,'Color',colours{:,i})
    xlabel('time elapsed [hh:mm:ss]','FontSize',14)
    ylabel('C_1 average [-]','FontSize',14)
    set(gca, 'FontSize', 14)
    ylim([-0.02 1])
    grid on
    hold on

end
legend(legendEntries, 'Interpreter','none','FontSize',9.8,'Location','southeast')
