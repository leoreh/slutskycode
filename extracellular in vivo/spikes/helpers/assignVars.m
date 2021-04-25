function assignVars(varArray, isession)

if isempty(varArray{isession, 1})
    assignin('base', 'session', [])
else
    assignin('base', 'session', varArray{isession, 1}.session)
end
if isempty(varArray{isession, 2})
    assignin('base', 'cm', [])
else
    assignin('base', 'cm', varArray{isession, 2}.cell_metrics)
end
if isempty(varArray{isession, 3})
    assignin('base', 'spikes', [])
else
    assignin('base', 'spikes', varArray{isession, 3}.spikes)
end
if isempty(varArray{isession, 5})
    assignin('base', 'fr', [])
else
    assignin('base', 'fr', varArray{isession, 5}.fr)
end
if isempty(varArray{isession, 6})
    assignin('base', 'datInfo', [])
else
    assignin('base', 'datInfo', varArray{isession, 6}.datInfo)
end
if isempty(varArray{isession, 8})
    assignin('base', 'sr', [])
else
    assignin('base', 'sr', varArray{isession, 8}.fr)
end
if isempty(varArray{isession, 7})
    assignin('base', 'ss', [])
else
    assignin('base', 'ss', varArray{isession, 7}.ss)
end


end