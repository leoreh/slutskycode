 % preproc_wrapper
basepath = 'D:\VMs\shared\lh58\lh58_200901_080917';
cd(basepath)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% open ephys
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = 'D:\Data\lh86\2021-03-11_09-55-43';
rmvch = [1 : 35, 37 : 43];
rmvch = [21 : 27];
% mapch = [26 27 28 29 31 2 3 30 4 5 6 7 8 9 10 11 12 13 14 15 32 1 16 17 18 19 20 21 22 23 24 25 33 34 35];
mapch = [1 : 43];
mapch = [1 : 27];
exp = [1];
rec = cell(max(exp), 1);
rec{1} = [2, 3];
datInfo = preprocOE('basepath', basepath, 'exp', exp, 'rec', rec,...
    'rmvch', rmvch, 'mapch', mapch, 'concat', true,...
    'nchans', length(mapch), 'fsIn', 20000);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% tdt
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = 'G:\HB\hb1\baseline_18042021_0811';
store = 'Raw1';
blocks = [1];
chunksize = 300;
mapch = [1 : 16];
% mapch = [1 : 4];
rmvch = [1, 2, 3, 5, 7 : 9, 11 : 13, 15, 16];
% rmvch = [2, 4];
clip = cell(1, 1);
% clip{1} = [24000 Inf];
% clip{3} = [1080 Inf];
datInfo = tdt2dat('basepath', basepath, 'store', store, 'blocks',  blocks,...
    'chunksize', chunksize, 'mapch', mapch, 'rmvch', rmvch, 'clip', clip);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% session info (cell explorer foramt)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'force', true, 'saveVar', true);      
basepath = session.general.basePath;
nchans = session.extracellular.nChannels;
fs = session.extracellular.sr;
spkgrp = session.extracellular.spikeGroups.channels;
[~, basename] = fileparts(basepath);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% field
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
intens = flip([100 : 20 : 200, 240, 280, 320]);
fepsp = fEPSPfromDat('basepath', basepath, 'fname', '', 'nchans', nchans,...
    'spkgrp', spkgrp, 'intens', intens, 'saveVar', true,...
    'force', true, 'extension', 'dat', 'recSystem', 'oe',...
    'protocol', 'io', 'anaflag', true, 'inspect', false, 'fsIn', fs,...
    'cf', 0);  

intens = (100);
fepsp = fEPSPfromWCP('basepath', basepath, 'sfiles', [],...
    'sufx', 'stp_3pulse', 'force', true, 'protocol', 'stp',...
    'intens', intens, 'inspect', false, 'fs', 30000);

fepsp = fEPSP_analysis('fepsp', fepsp, 'basepath', basepath,...
    'force', true);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% spike sorting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% spike detection from temp_wh
[spktimes, ~] = spktimesWh('basepath', basepath, 'fs', fs, 'nchans', nchans,...
    'spkgrp', spkgrp, 'saveVar', true, 'saveWh', true,...
    'graphics', false, 'force', true);

% spike rate
for ii = 1 : length(spkgrp)
    spktimes{ii} = spktimes{ii} / fs;
end
sr = firingRate(spktimes, 'basepath', basepath,...
    'graphics', false, 'saveFig', false,...
    'binsize', 60, 'saveVar', 'sr', 'smet', 'none',...
    'winBL', [0 Inf]);

% clip ns files
% dur = -420;
% t = [];
% nsClip('dur', dur, 't', t, 'bkup', true, 'grp', [3 : 4]);

% create ns files 
dur = -720;
t = [];
spktimes2ns('basepath', basepath, 'fs', fs,...
    'nchans', nchans, 'spkgrp', spkgrp, 'mkClu', true,...
    'dur', dur, 't', t, 'psamp', [], 'grps', [1 : length(spkgrp)],...
    'spkFile', 'temp_wh');

% clean clusters after sorting 
cleanCluByFet('basepath', pwd, 'manCur', false, 'grp', [1 : 4])

% cut spk from dat and realign
fixSpkAndRes('grp', 3, 'dt', 0, 'stdFactor', 0);

% cell explorer metrics
cell_metrics = ProcessCellMetrics('session', session,...
    'manualAdjustMonoSyn', false, 'summaryFigures', false,...
    'debugMode', true, 'transferFilesFromClusterpath', false,...
    'submitToDatabase', false, 'getWaveformsFromDat', true);
cell_metrics = CellExplorer('basepath', basepath);

% cluster validation
mu = [];
spikes = cluVal('spikes', spikes, 'basepath', basepath, 'saveVar', true,...
    'saveFig', false, 'force', true, 'mu', mu, 'graphics', false,...
    'vis', 'on', 'spkgrp', spkgrp);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% cell explorer
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% spikes and cell metrics
spikes = loadSpikes('session', session);
spikes = fixCEspikes('basepath', basepath, 'saveVar', false,...
    'force', true);

cell_metrics = ProcessCellMetrics('session', session,...
    'manualAdjustMonoSyn', false, 'summaryFigures', false,...
    'debugMode', true, 'transferFilesFromClusterpath', false,...
    'submitToDatabase', false);

