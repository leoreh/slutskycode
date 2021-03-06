function snips = snipFromDat(varargin)

% maps dat file to memory and snips segments sorrounding specific
% samples. user defines the window length sorrounding each snippet (does
% not have to be symmetrical) and can arrange the output according to
% channel groups
%
% INPUT:
%   basepath    string. path to .dat file (not including dat file itself)
%               {pwd}.
%   fname       string. name of dat file. can be empty if only one dat file
%               exists in basepath or if fname can be extracted from basepath
%   stamps      vec. pointers to dat files from which snipping will occur
%               [samples].
%   win         vec of 2 elements. determines length of snip. for example,
%               win = [5 405] than each snip will be 401 samples, starting
%               5 samples after the corresponding stamp and ending 405
%               samples after stamp. if win = [-16 16] than snip will be of
%               33 samples symmetrically centered around stamp.
%   nchans      numeric. number of channels in dat file {35}
%   ch          vec. channels to load from dat file {[]}. if empty than all will
%               be loaded
%   precision   char. sample precision of dat file {'int16'}
%   b2uv        numeric. conversion of bits to uV {0.195}
%   dtrend      logical. detrend snippets {false}.
%   l2norm      logical. L2 normalize snippets {false}.
%   extension   string. load from {'dat'} or 'lfp' file.
%
% OUTPUT
%   snips       matrix of ch x sampels x stamps. class double
% 
% CALLS:
%   class2bytes
%
% TO DO LIST:
%
% 10 apr 20 LH  updates:
% 13 may 20 LH      separate detrend and normalize
% 03 sep 20 LH      snip from lfp 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'fname', '', @ischar);
addOptional(p, 'stamps', [], @isnumeric);
addOptional(p, 'win', [-16 16], @isnumeric);
addOptional(p, 'nchans', 35, @isnumeric);
addOptional(p, 'ch', [], @isnumeric);
addOptional(p, 'precision', 'int16', @ischar);
addOptional(p, 'b2uv', 0.195, @isnumeric);
addOptional(p, 'dtrend', false, @islogical);
addOptional(p, 'l2norm', false, @islogical);
addOptional(p, 'extension', 'dat', @ischar);

parse(p, varargin{:})
basepath = p.Results.basepath;
fname = p.Results.fname;
stamps = p.Results.stamps;
win = p.Results.win;
nchans = p.Results.nchans;
ch = p.Results.ch;
precision = p.Results.precision;
b2uv = p.Results.b2uv;
dtrend = p.Results.dtrend;
l2norm = p.Results.l2norm;
extension = p.Results.extension;

if isempty(ch)
    ch = 1 : nchans;
end

% size of one data point in bytes
nbytes = class2bytes(precision);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% preparations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% handle dat or lfp file
cd(basepath)
datFiles = dir([basepath filesep '**' filesep '*' extension]);
if isempty(datFiles)
    error('no .dat files found in %s', basepath)
end
if isempty(fname)
    if length(datFiles) == 1
        fname = datFiles.name;
    else
        fname = [bz_BasenameFromBasepath(basepath) '.' extension];
        if ~contains({datFiles.name}, fname)
            error('please specify which dat file to process')
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% snip
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% memory map to dat file
info = dir(fname);
nsamps = info.bytes / nbytes / nchans;
m = memmapfile(fname, 'Format', {precision, [nchans, nsamps] 'mapped'});

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
    v = double(m.Data.mapped(ch, stamps(i) + win(1) : stamps(i) + win(2)));
    
    % convert bits to uV
    if b2uv
        v = v * b2uv;
    end
    
    % L2 normalize 
    if l2norm
        v = v ./ vecnorm(v, 2, 2);
    end
    
    % detrend
    if dtrend
        v = [detrend(v')]';
    end
    
    snips(:, :, i) = v;
end

clear m

end

% EOF