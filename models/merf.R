# MERF (SAEforest::MERFranger) with per-draw tuning of the random forest.
# Requires: pipeline/00_header.R, the dataset settings.R and
#   pipeline/02_load_data.R sourced beforehand.
# Output contract: one row per unit per sim_id with columns
#   sim_id, unit_id, area, y_true, pred
# Writes: {dataset_dir}/results/merf.parquet
#         {dataset_dir}/results/merf_params.csv
#
# MaxIterations = 10 and ErrorTolerance = 1e-5 give MERF the same stopping
# rule as CatBoost-EM and TabPFN-EM. MERFranger uses ranger's out-of-bag
# predictions inside the EM loop rather than a k-fold CV; this is part of the
# MERF construction. The forest is tuned per draw on y ~ x before the EM loop,
# because the random effects are unknown before estimation.

source(file.path("functions", "tune_ranger.R"))

TUNE_N_EVAL   <- 100
MERF_MAX_ITER <- 10
MERF_TOL      <- 1e-5

tuned_params_merf <- list()

run_merf <- function(sim_id, seed) {
  set.seed(seed)
  train <- samples[samples$sim_id == sim_id, ]
  pop   <- population

  tp <- tune_ranger(formula_ml, train, n_eval = TUNE_N_EVAL, seed = seed)
  tuned_params_merf[[as.character(sim_id)]] <<- data.frame(sim_id = sim_id, tp)

  fit <- SAEforest::MERFranger(
    Y               = train[[y_col]],
    X               = train[, covariates, drop = FALSE],
    random          = paste0("(1|", group_col, ")"),
    data            = train,
    num.trees       = 500,
    mtry            = tp$mtry,
    min.node.size   = tp$min.node.size,
    sample.fraction = tp$sample.fraction,
    respect.unordered.factors = "order",
    na.rm           = TRUE,
    MaxIterations   = MERF_MAX_ITER,
    ErrorTolerance  = MERF_TOL
  )
  pred <- predict(fit, pop)

  tibble(sim_id,
         unit_id   = pop[[unit_id]],
         area      = as.character(pop[[group_col]]),
         y_true    = pop[[y_col]],
         pred      = as.numeric(pred))
}

tic()
results <- pmap(sim_meta, run_merf, .progress = TRUE) |>
  compact() |>
  list_rbind()
toc()

arrow::write_parquet(results,
  file.path(dataset_dir, "results", "merf.parquet"))
write.csv(do.call(rbind, tuned_params_merf),
  file.path(dataset_dir, "results", "merf_params.csv"), row.names = FALSE)
