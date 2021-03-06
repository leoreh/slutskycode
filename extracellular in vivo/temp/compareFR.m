% params
path{1} = 'E:\Data\Dat\lh50\lh50_200421\120416';
path{2} = 'E:\Data\Dat\lh50\lh50_200422\110423';
path{3} = 'E:\Data\Dat\lh50\lh50_200423\090405';

force = true;
nsessions = length(path);

% load data
if force
    for i = 1 : nsessions
        basepath = path{i};
        cd(basepath)
        bname{i} = bz_BasenameFromBasepath(basepath);
        
        sfile = [path{i}, filesep, bname{i}, '.spikes.cellinfo.mat'];
        if exist(sfile)
            load(sfile)
            s{i} = spikes;
        end
        
        fr{i} = FR(s{i}.times, 'basepath', basepath, 'graphics', false, 'saveFig', false,...
            'binsize', 60, 'saveVar', false, 'smet', 'MA');
        
        cmfile = [path{i}, filesep, bname{i}, '.cell_metrics.cellinfo.mat'];
        if exist(cmfile)
            load(cmfile)
            cm{i} = cell_metrics;
        end
        
        accfile = [path{i}, filesep, bname{i}, '.acceleration.mat'];
        if exist(accfile)
            load(accfile); 
            a{i} = acc;
        end
       
        difile = [path{i}, filesep, bname{i}, '.datInfo.mat'];
        if exist(difile)
            load(difile);
            di{i} = datInfo;
        end       
    end
end


figure
plot(fr{i}.tstamps / 60, fr{i}.strd)
hold on
% yyaxis right
% plot(a{i}.tstamps / a{i}.fs_orig / 60, a{i}.mag)
Y = ylim;
fill([a{i}.sleep fliplr(a{i}.sleep)]' / 60, [Y(1) Y(1) Y(2) Y(2)],...
    'k', 'FaceAlpha', 0.25,  'EdgeAlpha', 0);

subplot(2, 1, 1)
plot(acc.tstamps / acc.fs_orig / 60, acc.mag)
axis tight
ylabel('L2 Magnitude')
set(gca, 'TickLength', [0 0], 'XTickLabel', [],...
    'Color', 'none', 'XColor', 'none')
box off
subplot(2, 1, 2)
plot(acc.tband / 60, acc.pband)
axis tight
xlabel('Time [m]')
ylabel('Power Band')
set(gca, 'TickLength', [0 0], 'Color', 'none')
box off
hold on
Y = ylim;
fill([acc.sleep fliplr(acc.sleep)]' / 60, [Y(1) Y(1) Y(2) Y(2)],...
    'k', 'FaceAlpha', 0.25,  'EdgeAlpha', 0);



% separate times to high and low FR
for i = 1 : nsessions
    idx{i} = mean(fr{i}.strd, 1) > 4;
    awake{i} = fr{i}.strd(:, idx{i});
    sleep{i} = fr{i}.strd(:, ~idx{i});
    cellawake{i} = mean(awake{i}, 2);
    cellsleep{i} = mean(sleep{i}, 2);
    mfrsu(i) = mean(mean(fr{i}.strd(s{i}.su, idx{i})));
    mfr(i) = mean(mean(fr{i}.strd(:, idx{i})));
    
%     figure
%     histogram(mean(fr{i}.strd, 1), 50)
end

mawake = cell2nanmat(cellawake);
msleep = cell2nanmat(cellsleep);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% fr of each unit during entire recording
figure
for i = 2 : nsessions
    units = cm{i}.refractoryPeriodViolation < 5;
    
    subplot(1, nsessions, i)
    stdshade(fr{i}.strd(units, :), 0.5, 'k')
    
%     plot(fr{i}.tstamps / 60, fr{i}.strd)
    ylim([0 20])
    hold on
    % yyaxis right
    % plot(a{i}.tstamps / a{i}.fs_orig / 60, a{i}.mag)  
    Y = ylim;
    plot([di{i}.nsamps(1) / fs / 60 di{i}.nsamps(1) / fs / 60], Y)
    fill([a{i}.sleep fliplr(a{i}.sleep)]' / 60, [Y(1) Y(1) Y(2) Y(2)],...
        'k', 'FaceAlpha', 0.25,  'EdgeAlpha', 0);
    
end

% fr of each unit only during awake
figure
for i = 1 : nsessions
    subplot(1, nsessions, i)
%     plot(fr{i}.tstamps(idx{i}), awake{i})
    stdshade(awake{i}, 0.5, 'k')
    ylim([0 20])
end

% fr of each unit only during awake
figure
for i = 1 : nsessions
    subplot(1, nsessions, i)
    plot(fr{i}.tstamps(~idx{i}), sleep{i})
end


% change in mfr for each unit
figure
hold on
for i = 1 : nsessions
    scatter(ones(size(awake{i}, 1), 1) * i, mean(awake{i}, 2));
end

% change in mfr of SU in awake
figure
scatter([1 : nsessions], mfr)
