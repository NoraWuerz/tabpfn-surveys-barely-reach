# Nested error regression (BHF) with data-driven log-shift transformation,
# saeTrafo::NER_Trafo (Wuerz, Schmid and Tzavidis 2022). Reported in the SI as
# "LMM log-shift" next to the untransformed LMM of models/lmm.R.
# Requires: pipeline/00_header.R, the dataset settings.R and
#   pipeline/02_load_data.R sourced beforehand.
# Output contract: one row per unit per sim_id with columns
#   sim_id, unit_id, area, y_true, pred
# Writes: {dataset_dir}/results/lmm_logshift.parquet
#         {dataset_dir}/results/lmm_logshift_params.csv  (shift per draw)
#
# Specification: fixed part formula_ml (covariates without the area
# identifier), area as random intercept; the shift s of log(y + s) is chosen
# per draw by REML on the package's default interval. With unit-level
# population data NER_Trafo applies the back-transformation with the bias
# correction of Berg and Chandra (2014) / Molina and Martin (2018). Areas
# without sample units get the synthetic estimate (fixed part only). No MSE.
#
# Zero or negative targets: saeTrafo shifts y by |min(y)| + 1 when min(y) <= 0,
# with the minimum taken from the sample. This is why the EVS population is
# defined without its five negative incomes (see datasets/05_evs62/settings.R).

source(file.path("functions", "sae_trafo_helpers.R"))

shift_params <- list()

run_lmm_logshift <- function(sim_id, seed) {
  set.seed(seed)
  # Factors as 0/1 dummies: NER_Trafo with pop_data cannot take factors with
  # more than two levels (see functions/sae_trafo_helpers.R).
  dc    <- dummy_code(as.data.frame(samples[samples$sim_id == sim_id, ]),
                      as.data.frame(population), covariates_cat, covariates_num, y_col)
  train <- dc$train; pop <- dc$pop

  # capture.output: NER_Trafo print()s a pointer to emdi on every call.
  utils::capture.output(
    est <- saeTrafo::NER_Trafo(fixed = dc$fixed,
                               smp_data = train, smp_domains = group_col,
                               pop_data = pop,   pop_domains = group_col,
                               transformation = "log.shift", MSE = FALSE, seed = seed)
  )
  # optimal_lambda is the shift s in log(y + s); shift_par is the additional
  # offset |min(y)| + 1 that saeTrafo sets only when min(y) <= 0 (else NULL).
  tp <- est$transform_param
  shift_params[[as.character(sim_id)]] <<- data.frame(
    sim_id    = sim_id,
    lambda    = as.numeric(tp$optimal_lambda),
    shift_par = if (is.null(tp$shift_par)) NA_real_ else as.numeric(tp$shift_par))

  area_means_to_units(est$ind, sim_id, pop)
}

tic()
results <- pmap(sim_meta, run_lmm_logshift, .progress = TRUE) |>
  compact() |>
  list_rbind()
toc()

arrow::write_parquet(results, file.path(dataset_dir, "results", "lmm_logshift.parquet"))
write.csv(do.call(rbind, shift_params),
          file.path(dataset_dir, "results", "lmm_logshift_params.csv"), row.names = FALSE)
