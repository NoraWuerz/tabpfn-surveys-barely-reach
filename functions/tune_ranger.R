# Random-search hyperparameter tuning for ranger random forests.
# Requires: nothing; sourced by models/rf.R, models/rf_id.R
# and models/merf.R.
# Writes: nothing (returns the best parameters and the OOB MSE of the tuned
# and the default configuration).
#
# Search space: mtry in 1..p, min.node.size in 1..max(5, n/10),
# sample.fraction in [0.2, 1]; replace and num.trees stay fixed. Candidates
# are scored by the OOB MSE, so only sample information is used.

tune_ranger <- function(formula, data, n_eval = 100, seed = 1, num.trees = 500) {
  p <- length(all.vars(formula)) - 1L          # number of covariates
  n <- nrow(data)

  set.seed(seed)
  grid <- data.frame(
    mtry            = sample.int(p, n_eval, replace = TRUE),
    min.node.size   = sample.int(max(5L, floor(n / 10)), n_eval, replace = TRUE),
    sample.fraction = runif(n_eval, 0.2, 1)
  )

  grid$oob_mse <- vapply(seq_len(n_eval), function(i) {
    fit <- ranger::ranger(
      formula         = formula,
      data            = data,
      num.trees       = num.trees,
      mtry            = grid$mtry[i],
      min.node.size   = grid$min.node.size[i],
      sample.fraction = grid$sample.fraction[i],
      respect.unordered.factors = "order",
      seed            = seed
    )
    fit$prediction.error
  }, numeric(1))

  best <- grid[which.min(grid$oob_mse), ]

  # Reference: the OOB error under the ranger defaults
  fit_def <- ranger::ranger(formula = formula, data = data,
                            num.trees = num.trees, seed = seed,
                            respect.unordered.factors = "order")

  list(mtry            = best$mtry,
       min.node.size   = best$min.node.size,
       sample.fraction = best$sample.fraction,
       oob_mse         = best$oob_mse,
       oob_mse_default = fit_def$prediction.error,
       mtry_default    = fit_def$mtry,
       p               = p)
}
