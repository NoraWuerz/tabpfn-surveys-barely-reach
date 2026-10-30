# Random-search hyperparameter tuning for CatBoost.
# Requires: df_to_pool() from pipeline/00_header.R; sourced by the
# models/catboost.R, catboost_id.R and catboost_em.R.
# Writes: nothing (returns the best parameters, best_iterations and the
# holdout RMSE of the tuned and the default configuration).
#
# CatBoost has no out-of-bag error, so the candidates are scored on a random
# 25 % holdout of the sample, which also drives early stopping. The tree count
# that is optimal on the holdout (best_iterations) is returned so that the
# final fit without an eval set does not fall back to the full iteration budget.

tune_catboost <- function(data, x_cols, cat_cols, y_col, base_params,
                          n_eval = 100, seed = 1, holdout = 0.25) {
  set.seed(seed)
  n  <- nrow(data)
  te <- sample(n, max(5L, floor(holdout * n)))
  tr <- setdiff(seq_len(n), te)

  pool_tr <- df_to_pool(data[tr, ], x_cols, cat_cols, label = data[[y_col]][tr])
  pool_te <- df_to_pool(data[te, ], x_cols, cat_cols, label = data[[y_col]][te])

  grid <- data.frame(
    depth            = sample(3:10, n_eval, replace = TRUE),
    learning_rate    = exp(runif(n_eval, log(0.01), log(0.3))),
    l2_leaf_reg      = exp(runif(n_eval, log(1), log(10))),
    min_data_in_leaf = sample.int(20, n_eval, replace = TRUE),
    subsample        = runif(n_eval, 0.5, 1),
    rsm              = runif(n_eval, 0.5, 1)
  )

  score <- vapply(seq_len(n_eval), function(i) {
    p <- modifyList(base_params, list(
      depth            = grid$depth[i],
      learning_rate    = grid$learning_rate[i],
      l2_leaf_reg      = grid$l2_leaf_reg[i],
      min_data_in_leaf = grid$min_data_in_leaf[i],
      subsample        = grid$subsample[i],
      rsm              = grid$rsm[i]))
    m <- tryCatch(catboost::catboost.train(pool_tr, pool_te, p), error = function(e) NULL)
    if (is.null(m)) return(c(Inf, NA_real_))
    pr <- catboost::catboost.predict(m, pool_te)
    c(sqrt(mean((pr - data[[y_col]][te])^2)), m$tree_count)
  }, numeric(2))

  grid$rmse_holdout <- score[1, ]
  grid$best_iter    <- score[2, ]
  best <- grid[which.min(grid$rmse_holdout), ]

  # Reference: the same holdout RMSE under the default parameters
  m_def <- catboost::catboost.train(pool_tr, pool_te, base_params)
  rmse_def <- sqrt(mean((catboost::catboost.predict(m_def, pool_te) - data[[y_col]][te])^2))

  list(depth            = best$depth,
       learning_rate    = best$learning_rate,
       l2_leaf_reg      = best$l2_leaf_reg,
       min_data_in_leaf = best$min_data_in_leaf,
       subsample        = best$subsample,
       rsm              = best$rsm,
       best_iterations  = max(10L, as.integer(best$best_iter)),
       rmse_holdout     = best$rmse_holdout,
       rmse_default     = rmse_def,
       n_holdout        = length(te))
}
