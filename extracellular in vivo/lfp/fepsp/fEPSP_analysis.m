function fepsp = fEPSP_analysis(varargin)

% gets a fepsp struct and analyzes the traces according to protocol
% (currently io or stp, in the future maybe more). assumes fEPSPfromDat or
% WCP has been called beforehand. 
%
% INPUT
%   fepsp       struct. see fEPSPfromDat or fEPSPfromWCP
%   basepath    string. path to .dat file (not including dat file itself)
%   dt          numeric. deadtime for exluding stim artifact
%   force       logical. force reload {false}.
%   saveVar     logical. save variable {1}.
%   saveFig     logical. save graphics {1}.
%   graphics    numeric. if 0 will not plot grpahics. if greater than
%               nspkgrp will plot all grps, else will plot only
%               selected grp {1}.
%   vis         char. figure visible {'on'} or not ('off')
%
% CALLS
%   none
%
% OUTPUT
%   fepsp       struct with fields described below
%
% TO DO LIST
%   # Lior Da Marcas take over
%
% 16 oct 20 LH   UPDATES

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addOptional(p, 'fepsp', []);
addOptional(p, 'basepath', pwd);
addOptional(p, 'dt', 2, @isnumeric);
addOptional(p, 'force', false, @islogical);
addOptional(p, 'saveVar', true, @islogical);
addOptional(p, 'saveFig', true, @islogical);
addOptional(p, 'graphics', 1000);
addOptional(p, 'vis', 'on', @ischar);

parse(p, varargin{:})
fepsp = p.Results.fepsp;
basepath = p.Results.basepath;
dt = p.Results.dt;
force = p.Results.force;
saveVar = p.Results.saveVar;
saveFig = p.Results.saveFig;
graphics = p.Results.graphics;
vis = p.Results.vis;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get params from fepsp struct
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[~, basename] = fileparts(basepath);
fepspname = [basename '.fepsp.mat'];
    
% try to load file if not in input
if isempty(fepsp)
    if exist(fepspname, 'file')
        load(fepspname)
    end
end
if isfield('fepsp', 'amp') && ~force
    load(fepspname)
    return
end