cell_metrics = CellExplorer('metrics', cell_metrics);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% spikes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% cluster validation
mu = [];
spikes = cluVal('spikes', spikes, 'basepath', basepath, 'saveVar', true,...
    'saveFig', false, 'force', true, 'mu', mu, 'graphics', false,...
    'vis', 'on', 'spkgrp', spkgrp);

% firing rate
binsize = 60;
winBL = [5 * 60 20 * 60];
% winBL = [1 Inf];
fr = firingRate(spikes.times, 'basepath', basepath, 'graphics', false, 'saveFig', false,...
    'binsize', binsize, 'saveVar', true, 'smet', 'MA', 'winBL', winBL);

% CCG
binSize = 0.001; dur = 0.12; % low res
binSize = 0.0001; dur = 0.02; % high res
[ccg, t] = CCG({xx.times{:}}, [], 'duration', dur, 'binSize', binSize);
u = 20;
plotCCG('ccg', ccg(:, u, u), 't', t, 'basepath', basepath,...
    'saveFig', false, 'c', {'k'}, 'u', spikes.UID(u));


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% sleep states
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create lfp
LFPfromDat('basepath', basepath, 'cf', 450, 'chunksize', 5e6,...
    'nchans', nchans, 'fsOut', 1250,...
    'fsIn', fs)   

% load lfp
lfpInterval = [150 * 60, 180 * 60];
lfp = getLFP('basepath', basepath, 'ch', [spkgrp{:}], 'chavg', {},...
    'fs', 1250, 'interval', lfpInterval, 'extension', 'lfp',...
    'savevar', true, 'forceL', true, 'basename', '');

% Buzsaki
badch = setdiff([session.extracellular.electrodeGroups.channels{:}],...
    [session.extracellular.spikeGroups.channels{:}]);
SleepScoreMaster(basepath, 'noPrompts', true, 'rejectChannels', badch)
TheStateEditor(fullfile(basepath, basename))

% accusleep
% prep signal
[EMG, EEG, sigInfo] = as_prepSig([basename, '.lfp'], [basename, '.emg.dat'],...
    'eegCh', [9 : 12], 'emgCh', 1, 'saveVar', true, 'emgNchans', 2,...
    'inspectSig', false, 'forceLoad', true, 'eegFs', 1250, 'emgFs', 3051.75);

% manually create labels
labelsmanfile = [basename, '.AccuSleep_labelsMan.mat'];
AccuSleep_viewer(EEG, EMG, 1250, 1, labels, labelsmanfile)

% classify with a network
ss = as_wrapper(EEG, EMG, [], 'basepath', basepath, 'calfile', [],...
    'viaGui', false, 'forceCalibrate', true, 'inspectLabels', true,...
    'saveVar', true, 'forceAnalyze', true, 'fs', 1250);

% show only x hours of data
x = 11;
tidx = [1 : x * 60 * 60 * 1250];
lidx = [1 : x * 60 * 60];
AccuSleep_viewer(EEG(tidx), EMG(tidx), 1250, 1, labels(lidx), [])

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% spike detection routine
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% create wh.dat
ops = opsKS('basepath', basepath, 'fs', fs, 'nchans', nchans,...
    'spkgrp', spkgrp, 'trange', [0 Inf]);
preprocessDataSub(ops);

% detect spikes
[spktimes, spkch] = spktimesWh('basepath', basepath, 'fs', fs, 'nchans', nchans,...
    'spkgrp', spkgrp, 'saveVar', true, 'chunksize', 2048 ^ 2 + 64,...
    'graphics', false);

% create ns files for kk sorting
% spktimes2ks

% firing rate per tetrode. note that using times2rate requires special care
% becasue spktimes is given in samples and not seconds
binsize = 60 * fs;
winCalc = [0 Inf];
[sr.strd, sr.edges, sr.tstamps] = times2rate(spktimes, 'binsize', binsize,...
    'winCalc', winCalc, 'c2r', false);
% convert counts to rate
sr.strd = sr.strd ./ (diff(sr.edges) / fs);
% fix tstamps
sr.tstamps = sr.tstamps / binsize;

figure, plot(sr.tstamps, sr.strd)
legend

%%% cat dat
nchans = 15;
newpath = 'D:\Data\lh86\lh86_210228_130000';
datFiles{1} = 'D:\Data\lh86\lh86_210228_070000\lh86_210228_070000.dat';
datFiles{2} = 'D:\Data\lh86\lh86_210228_190000\lh86_210228_190000.dat';
sigInfo = dir(datFiles{1});
nsamps = floor(sigInfo.bytes / class2bytes('int16') / nchans);
parts{1} = [nsamps - 6 * 60 * 60 * fs nsamps];
parts{2} = [0 6 * 60 * 60 * fs];

catDatMemmap('datFiles', datFiles, 'newpath', newpath, 'parts', parts,...
    'nchans', nchans, 'saveVar', true)



