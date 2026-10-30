# area_stats.R
# Area-level results aggregated over all populations: per population,
# estimator and scope the mean and median RRMSE / CV / RB over areas, their
# Monte Carlo standard errors and the paired bootstrap against the LMM, the ICC
# and R2 of each population, and the ID/EM ratios with bootstrap intervals.
# Requires: datasets/<id>/merged/results.rds from run_postprocess.R (populations
#           without it are skipped), settings.json, data/*.parquet
# Writes:   aggregated_results/tables/{dataset_stats,mc_se,ratio_stats,
#           dataset_icc_r2}.csv
# Run from the repository root: Rscript aggregated_results/area_stats.R

suppressMessages({ library(dplyr); library(tidyr); library(purrr); library(tibble); library(arrow); library(jsonlite); library(lme4) })
source("aggregated_results/plot_theme.R")

OUT_DIR <- "aggregated_results/tables"
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

# -----------------------------------------------------------------------------
# 1  Collect datasets
# -----------------------------------------------------------------------------

dataset_dirs <- list.dirs("datasets", recursive = FALSE)

ds_id <- function(dir) basename(dir)

result_files <- file.path(dataset_dirs, "merged", "results.rds")
has_results  <- file.exists(result_files)

if (any(!has_results)) {
  message("Without merged/results.rds and therefore not included: ",
          paste(ds_id(dataset_dirs[!has_results]), collapse = ", "))
}
dataset_dirs <- dataset_dirs[has_results]
result_files <- result_files[has_results]
dataset_ids  <- ds_id(dataset_dirs)

# Short population labels for the console messages and the ds_short column.
dataset_labels <- c(
  "01_eusilc"                 = "EU-SILC",
  "02_fdz_bee"                = "FDZ BEE",
  "03_pums_rent"              = "PUMS rent",
  "04_pums_homevalue"         = "PUMS value",
  "05_evs62"                  = "EVS",
  "06_DHS_kenya_BMI_women"    = "DHS BMI",
  "07_DHS_peru_hemoglobin_children" = "DHS Hb (Peru)",
  "08_recs_electricity"       = "RECS kWh",
  "09_pisa_esp_math"          = "PISA math",
  "10_afrobarometer_lpi"      = "Afrobar. LPI",
  "11_wvs7_trust"             = "WVS trust",
  "12_ces2024_policy"         = "CES policy",
  "13_envipe_gasto"           = "ENVIPE gasto",
  "14_lsms_pcexp"             = "LSMS pcexp",
  "15_pnadc_renda"            = "PNADC renda",
  "16_timss_are_math"         = "TIMSS math"
)
ds_lab <- function(x) ifelse(is.na(dataset_labels[x]), x, unname(dataset_labels[x]))

# -----------------------------------------------------------------------------
# 2  Method taxonomy
# -----------------------------------------------------------------------------
# Grouping: Baseline (Direct, LMM) | Naive | ID | EM. Labels and colours come
# from plot_theme.R (method_meta); "direct" is added here as a baseline.
# Result file name (column in results.rds) -> canonical estimator id.
alias <- c(
  direct      = "direct",
  lmm         = "lmm",
  rf          = "rf",
  catboost    = "catboost",
  tabpfn      = "tabpfn",
  rf_id       = "rf_group",
  catboost_id = "catboost_group",
  tabpfn_id   = "tabpfn_group",
  merf        = "merf",
  catboost_em = "catboost_em",
  tabpfn_em   = "tabpfn_em"
)

estimator_meta <- bind_rows(
  tibble::tibble(canonical = "direct", label = "Direct", family = "direct",
                 variant = "Baseline", color_can = "#1B1B1B"),
  method_meta
) |>
  # cmp_group: Baseline / Naive / ID / EM; the LMM counts as Baseline.
  mutate(cmp_group = case_when(
    canonical %in% c("direct", "lmm") ~ "Baseline",
    variant == "Naive"                ~ "Naive",
    variant == "ID"                   ~ "ID",
    TRUE                              ~ "EM"
  )) |>
  filter(canonical %in% alias) |>
  arrange(match(cmp_group, c("Baseline", "Naive", "ID", "EM")),
          match(family, c("direct", "lmm", "rf", "catboost", "tabpfn")))

