% fr_sessions

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
forceL = true;
forceA = true;

% should allow user to input varName or columnn index
colName = 'Session';                    % column name in xls sheet where dirnames exist
% string array of variables to load
vars = ["session.mat";...
    "cell_metrics.cellinfo";...
    "spikes.cellinfo";...
    "SleepState.states";....
    "fr"];      
% column name of logical values for each session. only if true than session
% will be loaded. can be a string array and than all conditions must be
% met.
pcond = ["manCur"];     
% pcond = [];
% same but imposes a negative condition)
ncond = ["fix"];                      
ncond = ["fEPSP"];
sessionlist = 'sessionList.xlsx';       % must include extension
fs = 20000;                             % can also be loaded from datInfo


basepath = 'D:\VMs\shared\lh50';
% dirnames = ["lh49_200324"; "lh49_200325"; "lh49_200326"; "lh49_200331"];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get directory paths
if exist('dirnames', 'var') && isstring(dirnames)
    % ALT 1: user input dirnames
    dirnames = dirnames;
elseif ischar(sessionlist) && contains(sessionlist, 'xlsx')
    % ALT 2: get dirnames from xlsx file
    sessionInfo = readtable(fullfile(basepath, sessionlist));
    icol = strcmp(sessionInfo.Properties.VariableNames, colName);
    dirnames = string(table2cell(sessionInfo(:, icol)));
    % check dirnames meet conditions
    clear irow iicol
    irow = ones(length(dirnames), 1);
    for i = 1 : length(pcond)
        iicol(i) = find(strcmp(sessionInfo.Properties.VariableNames, char(pcond(i))));
        irow = irow & sessionInfo{:, iicol(i)} == 1;
    end
    for i = 1 : length(ncond)
        iicol(i) = find(strcmp(sessionInfo.Properties.VariableNames, char(ncond(i))));
        irow = irow & sessionInfo{:, iicol(i)} ~= 1;
    end
    dirnames = dirnames(irow);
    dirnames(strlength(dirnames) < 1) = [];
end

nsessions = length(dirnames);

% load files
if forceL   
    d = cell(length(dirnames), length(vars));
    for i = 1 : nsessions
        filepath = char(fullfile(basepath, dirnames(i)));
        if ~exist(filepath, 'dir')
            warning('%s does not exist, skipping...', filepath)
            continue
        end
        cd(filepath)
        
        for ii = 1 : length(vars)           
            filename = dir(['*', vars{ii}, '*']);
            if length(filename) == 1
                d{i, ii} = load(filename.name);
            else
                warning('no %s file in %s, skipping', vars{ii}, filepath)
            end
        end
    end
end

spkgrp = session.extracellular.electrodeGroups.channels;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% analyze data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if forceA
    for i = 1 : nsessions
        close all
        
        % file
        filepath = char(fullfile(basepath, dirnames(i)));
        cd(filepath)
        [~, basename] = fileparts(filepath);
        
        % session info
        session = CE_sessionTemplate(pwd, 'viaGUI', false,...
            'force', true, 'saveVar', true);
        nchans = session.extracellular.nChannels;
        fs = session.extracellular.sr;
        spkgrp = session.extracellular.spikeGroups.channels;
        
        % spike sorting
        rez = runKS('basepath', basepath, 'fs', fs, 'nchans', nchans,...
            'spkgrp', spkgrp, 'saveFinal', true, 'viaGui', false,...
            'cleanDir', false, 'trange', [0 Inf], 'outFormat', 'ns');
        fixSpkAndRes('grp', [], 'fs', fs);
        
        % lfp and states
        bz_LFPfromDat(basepath, 'noPrompts', true)
        SleepScoreMaster(basepath, 'noPrompts', true)
        
        % acceleration
        %         accch = setdiff([session.extracellular.electrodeGroups.channels{:}],...
        %             [session.extracellular.spikeGroups.channels{:}]);
        %         EMGfromACC('basepath', filepath, 'fname', '',...
        %             'nchans', 27, 'ch', accch, 'force', true, 'saveVar', true,...
        %             'graphics', false, 'fsOut', 1250);
        
        % spikes and cell metrics
        spikes = loadSpikes('session', session);
        spikes = fixCEspikes('basepath', filepath, 'saveVar', false,...
            'force', true);
        cm = ProcessCellMetrics('session', session,...
            'manualAdjustMonoSyn', false, 'summaryFigures', false,...
            'debugMode', true, 'transferFilesFromClusterpath', false,...
            'submitToDatabase', false);

        % cluster validation
        mu = [];
        spikes = cluVal('spikes', spikes, 'basepath', filepath, 'saveVar', false,...
            'saveFig', false, 'force', true, 'mu', mu, 'graphics', true,...
            'vis', 'on', 'spkgrp', spkgrp);
    
        % firing rate
        load([basename '.spikes.cellinfo.mat'])
        fr = FR(spikes.times, 'basepath', filepath, 'graphics', false, 'saveFig', false,...
            'binsize', 60, 'saveVar', true, 'smet', 'MA', 'winBL', [1 Inf]);
    end
