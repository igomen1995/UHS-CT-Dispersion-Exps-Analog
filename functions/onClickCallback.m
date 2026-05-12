
function onClickCallback(~,event,path,hSelected,BT,expCTData,filedataExp, ...
    ax1,ax2,ax3,ax4,cbPos,hTitle)

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
    xy1 = vars.C1Axial;
    x1 = xy1(:,1);
    y1 = xy1(:,2);
    cla(ax1)
    plot(ax1, x1, y1)
    xlim(ax1,[min(x1) max(x1)])
    ylim(ax1,[0 1])
    xlabel(ax1,'X [cm]')
    ylabel(ax1,'C_{ave}_1 [-]')
    title(ax1,"timeElapsed: " + vars.secondsElapsed + ...
              " s, volInjected: " + vars.volInjected + " mL")
    grid(ax1,'on')

    % hTitle
    set(hTitle, 'String', ...
        filedataExp.Key(i) + ": CT " + run_name + ...
        " ImgNumber_" + sprintf('%03d', k));

    % plot concentration in z ax4
    xy2 = vars.C1Profile;
    x2 = xy2(:,1);
    y2 = xy2(:,2);
    cla(ax4)
    plot(ax4, x2, y2)
    xlabel(ax4,'Z [cm]')
    ylabel(ax4,'C_{ave}_1 [-]')
    grid(ax4,'on')          
    axis(ax4,'tight')
    axis(ax4,'manual')
    camroll(ax4,270)
    ylim(ax4,[0 1])
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
    % nLevels = 10;
    % cmap = turbo(nLevels);
    % colormap(ax3,cmap)
    colormap(ax3,turbo)
    clim(ax3,[0 1]);
    cb = colorbar(ax3,'Position',cbPos);
    cb.Label.String = 'C_1 [-]';
    levels = 0:0.1:1;
    hold(ax3,'on')
    contour(ax3, imgSmooth, levels, ...
        'LineColor','k', ...
        'LineWidth',1,'ShowText',true,'LabelFormat',"%0.1f")
    hold(ax3,'off')

    % plot histogram ax3
    histData = vars.histImage;
    freq = histData(:,1);
    binCenters = (histData(:,2)+histData(:,3))/2;
    cla(ax2)
    bar(ax2,binCenters,freq,1)
    xlim(ax2,[0,1])
    ylim(ax2,[0,length(x1)*length(x2)])
    xlabel(ax2,'C_1 [-]')
    ylabel(ax2,'Counts')
    title(ax2,"run: " +string(j)+" , angle: " + vars.rotPos + "°")
    grid(ax2, 'on')

end


