% trains a network on half a data set and test
% accuracy on the other half

% step 1 - configuration
% step 2 - prepare data files (e.g. split 2 two)
% step 3 - train network on 1st half
% step 4 - create calibration on 2nd half using gldstrd
% step 5 - classify 2nd half
% step 6 - compare output with gldstrd
% step 7 - save output

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% params
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% general
fs = 1250;
epochLen = 1;
minBoutLen = epochLen;
nstates = 6; 

% load configuration file
[cfg_colors, cfg_names, cfg_weights, configfile] = as_loadConfig([]);

% weights
gldstrd = labels;
idx = gldstrd ~= 8;
weights = histcounts(gldstrd(idx)) / length(gldstrd(idx));
weights = round(weights * 100) / 100;       % round to two decimals
weights(4) = weights(4) + 1 - sum(weights); % add remainder to NREM
cfg_weights = weights;
cfg_weights = [cfg_weights 0];

% colors
cfg_colors{1} = [240 110 110] / 255;
cfg_colors{2} = [240 170 125] / 255;
cfg_colors{3} = [150 205 130] / 255;
cfg_colors{4} = [110 180 200] / 255;
cfg_colors{5} = [170 100 170] / 255;
cfg_colors{6} = [200 200 100] / 255;
cfg_colors{7} = [200 200 200] / 255;
% state names
cfg_names = {'WAKE'; 'QWAKE'; 'LSLEEP'; 'NREM'; 'REM'; 'N/REM'; 'BIN'};

% save
save(configfile, 'cfg_colors', 'cfg_names', 'cfg_weights')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% files and data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% -------------------------------------------------------------------------
% ALT 1: train network on entire data
basepaths{1} = 'D:\Data\lh87\lh87_210522_095319';
basepaths{2} = 'D:\Data\lh87\lh87_210522_233911';
basepaths{3} = 'D:\Data\lh87\lh87_210523_100607';
basepaths{4} = 'D:\Data\lh87\lh87_210523_224654';
basepaths{5} = 'D:\Data\lh87\lh87_210524_220000';
basepaths{6} = 'D:\Data\lh87\lh87_210525_104820';
basepaths{7} = 'D:\Data\lh87\lh87_210525_211957';
basepaths{8} = 'D:\Data\lh87\lh87_210526_094021';
basepaths{9} = 'D:\Data\lh87\lh87_210526_233634';
basepaths{10} = 'D:\Data\lh87\lh87_210527_101225';
basepaths{11} = 'D:\Data\lh87\lh87_210527_220000';
basepaths{12} = 'D:\Data\lh87\lh87_210528_100000';
basepaths{13} = 'D:\Data\lh87\lh87_210528_221714';
basepaths{14} = 'D:\Data\lh87\lh87_210529_100000';
basepaths{15} = 'D:\Data\lh87\lh87_210529_230722';

basepaths{1} = 'F:\Data\Colleagues\HB\sleepStates\baseline_19042021_0822';
basepaths{2} = 'G:\lh90\lh90_210508_201100';
basepaths{3} = 'G:\lh90\lh90_210509_200000';
basepaths{4} = 'G:\lh90\lh90_210510_085700';
basepaths{5} = 'G:\lh90\lh90_210510_200500';
basepaths{6} = 'G:\lh90\lh90_210511_083500';
basepaths{7} = 'G:\lh90\lh90_210511_201100';
basepaths{8} = 'G:\lh90\lh90_210512_090700';
basepaths{9} = 'G:\lh90\lh90_210512_200000';
basepaths{10} = 'G:\lh90\lh90_210513_090100';
basepaths{11} = 'G:\lh90\lh90_210513_200000';
basepaths{12} = 'G:\lh89\lh89_210507_200800';
basepaths{13} = 'G:\lh89\lh89_210508_083400';
basepaths{14} = 'G:\lh89\lh89_210508_201100';
basepaths{15} = 'G:\lh89\lh89_210509_081100';
basepaths{16} = 'G:\lh89\lh89_210509_200000';
basepaths{17} = 'G:\lh89\lh89_210510_210500';
basepaths{18} = 'G:\lh89\lh89_210511_083500';
basepaths{19} = 'G:\lh89\lh89_210511_201100';
basepaths{20} = 'G:\lh89\lh89_210512_090700';
basepaths{21} = 'G:\lh89\lh89_210512_200000';
basepaths{22} = 'G:\lh89\lh89_210513_081800';
basepaths{23} = 'G:\lh89\lh89_210513_200000';
basepaths{24} = 'G:\lh86\lh86_210227_070000';
basepaths{25} = 'G:\lh86\lh86_210227_190600';
basepaths{26} = 'G:\lh86\lh86_210228_070000';
basepaths{27} = 'G:\lh86\lh86_210228_190000';
basepaths{28} = 'G:\lh86\lh86_210302_084400';
basepaths{29} = 'G:\lh86\lh86_210302_183000';
basepaths{30} = 'G:\lh86\lh86_210303_171000';
basepaths{31} = 'G:\lh86\lh86_210304_070700';
basepaths{32} = 'G:\lh86\lh86_210304_180800';
fileList = as_fileLists(basepaths);

