# areasize_stats.R
# Accuracy relative to the LMM by area sample size, over all populations
# (source of Fig. 5). Per area i and estimator m:
#   RMSE_i(m)  = sqrt(mean_s (pred_is - y_i)^2)
#   ratio_i(m) = RMSE_i(m) / RMSE_i(LMM)
#   RRMSE_i(m) = 100 * RMSE_i(m) / y_i          (y_i = true area mean)
# Area size = sample size n_i of the area (first Monte Carlo sample; the design
# fixes n_i across the samples). Unsampled areas have n_i = 0 and form their own
# class "0 (unsampled)". Six classes:
#   0 (unsampled) | <= 3 | 4-5 | 6-10 | 11-20 | > 20
# Compared: TabPFN-ID, MERF and CatBoost-EM.
#
# Table written to aggregated_results/tables/:
#   areasize_dataset_medians.csv  per population and class: median over its
#                                 areas of ratio_i and RRMSE_i, mean rank
#                                 (read by paper_figures/final_PNAS_plots.R, Fig. 5)
#
# Inputs:  datasets/<id>/merged/results.rds, settings.json, data/samples.parquet
#          (populations whose merged/results.rds is present, see README step 4)
# Run from the repository root:  Rscript aggregated_results/areasize_stats.R
# -----------------------------------------------------------------------------
suppressMessages({
  library(dplyr); library(tidyr); library(purrr); library(arrow); library(jsonlite)
})
source("aggregated_results/plot_theme.R")   # method_meta

TAB_DIR <- "aggregated_results/tables"
dir.create(TAB_DIR, showWarnings = FALSE, recursive = TRUE)

# -- Estimators (column name in results.rds -> canonical ID from method_meta) --
alias <- c(lmm = "lmm", tabpfn_id = "tabpfn_group",
           "merf" = "merf", catboost_em = "catboost_em")
REF_METHOD    <- "lmm"
SHOW_METHODS  <- c("tabpfn_group", "merf", "catboost_em")   # order in the tables
method_labels <- setNames(method_meta$label, method_meta$canonical)[SHOW_METHODS]

# -- Size classes -------------------------------------------------------------
size_classes <- function(n_i) {
  cut(n_i, breaks = c(-Inf, 0, 3, 5, 10, 20, Inf),
      labels = c("0 (unsampled)", "≤ 3", "4–5", "6–10", "11–20", "> 20"))
}

# -----------------------------------------------------------------------------
# 1  Per-area RMSE / RRMSE per population
# -----------------------------------------------------------------------------
dataset_dirs <- list.dirs("datasets", recursive = FALSE)
dataset_dirs <- dataset_dirs[file.exists(file.path(dataset_dirs, "merged", "results.rds"))]
dataset_ids  <- basename(dataset_dirs)
if (!length(dataset_ids)) stop("No datasets/<id>/merged/results.rds found (README, step 4).")
message("Populations with merged/results.rds: ", paste(dataset_ids, collapse = ", "))

area_rmse_one <- function(dir, ds) {
  am  <- readRDS(file.path(dir, "merged", "results.rds"))$area_means |>
    mutate(area = as.character(area))
  cols <- intersect(names(alias), names(am))
  missing <- setdiff(names(alias), cols)
  if (length(missing)) message("  ", ds, ": without ", paste(missing, collapse = ", "))

  cfg <- fromJSON(file.path(dir, "settings.json"))
  n_i <- read_parquet(file.path(dir, "data", "samples.parquet"),
                      col_select = c("sim_id", cfg$group_col)) |>
    filter(sim_id == 1) |>
    count(.data[[cfg$group_col]], name = "n_i") |>
    transmute(area = as.character(.data[[cfg$group_col]]), n_i)

  am |>
    pivot_longer(all_of(cols), names_to = "raw", values_to = "pred") |>
    group_by(area, raw) |>
    summarise(n_sim = sum(!is.na(pred)),
              rmse  = sqrt(mean((pred - y_true)^2, na.rm = TRUE)),
              y_bar = mean(y_true, na.rm = TRUE),
              .groups = "drop") |>
    mutate(rrmse = 100 * rmse / y_bar) |>
    filter(n_sim > 0, is.finite(rmse)) |>
    left_join(n_i, by = "area") |>
    mutate(n_i = replace_na(n_i, 0L), dataset = ds)
}

area_rmse <- map2(dataset_dirs, dataset_ids, area_rmse_one) |> list_rbind()

# -----------------------------------------------------------------------------
# 2  Ratio to the LMM per area, size class, rank
# -----------------------------------------------------------------------------
d_all <- area_rmse |>
  mutate(canonical = unname(alias[raw])) |>
  select(dataset, area, n_i, canonical, rmse, rrmse)
ref <- d_all |> filter(canonical == REF_METHOD) |>
  select(dataset, area, rmse_lmm = rmse)
ratios <- d_all |>
  filter(canonical %in% SHOW_METHODS) |>
  inner_join(ref, by = c("dataset", "area")) |>
  mutate(ratio    = rmse / rmse_lmm,
         method_f = factor(method_labels[canonical], levels = method_labels),
         scope    = if_else(n_i > 0, "insample", "oos"),
         size_f   = size_classes(n_i)) |>
  filter(is.finite(ratio))

# Only areas for which all three estimators are available; otherwise the
# three estimators of a class would be compared on different sets of areas.
complete_areas <- ratios |>
  count(dataset, area) |>
  filter(n == length(SHOW_METHODS)) |>
  select(dataset, area)
dropped <- anti_join(distinct(ratios, dataset, area), complete_areas,
                     by = c("dataset", "area")) |>
  count(dataset, name = "n_areas")
if (nrow(dropped)) {
  message("Areas without all three estimators (dropped): ",
          paste(sprintf("%s: %d", dropped$dataset, dropped$n_areas), collapse = "; "))
}
ratios <- semi_join(ratios, complete_areas, by = c("dataset", "area")) |>
  # rank per area: 1 = smallest RMSE among the three estimators
  group_by(dataset, area) |>
  mutate(rank = rank(rmse, ties.method = "min")) |>
  ungroup()


# -----------------------------------------------------------------------------
# 3  Per population and class (Fig. 5)
# -----------------------------------------------------------------------------
dataset_medians <- ratios |>
  group_by(dataset, size_f, method_f) |>
  summarise(n_areas = n(), median_ratio = median(ratio), median_rrmse = median(rrmse),
            mean_rank = mean(rank), .groups = "drop") |>
  arrange(dataset, size_f, method_f)
write.csv(dataset_medians, file.path(TAB_DIR, "areasize_dataset_medians.csv"),
          row.names = FALSE)


# Typical ratio per size class (quoted with Fig. 5): the "typical" population,
# i.e. the median over populations of the per-population medians.
cat("\n--- Fig. 5: median over populations of the per-population median ratio to the LMM ---\n")
print(dataset_medians |>
        group_by(size_f, method_f) |>
        summarise(n_datasets = n(), typical_ratio = median(median_ratio), .groups = "drop") |>
        mutate(typical_ratio = round(typical_ratio, 3)) |>
        pivot_wider(names_from = method_f, values_from = typical_ratio) |>
        as.data.frame(), row.names = FALSE)

message("Done. Tables in: ", normalizePath(TAB_DIR, winslash = "/"))
