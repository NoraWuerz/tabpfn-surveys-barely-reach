# CatBoost-EM: CatBoost with EM-estimated area random effects, tuned.
# Requires: pipeline/00_header.R, the dataset settings.R and
#   pipeline/02_load_data.R sourced beforehand.
# Output contract: one row per unit per sim_id with columns
#   sim_id, unit_id, area, y_true, pred
# Writes: {dataset_dir}/results/catboost_em.parquet
#         {dataset_dir}/results/catboost_em_params.csv
#
# Tuning is done once per dataset on the first sample draw, on y ~ x without
# random effects: inside the EM loop CatBoost is fitted to y - v_i, but the
# random effects are only known after estimation, so tuning on that target
# would be circular. The tuned parameters are used in all EM iterations.

source(file.path("functions", "tune_catboost.R"))

x_cols_cb   <- covariates
cat_cols_cb <- covariates_cat

first_draw <- samples[samples$sim_id == sim_meta$sim_id[1], ]
tp <- tune_catboost(first_draw, x_cols_cb, cat_cols_cb, y_col, catboost_params,
                    n_eval = 100, seed = sim_meta$seed[1])

# iterations is set to the tree count found optimal on the tuning holdout.
em_params_tuned <- modifyList(catboost_params, list(
  thread_count     = 3,
  depth            = tp$depth,
  learning_rate    = tp$learning_rate,
  l2_leaf_reg      = tp$l2_leaf_reg,
  min_data_in_leaf = tp$min_data_in_leaf,
  subsample        = tp$subsample,
  rsm              = tp$rsm,
  iterations       = tp$best_iterations))

get_cv_predictions <- function(df, y, x_cols, cat_cols, params, nfold = 5) {
  n     <- nrow(df)
  folds <- sample(rep(seq_len(nfold), length.out = n))
  preds <- numeric(n)

  for (k in seq_len(nfold)) {
    train_idx <- which(folds != k)
    test_idx  <- which(folds == k)

    train_pool <- df_to_pool(df[train_idx, ], x_cols, cat_cols, label = y[train_idx])
    test_pool  <- df_to_pool(df[test_idx, ],  x_cols, cat_cols)

    model           <- catboost::catboost.train(train_pool, NULL, params)
    preds[test_idx] <- catboost::catboost.predict(model, test_pool)
  }
  preds
}

run_catboost_em <- function(sim_id, seed, max_iter = 10, tol = 1e-5, cv_folds = 5) {
  set.seed(seed)
  train <- samples[samples$sim_id == sim_id, ]
  pop   <- population

  y    <- train[[y_col]]
  area <- factor(train[[group_col]])
  D    <- nlevels(area)

  v_hat    <- setNames(rep(0, D), levels(area))
  gll_prev <- -Inf

  for (b in seq_len(max_iter)) {
    y_star <- y - v_hat[as.character(area)]

    f_oob <- get_cv_predictions(train, y_star, x_cols_cb, cat_cols_cb,
                                 em_params_tuned, cv_folds)

    fit_df <- train |> dplyr::mutate(f_oob = f_oob, area_factor = area)

    lmm <- lme4::lmer(
      y ~ 0 + offset(f_oob) + (1 | area_factor),
      data = fit_df, REML = TRUE,
      control = lme4::lmerControl(optimizer = "bobyqa")
    )

    re        <- lme4::ranef(lmm)$area_factor
    v_hat_new <- setNames(re[, 1], rownames(re))

    gll <- as.numeric(logLik(lmm))
    if (!is.infinite(gll_prev)) {
      rel_change <- abs(gll - gll_prev) / abs(gll_prev)
      if (rel_change < tol) {
        v_hat <- v_hat_new
        break
      }
    }

    v_hat    <- v_hat_new
    gll_prev <- gll
  }

  y_star_final <- y - v_hat[as.character(area)]
  final_pool   <- df_to_pool(train, x_cols_cb, cat_cols_cb, label = y_star_final)
  final_model  <- catboost::catboost.train(final_pool, NULL, em_params_tuned)

  pop_pool <- df_to_pool(pop, x_cols_cb, cat_cols_cb)
  f_pop    <- catboost::catboost.predict(final_model, pop_pool)

  v_pop               <- v_hat[as.character(pop[[group_col]])]
  v_pop[is.na(v_pop)] <- 0
  pred                <- f_pop + v_pop

  tibble(sim_id,
         unit_id   = pop[[unit_id]],
         area      = as.character(pop[[group_col]]),
         y_true    = pop[[y_col]],
         pred      = pred)
}

plan(multisession, workers = 4)
tic()
results <- future_pmap(sim_meta, run_catboost_em, .progress = TRUE) |>
  compact() |>
  list_rbind()
toc()
plan(sequential)

arrow::write_parquet(results, file.path(dataset_dir, "results", "catboost_em.parquet"))
write.csv(data.frame(tp), file.path(dataset_dir, "results", "catboost_em_params.csv"),
          row.names = FALSE)
