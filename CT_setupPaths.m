function CT_setupPaths()
% Adds this repo's functions and the BTC repo's functions to the MATLAB path.
    repoRoot = fileparts(mfilename('fullpath'));
    btcFuncs = fullfile(repoRoot, '..', 'UHS-CF-Dispersion-Exps2', 'functions');

    if ~isfolder(btcFuncs)
        error(['BTC repo not found at %s.\n' ...
               'Clone UHS-CF-Dispersion-Exps2 next to this repo.'], btcFuncs);
    end

    addpath(genpath(fullfile(repoRoot, 'functions')));
    addpath(btcFuncs);

    % Warn about duplicate function names between the two repos
    a = dir(fullfile(repoRoot, 'functions', '*.m'));
    b = dir(fullfile(btcFuncs, '*.m'));
    dup = intersect({a.name}, {b.name});
    if ~isempty(dup)
        warning('Duplicate function names on path:\n  %s', strjoin(dup, '\n  '));
    end
end