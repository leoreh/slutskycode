
%%% input

basepath = 'E:\Data\Dat\lh46\lh46_200225a';
basename = bz_BasenameFromBasepath(basepath);
spikes = getSpikes('basepath', basepath, 'saveMat', true,...
    'noPrompts', true, 'forceL', false);

grp = spikes.shankID;
ch{1} = 1 : 4;
ch{2} = 5 : 8;
ch{3} = 9 : 12;
ch{4} = 13 : 16;

nunits = length(spikes.times);


%%% params
win = [-19 20];
nchans = 16;
precision = 'int16';
fname = '';
nbytes = class2bytes(precision);
b2uv = 0.195;
dtrend = true; 

%%% extract
% for 69 units and 2608583 spikes this took 24.5 minutes w/ snipFromDat and
% 42.5 min with one time memmap

          
% handle dat file
cd(basepath)
datFiles = dir([basepath filesep '**' filesep '*dat']);
if isempty(datFiles)
    error('no .dat files found in %s', basepath)
end
if isempty(fname)
    if length(datFiles) == 1
        fname = datFiles.name;
    else
        fname = [bz_BasenameFromBasepath(basepath) '.dat'];
        if ~contains({datFiles.name}, fname)
            error('please specify which dat file to process')
        end
    end
end

% memory map to dat file
info = dir(fname);
nsamps = info.bytes / nbytes / nchans;
m = memmapfile(fname, 'Format', {precision, [nchans, nsamps] 'mapped'});

tic
for j = 1 : nunits
    
    stamps = round(spikes.times{j} * spikes.samplingRate);
       
    % initialize
    sniplength = diff(win) + 1;
    nsnips = length(stamps);
    snips = zeros(length(ch), sniplength, nsnips);
    
    % go over stamps and snip data
    for i = 1 : length(stamps)
        if stamps(i) + win(1) < 1 || stamps(i) + win(2) > nsamps
            warning('skipping stamp %d because snip incomplete', i)
            snips(:, :, i) = nan(length(ch), sniplength);
            continue
        end
        v = m.Data.mapped(ch{grp(j)}, stamps(i) + win(1) : stamps(i) + win(2));
        
        % convert bits to uV
        if b2uv
            v = double(v) * b2uv;
        end
        
        % L2 normalize and detrend
        if dtrend
            v = double(v) ./ vecnorm(double(v), 2, 2);
            v = [detrend(v')]';
        end
        snips(:, :, i) = v;
    end
    
    
%     snips = snipFromDat('basepath', basepath, 'fname', '',...
%         'stamps', stamps, 'win', win, 'nchans', nchans, 'ch', ch{grp(j)},...
%         'dtrend', true, 'precision', precision);
    
    avgwv(j, :, :) = mean(snips, 3);
    stdwv(j, :, :) = std(snips, [], 3);
    
    x = squeeze(avgwv(j, :, :));
    [~, maxi] = max(abs(min(x, [], 2) - max(x, [], 2)));
    maxch(j) = ch{grp(j)}(maxi);
    maxwv(j, :) = avgwv(j, maxi, :);
    
end
toc

spikes.avgwv = avgwv;
spikes.stdwv = stdwv;
spikes.maxwv = maxwv;
spikes.maxch = maxch;

save([basepath filesep basename '.spikes.mat'], 'spikes')

figure
subplot(1, 2, 1)
plotWaveform('avgwv', avgwv, 'sbar', false)
subplot(1, 2, 2)
plotWaveform('avgwv', spikes.avgWaveform{i}, 'sbar', false)




% amp = 