
%   intens      vec describing stimulus intensity [uA]. must be equal in
%               length to number of recording files in experiment. 
%   dt          numeric. dead time for calculating amplitude. 
%               important for exclusion of stim artifact. {40}[samples]

intens = [100 200 400 800];
dt = 40;
inspect = false;
force = true;

basepath = 'F:\Data\fEPSP\B3\lh59';
cd(basepath)

% load fepsp if already exists
% [~, basename, ~] = fileparts(basepath);
% fepspname = [basename '.fepsp.mat'];
% if exist(fepspname, 'file') && ~force
%     fprintf('\n loading %s \n', fepspname)
%     load(fepspname)
%     return
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% handle files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% find all .wcp files
files = dir('*.wcp');
filenames = natsort({files.name});
% select spicific files
sfiles = [1 2 3 5];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for i = 1 : length(sfiles)
    
    % load data
    filename = files(sfiles(i)).name;
    lfp = getLFP('basepath', basepath, 'basename', filename,...
        'extension', 'wcp', 'forceL', true, 'fs', 1250, 'saveVar', false,...
        'ch', 1);
    
    % manually inspect and remove unwanted traces
    if inspect
        [sig, rm] = rmTraces(lfp.data, lfp.timestamps);
    end
    
    % arrange data
    wv{i} = sig;
    wvavg(i, :) = mean(sig, 2);
    amp(i) = range(wvavg(i, dt : end));
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arrange struct and save
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[intens, ia] = sort(intens);

% arrange struct
fepsp.wv = wv(:, ia);
fepsp.wvavg = wvavg(:, ia, :);
fepsp.amp = amp(:, ia);
fepsp.intens = intens;
fepsp.rm = rm;
% fepsp.t = win(1) : win(2);
% fepsp.dt = dt;

if saveVar
    save(fepspname, 'fepsp');
end