fs = fepsp.info.fs;
tstamps = fepsp.tstamps;
spkgrp = fepsp.info.spkgrp;
nspkgrp = length(spkgrp);
nfiles = length(fepsp.intens);
protocol = fepsp.info.protocol;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% prepare for analysis
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dt = round(dt / 1000 * fs);
switch protocol
    case 'io'
        % single pulse of 500 us after 30 ms. recording length 150 ms.
        % repeated once every 15 s. negative peak of response typically
        % 10 ms after stim.
        nstim = 1;
        [~, wvwin(1)] = min(abs(tstamps - 0));
        [~, wvwin(2)] = min(abs(tstamps - 30));
        wvwin(1) = wvwin(1) + dt;
    case 'stp'
        % 5 pulses of 500 us at 50 Hz. starts after 10 ms. recording length
        % 200 ms. repeated once every 30 s
        nstim = 5;
        switch fepsp.info.recSystem
            case 'oe'
                % correct stim frequency
                ts = fepsp.info.stimTs;
                ts = mean(ts(ts < 500)) / fs * 1000;
            case 'wcp'
                ts = 20;
        end     
        wvwin = round([10 : ts : 5 * ts; 30 : ts : 5 * ts + 10]' * fs / 1000);
        wvwin(:, 1) = wvwin(:, 1) + dt;
        wvwin(:, 2) = wvwin(:, 2) - dt;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% analyze
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% traceAvg      3d mat (tetrode x intensity x sample) of entire trace
fepsp.traceAvg  = nan(nspkgrp, nfiles, length(fepsp.tstamps));
% waves         2d cell (tetrode x intensity) where each cell contains the
%               waves (zoom in view of traces) 
fepsp.waves     = cell(nspkgrp, nfiles);
% wavesAvg      3d mat (tetrode x intensity x sample) of waves (zoom in
%               view of trace), averages across traces. for io only             
fepsp.wavesAvg  = nan(nspkgrp, nfiles, length(wvwin(1) : wvwin(2)));
% ampcell       2d array (tetrode x intensity) where each cell contains the
%               amplitude/s for each trace
fepsp.ampcell   = cell(nspkgrp, nfiles);
% amp           2d (io) or 3d (stp) mat (tetrode x intensity x stim) of
%               amplitude averaged across traces
fepsp.amp   = nan(nspkgrp, nfiles, nstim);
% ampNorm       2d array of normalized amplitudes. for each trace the
%               responses are normalized to first response. these
%               normalized amplitudes. for
%               stp only
fepsp.ampNorm   = nan(nspkgrp, nfiles, nstim);
% facilitation  2d mat of average maximum normalized response. for stp only
fepsp.facilitation = nan(nspkgrp, nfiles);

fepsp = rmfield(fepsp, 'ampNorm');

for j = 1 : nspkgrp
    for i = 1 : nfiles
        fepsp.traceAvg(j, i, :) = mean(fepsp.traces{j, i}, 2);
        switch protocol
            case 'io'
                fepsp.waves{j, i} = fepsp.traces{j, i}(wvwin(1) : wvwin(2), :);
                fepsp.wavesAvg(j, i, :) = mean(fepsp.waves{j, i}, 2);
                fepsp.ampcell{j, i} = range(fepsp.waves{j, i});
                fepsp.amp(j, i) = mean(fepsp.ampcell{j, i});
                                              
            case 'stp'
                % note; after reviewing the data it seems that specifically
                % for stp maximum absolute value may be better than range
                for ii = 1 : nstim
                    fepsp.ampcell{j, i}(ii, :) =...
                        range(fepsp.traces{j, i}(wvwin(ii, 1) :  wvwin(ii, 2), :));
                end
                fepsp.ampNorm{j, i} = fepsp.ampcell{j, i} ./ fepsp.ampcell{j, i}(1, :);
                fepsp.facilitation(j, i) = mean(max(fepsp.ampNorm{j, i}));
        end
    end
end

% save updated struct
if saveVar
    save(fepspname, 'fepsp');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if graphics
    if graphics > nspkgrp 
        grp = 1 : nspkgrp;
    else
        grp = graphics;
    end
    for i = grp
        switch protocol
            case 'io'
                fh = figure('Visible', vis);
                suptitle(sprintf('T#%d', i))
                subplot(1, 2, 1)
                plot(fepsp.tstamps(wvwin(1) : wvwin(2)), squeeze(fepsp.wavesAvg(i, :, :))')
                axis tight
                yLimit = [min([fepsp.wavesAvg(:)]) max([fepsp.wavesAvg(:)])];
                ylim(yLimit)
                xlabel('Time [ms]')
                ylabel('Voltage [mV]')
                legend(split(num2str(sort(fepsp.intens))))
                box off
                
                subplot(1, 2, 2)
                ampmat = cell2nanmat(fepsp.ampcell(i, :));
                boxplot(ampmat, 'PlotStyle', 'traditional')
                ylim([min(horzcat(fepsp.ampcell{:})) max(horzcat(fepsp.ampcell{:}))])
                xticklabels(split(num2str(sort(fepsp.intens))))
                xlabel('Intensity [uA]')
                ylabel('Amplidute [mV]')
                box off
                
            case 'stp'
                fh = figure('Visible', vis);
                suptitle(sprintf('%s - T#%d', basename, i))
                subplot(2, 1, 1)
                plot(fepsp.tstamps, squeeze(fepsp.traceAvg(i, :, :))')
                axis tight
                yLimit = [min(min(horzcat(fepsp.traces{i, :})))...
                    max(max(horzcat(fepsp.traces{i, :})))];
                ylim(yLimit)
                hold on
                plot(repmat([0 : ts : ts * 4]', 1, 2), yLimit, '--k')
                xlabel('Time [ms]')
                ylabel('Voltage [mV]')
                legend(split(num2str(sort(fepsp.intens))))
                box off
                
                subplot(2, 1, 2)
                for ii = 1 : length(fepsp.intens)
                    x(ii, :) = mean(fepsp.ampNorm{i, ii}, 2);
                end
                plot([1 : nstim], x)
                xticks([1 : nstim])
                xlabel('Stim No.')
                ylabel('Norm. Amplitude')
                yLimit = ylim;
                ylim([0 yLimit(2)])
        end
        if saveFig
            figpath = fullfile(basepath, 'graphics');
            mkdir(figpath)
            figname = [figpath '\fepsp_t' num2str(i)];
            export_fig(figname, '-tif', '-r300', '-transparent')
        end
    end
end

end

% EOF