function ss = accusleep_wrapper(varargin)

% wrapper for state classification via AccuSleep by Yang Dan
% paper: Berger et al., PlosOne, 2019
% git: https://github.com/zekebarger/AccuSleep
% documentation: doc AccuSleep_instructions
% allows for user defined ignore times obtained automatically from the eeg
% spectrogram or manually using the AccuSleep gui
%
% INPUT:
%   basepath    string. path to recording folder {pwd}
%   cleanRec    numeric. clean recording manually (1) or automatically {2}
%   SR          numeric. sampling frequency of EMG and EEG {512}
%   epochLen    numeric. length of epoch [s] {2.5}
%   minBoutLen  numeric. length of minimum episodes. if empty will be equal
%               to epochLen
%   recSystem   string. recording system, {'tdt'} or 'oe'
%   calfile     string. path to calibrationData file. if empty will search
%               in mouse folder.
%   badEpochs   n x 2 matrix of times to exclude from analysis [s]{[]}
%   lfpCh       numeric. channel number of eeg to load from lfp file. can
%               be a vector and then the channels will be averaged 
%   emgCh       numeric. channel number of eeg to load from lfp file. for
%               oe recording system
%   viaGui      logical. perform analysis manually via gui (true) or
%               automatically via this script {false}
%   forceCalibrate  logical. create calibration matrix even if one already
%                   exists for this mouse {false}
%   inspectLabels   logical. manually review classification 
%   saveVar     logical. save ss var {true}
%   force       logical. reanalyze recordings {false}
%
% DEPENDENCIES:
%   AccuSleep
%
% TO DO LIST:
%       # reduce time bin of rec cleaning
%       # uigetf for net
%       # improve removing badEpochs (very slow)
%       # graphics
%
% 06 feb 21 LH  

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'cleanRec', '2', @isnumeric);
addOptional(p, 'SR', 512, @isnumeric);
addOptional(p, 'epochLen', 2.5, @isnumeric);
addOptional(p, 'minBoutLen', [], @isnumeric);
addOptional(p, 'recSystem', 'tdt', @ischar);
addOptional(p, 'calfile', []);
addOptional(p, 'badEpochs', [], @isnumeric);
addOptional(p, 'lfpCh', [], @isnumeric);
addOptional(p, 'emgCh', [], @isnumeric);
addOptional(p, 'viaGui', [], @islogical);
addOptional(p, 'forceCalibrate', [], @islogical);
addOptional(p, 'inspectLabels', [], @islogical);
addOptional(p, 'saveVar', true, @islogical);
addOptional(p, 'force', false, @islogical);

parse(p, varargin{:})
basepath        = p.Results.basepath;
cleanRec        = p.Results.cleanRec;
SR              = p.Results.SR;
epochLen        = p.Results.epochLen;
minBoutLen      = p.Results.minBoutLen;
recSystem       = p.Results.recSystem;
calfile         = p.Results.calfile;
badEpochs       = p.Results.badEpochs;
lfpCh           = p.Results.lfpCh;
emgCh           = p.Results.emgCh;
viaGui          = p.Results.viaGui;
forceCalibrate  = p.Results.forceCalibrate;
inspectLabels   = p.Results.inspectLabels;
saveVar         = p.Results.saveVar;
force       = p.Results.force;

if isempty(minBoutLen)
    minBoutLen = epochLen;
end

% badEpochs = [];
% recSystem = 'tdt';
% SR = 512;            
% epochLen = 2.5;        
lfpCh = 13 : 16;
% viaGui = false;
% cleanRec = 2;
% forceCalibrate = false;
% minBoutLen = epochLen;

% session info
[~, basename] = fileparts(basepath);
load([basename, '.session.mat'])
basepath = session.general.basePath;
nchans = session.extracellular.nChannels;
recDur = session.general.duration;
fsLfp = session.extracellular.srLfp;

% files
mousepath = fileparts(basepath);
calfile = fullfile(mousepath, [session.animal.name, '.AccuSleep_calibration.mat']);
labelsfile = [basename, '.AccuSleep_labels.mat'];
statesfile = [basename '.AccuSleep_states.mat'];
netfile = 'D:\Code\AccuSleep\trainedNetworks\trainedNetwork2,5secEpochs';
load(netfile, 'net')

% check if already analyzed
if exist(statesfile, 'file') && ~force
    load(statesfile, 'ss')
    return
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arrange data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch recSystem
    case 'tdt'
        % emg
        emgInfo = dir([basename, '.EMG*.datInfo*']);
        load(emgInfo.name)
        fsEmg = datInfo.fs;
        emgname = [basename '.emg.dat'];
        emg_orig = double(bz_LoadBinary(emgname, 'duration', Inf,...
            'frequency', fsEmg, 'nchannels', 1, 'start', 0,...
            'channels', 1, 'downsample', 1));
        
        % lfp
        lfpname = [basename, '.lfp'];
        eeg_orig = double(bz_LoadBinary(lfpname, 'duration', Inf,...
            'frequency', fsLfp, 'nchannels', nchans, 'start', 0,...
            'channels', lfpCh, 'downsample', 1));
        if size(eeg_orig, 2) > 1
            eeg_orig = mean(eeg_orig, 2);
        end
    case 'oe'
