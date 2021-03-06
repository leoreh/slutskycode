
% compares distribution of state-dependent firing rate during different
% times of the same recording or during different sessions. can compare
% bins of mu activity or su firing rate. uses box plots with diamonds
% marking the mean. relies on vars loaded from fr_sessions, session params,
% as_configFile, selecUnits.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% params
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% general
saveFig = true;
grp = [1 : 4];
stateidx = [1, 4 ,5];
dataType = 'su';        % can be 'mu' (bins of sr) or 'su' (fr)
unitClass = 'pyr';      % plot 'int', 'pyr', or 'all'
suFlag = 0;             % plot only su or all units
frBoundries = [0 Inf];  % include only units with mean fr in these boundries

% initialize
maxY = 0;
[cfg_colors, cfg_names, ~] = as_loadConfig([]);

% selection of sessions. if sessionidx longer than one will ingore tstamps
sessionidx = [7];

% selection of timestamps from the same recording for comparison
assignVars(varArray, sessionidx(1))
if length(sessionidx) == 1
    figpath = session.general.basePath;
    
%     csamps = cumsum(datInfo.nsamps) / fs;
%     tstamps = [ceil(csamps(1)), floor(csamps(2));...
%         ceil(csamps(2)), floor(csamps(3));...
%         ceil(csamps(3)), floor(csamps(4))];
    
    tstamps = [1, 150 * 60; 200 * 60, Inf];
    
    xLabel = ["Before"; "After"];
else
    figpath = fileparts(session.general.basePath);
end
cd(figpath)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear frcell
if length(sessionidx) > 1
    % compare different sessions
    for istate = 1 : length(stateidx)
        for isession = 1 : length(sessionidx)
            assignVars(varArray, sessionidx(isession))
            switch dataType
                case 'mu'
                    frcell{istate, isession} = sr.states.fr{stateidx(istate)}(grp, :);
                    frcell{istate, isession} = frcell{istate, isession}(:);
                case 'su'
                    units = selectUnits(spikes, cm, fr, suFlag, grp, frBoundries, unitClass);
                    nunits = sum(units);
                    frcell{istate, isession} = mean(fr.states.fr{stateidx(istate)}(units, :), 2, 'omitnan');
            end
            maxY = max([prctile(frcell{istate, isession}, 80), maxY]);
        end
    end
    % get x labels for dirnames
    for isession = 1 : length(sessionidx)
        [dt, ~] = guessDateTime(dirnames(sessionidx(isession)));
        xLabel{isession} = datestr(datenum(dt), 'dd/mm_HH:MM');
    end
else
    % compare different times from the same session
    for istate = 1 : length(stateidx)
        for itstamps = 1 : size(tstamps, 1)
            tidx = sr.states.tstamps{stateidx(istate)} > tstamps(itstamps, 1) &...
                sr.states.tstamps{stateidx(istate)} < tstamps(itstamps, 2);
            switch dataType
                case 'mu'
                    frcell{istate, itstamps} = sr.states.fr{stateidx(istate)}(grp, tidx);
                    frcell{istate, itstamps} = frcell{istate, itstamps}(:);
                case 'su'
                    units = selectUnits(spikes, cm, fr, suFlag, grp, frBoundries, unitClass);
                    nunits = sum(units);
                    frcell{istate, itstamps} = mean(fr.states.fr{stateidx(istate)}(units, tidx), 2, 'omitnan');
            end
            maxY = max([prctile(frcell{istate, itstamps}, 90), maxY]);
        end
    end
end

% compare firing ratio between two states
stateRatio = [];
if ~isempty(stateRatio)
    for isession = 1 : length(sessionidx)
        tempcell{1, isession} = frcell{stateRatio(1), isession} ./...
            frcell{stateRatio(2), isession};
    end
    frcell = tempcell;
    stateidx = 1;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fh = figure;
for istate = 1 : size(frcell, 1)
    subplot(1, length(stateidx), istate)
    hold on
    frmat = cell2nanmat(frcell(istate, :));
    plot([1 : size(frmat, 2)], mean(frmat, 1, 'omitnan'),...
        'kd', 'markerfacecolor', 'k')
    boxplot(frmat, 'PlotStyle', 'traditional', 'Whisker', 1.5);
    bh = findobj(gca, 'Tag', 'Box');
    bh = flipud(bh);
    for ibox = 1 : length(bh)
        patch(get(bh(ibox), 'XData'), get(bh(ibox), 'YData'),...
            cfg_colors{stateidx(istate)}, 'FaceAlpha', 0.5)
    end
    xticklabels(xLabel)
    xtickangle(45)
    if istate == 1
        ylabel([dataType, ' firing rate [Hz]'])
    end
    title(cfg_names(stateidx(istate)))
    ylim([0 ceil(maxY)])
end

if saveFig
    figpath = fullfile(figpath, 'graphics', 'sleepState');
    mkdir(figpath)
    switch dataType
        case 'mu'
            figname = fullfile(figpath, ['mu_states_times']);
        case 'su'
            figname = fullfile(figpath, [unitClass, '_states_times']);
    end
    export_fig(figname, '-tif', '-transparent', '-r300')
end
