function  cc = cellclass(varargin)

% classifies clusters to PYR \ INT according to waveform parameters
% (trough-to-peak and spike width, also calculates asymmetry).
% 
% INPUT
%   waves       matrix of sampels (rows) x units (columns). for example:
%               waves = cat(1, spikes.rawWaveform{spikes.su})'
%               waves = cat(1, spikes.rawWaveform{:})'
%   spikes      struct. see getSpikes.m
%   u           vector of indices or logical according to spikes.UID
%   mfr         mean firing rate for each unit
%   man         logical. manual selection or automatic via known values
%   fs          sampling frequency
%   basepath    recording session path {pwd}
%   graphics    plot figure {1}.
%   saveFig     save figure {1}.
%   saveVar     save variable {1}.
% 
% OUTPUT
%   CellClass   struct with fields:
%       pyr         logical vector where 1 = PYR and 0 = INT
%       tp          trough-to-peak times
%       spkw        spike width
%       asym        asymmetry
% 
% DEPENDENCIES
%   getWavelet      from buzcode
%   fft_upsample    from Kamran Diba
%
% 08 apr 19 LH. 
% 21 nov 19 LH      added spikes and FR in scatter

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

p = inputParser;
addOptional(p, 'spikes', struct);
addOptional(p, 'waves', []);
addOptional(p, 'u', []);
addOptional(p, 'mfr', [], @isnumeric);
addOptional(p, 'basepath', pwd);
addOptional(p, 'man', false, @islogical);
addOptional(p, 'fs', 24414.14, @isnumeric);
addOptional(p, 'graphics', true, @islogical);
addOptional(p, 'saveFig', false, @islogical);
addOptional(p, 'saveVar', false, @islogical);

parse(p, varargin{:})
spikes = p.Results.spikes;
waves = p.Results.waves;
u = p.Results.u;
mfr = p.Results.mfr;
basepath = p.Results.basepath;
man = p.Results.man;
fs = p.Results.fs;
graphics = p.Results.graphics;
saveFig = p.Results.saveFig;
saveVar = p.Results.saveVar;

% params
if isempty(mfr)
    mfr = ones(1, size(waves, 2)) * 20;
else
    mfr = rescale(mfr, 10, 50);
end

nunits = size(waves, 2);
upsamp = 4;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% trough-to-peak time [ms]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i = 1 : nunits
    w = fft_upsample(waves(:, i), upsamp);
    [~, minpos] = min(w);
    [maxval, ~] = max(w(1 : minpos - 1));   
    [maxvalpost, maxpost] = max(w(minpos : end));               
    if ~isempty(maxpost)
        % trough-to-peak - Stark et al., 2013; Bartho et al., 2004
        tp(i) = maxpost;
        if ~isempty(maxval)
            % asymmetry - Sirota et al., 2008
            asym(i) = (maxvalpost - maxval) / (maxvalpost + maxval);
        end
    else
        warning('waveform may be corrupted')
        tp(i) = NaN;
        asym(i) = NaN;
    end
end
% samples to ms
tp = tp / fs * 1000 / upsamp;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% spike width by inverse of max frequency in spectrum
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fb = cwtfilterbank('SignalLength', size(waves, 1), 'VoicesPerOctave', 32,...
%     'SamplingFrequency', fs, 'FrequencyLimits', [1 fs / 4]);
fb = cwtfilterbank('SignalLength', 2040, 'VoicesPerOctave', 32,...
    'SamplingFrequency', fs, 'FrequencyLimits', [1 fs / 4]);
tic
for i = 1 : nunits
    w = waves(:, i);
    w = [w(1) * ones(1000, 1); w; w(end) * ones(1000, 1)];
    % ALT 1: ES getWavelet
    [wave, f, t] = getWavelet(w, fs, 500, 3000, 128);
    % wt = cwt(w, fs, 'amor', 'FrequencyLimits', [500 3000]);
    wave = wave(:, int16(length(t) / 4) : 3 * int16(length(t) / 4));
    
    % find maximum
    [maxPow, ix] = max(wave);
    [~, mix] = max(maxPow);
    ix = ix(mix);
    spkw(i) = 1000 / f(ix);
    
    % ALT 2: MATLAB cwt
    [cfs, f, ~] = cwt(w, 'FilterBank', fb);
    [~, ifreq] = max(abs(squeeze(cfs)), [], 1);
    maxf = f(ifreq(round(length(w) / 2)));
    spkwnew(i) = 1000 / maxf;    
end
toc

figure
subplot(1, 2, 1)
histogram(spkwnew, 60)
subplot(1, 2, 2)
histogram(spkw, 60)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Generate separatrix according to known values 
xx = [0 0.8];
yy = [2.4 0.4];
m = diff(yy) / diff(xx);
b = yy(1) - m * xx(1);  % y = ax + b
sep = [m b];

if graphics  
    s = scatter(tp, spkw, mfr, 'filled');
    hold on
    xlabel('trough-to-peak [ms]')
    ylabel('spike width [ms]')
    xb = get(gca, 'XLim');
    yb = get(gca, 'YLim');
    plot(xb, [sep(1) * xb(1) + sep(2), sep(1) * xb(2) + sep(2)])
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% select PYRs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Generate separatrix according to known values 
xx = [0 0.8];
yy = [2.4 0.4];
m = diff(yy) / diff(xx);
b = yy(1) - m * xx(1);  % y = ax + b

if ~man     % automatic selection according to separatrix
    pyr = spkw >= m * tp + b;
else        % manual selection of boundary, with separatrix as a guide   
    fprintf('\nDiscriminate pyr and int (select Pyramidal)\n\n');
    [pyr, boundary] = selectCluster([tp; spkw] ,[m b], h);
end

cc.pyr = pyr;
cc.tp = tp;
cc.spkw = spkw;
cc.asym = asym;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if saveVar   
    [~, filename] = fileparts(basepath);
    save([basepath, '\', filename, '.cellClass.mat'], 'CellClass')
end

end

% EOF