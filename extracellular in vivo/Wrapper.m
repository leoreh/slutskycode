% this is a wrapper for processing extracellular data.
% contains calls to various functions.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% file conversions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = 'H:\Data\Dat\lh46\lh46_200226';
store = 'Raw1';
fs = 24414.06;
blocks = [1, 2];
chunksize = 300;
mapch = [1 : 16];
% mapch = [];
% mapch = [1 : 2 : 7, 2 : 2 : 8, 9 : 2 : 15, 10 : 2 : 16];
rmvch = [];
clip = cell(1, 1);

% tank to dat
[datInfo] = tdt2dat('basepath', basepath, 'store', store, 'blocks',  blocks,...
    'chunksize', chunksize, 'mapch', mapch, 'rmvch', rmvch, 'clip', clip);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 1b: open ephys
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = 'F:\Data\Dat\lh52\2020-06-09_09-05-32';
rmvch = [10, 12, 13, 16, 17, 21, 23, 24];
mapch = [25 26 27 28 30 1 2 29 3 : 14 31 0 15 16 17 : 24 32 33 34] + 1;
exp = [10];
rec = cell(max(exp), 1);
% rec{exp} = 1 : 4;
datInfo = preprocOE('basepath', basepath, 'exp', exp, 'rec', rec,...
    'rmvch', rmvch, 'mapch', mapch, 'concat', true, 'nchans', 35);

basepath = 'H:\Data\Dat\lh50\lh50_200423\090405_e1r1-1';
datInfo = preprocDat('basepath', basepath, 'fname', '', 'mapch', mapch,...
    'rmvch', rmvch, 'nchans', 35, 'saveVar', true,...
    'chunksize', 5e5, 'precision', 'int16', 'bkup', true);

% get fEPSP
basepath = 'E:\Data\Dat\lh50\lh50_200428\100405_e4r1-5';
tet = [1 : 4; 5 : 8; 9 : 12; 13 : 16; 17 : 20; 21 : 24; 25 : 28];
tet = num2cell(tet, 2);
intens = [20 40 60 80 100];
fepsp = getfEPSPfromOE('basepath', basepath, 'fname', '', 'nchans', 31,...
    'tet', tet, 'intens', intens, 'concat', false, 'saveVar', true,...
    'force', true);  

% acceleration
newch = length(mapch) - length(rmvch);
chAcc = [newch : -1 : newch - 2];
newpath = fileparts(datInfo.newFile);
getACCfromDat('basepath', newpath, 'fname', '',...
    'nchans', newch, 'ch', chAcc, 'force', false, 'saveVar', true,...
    'graphics', false, 'fs', 1250);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 2: LFP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% load lfp
ch = [1 : 16];
chavg = {1 : 4; 5 : 7; 8 : 11; 12 : 15};
chavg = {};
lfp = getLFP('basepath', basepath, 'ch', ch, 'chavg', chavg,...
    'fs', 1250, 'interval', [0 inf], 'extension', 'lfp',...
    'savevar', true, 'forceL', true, 'basename', '');

% load with stim (tdt). DONT FORGET TO CHANGE NAME
lfp = getfEPSPfromTDT('basepath', basepath, 'andname', 'stability2',...
    'blocks', blocks, 'mapch', mapch, 'ch', ch, 'clip', clip,...
    'saveVar', true, 'fdur', 0.1, 'concat', true);

% inter ictal spikes
thr = [5 0];
marg = 0.05;
binsize = (2 ^ nextpow2(30 * lfp.fs));
ch = 1;
smf = 7;
iis = getIIS('sig', double(lfp.data(:, ch)), 'fs', lfp.fs, 'basepath', basepath,...
    'graphics', true, 'saveVar', true, 'binsize', binsize,...
    'marg', marg, 'basename', '', 'thr', thr, 'smf', 7,...
    'saveFig', false, 'forceA', true, 'spkw', false, 'vis', true);

% burst suppression
vars = {'std', 'max', 'sum'};
bs = getBS('sig', double(lfp.data(:, ch)), 'fs', lfp.fs,...
    'basepath', basepath, 'graphics', true,...
    'saveVar', true, 'binsize', 1, 'BSRbinsize', binsize, 'smf', smf,...
    'clustmet', 'gmm', 'vars', vars, 'basename', '',...
    'saveFig', false, 'forceA', true, 'vis', true);

% anesthesia states
[bs, iis, ep] = aneStates_m('ch', 1, 'basepath', basepath,...
    'basename', '', 'graphics', true, 'saveVar', true,...
    'saveFig', false, 'forceA', false, 'binsize', 30, 'smf', 7);
    

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 3: load EMG
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% option 1:
blocks = [2];
rmvch = [2:4];
emg = getEMG(basepath, 'Stim', blocks, rmvch);

% option 2:
emglfp = getEMGfromLFP(double(lfp.data(:, chans)), 'emgFs', 10, 'saveVar', true);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 4: spikes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% load
spikes = getSpikes('basepath', basepath, 'saveMat', true,...
    'noPrompts', true, 'forceL', false);