method_levels <- estimator_meta$label
cmp_levels    <- c("Baseline", "Naive", "ID", "EM")

# -----------------------------------------------------------------------------
# 3  Area-level metrics
# -----------------------------------------------------------------------------
# Computed from area_means (per area i and Monte Carlo sample s), in percent:
#   RRMSE_i = 100 * sqrt(mean_s (pred_is - y_i)^2) / y_i
#   CV_i    = 100 * sqrt(mean_s (pred_is - y_i)^2) / mean_s(pred_is)
#   RB_i    = 100 * mean_s ((pred_is - y_i) / y_i)

area_stats_one <- function(f, ds) {
  am    <- readRDS(f)$area_means
  mcols <- setdiff(names(am), c("sim_id", "area", "y_true"))
  am |>
    tidyr::pivot_longer(all_of(mcols), names_to = "method", values_to = "pred") |>
    mutate(diff = pred - y_true) |>
    group_by(area, method) |>
    summarise(
      n_sim    = sum(!is.na(diff)),
      rmse     = sqrt(mean(diff^2, na.rm = TRUE)),
      y_bar    = mean(y_true, na.rm = TRUE),
      pred_bar = mean(pred,   na.rm = TRUE),
      rb       = 100 * mean(diff / y_true, na.rm = TRUE),
      .groups  = "drop"
    ) |>
    mutate(rrmse   = 100 * rmse / y_bar,
           cv      = 100 * rmse / pred_bar,
           dataset = ds) |>
    filter(n_sim > 0)
}

area_stats <- map2(result_files, dataset_ids, area_stats_one) |> list_rbind()

# -- In-sample flag per area (n_i > 0 in the first sample) --------------------
samplesize_df <- map(dataset_dirs, \(dir) {
  cfg <- jsonlite::fromJSON(file.path(dir, "settings.json"))
  read_parquet(file.path(dir, "data", "samples.parquet"),
               col_select = c("sim_id", cfg$group_col)) |>
    filter(sim_id == 1) |>
    count(.data[[cfg$group_col]], name = "samplesize") |>
    mutate(area = as.character(.data[[cfg$group_col]]), dataset = ds_id(dir)) |>
    select(dataset, area, samplesize)
}) |> list_rbind()

area_stats <- area_stats |>
  mutate(area = as.character(area)) |>
  left_join(samplesize_df, by = c("dataset", "area")) |>
  mutate(samplesize = tidyr::replace_na(samplesize, 0L),
         scope      = if_else(samplesize > 0, "insample", "oos"))

# -- Keep only the estimators of the taxonomy and map to canonical names ------
area_stats <- area_stats |>
  filter(method %in% names(alias)) |>
  resolve_method(alias, meta = estimator_meta) |>
  mutate(method_f = factor(label, levels = method_levels),
         cmp_f    = factor(cmp_group, levels = cmp_levels)) |>
  filter(is.finite(rmse))

# Out-of-sample: Direct is not defined there. The out-of-sample statistics
# need at least three unsampled areas per population; every population of the
# study has them (Table S1, column OOS).
oos_counts <- area_stats |> filter(scope == "oos") |> distinct(dataset, area) |> count(dataset, name = "n_oos")
if (any(oos_counts$n_oos < 3))
  stop("Fewer than 3 out-of-sample areas: ", paste(oos_counts$dataset[oos_counts$n_oos < 3], collapse = ", "))
area_stats <- area_stats |> filter(scope == "insample" | canonical != "direct")

