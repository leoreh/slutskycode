% params
path{1} = 'E:\Data\Dat\lh46\lh46_200225a';
path{2} = 'E:\Data\Dat\lh46\lh46_200225b';
path{3} = 'E:\Data\Dat\lh46\lh46_200226a';
path{4} = 'E:\Data\Dat\lh46\lh46_200226b';
path{5} = 'E:\Data\Dat\lh46\lh46_200227a';
path{6} = 'E:\Data\Dat\lh46\lh46_200227b';

force = true;
nsessions = length(path);

% load data
if force
    for i = 1 : nsessions
        basepath = path{i};
        cd(basepath)
        bname{i} = bz_BasenameFromBasepath(basepath);
        
        s{i} = getSpikes('basepath', basepath, 'saveMat', true,...
            'noPrompts', true, 'forceL', false);
        
        fr{i} = FR(s{i}.times, 'basepath', basepath, 'graphics', false, 'saveFig', false,...
            'binsize', 60, 'saveVar', false, 'smet', 'MA');
    end
end

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
for i = 1 : nsessions
    subplot(1, nsessions, i)
    stdshade(fr{i}.strd, 0.5, 'k')
    ylim([0 20])
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