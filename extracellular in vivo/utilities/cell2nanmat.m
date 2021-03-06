function mat = cell2nanmat(c, dim)

% converts a cell array of n vectors with maximum length m to a matrix n x
% m. vectors shorter than m are nan padded. similarily can concatenate an
% array of 2d matrices along the dim dimension by nan padding the other
% dimension. c must be a 1d cell array. 
%
% INPUT:
%   c           cell of numeric vectors
%
% OUTPUT
%   mat         
%
% 09 may 20 LH  updates:
% 13 jun 21         adapted for arrays with n dimensions

c = c(:);
nDimensions = unique(cellfun(@isvector, c));
if numel(nDimensions) > 1
    error('all arrays must have the same number of dimensions')
end

if nargin < 2 || isempty(dim)
    dim = 1;
end
maxlength = max(cellfun('size', c, dim));

if nDimensions == 1
    mat = cellfun(@(x) [x(:); nan(maxlength - length(x), 1)], c,...
        'UniformOutput', false);
else
    for icell = 1 : length(c)
        if dim == 1
            mat{icell} = [c{icell}; nan(maxlength - size(c{icell}, 1), size(c{icell}, 2))];
        elseif dim == 2
            mat{icell} = [c{icell}, nan(maxlength - size(c{icell}, 2), size(c{icell}, 1))];
        end
    end
end
mat = cell2mat(mat');

% EOF