end

% second analysis (depends on first run and load data)
for i = 1 : nsessions
    % file
    filepath = char(fullfile(basepath, dirnames(i)));
    cd(filepath)
    [datename, basename] = fileparts(filepath);
    [~, datename] = fileparts(datename);
    spikes = d{i, 3}.spikes;
    session = d{i, 1}.session;
    cm = d{i, 2}.cell_metrics;

    cm = CellExplorer('metrics', cm); 

    
    
    xxx = getSpikesFromSPK('basepath', filepath, 'saveMat', false,...
    'noPrompts', true, 'forceL', true);
%     
%         isi = cell_metrics.refractoryPeriodViolation; % percent isi < 2 ms
    % mu = find(isi < 10);
    mu = [];
    spikes = cluVal(spikes, 'basepath', filepath, 'saveVar', false,...
        'saveFig', false, 'force', true, 'mu', mu, 'graphics', false,...
        'vis', 'off', 'spkgrp', spkgrp);
    
    d{i, 3}.spikes = spikes;
    
% binsize = 60;
% fr{i} = FR(spikes.times, 'basepath', filepath, 'graphics', false, 'saveFig', false,...
%     'binsize', binsize, 'saveVar', true, 'smet', 'MA', 'winBL', [20 50 * 60]);




end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% rearrange data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
grp = [1 : 4];
for i = 1 : nsessions
    % session data
    filepath = char(fullfile(basepath, dirnames(i)));
    cd(filepath)
    [datename, basename] = fileparts(filepath);
    [~, datename] = fileparts(datename);
    session = d{i, 1}.session;
    cm = d{i, 2}.cell_metrics;
    spikes = d{i, 3}.spikes;
    ss = d{i, 4}.SleepState;
    
    % states
    states = {ss.ints.WAKEstate, ss.ints.NREMstate, ss.ints.REMstate};
    for ii = 1 : length(states)
        tStates{i, ii} = InIntervals(fr{i}.tstamps, states{ii});
        frStates{i, ii} = mean(fr{i}.strd(:, tStates{i, ii}), 2);
    end
    
    % specific grp
    grpidx = zeros(1, length(spikes.shankID));
    for ii = 1 : length(grp)
        grpidx = grpidx | spikes.shankID == grp(ii);
    end
    
    % su
    su = cm.refractoryPeriodViolation < 2000;
    
    % cell class
    pyr = strcmp(cm.putativeCellType, 'Pyramidal Cell');
    int = strcmp(cm.putativeCellType, 'Narrow Interneuron');
    int = ~pyr;
    
    % fr
    for ii = 1 : length(states)
        pyrFr{i, ii} = mean(fr{i}.strd(pyr & grpidx & su, tStates{i, ii}), 2);
        intFr{i, ii} = mean(fr{i}.strd(int & grpidx & su, tStates{i, ii}), 2);
        allFr{i, ii} = mean(fr{i}.strd(grpidx & su, tStates{i, ii}), 2);
    end
    
