function amp = stability(varargin)

% loads data through GUI
% allows user to remove unwanted traces
% plots amplitude as a function of time
% repeats for specified number of sessions
% 
% INPUT
%   nsessions   number of stability sessions to concatenate
%   inspect     logical. inspect traces {1} or not (0).
%   basepath    recording session path {pwd} to save figure and variables
%   graphics    logical. plot graphics {1} or not.
%   saveFig     logical. saveFig to current path {1} or not (0).
% 
% OUTPUT
%   amp         vector of amplitude (min - baseline) for each trace  
% 
% 09 mar 19 LH

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
p = inputParser;
addOptional(p, 'nsessions', 1);
addOptional(p, 'inspect', true, @islogical);
addOptional(p, 'basepath', pwd);
addOptional(p, 'graphics', true, @islogical);
addOptional(p, 'saveFig', false, @islogical);

parse(p,varargin{:})
nsessions = p.Results.nsessions;
inspect = p.Results.inspect;
basepath = p.Results.basepath;
graphics = p.Results.graphics;
saveFig = p.Results.saveFig;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get and analyse data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i = 1 : nsessions
    data = import_wcp();
    
    % find artifact onset from derirative
    [~, art] = max(diff(data.S(:, 1)));
    
    % remove DC
    data.S = rmDC(data.S, [1, art - 0.003 * data.fs]);
    
    % manually inspect and remove unwanted traces
    if inspect
        [data.S, data.rm_idx] = rmTraces(data.S);
    end
    
    % find amplitude
    a{i} = abs(min(data.S(art + 0.003 * data.fs : end, :)));
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% graphics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if graphics    
    amp = [a{:}];

    dt = 15;                                    % inter-trace interval [s]
    x = [1 : dt : length(amp) * dt] / 60;       % time axis in minutes

    f = figure;
    plot(x, amp, '*')
    axis tight
    box off
    xlabel('Time [m]')
    ylabel('Amplitude [mV]')
    title('Stability')
    set(gca,'TickLength',[0, 0])
    
    for i = 1 : length(a) - 1
        breakxaxis([x(length(a{i})), x(length(a{i})) + 1])
    end
    
    if saveFig
        filename = 'Stability';
        savePdf(filename, basepath, f)
    end   
end