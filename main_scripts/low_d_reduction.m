% Projecting to 3D or 2D for low-D representation 
% Can either use PCA or UMAP reductions
if analysis_options.visualise_with_umap
    disp('visualising with UMAP')
    reduction{ndim} = run_umap(eAll_mean, 'metric', 'cosine', 'n_components', ndim, 'verbose', 'none', 'min_dist', .2, 'n_neighbors', 25, 'randomize', false);
    axis_nam = ''; % UMAP dimensions lack linear interpretability
else
    disp('visualising with PCA')
    if ~analysis_options.usePCA
        [~, reduction{ndim}, ~, ~, ~] = pca(eAll_mean, 'Algorithm', 'svd',  'NumComponents', ndim, 'randomize', false);
    end
    axis_nam = 'Principal axis';
end

