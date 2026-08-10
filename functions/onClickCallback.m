function onClickCallback(~,event,path,hSelected,BT,expCTData,filedataExp, ...
    ax1,ax2,ax3,ax4,cbPos,hTitle)


%ONCLICKCALLBACK Update visualization panels after selecting a breakthrough point.
%
%   This callback function is executed when the user clicks a point on the
%   breakthrough (BT) curve. The selected point is used to identify the
%   corresponding CT image and associated experimental variables. Several
%   axes are then updated to display:
%
%       1. Axial concentration profile
%       2. Concentration histogram
%       3. 2-D concentration map with contour lines
%       4. Radial/vertical concentration profile
%
%   The function retrieves the required data from the experiment structure
%   and associated HDF5 files, allowing interactive exploration of CT scan
%   results throughout the experiment.
%
%   Inputs:
%       event        - MATLAB event data containing the clicked location.
%       path         - Directory containing HDF5 experiment files.
%       hSelected    - Graphics handle for the selected BT point marker.
%       BT           - Structure containing breakthrough curve data and
%                      image indices.
%       expCTData    - Structure containing processed CT experiment data.
%       filedataExp  - Experiment metadata table.
%       ax1          - Axes for axial concentration profile.
%       ax2          - Axes for concentration histogram.
%       ax3          - Axes for concentration image visualization.
%       ax4          - Axes for vertical concentration profile.
%       cbPos        - Position vector for the colorbar.
%       hTitle       - Handle to the figure title.
%
%   Function Actions:
%       - Identifies the nearest breakthrough point to the click location.
%       - Retrieves the associated image and concentration variables.
%       - Updates the selected-point marker.
%       - Displays axial and vertical concentration profiles.
%       - Loads the corresponding concentration image from HDF5 storage.
%       - Overlays concentration contour lines.
%       - Updates the concentration histogram.
%       - Refreshes figure titles and annotations.
%
%   Notes:
%       - Concentration images are read from:
%
%             /exp/run_xx/conc
%
%         within the experiment HDF5 file.
%
%       - Concentration values are assumed to be normalized to the range
%         [0, 1].
%
%       - A Gaussian filter is applied before contour generation to
%         produce smoother contour lines.
%
%   See also:
%       h5read, h5info, imagesc, contour, imgaussfilt


    % Get clicked coordinates
    cp = event.IntersectionPoint;
    xClick = cp(1);
    yClick = cp(2);

    % Find closest point
    dist = (BT.t - xClick).^2 + (BT.C - yClick).^2;
    [~, idx] = min(dist);

    % Recover indices
    i = BT.i(idx);
    j = BT.j(idx);
    k = BT.k(idx);

    run_name = "run_" + sprintf('%02d', j);
    vars = expCTData.(filedataExp.Key(i)).exp.(run_name).concVars(k);

    % load image params
    HDF5filename = fullfile(path, filedataExp.Key(i) + ".h5");
    HDF5dataPath = ['/exp/' char(run_name) '/conc'];   
    info = h5info(HDF5filename, HDF5dataPath);
    dims = info.Dataspace.Size;   
    nx = dims(1);
    ny = dims(2);

    % Update selected point in ax5
    set(hSelected, ...
        'XData', BT.t(idx), ...
        'YData', BT.C(idx));

    % plot concentration in x ax1
    x1 = vars.C1Axial.xHorzcm;
    y1 = vars.C1Axial.rhoNormHorz;
    cla(ax1)
    plot(ax1, x1, y1,'LineWidth',2)
    xlim(ax1,[min(x1) max(x1)])
    ylim(ax1,[-0.02 1])
    xlabel(ax1,'X [cm]')
    ylabel(ax1,'C_{ave}_1 [-]')
    title(ax1,"timeElapsed: " + vars.secondsElapsed + ...
              " s, volInjected: " + sprintf('%.2f', vars.volInjected) + ...
              " mL, tD: " + sprintf('%.3f', vars.tDtotal))
    grid(ax1,'on')

    % hTitle
    set(hTitle, 'String', ...
        filedataExp.Key(i) + ": CT " + run_name + ...
        " ImgNumber_" + sprintf('%03d', k));

    % plot concentration in z ax4
    x2 = vars.C1Profile.zVertcm;
    y2 = vars.C1Profile.rhoNormVert;
    cla(ax4)
    plot(ax4, x2, y2,'LineWidth',2)
    xlabel(ax4,'Z [cm]')
    ylabel(ax4,'C_{ave}_1 [-]')
    grid(ax4,'on')          
    axis(ax4,'tight')
    axis(ax4,'manual')
    camroll(ax4,270)
    ylim(ax4,[-0.02 1])
    ax4.YAxisLocation = 'right';

    % plot image ax3
    concCTimages = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
    imgSmooth = imgaussfilt(concCTimages, 20);
    cla(ax3)
    imagesc(ax3, concCTimages)
    axis(ax3,'xy','fill')
    set(ax3,'YDir','reverse')
    xlabel(ax3,'Pixel Number')
    ylabel(ax3,'Pixel Number')
    cmap = turbo;
    colormap(ax3,cmap)
    % nLevels = 10;
    % cmap = turbo(nLevels);
    % colormap(ax3,cmap)
    % % colormap(ax3,gray)
    clim(ax3,[0 1]);
    cb = colorbar(ax3,'Position',cbPos);
    cb.Label.String = 'C_1 [-]';
    levels = 0:0.1:1;
    hold(ax3,'on')
    contour(ax3, imgSmooth, levels, ...
        'LineColor','k', ...
        'LineWidth',1,'ShowText',true,'LabelFormat',"%0.1f")
    hold(ax3,'off')

    % plot histogram ax2
    freq = vars.histImage.counts;
    binCenters = (vars.histImage.minEdge+vars.histImage.maxEdge)/2;
    cla(ax2)
    bar(ax2,binCenters,freq,1)
    xlim(ax2,[-0.02,1])
    ylim(ax2,[0,length(x1)*length(x2)])
    xlabel(ax2,'C_1 [-]')
    ylabel(ax2,'Counts')
    title(ax2,"run: " +string(j)+" , angle: " + vars.rotPos + "°")
    grid(ax2, 'on')

end


