function [varArray, dirnames] = getSessionVars(varargin)

% loads specific matlab variables from specified directories and organizes
% them in a cell array. the directories can be specified directly as input
% or recieved from an xls file with certain conditions. assumes all
% variables in each dir are named "dirname.varname.mat".

% INPUT:
%   basepath    string. path to mouse folder with all sessions {pwd}.
%   xlsname     string. name of xls file with list of sessions. must
%               include extension {'sessionList.xlsx'}
%   dirColumn 	string. column name in xls sheet where dirnames exist
%   vars        string array of matlab variables to load.
%   pcond       string. column name of logical values for each
%               session. only if true than session will be loaded. can be a
%               string array and than all conditions must be met.
%   ncond       string. same as pcond but imposes a negative condition.
%   sortDir     logical. sort varArray according to dirnames {true}
%
% DEPENDENCIES
%   none
%
% TO DO LIST:
%   add option to input dirnames
%
% 21 oct 20 LH      updates:

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

p = inputParser;
addOptional(p, 'basepath', pwd);
addOptional(p, 'xlsname', 'sessionList.xlsx', @ischar);
addOptional(p, 'dirColumn', "Session", @isstring);
addOptional(p, 'vars', "session", @isstring);
addOptional(p, 'pcond', "tempFlag", @isstring);
addOptional(p, 'ncond', "", @isstring);
addOptional(p, 'sortDir', true, @islogical);
addOptional(p, 'dirnames', []);

parse(p, varargin{:})
basepath        = p.Results.basepath;
xlsname         = p.Results.xlsname;
dirColumn       = p.Results.dirColumn;
vars            = p.Results.vars;
pcond           = p.Results.pcond;
ncond           = p.Results.ncond;
sortDir         = p.Results.sortDir;
dirnames         = p.Results.dirnames;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get directory paths
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if exist('dirnames', 'var') && isstring(dirnames)
    % ALT 1: user input dirnames
    dirnames = dirnames;
    
    % ALT 2: get dirnames from xlsx file
elseif ischar(xlsname) && contains(xlsname, 'xlsx')
    sessionInfo = readtable(fullfile(basepath, xlsname));
    icol = strcmp(sessionInfo.Properties.VariableNames, dirColumn);
    dirnames = string(table2cell(sessionInfo(:, icol)));
    
    % check dirnames meet conditions
    clear irow icol
    irow = ones(length(dirnames), 1);
    for i = 1 : length(pcond)
        icol = strcmp(sessionInfo.Properties.VariableNames, char(pcond(i)));
        if any(icol)
            irow = irow & sessionInfo{:, icol} == 1;
        end
    end
    for i = 1 : length(ncond)
        icol = strcmp(sessionInfo.Properties.VariableNames, char(ncond(i)));
        if any(icol)
            irow = irow & sessionInfo{:, icol} ~= 1;
        end
    end
    dirnames = dirnames(irow);
    dirnames(strlength(dirnames) < 1) = [];
end

if sortDir
    dirnames = string(natsort(cellstr(dirnames)));
end
ndirs = length(dirnames);

% load files
varArray = cell(length(dirnames), length(vars));
for i = 1 : ndirs
    filepath = char(fullfile(basepath, dirnames(i)));
    if ~exist(filepath, 'dir')
        warning('%s does not exist, skipping...', filepath)
        continue
    end
    cd(filepath)
    
    for ii = 1 : length(vars)
        filename = dir(['*', vars{ii}, '*']);
        if length(filename) == 1
            varArray{i, ii} = load(filename.name);
        else
            warning('no %s file in %s, skipping', vars{ii}, filepath)
        end
    end
end


end