function cleanCluByFet(varargin)

% removes rpv spikes on fet / mDist

% alternative option tested was to compare distributions with the
% Kullback�Leibler divergence, e.g.: kl(ifet) = kldiv(bincents', spkpdf' + eps, rpvpdf' + eps, 'sym');
%
% INPUT:
%   basepath    string. path to recording folder {pwd}.
%   grps        numeric. groups (tetrodes) to work on
%   ref         numeric. minimium isi for spike to be defined as rvd [s]{0.002}
%   rpvThr      remove entire cluster if rpv ratio after clean is still
%               greater than rpvTHr
%   spkgrp      array where each cell is the electrodes for a spike group
%   fs          numeric. sample frequency. if empty will try to take from
%               session (cell explorer format)
%
% DEPENDENCIES
%
% TO DO LIST
%
% 15 mar 21 LH

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tic;

p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'grps', [], @isnumeric);
addOptional(p, 'ref', 0.002, @isnumeric);
addOptional(p, 'rpvThr', 2, @isnumeric);
addOptional(p, 'spkgrp', {}, @iscell);
addOptional(p, 'fs', 20000, @isnumeric);
addOptional(p, 'graphics', true, @islogical);
addOptional(p, 'manCur', false, @islogical);

parse(p, varargin{:})
basepath    = p.Results.basepath;
grps        = p.Results.grps;
ref         = p.Results.ref;
rpvThr      = p.Results.rpvThr;
spkgrp      = p.Results.spkgrp;
fs          = p.Results.fs;
graphics    = p.Results.graphics;
manCur    = p.Results.manCur;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% preparations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cd(basepath)
[~, basename] = fileparts(basepath);
if isempty(fs) || isempty(spkgrp)
    session = CE_sessionTemplate(pwd, 'viaGUI', false,...
        'force', true, 'saveVar', true);
    fs = session.extracellular.sr;
    spkgrp = session.extracellular.spikeGroups.channels;
end
bkpath = fullfile(basepath, 'kk', 'bkupFixRvd');
mkdir(bkpath)

npca = 3;
ref = ref * fs;
if isempty(grps)
    grps = 1 : length(spkgrp);
end

% constants
rmvLim = [0.05 0.25];   % ratio of spikes allowed to be removed from one feature and in total
nspksMin = 10000;       % cluster with less spikes will not be cleaned
cdfThr = 0.1;           % threshold for cdf difference from which to clean cluster
rpvRatioThr = 0.35;     % threshold for rpv ratio above which to clean cluster
nbins = 100;            % for histograms
rpvCrt = 0.5;           % rpv ratio cluster much reach in while loop

% shared vars between nested and parent
cluname = []; uclu = []; nclu = []; nfet = []; nspks = []; rmvSpkIdx = [];
rpvRatioAll = []; rmvLimTemp = []; nrmvSpk = []; nrmvSpkTot = [];
% poofed vars to static workspace for debugging
db1 = []; db2 = [];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% manual inspection of features and rpvs
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if manCur
    dbstop in cleanCluByFet at 90 if manCur
    
    igrp = 4;                   % select spiking grp
    [res, fet] = loadResFet;    % load data (once per group)
    rmvflag = zeros(nfet, 2);

    % print to screen rpv ratio of all clusters in group
    [~, clu] = sprintRPV();
    uclu = unique(clu);
    
    % rmv spks from selected cluster
    cluid = 2;      % cluster id
    cluidx = find(clu == cluid);    
    cleanClu(0.0001, [0.03 0.25]);           % inputs: cdfThr, RmLim
    saveClu()
    
    % rmv spks from all clusters until criterion is reached
    clean2criterion(rpvCrt, rmvLim)   
    
    % plot fets of specific cluster
    plotFets('on')
    
    % calc quality of cluster separation
    sprintCluDist(sclu)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% go over groups and clus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for igrp = 1 : length(grps)
    
    grpchans = spkgrp{igrp};
    fprintf('\nworking on spkgrp #%d\n', grps(igrp))
    fprintf('loading data... ')
    
    % ---------------------------------------------------------------------
    % load data from neurosuite files
    [nclu, clu] = loadClu;
    uclu = unique(clu);
    [res, fet] = loadResFet;
    fprintf('data loaded.\n')
    
    % ---------------------------------------------------------------------
    % go over each cluster
    for iclu = 1 : length(uclu)   
        cluid = uclu(iclu);
        if cluid == 0 || cluid == 1
            continue
        end
        cluidx = find(clu == cluid);
        nspks = length(cluidx);
        
        % skip if low number of spikes or rpvs
        if nspks < nspksMin || rpvRatio < rpvRatioThr
            continue
        end
        
        % clean cluster
        cleanClu(cdfThr, rmvLim)
        
        % plot cluster summary if cleaned
        if graphics && any(any(rmvflag))
            fprintf('cleaning clu #%d...\n', cluid)
            plotFets('off')
        end
        
        % remove entire cluster if still too many rpvs
        if ~isempty(rpvThr)
            if rpvRatioNew > rpvThr
                clu(cluidx) = 1;
                fprintf('removing clu #%d...\n', cluid)
            end
        end
    end
    
    % save clu
    saveClu()
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% nested functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% -------------------------------------------------------------------------
% find rpv and calc rpv ratio
    function [rpv, rpvRatio] = getRpv()
        rpv = find(diff([0; res(cluidx)]) < ref);
        nspks = length(cluidx);
        rpvRatio = length(rpv) / nspks * 100;
    end

