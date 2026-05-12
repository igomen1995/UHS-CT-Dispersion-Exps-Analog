
function onClickCallback(~,event,path,hSelected,BT,expCTData,filedataExp, ...
    ax1,ax2,ax3,ax4,cbPos)

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
    xlabel(ax1,'X Distance [cm]')
    ylabel(ax1,'Average concentration')
    title(ax1,"timeElapsed: " + vars.secondsElapsed + ...
              " s, volInjected: " + vars.volInjected + " mL")
    grid(ax1,'on')

    % plot concentration in z ax4
    xy2 = vars.C1Profile;
    x2 = xy2(:,1);
    y2 = xy2(:,2);
    cla(ax4)
    plot(ax4, x2, y2)
    xlabel(ax4,'Z Distance [cm]')
    ylabel(ax4,'Average concentration')
    grid(ax4,'on')          
    axis(ax4,'tight')
    axis(ax4,'manual')
    camroll(ax4,270)
    ylim(ax4,[0 1])

    % plot image ax3
    concCTimages = h5read(HDF5filename, HDF5dataPath, [1 1 k], [nx ny 1]);
    cla(ax3)
    imagesc(ax3, concCTimages)
    axis(ax3,'xy','fill')
    set(ax3,'YDir','reverse')
    colormap(ax3,turbo)
    clim(ax3,[0 1]);
    cb = colorbar(ax3,'Position',cbPos);
    cb.Label.String = 'Concentration';

    % plot histogram ax3
    histData = vars.histImage;
    freq = histData(:,1);
    binCenters = (histData(:,2)+histData(:,3))/2;
    cla(ax2)
    bar(ax2,binCenters,freq,1)
    xlim(ax2,[0,1])
    ylim(ax2,[0,length(x1)*length(x2)])
    xlabel(ax2,'Concentration')
    ylabel(ax2,'Counts')
    title(ax2,"run: " +string(j)+" , angle: " + vars.rotPos + "°")
    grid(ax2, 'on')

end


