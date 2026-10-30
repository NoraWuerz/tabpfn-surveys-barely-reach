# logshift_stats.R
# Median and mean area-level RRMSE (%) over the 50 Monte Carlo samples of the
# LMM, the LMM with log-shift transformation (models/lmm_logshift.R) and
# TabPFN-ID, per population and scope (source of Fig. S4). The metrics are
# computed from the result files as in area_stats.R
# (RRMSE_i = 100 * RMSE_i / y_i; in-sample = area sampled in the first Monte
# Carlo sample); the LMM and TabPFN-ID values are checked against
# dataset_stats.csv.
# Requires: datasets/<id>/settings.json, data/samples.parquet and
#           results/{lmm,lmm_logshift,tabpfn_id}.parquet (populations
#           without them are skipped), aggregated_results/tables/dataset_stats.csv
# Writes:   aggregated_results/tables/logshift_stats.csv
# Run from the repository root:  Rscript aggregated_results/logshift_stats.R
suppressMessages({ library(dplyr); library(purrr); library(arrow); library(jsonlite) })

AGG <- "aggregated_results/tables"
OUT <- file.path(AGG, "logshift_stats.csv")

# result file (without .parquet) -> label
methods <- c(lmm = "LMM", lmm_logshift = "LMM log-shift", tabpfn_id = "TabPFN-ID")

dataset_dirs <- list.dirs("datasets", recursive = FALSE)
has_res <- file.exists(file.path(dataset_dirs, "results", "lmm_logshift.parquet")) &
           file.exists(file.path(dataset_dirs, "data", "samples.parquet"))
dataset_dirs <- dataset_dirs[has_res]
if (!length(dataset_dirs)) stop("No datasets/<id>/results/lmm_logshift.parquet found.")
message("Populations with log-shift results: ", paste(basename(dataset_dirs), collapse = ", "))

area_stats_one <- function(dir) {
  ds  <- basename(dir)
  cfg <- fromJSON(file.path(dir, "settings.json"))
  ins <- read_parquet(file.path(dir, "data", "samples.parquet"),
                      col_select = c("sim_id", cfg$group_col)) |>
    filter(sim_id == 1) |> pull(cfg$group_col) |> as.character() |> unique()
  map(names(methods), function(m) {
    f <- file.path(dir, "results", paste0(m, ".parquet"))
    if (!file.exists(f)) { warning(ds, ": ", m, ".parquet missing"); return(NULL) }
    read_parquet(f, col_select = c("sim_id", "area", "y_true", "pred")) |>
      mutate(area = as.character(area)) |>
      group_by(sim_id, area) |>
      summarise(y_true = mean(y_true), pred = mean(pred), .groups = "drop") |>
      mutate(diff = pred - y_true) |>
      group_by(area) |>
      summarise(n_sim = sum(!is.na(diff)),
                rmse  = sqrt(mean(diff^2, na.rm = TRUE)),
                y_bar = mean(y_true), .groups = "drop") |>
      filter(n_sim > 0) |>
      mutate(rrmse = 100 * rmse / y_bar, method = m, dataset = ds,
             scope = if_else(area %in% ins, "insample", "oos"))
  }) |> list_rbind()
}
cat("Computing area metrics ...\n")
area_stats <- map(dataset_dirs, area_stats_one) |> list_rbind()

stats <- area_stats |>
  group_by(scope, dataset, method) |>
  summarise(n_areas = n(), median_rrmse = median(rrmse), mean_rrmse = mean(rrmse),
            .groups = "drop") |>
  mutate(label = unname(methods[method])) |>
  arrange(dataset, scope, match(method, names(methods)))
write.csv(stats, OUT, row.names = FALSE)

# ---- check against dataset_stats.csv (LMM, TabPFN-ID) -----------------------
ref <- read.csv(file.path(AGG, "dataset_stats.csv")) |>
  filter(canonical %in% c("lmm", "tabpfn_group")) |>
  mutate(method = c(lmm = "lmm", tabpfn_group = "tabpfn_id")[canonical]) |>
  select(scope, dataset, method, ref_median = median_rrmse)
chk <- stats |> inner_join(ref, by = c("scope", "dataset", "method")) |>
  mutate(abs_diff = abs(median_rrmse - ref_median))
cat(sprintf("Check against dataset_stats.csv: %d cells, max. deviation %.2e\n",
            nrow(chk), max(chk$abs_diff)))
if (nrow(chk) && max(chk$abs_diff) > 1e-6) {
  print(chk |> filter(abs_diff > 1e-6) |> as.data.frame())
  stop("Deviation from dataset_stats.csv -- check definition or data.")
}
cat("written:", OUT, "\n")