% -------------------------------------------------------------------------
% load clu data
    function [nclu, clu] = loadClu()
        cluname = fullfile([basename '.clu.' num2str(igrp)]);
        fid = fopen(cluname, 'r');
        nclu = fscanf(fid, '%d\n', 1);
        clu = fscanf(fid, '%d\n');
        rc = fclose(fid);
        if rc ~= 0 || isempty(clu)
            warning(['failed to read clu ' num2str(igrp)])
        end
        uclu = unique(clu);
    end

% -------------------------------------------------------------------------
% save new clu file
    function saveClu
        % bkup       
        source = fullfile(basepath, cluname);
        destination = fullfile(bkpath, [cluname, '.' datestr(datetime, 'ddmmyy_HHMMss')]);
        copyfile(source, destination)     
        % save
        fid = fopen(cluname, 'w');
        fprintf(fid, '%d\n', length(unique(clu)));
        fprintf(fid, '%d\n', clu);
        rc = fclose(fid);
        if rc ~= 0
            warning(['failed to write clu ' num2str(grps(igrp))])
        end
    end

% -------------------------------------------------------------------------
% load res and fet data
    function [res, fet] = loadResFet()
        resname = fullfile([basename '.res.' num2str(igrp)]);
        fid = fopen(resname, 'r');
        res = fscanf(fid, '%d\n');
        rc = fclose(fid);
        if rc ~= 0 || isempty(res)
            warning(['failed to read res ' num2str(igrp)])
        end
        
        nfet = npca * length(spkgrp{igrp});
        fetname = fullfile([basename '.fet.' num2str(igrp)]);
        fid = fopen(fetname, 'r');
        nFeatures = fscanf(fid, '%d', 1);
        fet = fscanf(fid, '%d', [nFeatures, inf])';
        fet = fet(:, 1 : nfet);
        rc = fclose(fid);
        if rc ~= 0 || isempty(fet)
            warning(['failed to read fet ' num2str(igrp)])
        end
    end

% -------------------------------------------------------------------------
% plot histogram of features (all spks and only rpvs)
    function plotFets(visible)
        % if not nested, required arguments are: fetclu, rpv, grp,
        % iclu, rmflag, rpvRatioNew, rmSpkIdx
        
        nfet = size(fetclu, 2);
        [nsub] = numSubplots(nfet);
        nbins = 100;
        normmode = 'probability';
        figure('units','normalized','outerposition',[0 0 1 1], 'visible', visible)
        for ifet = 1 : nfet
            subplot(nsub(1), nsub(2), ifet)
            histogram(fetclu(:, ifet), nbins,...
                'FaceAlpha', 0.4, 'LineStyle', 'none', 'Normalization', normmode)
            hold on
            histogram(fetclu(rpv, ifet), nbins,...
                'FaceAlpha', 0.4, 'LineStyle', 'none', 'Normalization', normmode)
            yLim = ylim;
            if rmvflag(ifet, 1) ~= 0
                plot([rmvflag(ifet, 1) rmvflag(ifet, 1)], yLim, '--k', 'LineWidth', 3)
            end
            if rmvflag(ifet, 2) ~= 0
                plot([rmvflag(ifet, 2) rmvflag(ifet, 2)], yLim, '--k', 'LineWidth', 3)
            end
            title(sprintf('fet #%d', ifet))
            if ifet == 1
                legend({'All spks', 'RPVs'})
            end
        end
        suptitle(sprintf('T#%d clu#%d; RPV from %.2f to %.2f; removed %d%% of spks', igrp, iclu,...
            length(rpv) / length(fetclu) * 100, rpvRatioNew, round(length(unique(rmvSpkIdx)) / length(fetclu) * 100)))
        if strcmp(visible, 'off')
            mkdir(fullfile('graphics', 'clusterClean'))
            figname = fullfile('graphics', 'clusterClean', sprintf('T%d_clu%d', igrp, iclu));
            export_fig(figname)
        end
    end

