# RF-ID: random forest with the area identifier as covariate; mtry,
# min.node.size and sample.fraction are tuned per draw (functions/tune_ranger.R).
# Requires: pipeline/00_header.R, the dataset settings.R and
#   pipeline/02_load_data.R sourced beforehand.
# Output contract: one row per unit per sim_id with columns
#   sim_id, unit_id, area, y_true, pred
# Writes: {dataset_dir}/results/rf_id.parquet
#         {dataset_dir}/results/rf_id_params.csv

source(file.path("functions", "tune_ranger.R"))

TUNE_N_EVAL <- 100

all_areas          <- sort(unique(population[[group_col]]))
tuned_params_group <- list()

run_rf_id <- function(sim_id, seed) {
  set.seed(seed)
  train <- samples[samples$sim_id == sim_id, ]
  pop   <- population

  # The area factor takes its levels from the population, since out-of-sample
  # areas never occur in train. It must be an ordered factor: with
  # respect.unordered.factors = "order", ranger would re-sort unordered levels
  # by the mean response in training, which is NaN for out-of-sample areas and
  # places them at the top rank; ordered factors are exempt from this recoding,
  # while the other categorical covariates still benefit from "order".
  train[[group_col]] <- factor(train[[group_col]], levels = all_areas, ordered = TRUE)
  pop[[group_col]]   <- factor(pop[[group_col]],   levels = all_areas, ordered = TRUE)

  tp <- tune_ranger(formula_ml_group, train, n_eval = TUNE_N_EVAL, seed = seed)
  tuned_params_group[[as.character(sim_id)]] <<- data.frame(sim_id = sim_id, tp)

  fit <- ranger::ranger(
    formula         = formula_ml_group,
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
results <- pmap(sim_meta, run_rf_id, .progress = TRUE) |>
  compact() |>
  list_rbind()
toc()

arrow::write_parquet(results, file.path(dataset_dir, "results", "rf_id.parquet"))
write.csv(do.call(rbind, tuned_params_group),
          file.path(dataset_dir, "results", "rf_id_params.csv"), row.names = FALSE)
