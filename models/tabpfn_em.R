# TabPFN-EM via reticulate with 5-fold CV inside the EM loop; cv_folds,
# max_iter and tol match CatBoost-EM so that only the base learner differs.
# Requires: pipeline/00_header.R, the dataset settings.R and
#   pipeline/02_load_data.R sourced beforehand; Python environment in .venv.
# Output contract: one row per unit per sim_id with columns
#   sim_id, unit_id, area, y_true, pred
# Writes: {dataset_dir}/results/tabpfn_em.parquet

source("functions/tabpfn_em.R")

# Seeds fix the random state, but TabPFN predictions can differ minimally
# between GPU models (floating-point behaviour of the CUDA kernels), so small
# deviations from the deposited results are expected on other hardware.
device   <- "cuda"   # "cpu" runs without a GPU (much slower); the paper used a GPU
cv_folds <- 5
max_iter <- 10
tol      <- 1e-5


run_tabpfn_em <- function(sim_id, seed) {
  set.seed(seed)
  train         <- samples[samples$sim_id == sim_id, ]
  pop           <- population

  t0 <- Sys.time()
  fit <- tabpfn_em_fit(train, y_col = y_col, x_cols = covariates, group_col = group_col,
                       cv_folds = cv_folds, max_iter = max_iter, tol = tol,
                       device = device, seed = seed)

  pred <- tabpfn_em_predict(fit, pop)

  # log EM iterations and runtime per draw
  cat(sprintf("[sim %s] EM iterations: %d | %.1f sec\n", sim_id, fit$iterations,
              as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  flush(stdout())   # Rscript buffers stdout when redirected to a file

  tibble(sim_id,
         unit_id   = pop[[unit_id]],
         area      = as.character(pop[[group_col]]),
         y_true    = pop[[y_col]],
         pred      = as.numeric(pred))
}

tic()
results <- pmap(sim_meta, run_tabpfn_em, .progress = TRUE) |>
  compact() |>
  list_rbind()
toc()

arrow::write_parquet(results, file.path(dataset_dir, "results", "tabpfn_em.parquet"))