% -------------------------------------------------------------------------
% print to screen rpv ratio for all clusters in grp
    function [nclu, clu] = sprintRPV()
        % load clu
        [nclu, clu] = loadClu;
        uclu = unique(clu);        
        % rpv
        rpvRatioAll = zeros(length(uclu), 2);
        rpvRatioAll(:, 1) = uclu;
        for iclu = 1 : length(uclu)
            cluid = uclu(iclu);
            if cluid == 0 || cluid == 1
                continue
            end
            cluidx = find(clu == cluid);
            npks = length(cluidx);
            [~, rpvRatioAll(iclu, 2)] = getRpv();
        end
        rpvRatioAll
    end

% -------------------------------------------------------------------------
% go over fets, calc cdf diff and remove spikes from clu
    function [nrmvSpk] = cleanClu(cdfThr, rmvLim)
        fetclu = fet(cluidx, :);
        [rpv, rpvRatio] = getRpv();
        spkRmvLimFet = floor(nspks * rmvLim(1));
        spkRmvLimTot = floor(nspks * rmvLim(2));
        rmvSpkIdx = [];
        rmvflag = zeros(nfet, 2);
        for ifet = 1 : nfet
            
            % find bin where number of spikes reaches percent limit
            [spkcount, binedges] = histcounts(fetclu(:, ifet), nbins, 'Normalization', 'count');
            [rpvcount] = histcounts(fetclu(rpv, ifet), 'BinEdges', binedges, 'Normalization', 'count');
            leftSpk = cumsum(spkcount);
            rightSpk = fliplr(cumsum(spkcount, 'reverse'));
            leftRpv = cumsum(rpvcount);
            rightRpv = fliplr(cumsum(rpvcount, 'reverse'));
            [~, limLeft] = min(abs(spkRmvLimFet - leftSpk));
            [~, limRight] = min(abs(spkRmvLimFet - rightSpk));
            
            % calculate difference between cdf of spks and rpvs
            % left side
            spkcdf = leftSpk(1 : limLeft - 1) / nspks;
            rpvcdf = leftRpv(1 : limLeft - 1) / length(rpv);
            [cdfDiff, rmBinIdx] = max(rpvcdf - spkcdf);
            if cdfDiff > cdfThr        % remove only if
                rmvflag(ifet, 1) = binedges(rmBinIdx);
                rmvSpkIdx = [rmvSpkIdx; find(fetclu(:, ifet) < binedges(rmBinIdx))];
            end
            
            % right side
            spkcdf = rightSpk(1 : limRight) / nspks;
            rpvcdf = rightRpv(1 : limRight) / length(rpv);
            [cdfDiff, rmBinIdx] = max(rpvcdf - spkcdf);
            if cdfDiff > cdfThr
                rmvflag(ifet, 2) = binedges(end - rmBinIdx);
                rmvSpkIdx = [rmvSpkIdx; find(fetclu(:, ifet) > rmvflag(ifet, 2))];
            end
            rmvSpkIdx = unique(rmvSpkIdx);
            nrmvSpk = length(rmvSpkIdx);
            
            % check if total number of spikes removed is greater than upper
            % limit
            if nrmvSpk > spkRmvLimTot
                break
            end
        end
        
        % remove spks
        clu(cluidx(rmvSpkIdx)) = 0;     % from clu
        cluidx(rmvSpkIdx) = [];         % from cluidx
        nspks = length(cluidx);
        [~, rpvRatioNew] = getRpv();
        
        % print to screen
        fprintf('removed %d (%d%%) spikes from clu #%d\n',...
            nrmvSpk, round(nrmvSpk / nspks  * 100), cluid)
        fprintf('rpv ratio: %.2f -> %.2f\n', length(rpv) / nspks * 100, rpvRatioNew)
    end