# RRMSE, CV and RB divide by the true area mean, so all area means must be
# positive (they are for the sixteen populations; a z-scored target would not qualify).
if (any(area_stats$y_bar <= 0))
  stop("Non-positive area mean in: ", paste(unique(area_stats$dataset[area_stats$y_bar <= 0]), collapse = ", "))

# -- Aggregation per dataset x estimator x scope (one point per dataset) ------
dataset_stats <- area_stats |>
  group_by(scope, dataset, canonical, label, method_f, cmp_f) |>
  summarise(
    n_areas      = n(),
    mean_rrmse   = mean(rrmse,   na.rm = TRUE),
    median_rrmse = median(rrmse, na.rm = TRUE),
    mean_cv      = mean(cv,      na.rm = TRUE),
    median_cv    = median(cv,    na.rm = TRUE),
    mean_rb      = mean(rb,      na.rm = TRUE),
    median_rb    = median(rb,    na.rm = TRUE),
    .groups      = "drop"
  )

write.csv(dataset_stats, file.path(OUT_DIR, "dataset_stats.csv"), row.names = FALSE)

# Warn if relative measures are unstable (target mean near zero).
flagged <- dataset_stats |>
  filter(scope == "insample") |>
  group_by(dataset) |>
  summarise(max_median_rrmse = max(abs(median_rrmse), na.rm = TRUE), .groups = "drop") |>
  filter(max_median_rrmse > 100)
if (nrow(flagged)) {
  message("WARNING - relative measures unstable (median RRMSE > 100 %), mean of ",
          "the target variable is probably close to zero: ",
          paste(ds_lab(flagged$dataset), collapse = ", "))
}

# -----------------------------------------------------------------------------
# 3b  Monte Carlo uncertainty: paired bootstrap over the S samples
# -----------------------------------------------------------------------------
# All estimators see the same S samples, so the sim_ids are resampled with
# replacement and all metrics are recomputed from the same resampled draws.
# Outputs:
#   mc_se.csv             SE per dataset x estimator x scope x metric
B_BOOT    <- 500
BOOT_SEED <- 20260918

boot_metrics <- function(P_list, y, scope_vec, idx) {
  # results are collected in a numeric matrix (one tibble per call) for speed
  ms  <- names(P_list)
  res <- matrix(NA_real_, nrow = 2 * length(ms), ncol = 6,
                dimnames = list(NULL, c("median_rrmse", "mean_rrmse",
                                        "median_rb", "mean_rb",
                                        "median_rmse", "mean_rmse")))
  meth <- character(nrow(res)); scp <- character(nrow(res)); k <- 0
  for (m in ms) {
    d     <- P_list[[m]][, idx, drop = FALSE] - y
    rmse  <- sqrt(rowMeans(d^2))
    rrmse <- 100 * rmse / y
    rb    <- 100 * rowMeans(d / y)
    for (s in c("insample", "oos")) {
      ok <- scope_vec == s & is.finite(rrmse)
      if (!any(ok)) next
      k <- k + 1; meth[k] <- m; scp[k] <- s
      res[k, ] <- c(median(rrmse[ok]), mean(rrmse[ok]), median(rb[ok]), mean(rb[ok]),
                    median(rmse[ok]), mean(rmse[ok]))
    }
  }
  k <- seq_len(k)
  tibble::tibble(canonical = meth[k], scope = scp[k],
                 as.data.frame(res[k, , drop = FALSE]))
}

