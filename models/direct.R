# Direct estimator (emdi::direct).
# Requires: pipeline/00_header.R, the dataset settings.R and
#   pipeline/02_load_data.R sourced beforehand.
# Output contract: one row per unit per sim_id with columns
#   sim_id, unit_id, area, y_true, pred
# Writes: {dataset_dir}/results/direct.parquet
#
# Out-of-sample areas get pred = NA: the direct estimator uses only the
# observations of the area itself and does not exist for unsampled areas.
# Samples are stratified simple random samples with the areas as strata, so
# the unweighted area mean equals the Horvitz-Thompson estimate and
# emdi::direct is called without weights.

run_direct <- function(sim_id, seed) {
  set.seed(seed)
  train         <- as.data.frame(samples[samples$sim_id == sim_id, ])
  pop           <- population

  # var = FALSE: only point estimates are needed; suppressMessages() silences
  # emdi's note on the poverty line for indicators that are not used here.
  est <- suppressMessages(
    emdi::direct(y = y_col, smp_data = train, smp_domains = group_col,
                 var = FALSE)
  )$ind

  # unsampled areas are absent from est, so match() yields NA
  pred <- est$Mean[match(as.character(pop[[group_col]]),
                         as.character(est$Domain))]

  tibble(sim_id,
         unit_id   = pop[[unit_id]],
         area      = as.character(pop[[group_col]]),
         y_true    = pop[[y_col]],
         pred      = as.numeric(pred))
}

tic()
results <- pmap(sim_meta, run_direct, .progress = TRUE) %>%
  compact() %>%
  list_rbind()
toc()

arrow::write_parquet(results, file.path(dataset_dir, "results", "direct.parquet"))