% -------------------------------------------------------------------------
% clean all clusters to rpv criteria
    function clean2criterion(rpvCrt, rmvLim)       
        for iclu = 1 : length(uclu)
            cluid = uclu(iclu);
            if cluid == 0 || cluid == 1
                continue
            end
            cluidx = find(clu == cluid);
            nspks = length(cluidx);            
            [~, rpvRatio] = getRpv();
            
            rmvLimTemp = [0.005 rmvLim(2)];    
            nrmvSpkTot = 0;
            nrmvSpk = 0;
            while 1
                while 1
                    nrmvSpk = cleanClu(0.0001, rmvLimTemp);
                    nrmvSpkTot = nrmvSpkTot + nrmvSpk;
                    if (nrmvSpkTot / nspks) > rmvLim(2) ||...
                            round(nrmvSpk / nspks)  * 100 < 1
                        break
                    end
                end
                [~, rpvRatio] = getRpv();
                if rpvRatio < rpvCrt
                    break
                end
                rmvLimTemp(1) = rmvLimTemp(1) + 0.005;
            end
        end        
    end

    function sprintCluDist(sclu)
        lRat = zeros(length(uclu), 1);
        iDist = zeros(length(uclu), 1);
        if isempty(sclu)
            sclu = uclu;
        end
        for iclu = 1 : length(sclu)
            cluid = sclu(iclu);
            if cluid == 0 || cluid == 1
                continue
            end
            fetMdist = [fet, clu];
            fetMdist(clu <= 1, :) = [];
            cluidx2 = find(fetMdist(:, end) == cluid);
            [lRat(iclu, 1), iDist(iclu, 1), ~] = cluDist(fetMdist(:, 1 : nfet), cluidx2);
        end
        [sclu, iDist, lRat]
    end
end
% EOF

% -------------------------------------------------------------------------
% additional subroutines

% alternative for cleaning cluster; compute pca only on cluster spikes and
% attemp at gmm to separate rvds
% recalculate pca
% clear fetnew
% for ichan = 1 : length(grpchans)
%     [~, pcFeat] = pca(permute(spk(ichan, :, cluidx), [3, 2, 1]), 'NumComponents', 3);
%     fetnew(:, ichan * 3 - 2 : ichan * 3) = pcFeat;
% end
%
% rpvgrp = ones(nspks, 1);
% rpvgrp(rpv) = 2;
% figure
% [nsub] = numSubplots(nfet / 2);
% kount = 1;
% for ifet = 1 : 2 : nfet
%     subplot(nsub(1), nsub(2), kount)
%     gscatter(fetnew(:, ifet), fetnew(:, ifet + 1), rpvgrp)
%     xlabel(sprintf('fet #%d', ifet))
%     ylabel(sprintf('fet #%d', ifet + 1))
%     kount = kount + 1;
% end
%
% % spk
%     sniplength = ceil(1.6 * 10^-3 * fs);
%     spkname = fullfile([basename '.spk.' num2str(grp)]);
%     fid = fopen(spkname, 'r');
%     spk = fread(fid, 'int16');
%     spk = reshape(spk, length(grpchans), sniplength, nspks(igrp));
%     rc = fclose(fid);
%     if rc ~= 0 || isempty(spk)
%        warning(['failed to read spk ' num2str(igrp)])
%     end
% fprintf('data successfully loaded\n')
%
%
% % plot ccg of specific units
% % CCG
% binSize = 0.0001; dur = 0.6; % low res
% iclus = [83, 116];
% for icluster = 1 : length(iclus)
%     cluidx = clu(clu == iclus(icluster));
%     spkclutimes{icluster} = res(cluidx)
% [ccg, t] = CCG({xx.times{:}}, [], 'duration', dur, 'binSize', binSize);
% u = 20;
% plotCCG('ccg', ccg(:, u, u), 't', t, 'basepath', basepath,...
%     'saveFig', false, 'c', {'k'}, 'u', spikes.UID(u));