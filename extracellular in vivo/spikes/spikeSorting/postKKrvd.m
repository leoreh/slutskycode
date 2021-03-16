function mu = postKKrvd(varargin)

% moves clusters defined as mu by their rpv to bad cluster
%
% INPUT:
%   basepath    string. path to recording folder {pwd}.
%   grps        numeric. groups (tetrodes) to work on
%   ref         vec. first element describes an rvd in s. 2nd element
%               descrbies the percent of rvds allowd. default is
%               [0.002 1] which means 1 % of ISIs can be < 2 ms.
%               otherwise cluster defined as noise
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
addOptional(p, 'ref', [0.002 1], @isnumeric);

parse(p, varargin{:})
basepath    = p.Results.basepath;
grps        = p.Results.grps;
ref        = p.Results.ref;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% preparations
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% session info
cd(basepath)
[~, basename] = fileparts(basepath);
session = CE_sessionTemplate(pwd, 'viaGUI', false,...
    'force', true, 'saveVar', true);
nchans = session.extracellular.nChannels;
fs = session.extracellular.sr;
spkgrp = session.extracellular.spikeGroups.channels;

% params
ref(1) = ref(1) * fs;
ref(1) = round(ref(1));

if isempty(grps)
    grps = 1 : length(spkgrp);
end
ngrps = length(grps);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% go over groups and clus
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for j = 1 : ngrps
     
    fprintf('\nworking on spkgrp #%d', grps(j))
    
    % ---------------------------------------------------------------------
    % load clu and res data 
    % clu
    cluname = fullfile([basename '.clu.' num2str(grps(j))]);
    fid = fopen(cluname, 'r');
    nclu = fscanf(fid, '%d\n', 1);
    clu = fscanf(fid, '%d\n');
    rc = fclose(fid);
    if rc ~= 0 || isempty(clu)
        warning(['failed to read clu ' num2str(grps(j))])
    end
    nspks(grps(j)) = length(clu);
    uclu = unique(clu);
    
    % res 
    resname = fullfile([basename '.res.' num2str(grps(j))]);
    fid = fopen(resname, 'r');
    res = fscanf(fid, '%d\n');
    rc = fclose(fid);
    if rc ~= 0 || isempty(res)
        warning(['failed to read res ' num2str(grps(j))])
    end
    
    for jj = 1 : nclu
        if uclu(jj) == 0 || uclu(jj) == 1
            continue
        end
        cluidx = find(clu == uclu(jj));
         
        % rvd
        rvd = find(diff([0; res(cluidx)]) < ref); 
        mu{grps(j)}(jj) = length(rvd) / length(cluidx) * 100;
        
        if mu{grps(j)}(jj) > ref(2)
            clu(cluidx) = 1;
        end       
    end
      
    % ---------------------------------------------------------------------
    % save new clu data
    % backup
    bkpath = fullfile(basepath, 'kk', 'bkupFixRvd');
    mkdir(bkpath)
    copyfile(cluname, bkpath)
    
    fid = fopen(cluname, 'w');
    fprintf(fid, '%d\n', length(unique(clu)));
    fprintf(fid, '%d\n', clu);
    rc = fclose(fid);
    if rc ~= 0
        warning(['failed to write clu ' num2str(grps(j))])
    end   
end

return
% EOF

% -------------------------------------------------------------------------
% load and inspect rvds in parallel to mancur

j = 1;      % spkgrp to work on
% load data
[~, basename] = fileparts(basepath);
cluname = fullfile([basename '.clu.' num2str(j)]);
fid = fopen(cluname, 'r');
nclu = fscanf(fid, '%d\n', 1);
clu = fscanf(fid, '%d\n');
rc = fclose(fid);
if rc ~= 0 || isempty(clu)
    warning(['failed to read clu ' num2str(j)])
end
nspks(j) = length(clu);
uclu = unique(clu);
resname = fullfile([basename '.res.' num2str(j)]);
fid = fopen(resname, 'r');
res = fscanf(fid, '%d\n');
rc = fclose(fid);
if rc ~= 0 || isempty(res)
    warning(['failed to read res ' num2str(j)])
end

ref = ceil(0.002 * fs);
for jj = 1 : nclu
        if uclu(jj) == 0 || uclu(jj) == 1
            continue
        end
        cluidx = find(clu == uclu(jj));
    
        % rvd
        rvd = find(diff([0; res(cluidx)]) < ref);
        mu{j}(jj) = length(rvd) / length(cluidx) * 100;
        
        % for ccg
        stimes{jj} = res(cluidx) / fs;
end

% CCG
binSize = 0.001; dur = 0.06; % low res
[ccg, t] = CCG(stimes, [], 'duration', dur, 'binSize', binSize);

for jj = 1 : nclu
        if uclu(jj) == 0 || uclu(jj) == 1
            continue
        end
        cluidx = find(clu == uclu(jj));
    
        % rvd
        muACG(jj) = sum(ccg(30 : 32, jj, jj)) / sum(ccg(:, jj, jj)) * 100;        
end

jj = [14];
plotCCG('ccg', ccg(:, jj, jj), 't', t, 'basepath', basepath,...
    'saveFig', false, 'c', {'k'}, 'u', jj);


