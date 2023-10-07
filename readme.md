> ***Trajectories through semantic spaces in schizophrenia and the relationship to ripple bursts***
>
> **PNAS**, October 2023
>
> **Matthew M Nour**, Daniel C McNamee, Yunzhe Liu, Raymond J Dolan
matthew.nour@psych.ox.ac.uk

# Main scripts 
To reproduce paper results (within tolerance of stochastic procedures like agglomerative clustering, permutation-based z-scoring, and UMAP)

## `semantic_master_movingAv_repo.m`
- Wrapper script for all NLP analyses excluding computational modelling. 
- Performed on a sliding-window basis and list-specific permutation-based z-scoring, as in paper.
- Analyses performed separately for category/letter task, and semantic/orthographic similarity (task/similarity metric set in the analysis_options structure)
- Semantic distances recomputed in code using fastText embedding
- Orthographic distances loaded in pre-computed
- Travelling salesman analyses is time-intensive, so I provide precomputed .mat files for this (to plot travelling salesman results using the precomputed .mat files, see `plot4paper_travellingSalesman_plotting_module.m` in the plotting folder)

## `semantic_master_modelling_concatTasks.m`
- Wrapper script for computational modelling analysis
- Precomputed models already saved in modelling_output folder
- For model comparison: `concat_model_comparison_repo.m`
- To visualise results using fitted parameters (including correlations with clinical/cognitive/MEG variables): `plot4paper_winning_model.m`


## Note on `data_store_repo.xlsx`
Note that the participant-level clinical, demographic and MEG data is in the `data_store_repo.xlsx`, however the participant numbering here matches that in a previous publication. I provide the .m code to reorder these rows to match the PNAS numbering (called automatically in all plotting scripts that relate variables in `data_store_repo.xlsx` to behavioural language measures). 
