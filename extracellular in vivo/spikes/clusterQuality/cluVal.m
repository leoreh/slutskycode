function spikes = cluVal(varargin)

% wrapper for inspecting and validating clusters
% computes:
%   (1) cluster isolation ditance via:
%       (a) L ratio (Schmitzer-Torbert and Redish, 2004)
%       (b) Isolation distance (Harris et al., 2001)
%   (2) ISI contamination
%
% INPUT:
%   basepath        path to recording
%   spikes          struct (see getSpikes)
%   npca            #PCA features for mahal dist {12}.
%                   If sorted with neurosuite should be #spk group * 3
%   spkgrp          array where each cell is the electrodes for a spike group. 
%   mu              vector of predetermined multi units. spikes from these
%                   units will be discarded from distance calculations.
%                   numbering should correspond to spikes.UID
%   force           logical. force recalculation of distance.
%   graphics        logical. plot graphics {true} or not (false)
%   vis             string. show figure {'on'} or not {'off'}
%   saveFig         logical. save figure {1} or not (0)
%   saveVar         logical. save variables (update spikes and save su)
%
% OUTPUT:           additional fields to struct (all 1 x nunits):
%   su              SU (1) or MU (0)
%   L
%   iDist
%   ISIratio
%
% DEPENDENCIES:
%   getSpikes       optional (if not given as input)
%   getFet          PCA feature array
%   cluDist         L ratio and iDist
%   plotCluster     plot waveform and ISI histogram
%   ISI             calc isi contamination
%
% TO DO LIST:
%   # adapt plotCluster to cell explorer
%
% 03 dec 18 LH      UPDATS: 
% 15 nov 19 LH      separated ISI to standalone function
%                   added predetermined mu
%                   adjusted i\o params
% 25 jun 20 LH      spkgrp and adaptation to cell explorer format

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addOptional(p, 'spikes', []);
addOptional(p, 'basepath', pwd, @ischar);
addOptional(p, 'npca', 3, @isscalar);
addOptional(p, 'spkgrp', {}, @iscell);
addOptional(p, 'mu', [], @isnumeric);
addOptional(p, 'force', false, @islogical);
addOptional(p, 'graphics', true, @islogical);
addOptional(p, 'vis', 'on', @ischar);
addOptional(p, 'saveFig', true, @islogical);
addOptional(p, 'saveVar', true, @islogical);

parse(p, varargin{:})
spikes = p.Results.spikes;
basepath = p.Results.basepath;
npca = p.Results.npca;
spkgrp = p.Results.spkgrp;
mu = p.Results.mu;
force = p.Results.force;
graphics = p.Results.graphics;
vis = p.Results.vis;
saveFig = p.Results.saveFig;
saveVar = p.Results.saveVar;

% load spikes if empty
if isempty(spikes)
    [~, filename] = fileparts(basepath);
    spkname = [filename '.spikes.cellinfo.mat'];
    if exist(spkname, 'file')
        load(spkname)
    else
        error('%s not found', spkname)
    end
end
% make sure spikes has required fields
if ~all(isfield(spikes, {'shankID', 'cluID', 'times'}))
    error('spikes missing required fields')
end

% params
ngrp = length(unique(spikes.shankID));  % only tetrodes with units
nunits = length(spikes.times);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ISI contamination
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SU = 1% of ISIs < 0.002
ref = 0.002;
thr = 1;
spikes.isi = zeros(nunits, 1);
for i = 1 : nunits
    nspks(i, 1) = length(spikes.times{i});
    spikes.isi(i, 1) = sum(diff(spikes.times{i}) < ref) / nspks(i, 1) * 100;
end

% arrange pre-determined multiunits
mu = mu(:);
mu = sort(unique([mu, find(spikes.isi > 1)]));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% calculate cluster separation
%%%%%%%%%%%%%%%%%%%%%%%%%%%%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fet = getFet(basepath, true, false);

if all(isfield(spikes, {'mDist', 'iDist', 'lRat'})) && ~force
    warning('separation matrices already calculated. Skipping cluDist');
else
    sprintf('\ncalculating separation matrices\n\n');
    
    % arrange predetermined mu
    rmmu = cell(1, length(fet));
    if ~isempty(mu)
        u = spikes.cluID(mu);
        for i = 1 : length(fet)
            rmmu{i} = u(spikes.shankID(mu) == i);
        end
    end
    
    % go over each spike group, clean and calc separation
    for i = 1 : length(fet)
        
        % disgard noise and artifact spikes
        if ~isempty(fet{i})
            idx = find(fet{i}(:, end) <= 1);
            fet{i}(idx, :) = [];
        end
              
        % disgard spikes that belong to predetermined mu
        for j = 1 : length(rmmu{i})
            idx = find(fet{i}(:, end) == rmmu{i}(j));
            fet{i}(idx, :) = [];
        end
        
        % calculate separation matrices
        clu = spikes.cluID(spikes.shankID == i);
        lRat{i} = zeros(length(clu), 1);
        iDist{i} = zeros(length(clu) ,1);
        ncol = npca * length(spkgrp{i});
        for j = 1 : length(clu)
            cluidx = find(fet{i}(:, end) == clu(j));
            [lRat{i}(j, 1), iDist{i}(j, 1), mDist{i}{j}] = cluDist(fet{i}(:, 1 : ncol), cluidx);
        end
    end
    
    % concatenate cell
    spikes.lRat = cat(1, lRat{:});
    spikes.iDist = cat(1, iDist{:});
    spikes.mDist = mDist;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% estimate SU or MU
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
spikes.su = spikes.iDist > 15 & spikes.isi < 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% save spikes
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if saveVar
    [~, filename] = fileparts(basepath);
    save([filename '.spikes.cellinfo.mat'], 'spikes')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if graphics
    plotCluster('basepath', basepath, 'spikes', spikes,...
        'vis', vis, 'saveFig', saveFig)
end

end

% EOF