# Random forest without area information; mtry, min.node.size and
# sample.fraction are tuned per draw by random search on the OOB error
# (functions/tune_ranger.R), since each draw is an independent realisation.
# Requires: pipeline/00_header.R, the dataset settings.R and
#   pipeline/02_load_data.R sourced beforehand.
# Output contract: one row per unit per sim_id with columns
#   sim_id, unit_id, area, y_true, pred
# Writes: {dataset_dir}/results/rf.parquet
#         {dataset_dir}/results/rf_params.csv  (tuned parameters and
#         OOB error per draw, with the ranger default for comparison)

source(file.path("functions", "tune_ranger.R"))

TUNE_N_EVAL <- 100

tuned_params <- list()

run_rf <- function(sim_id, seed) {
  set.seed(seed)
  train <- samples[samples$sim_id == sim_id, ]
  pop   <- population

  tp <- tune_ranger(formula_ml, train, n_eval = TUNE_N_EVAL, seed = seed)
  tuned_params[[as.character(sim_id)]] <<- data.frame(sim_id = sim_id, tp)

  fit <- ranger::ranger(
    formula         = formula_ml,
    data            = train,
    num.trees       = 500,
    mtry            = tp$mtry,
    min.node.size   = tp$min.node.size,
    sample.fraction = tp$sample.fraction,
    respect.unordered.factors = "order",
    seed            = seed
  )
  pred <- predict(fit, data = pop)$predictions

  tibble(sim_id,
         unit_id   = pop[[unit_id]],
         area      = as.character(pop[[group_col]]),
         y_true    = pop[[y_col]],
         pred      = pred)
}

tic()
results <- pmap(sim_meta, run_rf, .progress = TRUE) |>
  compact() |>
  list_rbind()
toc()

arrow::write_parquet(results, file.path(dataset_dir, "results", "rf.parquet"))
write.csv(do.call(rbind, tuned_params),
          file.path(dataset_dir, "results", "rf_params.csv"), row.names = FALSE)
