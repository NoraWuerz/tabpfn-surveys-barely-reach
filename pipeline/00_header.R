# Shared package loading, CatBoost base parameters and the df_to_pool() helper.
# Requires: nothing; sourced first by run_model.R and run_postprocess.R.
# Writes: nothing. pacman::p_load installs missing packages before loading.

pacman::p_load(
  arrow,       # read/write parquet files
  dplyr,       # data wrangling
  purrr,       # pmap, compact, list_rbind — parallel simulation runs
  tibble,      # tibble() for output construction
  tictoc,      # tic/toc runtime tracking
  lme4,        # linear mixed models (LMM)
  ranger,      # Random Forest
  reticulate,  # Python interop (TabPFN-EM)
  catboost,
  emdi,        # direct estimator (models/direct.R)
  saeTrafo,    # nested error regression under transformations (models/lmm_logshift.R)
  tidyr,
  tools,       # file_path_sans_ext() (pipeline/03_merge_results.R)
  future,      # plan() for parallel backends
  furrr
)


# Base parameters for the CatBoost scripts (overridden by the tuned values)
catboost_params <- list(
  loss_function         = "RMSE",
  iterations            = 500,
  learning_rate         = 0.05,
  depth                 = 6,
  subsample             = 0.8,
  rsm                   = 0.8,
  min_data_in_leaf      = 5,
  early_stopping_rounds = 20,
  eval_metric           = "RMSE",
  random_seed           = 42,
  verbose               = 0,
  thread_count          = 6
)

# Shared CatBoost helper: build a catboost.Pool from a data frame.
df_to_pool <- function(df, x_cols, cat_cols, label = NULL) {
  df_prep <- df |>
    dplyr::mutate(dplyr::across(dplyr::all_of(cat_cols), ~ factor(., ordered = FALSE))) |>
    dplyr::select(dplyr::all_of(x_cols))

  if (is.null(label)) catboost::catboost.load_pool(data = df_prep)
  else                 catboost::catboost.load_pool(data = df_prep, label = label)
}