%     % fr for pyr / int together
%     alltimes = sort(vertcat(spikes.times{:}));
%     pyrtimes = sort(vertcat(spikes.times{pyr}));
%     inttimes = sort(vertcat(spikes.times{int}));
%     binsize = 60;
%     edges = [0 : binsize : session.general.duration];
%     edges(end) = session.general.duration;
%     pyrtemp = histcounts(pyrtimes, edges, 'normalization', 'countdensity');
%     inttemp = histcounts(inttimes, edges, 'normalization', 'countdensity');
%     alltemp = histcounts(alltimes, edges, 'normalization', 'countdensity');
%     %     pyrtemp = calcFR(pyrtimes, 'binsize', 60,...
%     %         'winCalc', [1 Inf], 'smet', 'none', 'c2r', true);
%     %     inttemp = calcFR(inttimes, 'binsize', 60,...
%     %         'winCalc', [1 Inf], 'smet', 'none', 'c2r', true);
%     for ii = 1 : length(states)
%         pyrFr{i, ii} = mean(pyrtemp(tStates{i, ii}));
%         intFr{i, ii} = mean(inttemp(tStates{i, ii}));
%         allFr{i, ii} = mean(alltemp(tStates{i, ii}));
%     end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
set(groot,'defaultAxesTickLabelInterpreter','none');  
set(groot,'defaulttextinterpreter','latex');
set(groot,'defaultLegendInterpreter','latex');

close all

% % spike count for pyr and Int during selected state
% si = 2;
% figure
% plot([1 : nsessions], cell2mat(pyrFr(:, si)))
% hold on
% plot([1 : nsessions], cell2mat(intFr(:, si)))
% plot([1 : nsessions], cell2mat(allFr(:, si)))
% xticks([1 : nsessions])
% xticklabels(dirnames)
% xtickangle(45)

% fr all sessions during selected state for pyr and int separatly (rows)
figure
xvals = [1 : nsessions];
si = [1 2];     % selected state
for ii = 1 : length(si)
%     subplot(2, length(si), ii)
%     mat = cell2nanmat({pyrFr{:, ii}});
%     bar(nanmean(mat))
%     hold on
%     er = errorbar(xvals, nanmean(mat), nanstd(mat));
%     er.Color = [0 0 0];
%     er.LineStyle = 'none';
%     box off
%     set(gca, 'TickLength', [0 0])
%     ylim([0 15])
    subplot(2, length(si), ii + length(si))
    mat = cell2nanmat({intFr{:, ii}});
    bar(nanmean(mat))
    hold on
    er = errorbar(xvals, nanmean(mat), nanstd(mat));
    er.Color = [0 0 0];
    er.LineStyle = 'none';   
    box off
    set(gca, 'TickLength', [0 0])
    xticks(xvals)
    xticklabels(dirnames)
    xtickangle(45)
    ylim([0 20])
end


% fr per session
figure
for i = 1 : nsessions
    filepath = char(fullfile(basepath, dirnames(i)));
    cd(filepath)
    [datename, basename] = fileparts(filepath);
    [~, datename] = fileparts(datename);
    
    spikes = d{i, 3}.spikes;
    sum(spikes.su);
    
    subplot(1, nsessions, i)
%     plot(fr{i}.strd(spikes.su, :)')
%     plot(fr{i}.strd(:, :)')
    stdshade(fr{i}.strd(spikes.su, :), 0.3, 'k', fr{i}.tstamps / 60, 3)
    title([datename '_' basename], 'Interpreter', 'none')
    axis tight
    ylim([0 50])
end
% 
% % fr
% figure
% for i = 1 : nsessions
%     subplot(1, nsessions, i)
%     if ~isempty(fr{i})
% stdshade(fr{i}.strd(:, :), 0.3, 'k', fr{i}.tstamps / 60, 3)
% ylim([0 20])
%         %         plot(fr{i}.norm')
%     end
% end
% 
% % states
% load([basename '.SleepState.states.mat'])
% wake = SleepState.ints.WAKEstate;
% figure
% plot(acc.tstamps, acc.data)
% hold on
% axis tight
% y = ylim;
% plot([wake(:, 1) wake(:, 1)], y, 'k')
% plot([wake(:, 2) wake(:, 2)], y, 'r')


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% to prism
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
