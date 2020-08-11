function LFPfromDat(varargin)


% creates lfp
%  
% because the way downsampling occurs, the final duration may not be
% accurate if the input fs is not a round number. one way arround
% this is to define the output fs s.t. the ratio output/input is round.
% however, this is not possible for many inputs (including 24414.06). do
% not see a way around this inaccuracy.
% 
% difference from bz_LFPfromDat: (1) bz handles the remainder separately
% s.t. there is a continuity problem at the last chunk, (2) no annoying
% waitbar, (3) feeds sincFilter all channels at once (not much difference
% because sincFilter loops through channels), (4) handles data more
% efficiently (180 vs 230 s for 90 m recording), (5) documentation and
% arguments.
% 
% 
% INPUT
%   basename    string. filename of lfp file. if empty retrieved from
%               basepath. if .lfp should not include extension, if .wcp
%               should include extension
%   basepath    string. path to load filename and save output {pwd}
%   precision   char. sample precision of dat file {'int16'} 
%   clip        mat n x 2 indicating samples to diregard from chunks.
%               for example: clip = [0 50; 700 Inf] will remove the first
%               50 samples and all samples between 700 and n

%   extension   load from {'lfp'} (neurosuite), 'abf', 'wcp', or 'dat'.
%   forceL      logical. force reload {false}.
%   fs          numeric. requested sampling frequency {1250}
%   interval    numeric mat. list of intervals to read from lfp file [s]
%               can also be an interval of traces from wcp
%   ch          vec. channels to load
%   pli         logical. filter power line interferance (1) or not {0}
%   dc          logical. remove DC component (1) or not {0}
%   invertSig   logical. invert signal s.t. max is positive
%   saveVar     save variable {1}.
%   chavg       cell. each row contain the lfp channels you want to average
%   
% DEPENDENCIES
%   import_wcp
%   ce_LFPfromDat (if extension = 'dat')
% 
% OUTPUT
%   lfp         structure with the following fields:
%   fs
%   fs_orig
%   extension
%   interval    
%   duration    
%   chans
%   timestamps 
%   data  
% 
% 01 apr 19 LH & RA
% 19 nov 19 LH          load mat if exists  
% 14 jan 19 LH          adapted for wcp and abf 
%                       resampling
%
% TO DO LIST
%       # lfp from dat

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'basename', '');
addOptional(p, 'extension', 'lfp');
addOptional(p, 'forceL', false, @islogical);
addOptional(p, 'fs', 1250, @isnumeric);
addOptional(p, 'interval', [0 inf], @isnumeric);
addOptional(p, 'ch', [1 : 16], @isnumeric);
addOptional(p, 'pli', false, @islogical);
addOptional(p, 'dc', false, @islogical);
addOptional(p, 'invertSig', false, @islogical);
addOptional(p, 'saveVar', true, @islogical);
addOptional(p, 'chavg', {}, @iscell);

parse(p,varargin{:})
basepath = p.Results.basepath;
basename = p.Results.basename;
extension = p.Results.extension;
forceL = p.Results.forceL;
fs = p.Results.fs;
interval = p.Results.interval;
ch = p.Results.ch;
pli = p.Results.pli;
dc = p.Results.dc;
invertSig = p.Results.invertSig;
saveVar = p.Results.saveVar;
chavg = p.Results.chavg;

fsOut = 1250;
fsIn = 24414.06;
force = true;
cf = [0 450];
nchans = 16; 
clip = [];
precision = 'int16';

chunksize = 1e5; % 


[~, basename] = fileparts(basepath);
% size of one data point in bytes
nbytes = class2bytes(precision);

filtRatio = cf(2) / (fsIn / 2);
%   Y = IOSR.DSP.SINCFILTER(X,WN) applies a near-ideal low-pass or
%   band-pass brickwall filter to the array X, operating along the first
%   non-singleton dimension (e.g. down the columns of a matrix). The
%   cutoff frequency/frequencies are specified in WN. If WN is a scalar,
%   then WN specifies the low-pass cutoff frequency. If WN is a two-element
%   vector, then WN specifies the band-pass interval. WN must be 0.0 < WN <
%   1.0, with 1.0 corresponding to half the sample rate.
% 
%   The filtering is performed by FFT-based convolution of X with the sinc
%   kernel.

fsRatio = (fsIn / fsOut);
if cf(2) > fsOut / 2
    warning('low pass cutoff beyond nyquist')
end


import iosr.dsp.*

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% handle files and chunks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% handle files
fdat = fullfile(basepath,[basename,'.dat']);
flfp = fullfile(basepath,[basename,'.lfp']);

% check that basename.dat exists
if ~exist(fdat, 'file')
    error('%s does not exist', fdat)
end
datinfo = dir(fdat);

% check if basename.lfp exists
if exist(flfp, 'file') && ~force
  fprintf('%s exists, returning...', flfp)
end

% Set chunk and buffer size at even multiple of fsRatio
if mod(chunksize, fsRatio) ~= 0
    chunksize = round(chunksize + fsRatio - mod(chunksize, fsRatio));
end

ntbuff = 525;  % default filter size in iosr toolbox
if mod(ntbuff, fsRatio)~=0
    ntbuff = round(ntbuff + fsRatio - mod(ntbuff, fsRatio));
end

% partition into chunks
nsamps = datinfo.bytes / nbytes / nchans;
chunks = n2chunks('n', nsamps, 'chunksize', chunksize, 'clip', clip,...
    'overlap', ntbuff);
nchunks = size(chunks, 1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% processing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tic
% memory map to original file
m = memmapfile(fdat, 'Format', {precision [nchans nsamps] 'mapped'});
raw = m.data;

fid = fopen(fdat, 'r');
fidOut = fopen(flfp, 'a');
for i = 1 : nchunks
    
    % print progress
    if i ~= 1
        fprintf(repmat('\b', 1, length(txt)))
    end
    txt = sprintf('working on chunk %d / %d', i, nchunks);
    fprintf(txt)
    
    % load chunk
    d = raw.mapped(:, chunks(i, 1) : chunks(i, 2));
    d = double(d);
    
    % filter
    filtered = [iosr.dsp.sincFilter(d', filtRatio)]';
    
    % downsample
    if i == 1
        dd = int16(real(filtered(:, fsRatio : fsRatio :...
            length(filtered) - ntbuff)));
    else
        dd = int16(real(filtered(:, ntbuff + fsRatio : fsRatio :...
            length(filtered) - ntbuff)));
    end

    fwrite(fidOut, dd(:), 'int16'); 
end

fclose(fid);
fclose(fidOut);

toc
fprintf('that took %.2f minutes\n', toc / 60)

disp(['lfp file created: ', flfp,'. Process time: ' num2str(toc(timerVal)/60,2),' minutes'])

  
end






% EOF