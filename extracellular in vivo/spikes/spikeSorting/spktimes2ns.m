function spktimes2ns(varargin)

% creates ns files (spk, res, fet, and clu) from spktimes. can clip
% spktimes according to requested start time and/or duration. 
%
% INPUT:
%   basepath    string. path to recording folder {pwd}.
%   spkgrp      array where each cell is the electrodes for a spike group.
%               if empty will be loaded from session info file (cell
%               explorer format)
%   grps        numeric. groups (tetrodes) to work on
%   fs          numeric. sampling frequency [hz]{20000}
%   psamp       numeric. peak / trough sample {16}. if empty will be
%               set to half nsamps.
%   nchans      numeric. number of channels in dat file.
%   dur         numeric. duration of trim period [min]. 
%   t           string. start time of trim period. if empty than will take
%               dur minutes from end of recording (if dur is negative) or
%               dur minutes from start of recording (if dur is positive).
%               can be in the format 'HHmmss' or 'HHmm'.
%   mkClu       logical. create also clu file for inspection w/ ns {false}
%   spkFile     string. clip spike waveforms from {'dat'} or 'temp_wh'
% 
% DEPENDENCIES
%   class2bytes
%
% TO DO LIST
%   # replace memmap w/ fread 
%   # clean temp_wh after creation of ns files
% 
% 09 nov 20 LH  updates
% 09 mar 20 LH  dur can be pos / neg

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tic;

p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'spkgrp', {}, @iscell);
addOptional(p, 'grps', [], @isnumeric);
addOptional(p, 'fs', 20000, @isnumeric);
addOptional(p, 'psamp', [], @isnumeric);
addOptional(p, 'nchans', [], @isnumeric);
addOptional(p, 'dur', [], @isnumeric);
addOptional(p, 't', []);
addOptional(p, 'mkClu', false, @islogical);
addOptional(p, 'spkFile', 'dat', @ischar);

parse(p, varargin{:})
basepath    = p.Results.basepath;
spkgrp      = p.Results.spkgrp;
grps        = p.Results.grps;
fs          = p.Results.fs;
psamp       = p.Results.psamp;
nchans      = p.Results.nchans;
dur         = p.Results.dur;
t           = p.Results.t;
mkClu   	= p.Results.mkClu;
spkFile   	= p.Results.spkFile;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% preparations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

sniplength = ceil(1.6 * 10^-3 * fs);
win = [-(floor(sniplength / 2) - 1) floor(sniplength / 2)];   
precision = 'int16'; % for dat file. size of one data point in bytes
nbytes = class2bytes(precision); 

if isempty(psamp)
    psamp = round(sniplength / 2);
end
if isempty(grps)
    grps = 1 : length(spkgrp);
end
ngrps = length(grps);

% build regressor for detrending
s = 0 : sniplength - 1;
scaleS = s(end);
a = s./scaleS;
b = max(a, 0);
W = b(:);
W = [reshape(W, sniplength, []), ones(sniplength,1)];
[Q, R] = qr(W,0);

% memory map to dat file
cd(basepath)
[~, basename] = fileparts(basepath);
fraw = dir([basename '.dat']);
fwh = dir('temp_wh.dat');
nsamps = fraw.bytes / nbytes / nchans;
switch spkFile
    case 'dat'
        m = memmapfile(fraw.name, 'Format', {precision, [nchans, nsamps] 'mapped'});
    case 'temp_wh'
        nchansWh = length([spkgrp{:}]);
        nsampsWh = fwh.bytes / nbytes / nchansWh;
        m = memmapfile(fwh.name, 'Format', {precision, [nchansWh, nsampsWh] 'mapped'});
end       
raw = m.Data;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% trim spktimes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% find boundry samples
dur = dur * 60 * fs;
recStart = '';
if ischar(t)
    recStart = split(basename, '_');
    recStart = recStart{end};
    if numel(recStart) == 6
        tformat = 'HHmmss';
    elseif numel(recStart) == 4
        tformat = 'HHmm';
    end
    recStart = datetime(recStart, 'InputFormat', tformat);
    t = datetime(t, 'InputFormat', tformat);
    if t <= recStart
        t = t + hours(24);
    end
    s = seconds(t - recStart) * fs;
    if ~isempty(dur)
        trimEdges = sort([s s + dur]);
    else
        trimEdges = [s nsamps];
    end
else
    if dur < 0 
        trimEdges = [nsamps + dur nsamps];
    elseif dur > 0
        trimEdges = [1 dur];
    else
        trimEdges = [1 nsamps];
    end
end
if trimEdges(1) < 1
    warning('Requested time beyond recording duration')
    trimEdges(1) = 1;
elseif trimEdges(2) > nsamps
    warning('Requested time beyond recording duration')
    trimEdges(2) = nsamps;
end

% trim spktimes
load([basename '.spktimes.mat'])
for igrp = 1 : ngrps
    spktimes{igrp} = spktimes{igrp}(spktimes{igrp} > trimEdges(1)...
        & spktimes{igrp} < trimEdges(2));
end

