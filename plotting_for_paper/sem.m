function [sample_mean, standard_error_mean] = sem(x);
% [sample_mean, standard_error_mean] = sem(x);    
% if x is a matrix we treat as [nSubj, nVar]
    
    if length(size(x)) ~=2
        error('x needs to be a vector ([n, 1] mateix) or a [n, m] matrix')
    end
    
    if any(size(x) == 1)
        sSize = length(x); % vector
    else
        sSize = size(x,1); % matrix
    end
    
    if any(isnan(x), 'all')
        if  any(size(x) == 1)
            warning('input has %i NaN, which have been ignored', sum(isnan(x)))
            sSize = sSize - sum(isnan(x));
        else
            error('X is a matrix, and some NaNs exist')
        end
    end
    
    standard_error_mean = nanstd(x)/sqrt( sSize );
    sample_mean = nanmean(x);
   
    
    %disp(sprintf('Mean = %.3f, ± %.3f',sample_mean, standard_error_mean))
end