boot_one <- function(f, ds) {
  am <- readRDS(f)$area_means |> mutate(area = as.character(area))
  raw_cols <- intersect(names(alias),
                        setdiff(names(am), c("sim_id", "area", "y_true")))
  if (!length(raw_cols)) return(NULL)
  sims  <- sort(unique(am$sim_id)); S <- length(sims)
  areas <- sort(unique(am$area))
  ybar  <- am |> group_by(area) |> summarise(y = mean(y_true), .groups = "drop")
  y     <- ybar$y[match(areas, ybar$area)]
  ss    <- samplesize_df |> filter(dataset == ds)
  scope_vec <- if_else(areas %in% ss$area[ss$samplesize > 0], "insample", "oos")
  P_list <- lapply(raw_cols, function(m) {
    w <- am |> select(sim_id, area, all_of(m)) |>
      tidyr::pivot_wider(names_from = sim_id, values_from = all_of(m))
    M <- as.matrix(w[match(areas, w$area), as.character(sims), drop = FALSE])
    storage.mode(M) <- "double"
    M
  })
  names(P_list) <- unname(alias[raw_cols])
  point <- boot_metrics(P_list, y, scope_vec, seq_len(S))
  set.seed(BOOT_SEED)
  boots <- map(seq_len(B_BOOT), \(b) {
    boot_metrics(P_list, y, scope_vec, sample.int(S, S, replace = TRUE)) |>
      mutate(b = b)
  }) |> list_rbind()
  list(point = point |> mutate(dataset = ds, S = S),
       boots = boots |> mutate(dataset = ds))
}

message("Bootstrap (B = ", B_BOOT, ") over the Monte Carlo samples ...")
boot_res <- map2(result_files, dataset_ids, boot_one) |> compact()
mc_point <- map(boot_res, "point") |> list_rbind()
mc_boots <- map(boot_res, "boots") |> list_rbind()

metric_cols <- c("median_rrmse", "mean_rrmse", "median_rb", "mean_rb")
mc_se <- mc_boots |>
  tidyr::pivot_longer(all_of(metric_cols), names_to = "metric", values_to = "value") |>
  group_by(dataset, canonical, scope, metric) |>
  summarise(se = sd(value), .groups = "drop") |>
  left_join(mc_point |>
              tidyr::pivot_longer(all_of(metric_cols), names_to = "metric",
                                  values_to = "estimate"),
            by = c("dataset", "canonical", "scope", "metric")) |>
  left_join(estimator_meta |> select(canonical, label), by = "canonical") |>
  select(dataset, canonical, label, scope, metric, estimate, se, S)
write.csv(mc_se, file.path(OUT_DIR, "mc_se.csv"), row.names = FALSE)

# -----------------------------------------------------------------------------
# 4  ICC and R2 per dataset (random-intercept LMM fitted to the population)
# -----------------------------------------------------------------------------
# R2 after Nakagawa & Schielzeth (2013): marginal = fixed effects only,
# conditional = fixed + random effects. One maximum-likelihood fit per
# population, no randomness involved.

fit_dataset_stats <- function(dir) {
  cfg <- jsonlite::fromJSON(file.path(dir, "settings.json"))
  pop <- read_parquet(file.path(dir, "data", "population.parquet"))

  # unlist(): an empty x_cols_cat ("[]") is parsed by fromJSON() as a list
  covs     <- as.character(unlist(cfg$covariates))
  cat_cols <- unique(c(as.character(unlist(cfg$x_cols_cat)), cfg$group_col))

  pop <- pop |>
    select(all_of(unique(c(cfg$y_col, covs, cfg$group_col)))) |>
    mutate(across(all_of(cat_cols), as.factor)) |>
    tidyr::drop_na()

  form <- stats::reformulate(c(covs, sprintf("(1 | %s)", cfg$group_col)),
                             response = cfg$y_col)
  fit <- suppressMessages(suppressWarnings(
    lme4::lmer(form, data = pop, REML = FALSE,
               control = lme4::lmerControl(optimizer = "bobyqa"))
  ))

  sigma2_u  <- as.numeric(lme4::VarCorr(fit)[[1]])
  sigma2_e  <- sigma(fit)^2
  var_fixed <- stats::var(stats::predict(fit, re.form = NA))
  total     <- var_fixed + sigma2_u + sigma2_e

  tibble::tibble(
    dataset = ds_id(dir),
    icc     = sigma2_u / (sigma2_u + sigma2_e),
    r2_marg = var_fixed / total,
    r2_cond = (var_fixed + sigma2_u) / total
  )
}

