# Pipeline step 3: Merge the per-model results and compute the area means.
# Requires: 00_header.R and dataset settings.R sourced beforehand.
# Reads:    all .parquet files from {dataset_dir}/results/
# Writes:   {dataset_dir}/merged/results.rds

results_dir <- file.path(dataset_dir, "results")
merged_dir  <- file.path(dataset_dir, "merged")
dir.create(merged_dir, showWarnings = FALSE, recursive = TRUE)

all_files   <-  list.files(results_dir, pattern = "\\.parquet$", full.names = TRUE)
model_names <- file_path_sans_ext(basename(all_files))

join_keys <- c("sim_id", "unit_id", "area", "y_true")

pred_unit <- map2(all_files, model_names,
                  \(f, m) arrow::read_parquet(f) |> rename(!!m := pred)) |>
  reduce(full_join, by = join_keys)

# Area means per Monte Carlo sample; the aggregation scripts in
# aggregated_results/ read nothing else.
area_means <- pred_unit |>
  group_by(sim_id, area) |>
  summarise(
    y_true = mean(y_true),
    across(all_of(model_names), mean),
    .groups = "drop"
  )

saveRDS(list(area_means = area_means), file.path(merged_dir, "results.rds"))
message("written: ", file.path(merged_dir, "results.rds"), " (",
        n_distinct(area_means$area), " areas, ", n_distinct(area_means$sim_id),
        " samples, ", length(model_names), " estimators)")
