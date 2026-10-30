# CatBoost-ID: CatBoost with the area identifier as categorical feature, tuned
# once per dataset on the first sample draw (functions/tune_catboost.R).
# Requires: pipeline/00_header.R, the dataset settings.R and
#   pipeline/02_load_data.R sourced beforehand.
# Output contract: one row per unit per sim_id with columns
#   sim_id, unit_id, area, y_true, pred
# Writes: {dataset_dir}/results/catboost_id.parquet
#         {dataset_dir}/results/catboost_id_params.csv

source(file.path("functions", "tune_catboost.R"))

x_cols_cb   <- c(covariates, group_col)
cat_cols_cb <- c(covariates_cat, group_col)

first_draw <- samples[samples$sim_id == sim_meta$sim_id[1], ]
tp <- tune_catboost(first_draw, x_cols_cb, cat_cols_cb, y_col, catboost_params,
                    n_eval = 100, seed = sim_meta$seed[1])

cb_params_tuned <- modifyList(catboost_params, list(
  depth            = tp$depth,
  learning_rate    = tp$learning_rate,
  l2_leaf_reg      = tp$l2_leaf_reg,
  min_data_in_leaf = tp$min_data_in_leaf,
  subsample        = tp$subsample,
  rsm              = tp$rsm,
  iterations       = tp$best_iterations))

run_catboost_id <- function(sim_id, seed) {
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
results <- pmap(sim_meta, run_catboost_id, .progress = TRUE) |>
  compact() |>
  list_rbind()
toc()

arrow::write_parquet(results, file.path(dataset_dir, "results", "catboost_id.parquet"))
write.csv(data.frame(tp), file.path(dataset_dir, "results", "catboost_id_params.csv"),
          row.names = FALSE)
