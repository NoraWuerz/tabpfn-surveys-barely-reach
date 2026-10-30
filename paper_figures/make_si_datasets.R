# make_si_datasets.R
# Builds the SI data tables (Dataset S1: per-dataset summaries, S2: Monte Carlo
# SEs, S3: per-area RRMSE ratios to the LMM, S4: implicit-shrinkage slopes)
# from the aggregated tables.
# Inputs:  aggregated_results/tables/{dataset_stats,mc_se,mc_paired_vs_ref_medratio,
#          shrinkage_calibration}.csv
# Output:  paper_figures/SI_datasets/Dataset_S{1,2,3,4}_*.csv
# Run from the repository root.
AGG <- "aggregated_results/tables"
OUT <- "paper_figures/SI_datasets"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# display names as in Table S1, in Table S1 order (decreasing ICC)
pop <- c(
  "16_timss_are_math"                = "TIMSS 2023 UAE",
  "01_eusilc"                        = "EU-SILC Austria",
  "11_wvs7_trust"                    = "WVS wave 7",
  "03_pums_rent"                     = "PUMS 2023 renters",
  "02_fdz_bee"                       = "FDZ BEE 2017",
  "10_afrobarometer_lpi"             = "Afrobarometer R9",
  "15_pnadc_renda"                   = "PNADC 2024",
  "08_recs_electricity"              = "RECS 2020",
  "04_pums_homevalue"                = "PUMS 2023 owners",
  "14_lsms_pcexp"                    = "LSMS-ISA v2.0",
  "09_pisa_esp_math"                 = "PISA 2022 Spain",
  "07_DHS_peru_hemoglobin_children" = "Peru DHS 2009 children",
  "06_DHS_kenya_BMI_women"           = "KDHS 2022 women",
  "05_evs62"                         = "EVS 1962/63",
  "12_ces2024_policy"                = "CES 2024",
  "13_envipe_gasto"                  = "ENVIPE 2024")
est_order <- c("direct", "lmm", "rf", "catboost", "tabpfn", "rf_group",
               "catboost_group", "tabpfn_group", "merf", "catboost_em", "tabpfn_em")
lab <- c(direct = "Direct", lmm = "LMM", rf = "RF", catboost = "CatBoost",
         tabpfn = "TabPFN", rf_group = "RF-ID", catboost_group = "CatBoost-ID",
         tabpfn_group = "TabPFN-ID", merf = "MERF", catboost_em = "CatBoost-EM",
         tabpfn_em = "TabPFN-EM")

ord <- function(d) d[order(match(d$dataset, names(pop)), match(d$scope, c("insample", "oos")),
                          match(d$canonical, est_order)), ]

s1 <- read.csv(file.path(AGG, "dataset_stats.csv"))
stopifnot(all(s1$dataset %in% names(pop)), all(s1$method_f == s1$label))
s1$population <- unname(pop[s1$dataset])
s1 <- ord(s1[, c("population", "dataset", "scope", "canonical", "label", "cmp_f", "n_areas",
                 "mean_rrmse", "median_rrmse", "mean_cv", "median_cv", "mean_rb", "median_rb")])
names(s1)[names(s1) == "cmp_f"] <- "group"

s2 <- read.csv(file.path(AGG, "mc_se.csv"))
stopifnot(all(s2$S == 50))
s2$population <- unname(pop[s2$dataset])
s2 <- s2[, c("population", "dataset", "scope", "canonical", "label", "metric", "estimate", "se")]
s2 <- s2[order(match(s2$dataset, names(pop)), match(s2$scope, c("insample", "oos")),
               match(s2$canonical, est_order), match(s2$metric, c("mean_rrmse", "median_rrmse", "mean_rb", "median_rb"))), ]

s3 <- read.csv(file.path(AGG, "mc_paired_vs_ref_medratio.csv"))
stopifnot(all(s3$canonical != "lmm"), nrow(s3) == 304)
s3$population <- unname(pop[s3$dataset])
s3$label <- unname(lab[s3$canonical])
s3$resolved <- s3$significant
s3 <- ord(s3[, c("population", "dataset", "scope", "canonical", "label",
                 "ratio", "ratio_lo", "ratio_hi", "se_log", "resolved")])
# consistency: resolved == interval excludes 1
stopifnot(all(s3$resolved == (s3$ratio_lo > 1 | s3$ratio_hi < 1)))

# Dataset S4: implicit-shrinkage slopes per population, size group and -ID
# learner next to the LMM's (aggregated_results/shrinkage_calibration.R)
s4 <- read.csv(file.path(AGG, "shrinkage_calibration.csv"))
stopifnot(all(s4$dataset %in% names(pop)), nrow(s4) == 120)
s4$population <- unname(pop[s4$dataset])
s4 <- s4[order(match(s4$dataset, names(pop)),
               match(s4$ni_grp, c("n_i <= 5", "n_i 6-14", "n_i >= 15")),
               match(s4$learner, c("TabPFN-ID", "RF-ID", "CatBoost-ID"))),
         c("population", "dataset", "ni_grp", "learner", "slope", "intercept", "r2",
           "n_pairs", "lmm_slope", "lmm_intercept", "lmm_r2", "icc")]

write.csv(s1, file.path(OUT, "Dataset_S1_summaries.csv"), row.names = FALSE)
write.csv(s2, file.path(OUT, "Dataset_S2_mc_se.csv"), row.names = FALSE)
write.csv(s3, file.path(OUT, "Dataset_S3_ratios_to_lmm.csv"), row.names = FALSE)
write.csv(s4, file.path(OUT, "Dataset_S4_shrinkage_calibration.csv"), row.names = FALSE)
cat("rows:", nrow(s1), nrow(s2), nrow(s3), nrow(s4), "\n")
cat("S1 cols:", paste(names(s1), collapse = ","), "\n")
cat("S2 cols:", paste(names(s2), collapse = ","), "\n")
cat("S3 cols:", paste(names(s3), collapse = ","), "\n")
cat("S4 cols:", paste(names(s4), collapse = ","), "\n")
print(table(s1$group))
print(list.files(OUT))