% save trim info 
infoname = fullfile(basepath, [basename, '.datInfo.mat']);
if exist(infoname, 'file')
    load(infoname)
    datInfo.spktrim.dur = dur / fs / 60;
    datInfo.spktrim.edges = trimEdges;
    datInfo.spktrim.recStart = recStart;
    datInfo.spktrim.t = t;
    save(infoname, 'datInfo', '-v7.3');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% go over groups and save file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for igrp = 1 : ngrps
    grp = grps(igrp);
    nspks(igrp) = length(spktimes{igrp});
    grpchans = spkgrp{igrp};
    
    % ---------------------------------------------------------------------
    % spk file (binary, nsamples around each spike)
    spkname = fullfile([basename '.spk.' num2str(grp)]);
    fprintf('\nCreating \t%s. ', spkname)
    spk = zeros(length(grpchans), sniplength, nspks(igrp));   
    for ispk = 1 : nspks(igrp)
        % print progress
        if mod(ispk, 10000) == 0
            if ispk ~= 10000
                fprintf(repmat('\b', 1, length(txt)))
            end
            txt = ['Extracted ', num2str(ispk), ' / ', num2str(nspks(igrp)), ' spks'];
            fprintf('%s', txt)     
        end       
        % fix special case where spike is at end / begining of recording
        if spktimes{igrp}(ispk) + win(1) < 1 || spktimes{igrp}(ispk) + win(2) > nsamps
            warning('\nskipping stamp %d because waveform incomplete', ispk)
            spk(:, :, ispk) = [];
            spktimes{igrp}(ispk) = [];
            nspks(igrp) = nspks(igrp) - 1;
            continue
        end        
        % get waveform and remove best fit
        v = double(raw.mapped(grpchans, spktimes{igrp}(ispk) + win(1) :...
            spktimes{igrp}(ispk) + win(2)));
        if strcmp(spkFile, 'dat')
            v = [v' - W * (R \ Q' * v')]';
        end

%         % realign according to minimum
%         [~, ib] = max(range(v'));   % this can be replaced by spktimes 2nd column, will be faster
%         [~, ia] = min(v, [], 2);       
%         peak = ia(ib);
%         ishift = peak - psamp;
%         if ishift ~= 0 
%             spktimes{i}(ii) = spktimes{i}(ii) + ishift;
%                 v = double(raw.mapped(grpchans, spktimes{i}(ii) + win(1) :...
%                     spktimes{i}(ii) + win(2)));
%                 v = [v' - W * (R \ Q' * v')]';
%         end
        spk(:, :, ispk) = v;       

    end
    % save to spk file
    fid = fopen(spkname, 'w');
    fwrite(fid, spk(:), 'int16');
    rc = fclose(fid);
    if rc == 0
        fprintf('. done')
    else
        fprintf('. Failed to create %s!', spkname)
    end
    
    % ---------------------------------------------------------------------
    % res 
    resname = fullfile([basename '.res.' num2str(grp)]);
    fid = fopen(resname, 'w');
    fprintf(fid, '%d\n', spktimes{igrp});
    rc = fclose(fid);
    if rc == 0
        fprintf('\nCreated \t%s', resname)
    else
        fprintf('\nFailed to create %s!', resname)
    end

    % ---------------------------------------------------------------------
    % clu (temporary, for visualization w/ neuroscope)
    if mkClu
        mkdir(['kk' filesep 'preSorting']) 
        nclu = 1;
        clugrp = ones(1, nspks(igrp));
        cluname = fullfile(['kk' filesep 'preSorting'], [basename '.clu.' num2str(grp)]);
        fid = fopen(cluname, 'w');
        fprintf(fid, '%d\n', nclu);
        fprintf(fid, '%d\n', clugrp);
        rc = fclose(fid);
        if rc == 0
            fprintf('\nCreated \t%s', cluname)
        else
            fprintf('\nFailed to create %s!', cluname)
        end
    end
    
    % ---------------------------------------------------------------------
    % fet file    
    fetname = fullfile([basename '.fet.' num2str(grp)]);
    fprintf('\nCreating \t%s. Computing PCAs...', fetname)
    nFeatures = length(grpchans) * 3 + length(grpchans) + 1;
    fetMat = zeros(nspks(igrp), nFeatures);
    enrgIdx = length(grpchans) * 3;
    if ~isempty(spk)
        for ichan = 1 : length(grpchans)
            [~, pcFeat] = pca(permute(spk(ichan, :, :), [3, 2, 1]), 'NumComponents', 3);
            chEnrgy = sum(abs(permute(spk(ichan, :, :), [3, 2, 1])), 2);
            fetMat(:, ichan * 3 - 2 : ichan * 3) = pcFeat;
            fetMat(:, enrgIdx + ichan) = (chEnrgy);
        end
    end
    fetMat(:, end) = double(spktimes{igrp});
    fet = int32(fetMat');
    fid = fopen(fetname, 'w');
    formatstring = '%d';
    for ifet = 2 : nFeatures
        formatstring = [formatstring, '\t%d'];
    end
    formatstring = [formatstring, '\n'];  
    fprintf(fid, '%d\n', nFeatures);
    fprintf(fid, formatstring, fet);
    rc = fclose(fid);
    if rc == 0
        fprintf(' done\n')
    else
        fprintf(' Failed to create %s\n!', fetname)
    end
end
     
end

% EOF