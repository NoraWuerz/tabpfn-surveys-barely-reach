# shrinkage_calibration.R
# Implicit-shrinkage calibration over all populations (source of Fig. S8 and
# Dataset S4): for each population, -ID learner and per-area sample-size
# group, the least-squares slope of the implied area effect on the raw area
# effect (functions/shrinkage_effects.R) and its R^2, next to the slope the
# LMM itself attains by the same construction on the same samples
# (functions/shrinkage_lmm_effects.R). A slope near the LMM's means the
# learner shrinks like the mixed model.
#   raw_is     = mean_s(y) - mean_s(naive prediction)
#   implied_is = mean over population units of (ID prediction - naive prediction)
#   groups     : n_i <= 5 | 6-14 | >= 15 (a population contributes the groups it has)
# Inputs:  datasets/<id>/settings.{R,json}, data/{population,samples}.parquet,
#          results/{tabpfn,rf,catboost}_*.parquet (populations whose unit-level
#          files are present, see README), aggregated_results/tables/dataset_icc_r2.csv
# Output:  aggregated_results/tables/shrinkage_calibration.csv
#          (one row per population x group x learner; Fig. S8 is drawn from it
#          by paper_figures/final_PNAS_plots.R, Dataset S4 by make_si_datasets.R)
# Run from the repository root:  Rscript aggregated_results/shrinkage_calibration.R
suppressMessages(library(dplyr))
source("functions/shrinkage_effects.R")        # shrinkage_effects(), shrinkage_fit_stats(), shrinkage_groups()
source("functions/shrinkage_lmm_effects.R")    # lmm_shrinkage_effects(), lmm_shrinkage_slopes()

AGG <- "aggregated_results/tables"
OUT <- file.path(AGG, "shrinkage_calibration.csv")

ds_lab <- c("01_eusilc"="EU-SILC", "02_fdz_bee"="FDZ BEE", "03_pums_rent"="PUMS rent",
  "04_pums_homevalue"="PUMS value", "05_evs62"="EVS 1962/63",
  "06_DHS_kenya_BMI_women"="KDHS women", "07_DHS_peru_hemoglobin_children"="Peru DHS",
  "08_recs_electricity"="RECS 2020", "09_pisa_esp_math"="PISA Spain",
  "10_afrobarometer_lpi"="Afrobarometer", "11_wvs7_trust"="WVS 7",
  "12_ces2024_policy"="CES 2024", "13_envipe_gasto"="ENVIPE", "14_lsms_pcexp"="LSMS-ISA",
  "15_pnadc_renda"="PNADC", "16_timss_are_math"="TIMSS UAE")

ids <- names(ds_lab)[vapply(file.path("datasets", names(ds_lab)), shrinkage_has_data, logical(1))]
if (!length(ids)) stop("No population with the unit-level files needed (README).")
message("Populations with unit-level files: ", paste(ids, collapse = ", "))

one_dataset <- function(id) {
  dsdir <- file.path("datasets", id)
  eff <- shrinkage_effects(dsdir) |>
    mutate(learner = as.character(learner), ni_grp = shrinkage_groups(n_i))
  learner_stats <- eff |> group_by(learner, ni_grp) |>
    group_modify(~ shrinkage_fit_stats(.x)) |> ungroup() |> select(-resid_sd)

  lmm_eff <- lmm_shrinkage_effects(dsdir, file.path(dsdir, "settings.R")) |>
    mutate(ni_grp = shrinkage_groups(n_i))
  lmm_stats <- lmm_shrinkage_slopes(lmm_eff) |>
    select(ni_grp, lmm_slope = slope, lmm_intercept = intercept, lmm_r2 = r2)

  message(sprintf("%-34s groups: %s", id, paste(levels(droplevels(eff$ni_grp)), collapse = ", ")))
  learner_stats |> inner_join(lmm_stats, by = "ni_grp") |> mutate(dataset = id, .before = 1)
}

res <- bind_rows(lapply(ids, one_dataset)) |>
  mutate(learner = factor(learner, levels = names(shrinkage_pairs)),
         population = unname(ds_lab[dataset]))
icc <- read.csv(file.path(AGG, "dataset_icc_r2.csv"))[, c("dataset", "icc")]
res <- res |> left_join(icc, by = "dataset") |> arrange(desc(icc), ni_grp, learner)
write.csv(res, OUT, row.names = FALSE)

# ---- summary quoted in the SI text (Section S8) ----------------------------
dev <- res |> mutate(dev = slope - lmm_slope) |> group_by(learner) |>
  summarise(n = n(), mean_abs_dev = mean(abs(dev)), median_dev = median(dev),
            share_within_0.1 = mean(abs(dev) <= 0.1), n_within_0.1 = sum(abs(dev) <= 0.1),
            min_dev = min(dev), max_dev = max(dev), median_r2 = median(r2), .groups = "drop")
cat("\nDeviation of the learner slope from the LMM slope (population x group):\n")
print(as.data.frame(dev |> mutate(across(where(is.numeric), ~ round(.x, 3)))), row.names = FALSE)
cat("\nwritten:", OUT, "(", nrow(res), "rows )\n")