message("LMM fit (ICC / R2) for: ", paste(ds_lab(dataset_ids), collapse = ", "))
model_stats <- map(dataset_dirs, fit_dataset_stats) |> list_rbind()
write.csv(model_stats, file.path(OUT_DIR, "dataset_icc_r2.csv"), row.names = FALSE)

# -----------------------------------------------------------------------------
# 5  Ratio ID / EM per dataset with bootstrap intervals (Fig. 3)
# -----------------------------------------------------------------------------
# Ratio > 1: the EM variant is better than the ID variant of the same family.
# Computed from the dataset-level statistic, e.g.
# mean_rrmse(RF-ID) / mean_rrmse(MERF).

ratio_pairs <- tibble::tribble(
  ~pair,      ~num,             ~den,          ~pair_label,
  "rf",       "rf_group",       "merf",        "RF-ID / MERF",
  "catboost", "catboost_group", "catboost_em", "CatBoost-ID / CatBoost-EM",
  "tabpfn",   "tabpfn_group",   "tabpfn_em",   "TabPFN-ID / TabPFN-EM"
)

ratio_cols <- c("mean_rrmse", "median_rrmse", "mean_cv", "median_cv")

ratio_df <- pmap(ratio_pairs, function(pair, num, den, pair_label) {
  num_df <- dataset_stats |> filter(canonical == num) |>
    select(scope, dataset, all_of(ratio_cols))
  den_df <- dataset_stats |> filter(canonical == den) |>
    select(scope, dataset, all_of(ratio_cols))

  joined <- inner_join(num_df, den_df, by = c("scope", "dataset"),
                       suffix = c("_num", "_den"))
  out <- joined |> select(scope, dataset)
  for (cc in ratio_cols) {
    out[[cc]] <- joined[[paste0(cc, "_num")]] / joined[[paste0(cc, "_den")]]
  }
  out |> mutate(pair_label = pair_label)
}) |>
  list_rbind() |>
  left_join(model_stats, by = "dataset") |>
  mutate(pair_label = factor(pair_label, levels = ratio_pairs$pair_label),
         ds_short   = ds_lab(dataset))

# 95% percentile intervals of the ID/EM ratios from the paired bootstrap
# (section 3b); RRMSE only, CV is not part of the bootstrap.
ratio_ci <- pmap(ratio_pairs, function(pair, num, den, pair_label) {
  nb <- mc_boots |> filter(canonical == num) |>
    select(dataset, scope, b, num_med = median_rrmse, num_mean = mean_rrmse)
  db <- mc_boots |> filter(canonical == den) |>
    select(dataset, scope, b, den_med = median_rrmse, den_mean = mean_rrmse)
  inner_join(nb, db, by = c("dataset", "scope", "b")) |>
    group_by(dataset, scope) |>
    summarise(
      median_rrmse_lo = unname(quantile(num_med  / den_med,  0.025)),
      median_rrmse_hi = unname(quantile(num_med  / den_med,  0.975)),
      mean_rrmse_lo   = unname(quantile(num_mean / den_mean, 0.025)),
      mean_rrmse_hi   = unname(quantile(num_mean / den_mean, 0.975)),
      .groups = "drop") |>
    mutate(pair_label = pair_label)
}) |>
  list_rbind() |>
  mutate(pair_label = factor(pair_label, levels = ratio_pairs$pair_label))

ratio_df <- ratio_df |>
  left_join(ratio_ci, by = c("scope", "dataset", "pair_label")) |>
  mutate(em_better_ci = median_rrmse_lo > 1, id_better_ci = median_rrmse_hi < 1)

write.csv(ratio_df, file.path(OUT_DIR, "ratio_stats.csv"), row.names = FALSE)

message("Done. Tables written to: ", normalizePath(OUT_DIR, winslash = "/"))