% review clusters
mu = find(spikes.isi > 1);
mu = sort([mu', 2, 4, 19, 22, 26, 42, 44, 46, 48, 50, 52, 55, 59, 64, 67, 69, 75]);
mu = [];
spikes = cluVal(spikes, 'basepath', basepath, 'saveVar', false,...
    'saveFig', false, 'force', true, 'mu', mu, 'graphics', true,...
    'vis', 'on');

% compare number of spikes and clusters from clustering to curation 
numSpikes = getNumSpikes(basepath, spikes);

% separation of SU and MU
plotIsolation(basepath, spikes, false)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 4: CCH temporal dynamics 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% use buzcode CCG
% low res
binSize = 0.001; % [s]
dur = 0.05;
[ccg t] = CCG({spikes.times{:}}, [], 'duration', dur, 'binSize', binSize);
% high res
binSize = 0.0001; 
dur = 0.02;
[ccg t] = CCG({spikes.times{:}}, [], 'duration', dur, 'binSize', binSize);

for i = 1 : nunits
    nspikes(i) = length(spikes.times{i});
end

u = spikes.UID(nspikes > 6300);
u(1) = [];

u = sort([20 27]);
plotCCG('ccg', ccg(:, u, u), 't', t, 'basepath', basepath,...
    'saveFig', false, 'c', {'k'}, 'u', spikes.UID(u));

uu = datasample(u, 7, 'replace', false);
plotCCG('ccg', ccg(:, uu, uu), 't', t, 'basepath', basepath,...
    'saveFig', false, 'c', {'k'}, 'u', spikes.UID(uu));

    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 5: cell classification based on waveform
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
basepath = 'E:\Data\Dat\Refaela\120520_Bsl';
spikes = getSpikes('basepath', basepath, 'saveMat', false,...
    'noPrompts', true, 'forceL', false);
ch{1} = 1 : 4;
ch{2} = 5 : 8;
ch{3} = 9 : 12;
ch{4} = 13 : 16;
% ch{1} = 1 : 4;
% ch{2} = 5 : 7;
% ch{3} = 8 : 10;
% ch{4} = 11 : 13;

spikes = getSPKfromDat('basepath', basepath, 'fname', '',...
    'win', [-18 21], 'spktimes', spikes.times, 'grp', spikes.shankID,...
    'ch', ch, 'dtrend', true, 'nchans', length([ch{:}]),...
    'fs', spikes.samplingRate, 'b2uv', []);

waves = [];
for i = 1 : length(path)
    waves = [waves, cat(1, s{i}.rawWaveform{:})'];
end
waves = cat(1, spikes.rawWaveform{:})';
waves = spikes.maxwv';
cc = cellclass('waves', waves,...
    'fs', spikes.samplingRate, 'man', false, 'spikes', spikes); 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 6: firing rate
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
winBL = [info.lns(1) info.lns(3)] * spikes.samplingRate * 60;
fr = FR(x, 'basepath', basepath, 'graphics', false, 'saveFig', false,...
    'binsize', 60, 'saveVar', false, 'smet', 'MA');

% unite all units
x = {sort(vertcat(spikes.times{:}))};
[fr.strd, ~, fr.tstamps] = calcFR(x, 'binsize', 60,...
    'winCalc', [1 Inf], 'smet', 'none');

filename = bz_BasenameFromBasepath(basepath);
filename = [filename '.Raw1.Info.mat'];
load(filename);
info.labels = {'BL', '2', '3', '4'};
lns = cumsum(info.blockduration / 60);
lns = [1e-6 lns];
info.lns = lns(1);
save(filename, 'info');

info.lns = cumsum(datInfo.nsamps / 20000 / 60);

f = figure;
subplot(2, 1, 1)
plotFRtime('fr', fr, 'units', true, 'spktime', spikes.times,...
    'avg', false, 'lns', info.lns, 'lbs', info.labels,...
    'raster', false, 'saveFig', false);
title('')
xlabel('')
subplot(2, 1, 2)
plotFRtime('fr', fr, 'units', false, 'spktime', spikes.times,...
    'avg', true, 'lns', info.lns, 'lbs', info.labels,...
    'raster', false, 'saveFig', false);
xlabel('Time [m]')
title('')
figname = 'Firing Rate';
export_fig(figname, '-tif', '-transparent')
        
[nunits, nbins] = size(fr.strd);
tFR = ([1 : nbins] / (60 / fr.binsize) / 60);
p = plot(tFR, log10(fr.strd));
hold on
plot(tFR, mean(log10(fr.strd)), 'k', 'LineWidth', 3)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 7: concatenate spikes from different sessions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parentdir = 'E:\Data\Others\Buzsaki';
basepath = parentdir;
structname = 'spikes';
spikes = catStruct(parentdir, structname);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% STEP 8: get video projection from ToxTrack file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
filename = 'TestProject';
vid = getVid(filename, 'basepath', basepath, 'graphics', true, 'saveFig', false, 'saveVar', false);