% -------------------------------------------------------------------------
% ALT 2: use part of the data for training and part for testing

% indices
idx = [0 18];      % time for training [h]
idxT = idx * 60 * 60 * fs;
idxL = idx * 60 * 60;
if idxT(1) == 0
    idxT(1) = 1;
    idxL(1) = 1;
end
if idxT(2) == Inf
    idxT(2) = length(EMG);
    idxL(2) = labels;
end

% data
EMG_orig = EMG; 
EEG_orig = EEG;
gldstrd = labels;
EMG = EMG_orig(idxT(1) : idxT(2));
EEG = EEG_orig(idxT(1) : idxT(2));
labels = gldstrd(idxL(1) : idxL(2));
idxT2 = setdiff(1 : length(EMG_orig), idxT(1) : idxT(2));
idxL2 = setdiff(1 : length(gldstrd), idxL(1) : idxL(2));
labels2 = gldstrd(idxL2);
EMG2 = EMG_orig(idxT2);
EEG2 = EEG_orig(idxT2);

% visualize data
AccuSleep_viewer(EEG_orig, EMG_orig, fs, epochLen, gldstrd, [])
AccuSleep_viewer(EEG2, EMG2, fs, epochLen, labels2, [])
AccuSleep_viewer(EEG, EMG, fs, epochLen, labels, [])

% files
basepath = 'F:\Data\Colleagues\KBO\040721_0746';
[~, basename] = fileparts(basepath);
basepath = fullfile(basepath, 'netTraining');
mkdir(basepath)
save(fullfile(basepath, [basename, '.AccuSleep_EEG.mat']), 'EEG')
save(fullfile(basepath, [basename, '.AccuSleep_EMG.mat']), 'EMG')
save(fullfile(basepath, [basename, '.AccuSleep_labelsMan.mat']), 'labels1')
fileList = as_fileLists(basepaths);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% train
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[net, netInfo] = AccuSleep_train(fileList, fs, epochLen, 63);
netpath = 'D:\Code\slutskycode\extracellular in vivo\lfp\SleepStates\AccuSleep\trainedNetworks';
netname = ['net_',  datestr(datetime, 'yymmdd_HHMMss')]; 
save(fullfile(netpath, netname), 'net', 'netInfo')      

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% test net (on remaining part of the data)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
% create calibration (based on entire dataset, doesn't matter)
calibrationData = createCalibrationData(standardizeSR(EEG_orig, fs, 128),...
    standardizeSR(EMG_orig, fs, 128), gldstrd, 128, epochLen);

% classify
[labels_net, netScores] = AccuSleep_classify(standardizeSR(EEG2, fs, 128),...
    standardizeSR(EMG2, fs, 128), net, 128, epochLen, calibrationData, minBoutLen);
    
% manually inspect model output and gldstrd
AccuSleep_viewer(EEG2, EMG2, fs, epochLen, labels_net, [])
AccuSleep_viewer(EEG2, EMG2, fs, epochLen, labels2, [])

% check precision
[netPrecision, netRecall] = as_cm(labels2, labels_net);


