% figS9 in Zarhin et al., 2020

close all
force = false;
saveFig = true;

grppath{1} = 'G:\Data\Processed\Manuscripts\Zarhin2020\IIS\WT\New analyis';
grppath{2} = 'G:\Data\Processed\Manuscripts\Zarhin2020\IIS\APPPS1\New analysis';

% select mouse (according to file order in path)
i_wt = 7;
i_app = 27;

i_wt = 6;
i_app = 7;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if force
    
    % load wt data
    cd(grppath{1})
    filename = dir('*.lfp.*');
    files = natsort({filename.name});
    nfiles = 1 : length(files);
    [~, basename] = fileparts(files{nfiles(i_wt)});
    [~, basename] = fileparts(basename);
    [bs, iis, ep] = aneStates('ch', 1, 'basepath', grppath{1},...
        'basename', basename, 'graphics', false,...
        'saveVar', false, 'saveFig', false, 'forceA', false,...
        'binsize', 30, 'smf', 7, 'thrMet', 1);
    load([fullfile(grppath{1}, basename) '.lfp.mat'])
    lfpwt = lfp;
    bswt = bs;
    iiswt = iis;
    epwt = ep;
    
    % load apps1 data
    cd(grppath{2})
    filename = dir('*.lfp.*');
    files = natsort({filename.name});
    nfiles = 1 : length(files);
    [~, basename] = fileparts(files{nfiles(i_app)});
    [~, basename] = fileparts(basename);
    [bs, iis, ep] = aneStates('ch', 1, 'basepath', grppath{2},...
        'basename', basename, 'graphics', false,...
        'saveVar', false, 'saveFig', false, 'forceA', false,...
        'binsize', 30, 'smf', 7, 'thrMet', 1);
    load([fullfile(grppath{2}, basename) '.lfp.mat'])
    
    
    % bs classification
    fs = lfp.fs;
    binsize = 2 ^ nextpow2(0.5 * fs);   % for pc1
    
    ibins = [1 : binsize : length(lfpwt.data)];
    ibins(end) = length(lfpwt.data);
    
    % divide signal to bins
    sigre = lfpwt.data(1 : end - (mod(length(lfpwt.data), binsize) + binsize));
    sigmat = reshape(sigre, binsize, (floor(length(lfpwt.data) / binsize) - 1));
    
    % last bin
    siglastbin = lfpwt.data(length(sigre) + 1 : length(lfpwt.data));
    
    stdvec = std(sigmat);
    stdvec = [stdvec, std(siglastbin)];
    maxvec = max(abs(sigmat));
    maxvec = [maxvec, max(abs(siglastbin))];
    freq = logspace(0, 2, 100);
    win = hann(binsize);
    [~, fff, ttt, pband] = spectrogram(lfpwt.data, win, 0, freq, fs, 'yaxis', 'psd');
    pband = 10 * log10(abs(pband));
    [~, pc1] = pca(pband', 'NumComponents', 1);
    
    % concatenate and lognorm
    varmat = [stdvec; maxvec];
    if size(varmat, 1) < size (varmat, 2)
        varmat = varmat';
    end
    varmat = log10(varmat);
    varmat = [varmat, pc1];
    
    options = statset('MaxIter', 500);
    gm = fitgmdist(varmat, 2,...
        'options', options, 'Start', 'plus', 'Replicates', 50);
    % cluster
    [gi, ~, ~, ~, mDist] = cluster(bs.gm, varmat);
    
    options = statset('MaxIter', 50);
    gm = fitgmdist(varmat(:, [1, 3]), 2,...
        'options', options, 'Start', 'plus', 'Replicates', 50);
    
    % group data
    basepath = fileparts(fileparts(grppath{1}))
    load(fullfile(basepath, 'as.mat'))
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% general params
fh = figure('Visible', 'on');
set(gcf, 'units','normalized','outerposition',[0 0 1 1]);

Y = sort([1 -1]); % ylim for raw
YY = sort([0.5 -1.5]); % ylim for zoom
binsize = (2 ^ nextpow2(fs * 1));
smf = 15;
marg = 0.05;
minmarg = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% wt mouse

% idx for total recording
idx1 = 18 * fs * 60 : 24 * fs * 60;

idx1 = 20 * fs * 60 : 25 * fs * 60;

dc = mean(lfpwt.data(idx1));
lfpwt.data(idx1) = lfpwt.data(idx1) - mean(lfpwt.data(idx1));
if min(lfpwt.data(idx1)) < max(abs(lfpwt.data(idx1)))
    lfpwt.data(idx1) = -lfpwt.data(idx1);
end

% idx for zoomin in samples
midsig = 22.5;
idx2 = round((midsig - minmarg) * fs * 60 : (midsig + minmarg) * fs * 60);

% raw
subplot(6, 2, 1);
plot(lfpwt.timestamps(idx1) / 60, lfpwt.data(idx1), 'k', 'LineWidth', 1)
hold on
plot([epwt.sur_stamps(:, 1), epwt.sur_stamps(:, 1)] / fs / 60, Y, '-b', 'LineWidth', 2);
set(gca, 'TickLength', [0 0], 'Color', 'none', 'XTickLabel', [],...
    'XColor', 'none')
yticks(Y)
box off
ylabel('Voltage [mV]')
ylim(Y)
idx3 = [idx2(1) idx2(end)] / fs / 60;
fill([idx3 fliplr(idx3)]', [Y(1) Y(1) Y(2) Y(2)],...
    'r', 'FaceAlpha', 0.2,  'EdgeAlpha', 0, 'HandleVisibility', 'off');
xlim([idx1(1) idx1(end)] / fs / 60)
xlabel('Time [m]')
title('WT')

% spectrogram
subplot(6, 2, 3);
specBand('sig', lfpwt.data(idx1), 'graphics', true, 'binsize', binsize,...
    'smf', smf, 'normband', true);
set(gca, 'TickLength', [0 0], 'XTickLabel', [],...
    'Color', 'none', 'XColor', 'none')
ylim([0 100])
set(gca, 'YScale', 'log')
title('')
colorbar('off');

% bsr
subplot(6, 2, 5);
[~, bsidx] = min(abs(bswt.cents - idx1(1)));
[~, bsidx(2)] = min(abs(bswt.cents - idx1(end)));
bsidx = bsidx(1) - 1 : bsidx(2) + 1;
plot(bswt.cents(:) / fs / 60, bswt.bsr(:), 'k', 'LineWidth', 1)
hold on
plot(bswt.cents(:) / fs / 60, epwt.dband(:), 'b', 'LineWidth', 1)
axis tight
ylim([0 1])
set(gca, 'TickLength', [0 0],...
    'Color', 'none')
box off
yticks([0 1])
legend({'BSR', 'Delta Power'}, 'Location', 'northwest')
xlim([idx1(1) idx1(end)] / fs / 60)
xlabel('Time [m]')
xticks(idx1(1) / 60 / fs : 5 : idx1(end) / 60 / fs)
xticklabels({'0', '5', '10', '15', '20'})

% zoom in
subplot(6, 2, 7);
idx5 = iiswt.peakPos > idx2(1) & iiswt.peakPos < idx2(end);
plot(lfpwt.timestamps(idx2) / 60, lfpwt.data(idx2), 'k')
axis tight
hold on
x = xlim;
iiswt.thr(2) = iiswt.thr(2) - dc;
plot(x, -[iiswt.thr(2) iiswt.thr(2)], '--r')
scatter(iiswt.peakPos(idx5) / fs / 60,...
    -iiswt.peakPower(idx5), '*');
bsstamps = RestrictInts(bswt.stamps, [idx2(1) - fs * 20 idx2(end) + 20 * fs]);
ylim(YY)
yticks(YY)
if ~isempty(bsstamps)
    fill([bsstamps fliplr(bsstamps)] / fs / 60, [YY(1) YY(1) YY(2) YY(2)],...
        'k', 'FaceAlpha', 0.25,  'EdgeAlpha', 0);
end
ylabel('Voltage [mV]')
xlabel('Time [m]')
xlim(idx3)
xticks(idx3)
xticklabels([0 2])
set(gca, 'TickLength', [0 0])
box off

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% app mouse

% idx for total recording
idx1 = 28 * fs * 60 : 34 * fs * 60;
idx1 = 130 * fs * 60 : 135 * fs * 60;

dc = mean(lfp.data(idx1));
lfp.data(idx1) = lfp.data(idx1) - dc;
if abs(min(lfp.data(idx1))) < max((lfp.data(idx1)))
    lfp.data(idx1) = -lfp.data(idx1);
end

% idx for zoomin in samples
midsig = 131.5;
idx2 = round((midsig - minmarg) * fs * 60 : (midsig + minmarg) * fs * 60);

% raw
subplot(6, 2, 2);
plot(lfp.timestamps(idx1) / 60, lfp.data(idx1), 'k', 'LineWidth', 1)
hold on
set(gca, 'TickLength', [0 0], 'XTickLabel', [], 'XColor', 'none',...
    'Color', 'none', 'YColor', 'none')
box off
plot([ep.deep_stamps(:, 1), ep.deep_stamps(:, 1)] / fs / 60, Y, '-b', 'LineWidth', 2);
ylim(Y)
% yticks(Y)
idx3 = [idx2(1) idx2(end)] / fs / 60;
fill([idx3 fliplr(idx3)]', [Y(1) Y(1) Y(2) Y(2)],...
    'r', 'FaceAlpha', 0.2,  'EdgeAlpha', 0, 'HandleVisibility', 'off');
axis tight
xlim([idx1(1) idx1(end)] / fs / 60)
xlabel('Time [m]')
% ylabel('LFP [mV]')
title('APP-PS1', 'Interpreter', 'none')

% spectrogram
subplot(6, 2, 4);
specBand('sig', lfp.data(idx1), 'graphics', true, 'binsize', binsize,...
    'smf', smf, 'normband', true);
set(gca, 'TickLength', [0 0], 'XTickLabel', [],...
    'Color', 'none', 'XColor', 'none', 'YColor', 'none')
ylim([0 100])
set(gca, 'YScale', 'log')
title('')

% bsr
subplot(6, 2, 6);
[~, bsidx] = min(abs(bs.cents - idx1(1)));
[~, bsidx(2)] = min(abs(bs.cents - idx1(end)));
bsidx = bsidx(1) : bsidx(2);
plot(bs.cents(:) / fs / 60, bs.bsr(:), 'k', 'LineWidth', 1)
hold on
plot(bs.cents(:) / fs / 60, ep.dband(:), 'b', 'LineWidth', 1)
set(gca, 'TickLength', [0 0], 'YTickLabel', [],...
    'Color', 'none', 'YColor', 'none')
box off
axis tight
ylim([0 1])
xlim([idx1(1) idx1(end)] / fs / 60)
xlabel('Time [m]')
xticks(idx1(1) / 60 / fs : 6 : idx1(end) / 60 / fs)
xticklabels({'0', '5', '10', '15', '20'})

% zoom in
subplot(6, 2, 8);
idx5 = iis.peakPos > idx2(1) & iis.peakPos < idx2(end);
plot(lfp.timestamps(idx2) / 60, lfp.data(idx2), 'k')
axis tight
hold on
x = xlim;
iis.thr(2) = iis.thr(2) - dc;
if iis.thr(2) > 0
    thr = -iis.thr(2);
    power = -iis.peakPower(idx5);
else
    thr = iis.thr(2);
    power = iis.peakPower(idx5);
end
plot(x, [thr thr], '--r')
scatter(iis.peakPos(idx5) / fs / 60,...
    power, '*');
bsstamps = RestrictInts(bs.stamps, [idx2(1) - 60 * fs idx2(end) + 60 * fs]);
ylim(YY);
% yticks(Y);
if ~isempty(bsstamps)
    fill([bsstamps fliplr(bsstamps)] / fs / 60, [YY(1) YY(1) YY(2) YY(2)],...
        'k', 'FaceAlpha', 0.25,  'EdgeAlpha', 0);
end
% ylabel('Voltage [mV]')
xlabel('Time [m]')
xticks(idx3)
xticklabels([0 2])
xlim(idx3)
set(gca, 'TickLength', [0 0], 'YColor', 'none')
box off

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% bs identification

subplot(6, 2, [9, 11])
gscatter(varmat(:, 1), varmat(:, 3), gi, 'rk', '.', 4);
axis tight
hold on
gmPDF = @(x1, x2)reshape(pdf(gm, [x1(:) x2(:)]), size(x1));
ax = gca;
fcontour(gmPDF, [ax.XLim ax.YLim], 'HandleVisibility', 'off')
xlabel(['std [log10(\sigma)]'])
ylabel('PC1 [a.u.]')
legend({'Burst', 'Suppression'}, 'Location', 'northwest')
set(gca, 'TickLength', [0 0])
box off

% std histogram
axes('Position',[.412 .11 .05 .05])
box on
h = histogram(varmat(:, 1), 30, 'Normalization', 'Probability');
h.EdgeColor = 'none';
h.FaceColor = 'k';
h.FaceAlpha = 1;
title(['std'])
axis tight
set(gca, 'TickLength', [0 0], 'YTickLabel', [], 'XTickLabel', [],...
    'YColor', 'none', 'Color', 'none')
box off

% max histogram
axes('Position',[.412 .18 .05 .05])
box on
h = histogram(varmat(:, 2), 30, 'Normalization', 'Probability');
h.EdgeColor = 'none';
h.FaceColor = 'k';
h.FaceAlpha = 1;
title(['max'])
axis tight
set(gca, 'TickLength', [0 0], 'YTickLabel', [], 'XTickLabel', [],...
    'YColor', 'none', 'Color', 'none')
box off

% PC1 histogram
axes('Position',[.362 .11 .05 .05])
box on
h = histogram(varmat(:, 3), 30, 'Normalization', 'Probability');
h.EdgeColor = 'none';
h.FaceColor = 'k';
h.FaceAlpha = 1;
title(['PC1'])
axis tight
set(gca, 'TickLength', [0 0], 'YTickLabel', [], 'XTickLabel', [],...
    'YColor', 'none', 'Color', 'none')
box off

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% aneStats

% All groups
gidx = [ones(1, 30), ones(1, 30) * 2,...
    ones(1, 30) * 3, ones(1, 30) * 4];
% data = as.deepFraction;
c2 = 'kr';

% WT and APPPS1 only
gidx = [ones(1, 30), ones(1, 30) * 2];
% data = as.deepFraction(:, 1 : 2);
data = cell2nanmat(as.bsrDeep(:, 1 : 2));
% data = as.bsr

subplot(6, 2, [10, 12])
boxplot(data, gidx, 'PlotStyle', 'traditional',...
    'BoxStyle', 'outline', 'Color', c2, 'notch', 'off')
hold on
gscatter(gidx, [data(:)], gidx, c2)
legend off
xlabel('')
xticklabels({'WT', 'APPPS1', 'APPKi', 'FADx5'})
% ylabel('Deep anesthesia duration [% total]')
ylabel('BSR in deep anaesthesia')
ylim([0 1])
box off
set(gca, 'TickLength', [0 0])
% % sigstar({[1, 3], [1, 4], [2, 4], [2, 3]}, [0.05, 0.01, 0.01, 0.05], 1);

if saveFig
    figname = fullfile(basepath, 'figS9');
    export_fig(figname, '-tif', '-transparent', '-r300')
    savePdf('figS9', basepath, fh)
end