end

% find corresponsding timestamps for EMG and labels [s]
tstamps_sig = [1 / SR : 1 / SR : recDur];
tstamps_labels = [0 : epochLen : recDur];

% resmaple 
EMG = [interp1([1 : length(emg_orig)] / fsEmg, emg_orig, tstamps_sig,...
            'pchip')]';
EEG = [interp1([1 : length(eeg_orig)] / fsLfp, eeg_orig, tstamps_sig,...
            'pchip')]';      

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% clean recording 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% find time indices of artifacts. currently uses a temporal resolution that
% corresponds to epoch length but should be improved to < 1 s. just need to
% find away to restore deleted sections afterwards.

if cleanRec == 1
    % ALT 1: manual mark bad times using AccuSleep gui (use NREM
    % as a bad epoch)
    AccuSleep_viewer(EEG, EMG, newFs, 1, [], [basename, '.AccuSleep_ignoreTimes.mat'])
    load([basename, '.AccuSleep_ignoreTimes.mat'])
    badtimes(labels == 3) = 1;
    badtimes(labels == 4) = 0;
    
    % ALT 2: semi-automatically find bad epochs from spectrogram
elseif cleanRec == 2
    [s, ~, ~] = createSpectrogram(standardizeSR(EEG, SR, 128), 128, epochLen);
    badtimes = zeros(round(length(EMG) / SR / epochLen), 1);
    badtimes(zscore(mean(zscore(s), 2)) > 2) = 1;
end

% define bad epoch and remove them from EMG and EEG. this is time consuming
% for no reason
badEpochs = binary2epochs('vec', badtimes, 'minDur', [], 'maxDur', [],...
    'interDur', [], 'exclude', false); 
for i = 1 : size(badEpochs, 1)
    [~, idx1] = min(abs(tstamps_sig - tstamps_labels(badEpochs(i, 1))));
    [~, idx2] = min(abs(tstamps_sig - tstamps_labels(badEpochs(i, 2))));
    EMG(idx1 : idx2) = nan;
    EEG(idx1 : idx2) = nan;
end
EEG(isnan(EEG)) = [];
EMG(isnan(EMG)) = [];
tRemoved = (length(tstamps_sig) - length(EEG)) / SR; % total time removed from data [s]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% AccuSleep pipeline
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if viaGui
    % save files
    save([basename, '.AccuSleep_EEG.mat'], 'EEG')
    save([basename, '.AccuSleep_EMG.mat'], 'EMG')
    labels = ones(1, round(length(EMG) / SR / epochLen)) * 4;
    save(labelsfile, 'labels')
    
    % gui
    AccuSleep_GUI
else
    % get mouse calibration. if does not exist already, manualy score some
    % of the data and save the labels as basename.AccuSleep_labels
    if ~exist(calfile, 'file') || forceCalibrate
        AccuSleep_viewer(EEG, EMG, SR, epochLen, [], []) % not sure calibration can be from here
        load(labelsfile)
        calibrationData = createCalibrationData(standardizeSR(eegFile.EEG, oldSR, 128),...
            standardizeSR(emgFile.EMG, oldSR, 128),...
            labels, 128, str2num(get(handles.tsBox,'String')));
        save(calfile, 'calibrationData')
    else
        load(calfile)
    end
    
    % classify recording
    [labels] = AccuSleep_classify(EEG, EMG, net, SR, epochLen, calibrationData, minBoutLen);
end

% review classification
if inspectLabels
    AccuSleep_viewer(EEG, EMG, SR, epochLen, [], labelsfile)
    load(labelsfile)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Create states structure
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% return bad epochs to labels
x = labels;
for i = 1 : size(badEpochs, 1)
    x = [x(1 : badEpochs(i, 1) - 1);...
        nan(diff(badEpochs(i, :)) + 1, 1);...
    x(badEpochs(i, 1) + 1 : end)];
end

% convert labels to state epochs. 1 - REM, 2 - wake, 3 - NREM
for i = 1 : 3
    binaryVec = zeros(length(x), 1);
    binaryVec(x == i) = 1;
    stateEpisodes = binary2epochs('vec', binaryVec, 'minDur', [], 'maxDur', [],...
        'interDur', [], 'exclude', false); % these are given as indices are equivalent to seconds
    ss.stateEpochs{i} = stateEpisodes * 2.5;
end

ss.labels = labels;
ss.labelNames{1} = 'REM';
ss.labelNames{2} = 'WAKE';
ss.labelNames{3} = 'NREM';
ss.fs = SR;
ss.calibrationData = calibrationData;
ss.badEpochs = badEpochs;
ss.tRemoved = tRemoved;

if saveVar
    save(statesfile, 'ss')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


