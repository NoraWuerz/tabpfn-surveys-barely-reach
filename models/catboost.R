# CatBoost without area information, tuned once per dataset on the first
# sample draw (100 random configurations, functions/tune_catboost.R).
# Requires: pipeline/00_header.R, the dataset settings.R and
#   pipeline/02_load_data.R sourced beforehand.
# Output contract: one row per unit per sim_id with columns
#   sim_id, unit_id, area, y_true, pred
# Writes: {dataset_dir}/results/catboost.parquet
#         {dataset_dir}/results/catboost_params.csv
#
# CatBoost is tuned once per dataset rather than per draw (as for the RF)
# because one CatBoost fit is orders of magnitude slower than a ranger fit.

source(file.path("functions", "tune_catboost.R"))

x_cols_cb   <- covariates
cat_cols_cb <- covariates_cat

first_draw <- samples[samples$sim_id == sim_meta$sim_id[1], ]
tp <- tune_catboost(first_draw, x_cols_cb, cat_cols_cb, y_col, catboost_params,
                    n_eval = 100, seed = sim_meta$seed[1])

# iterations is set to the tree count found optimal on the tuning holdout,
# since the final fit runs without an eval set.
cb_params_tuned <- modifyList(catboost_params, list(
  depth            = tp$depth,
  learning_rate    = tp$learning_rate,
  l2_leaf_reg      = tp$l2_leaf_reg,
  min_data_in_leaf = tp$min_data_in_leaf,
  subsample        = tp$subsample,
  rsm              = tp$rsm,
  iterations       = tp$best_iterations))

run_catboost <- function(sim_id, seed) {
  set.seed(seed)
  train <- samples[samples$sim_id == sim_id, ]
  pop   <- population

  dtrain <- df_to_pool(train, x_cols_cb, cat_cols_cb, label = train[[y_col]])
  dpop   <- df_to_pool(pop,   x_cols_cb, cat_cols_cb)

  model <- catboost::catboost.train(dtrain, test_pool = NULL, params = cb_params_tuned)
  pred  <- catboost::catboost.predict(model, dpop)

  tibble(sim_id,
         unit_id   = pop[[unit_id]],
         area      = as.character(pop[[group_col]]),
         y_true    = pop[[y_col]],
         pred      = pred)
}

tic()
results <- pmap(sim_meta, run_catboost, .progress = TRUE) |>
  compact() |>
  list_rbind()
toc()

arrow::write_parquet(results, file.path(dataset_dir, "results", "catboost.parquet"))
write.csv(data.frame(tp), file.path(dataset_dir, "results", "catboost_params.csv"),
          row.names = FALSE)
