function [EMG, EEG, sigInfo] = as_prepSig(eegData, emgData, varargin)

% prepare signals for accusleep. filters and subsamples eeg and emg. two
% options to input data; ALT 1 is to directly input eeg and emg data as
% vectors (e.g. via getLFP). this requires inputing the signals sampling
% frequency. ALT 2 is to load traces from an lfp / dat file. this requires
% session info struct (cell explorer format) and inputing the signal
% channels within the file.
%
% INPUT:
%   eegData     ALT 1; eeg numeric data (1 x n1).
%               ALT 2; string. name of file with data. must include
%               extension (e.g. lfp / dat)
%   emgData     ALT 1; emg numeric data (1 x n2).
%               ALT 2; string. name of file with data. must include
%               extension (e.g. lfp / dat)
%   eegFs       numeric. eeg sampling frequency
%   emgFs       numeric. emg sampling frequency
%   eegCh       numeric. channel number of eeg to load from lfp file. can
%               be a vector and then the channels will be averaged
%   emgCh       numeric. channel number of eeg to load from lfp file. for
%               oe recording system
%   basepath    string. path to recording folder {pwd}
%   saveVar     logical. save ss var {true}
%   forceLoad   logical. reload recordings even if mat exists
%   inspectSig  logical. inspect signals via accusleep gui {false}
%
% DEPENDENCIES:
%   rmDC
%   iosr.DSP.SINCFILTER     for low-pass filtering EEG data
%
% TO DO LIST:
%       # implement cleanSig
%       # input nchans for emg / eeg files separately
%
% 19 apr 21 LH

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'eegCh', 1, @isnumeric);
addOptional(p, 'emgCh', 1, @isnumeric);
addOptional(p, 'eegFs', [], @isnumeric);
addOptional(p, 'emgFs', [], @isnumeric);
addOptional(p, 'saveVar', true, @islogical);
addOptional(p, 'inspectSig', false, @islogical);
addOptional(p, 'forceLoad', false, @islogical);

parse(p, varargin{:})
basepath        = p.Results.basepath;
eegCh           = p.Results.eegCh;
emgCh           = p.Results.emgCh;
eegFs           = p.Results.eegFs;
emgFs           = p.Results.emgFs;
saveVar         = p.Results.saveVar;
inspectSig      = p.Results.inspectSig;
forceLoad       = p.Results.forceLoad;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% preparations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% analysis params (decided by RA, HB, and LH 20 apr 21)
eegCf = 60;         % cutoff frequency for eeg
emgCf = [10 200];   % cutoff frequency for emg
fs = 1250;          % requested sampling frequency

% eegCf = [];
% emgCf = [];
% fs = 1250;

% file names
cd(basepath)
mousepath = fileparts(basepath);
[~, basename] = fileparts(basepath);
eegfile = [basename '.AccuSleep_EEG.mat'];
emgfile = [basename '.AccuSleep_EMG.mat'];
sessionInfoFile = [basename, '.session.mat'];

% initialize
sigInfo = [];
recDur = [];

% reload data if already exists and return
if exist(emgfile, 'file') && exist(eegfile, 'file') && ~forceLoad
    fprintf('\n%s and %s already exist. loading...\n', emgfile, eegfile)
    load(eegfile, 'EEG')
    load(emgfile, 'EMG')
    return
end
    
% import toolbox for filtering    
import iosr.dsp.*

% session info
if exist(sessionInfoFile, 'file')
    load([basename, '.session.mat'])
    nchans = session.extracellular.nChannels;
    recDur = session.general.duration;
    if isempty(eegFs)
        eegFs = session.extracellular.srLfp;
    end
    if isempty(emgFs)
        emgFs = eegFs;
    end
end

% load data from lfp file if raw data was not given 
if ischar(eegData) || isempty(eegData)
    if isempty(eegData)
        eegData = [basename '.lfp'];
        if ~exist(eegData, 'file')
            eegData = [basename '.dat'];
            if ~exist(eegData, 'file')
                error('could not fine %s. please specify lfp file or input data directly', eegfile)
            end
        end
        if isempty(emgData)
            emgData = eegData;
        end
    end
    
    % load emg
    emgOrig = double(bz_LoadBinary(emgData, 'duration', Inf,...
        'frequency', emgFs, 'nchannels', 2, 'start', 0,...
        'channels', emgCh, 'downsample', 1));
        
    % load eeg and average across given channels
    eegOrig = double(bz_LoadBinary(eegData, 'duration', Inf,...
        'frequency', eegFs, 'nchannels', nchans, 'start', 0,...
        'channels', eegCh, 'downsample', 1));
    if size(eegOrig, 2) > 1
        eegOrig = mean(eegOrig, 2);
    end   
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% filter and downsample
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% low-pass filter eeg to assure nyquist.
% note accusleep only uses spectrogram up to 50 Hz
if ~isempty(eegCf)
    fprintf('\nfiltering EEG, cutoff = %d Hz', eegCf)
    filtRatio = eegCf / (eegFs / 2);
    eegOrig = iosr.dsp.sincFilter(eegOrig, filtRatio);
end

if ~isempty(emgCf)
    fprintf('\nfiltering EMG, cutoff = %d Hz', emgCf)
    filtRatio = emgCf / (emgFs / 2);
    emgOrig = iosr.dsp.sincFilter(emgOrig, filtRatio);
end

% remove DC component
fprintf('\nremoving DC component\n')
eegOrig = rmDC(eegOrig, 'dim', 1);
if numel(emgCf) ~= 2
    emgOrig = rmDC(emgOrig, 'dim', 1);
end

if isempty(recDur)
    recDur = length(emgOrig) / emgFs;
end

% validate recording duration and sampling frequency 
emgDur = length(emgOrig) / emgFs;
eegDur = length(eegOrig) / eegFs;
if abs(emgDur - eegDur) > 2
    warning(['EEG and EMG are of differnet duration (diff = %.2f s).\n',...
        'Check data and sampling frequencies.\n'], abs(emgDur - eegDur))
end
if isempty(recDur)
    recDur = eegDur;
end
tstamps_sig = [1 / fs : 1 / fs : recDur];

% subsample emg and eeg to the same length. assumes both signals span the
% same time interval. interpolation, as opposed to idx subsampling, is
% necassary for cases where the sampling frequency is not a round number
% (tdt). currently, this is done even when fs == round(fs) for added
% consistancy.
fprintf('downsampling to %d Hz\n', fs)
if fs ~= emgFs
    EMG = [interp1([1 : length(emgOrig)] / emgFs, emgOrig, tstamps_sig,...
        'pchip')]';
end
if fs ~= eegFs || length(emgOrig) ~= length(eegOrig)
    EEG = [interp1([1 : length(eegOrig)] / eegFs, eegOrig, tstamps_sig,...
        'pchip')]';
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% finilize and save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% inspect signals
if inspectSig
    AccuSleep_viewer(EEG, EMG, fs, 1, [], [])
    uiwait
end

info.fs = fs;
info.eegFs = eegFs;
info.emgFs = emgFs;
info.eegCf = eegCf;
info.emgCf = emgCf;

% save files
if saveVar
    save(eegfile, 'EEG')
    save(emgfile, 'EMG')
end

end

% EOF


