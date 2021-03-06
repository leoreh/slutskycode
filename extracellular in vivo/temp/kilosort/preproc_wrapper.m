 % preproc_wrapper
basepath = 'D:\VMs\shared\lh58\lh58_200901_080917';
cd(basepath)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% open ephys
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = 'H:\sleep after CFC\OS\os1\2021-06-30_12-24-18';
rmvch = [3, 7, 13];
mapch = [1 : 20];
exp = [4];
rec = cell(max(exp), 1);
% rec{1} = [2, 3];
datInfo = preprocOE('basepath', basepath, 'exp', exp, 'rec', rec,...
    'rmvch', rmvch, 'mapch', mapch, 'concat', true,...
    'nchans', length(mapch), 'fsIn', 20000);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% tdt
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = 'D:\Data\lh89_210512_090700';
store = 'Raw2';
blocks = [1];
chunksize = 300;
mapch = [1 : 10];
% mapch = [1];
rmvch = [6 : 10];
% rmvch = [];
clip = cell(1, 1);
clip{1} = [0, 42780; 80290, Inf];
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
dur = [];
t = [];
spktimes2ns('basepath', basepath, 'fs', fs,...
    'nchans', nchans, 'spkgrp', spkgrp, 'mkClu', true,...
    'dur', dur, 't', t, 'psamp', [], 'grps', [1 : length(spkgrp)],...
    'spkFile', 'temp_wh');

% clean clusters after sorting 
cleanCluByFet('basepath', pwd, 'manCur', true, 'grp', [1 : 4])

% cut spk from dat and realign
fixSpkAndRes('grp', 3, 'dt', 0, 'stdFactor', 0);

% cell explorer metrics
cell_metrics = ProcessCellMetrics('session', session,...
    'manualAdjustMonoSyn', false, 'summaryFigures', false,...
    'debugMode', true, 'transferFilesFromClusterpath', false,...
    'submitToDatabase', false, 'getWaveformsFromDat', true);
cell_metrics = CellExplorer('basepath', basepath);

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
winBL = [1 Inf];
fr = firingRate(spikes.times, 'basepath', basepath, 'graphics', false, 'saveFig', false,...
    'binsize', binsize, 'saveVar', true, 'smet', 'MA', 'winBL', winBL);

% CCG
binSize = 0.001; dur = 0.12; % low res
binSize = 0.0001; dur = 0.02; % high res
[ccg, t] = CCG({xx.times{:}}, [], 'duration', dur, 'binSize', binSize, 'norm', 'counts');
u = 20;
plotCCG('ccg', ccg(:, u, u), 't', t, 'basepath', basepath,...
    'saveFig', false, 'c', {'k'}, 'u', spikes.UID(u));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% lfp
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

% remove 50 Hz from signal
emgOrig = filterLFP(emgOrig, 'fs', 1250, 'stopband', [49 51],...
    'dataOnly', true, 'saveVar', false, 'graphics', false);

acc = EMGfromACC('basepath', basepath, 'fname', [basename, '.lfp'],...
    'nchans', nchans, 'ch', nchans - 2 : nchans, 'saveVar', true, 'fsIn', 1250,...
    'graphics', false);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% sleep states
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% prep signal
[EMG, EEG, sigInfo] = as_prepSig([basename, '.lfp'], [basename, '.emg.dat'],...
    'eegCh', [1 : 15], 'emgCh', 1, 'saveVar', true, 'emgNchans', 2,...
    'inspectSig', false, 'forceLoad', true, 'eegFs', 1250, 'emgFs', 3051.7578125);

% manually create labels
labelsmanfile = [basename, '.AccuSleep_labelsMan.mat'];
AccuSleep_viewer(EEG, EMG, 1250, 1, labels, labelsmanfile)

% classify with a network
netfile = 'D:\Code\slutskycode\extracellular in vivo\lfp\SleepStates\AccuSleep\trainedNetworks\net_210708_200155.mat';
ss = as_wrapper(EEG, EMG, [], 'basepath', basepath, 'calfile', [],...
    'viaGui', false, 'forceCalibrate', true, 'inspectLabels', false,...
    'saveVar', false, 'forceAnalyze', true, 'fs', 1250, 'netfile', netfile,...
    'graphics', true);

% inspect separation after classifying / manual scoring
as_stateSeparation(EEG, EMG, labels)

% get confusion matrix between two labels
[ss.netPrecision, ss.netRecall] = as_cm(labels1, labels2);

% show only x hours of data
x = 11;
tidx = [1 : x * 60 * 60 * 1250];
lidx = [1 : x * 60 * 60];
AccuSleep_viewer(EEG(tidx), EMG(tidx), 1250, 1, labels(lidx), [])

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% handle dat  files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% cat dat
nchans = 2;
fs = 3051.7578125;
newpath = mousepath;
datFiles{1} = 'G:\lh86\lh86_210228_070000\lh86_210228_070000.emg.dat';
datFiles{2} = 'G:\lh86\lh86_210228_190000\lh86_210228_190000.emg.dat';
sigInfo = dir(datFiles{1});
nsamps = floor(sigInfo.bytes / class2bytes('int16') / nchans);
parts{1} = round([195360091 722703787] / 24414.06 * fs);
parts{2} = round([1 722703787] / 24414.06 * fs);

catDatMemmap('datFiles', datFiles, 'newpath', newpath, 'parts', parts,...
    'nchans', nchans, 'saveVar', true)


% preproc dat
clip = [1, 864000000];
datInfo = preprocDat('basepath', pwd,...
    'fname', 'continuous.dat', 'mapch', 1 : 20,...
    'rmvch', [3, 7, 13], 'nchans', 20, 'saveVar', false, 'clip', clip,...
    'chunksize', 5e6, 'precision', 'int16', 'bkup', true);


