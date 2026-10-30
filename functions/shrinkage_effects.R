# shrinkage_effects.R
# Raw and implied area effects of the -ID learners for the implicit-shrinkage
# analysis (Figs. 4, S5-S8). For each in-sample area i and Monte Carlo sample s:
#   raw effect     x_is = mean(y, sampled units) - mean(naive prediction, sampled units)
#                        (the unshrunken area-effect estimate a fixed-effects
#                         estimator would use)
#   implied effect y_is = mean over POPULATION units of (pred_ID - pred_naive)
#                        (what the -ID variant actually adds for the area)
# A slope < 1 of y on x means the learner shrinks the raw effect; mixed-model
# theory predicts the slope to grow with n_i. The LMM counterpart is in
# shrinkage_lmm_effects.R.
# Requires: arrow, dplyr, jsonlite. Used by paper_figures/final_PNAS_plots.R
# and aggregated_results/shrinkage_calibration.R.

shrinkage_pairs <- list(
  "TabPFN-ID"   = c(id = "tabpfn_id",   naive = "tabpfn"),
  "RF-ID"       = c(id = "rf_id",       naive = "rf"),
  "CatBoost-ID" = c(id = "catboost_id", naive = "catboost")
)
shrinkage_id_cols <- c("TabPFN-ID" = "#60A1AA", "RF-ID" = "#CC7052", "CatBoost-ID" = "#AE6987")

# per-area sample-size groups used throughout
shrinkage_groups <- function(n_i) {
  cut(n_i, breaks = c(0, 5, 14, Inf), labels = c("n_i <= 5", "n_i 6-14", "n_i >= 15"))
}

# TRUE if the unit-level files needed for the analysis are present
shrinkage_has_data <- function(dsdir) {
  all(file.exists(c(file.path(dsdir, "data/samples.parquet"),
                    file.path(dsdir, "data/population.parquet"),
                    file.path(dsdir, "results", paste0(unlist(shrinkage_pairs), ".parquet")))))
}

# one row per Monte Carlo sample, in-sample area and learner:
# sim_id, area, raw, n_i, implied, learner (factor in shrinkage_pairs order)
shrinkage_effects <- function(dsdir) {
  set <- jsonlite::fromJSON(file.path(dsdir, "settings.json"))
  s   <- arrow::read_parquet(file.path(dsdir, "data/samples.parquet"))
  smp <- dplyr::tibble(sim_id = s$sim_id, unit_id = s[[set$unit_id]],
                       area = as.character(s[[set$group_col]]), y = s[[set$y_col]])
  rd <- function(f) arrow::read_parquet(file.path(dsdir, "results", paste0(f, ".parquet")))
  eff_all <- list()
  for (nm in names(shrinkage_pairs)) {
    idp <- rd(shrinkage_pairs[[nm]]["id"])    |> dplyr::select(sim_id, unit_id, area, pred_id = pred)
    nvp <- rd(shrinkage_pairs[[nm]]["naive"]) |> dplyr::select(sim_id, unit_id, pred_nv = pred)
    imp <- idp |> dplyr::inner_join(nvp, by = c("sim_id", "unit_id")) |>
      dplyr::group_by(sim_id, area) |>
      dplyr::summarise(implied = mean(pred_id - pred_nv), .groups = "drop")
    raw <- smp |> dplyr::inner_join(nvp, by = c("sim_id", "unit_id")) |>
      dplyr::group_by(sim_id, area) |>
      dplyr::summarise(raw = mean(y) - mean(pred_nv), n_i = dplyr::n(), .groups = "drop")
    eff_all[[nm]] <- dplyr::inner_join(raw, imp, by = c("sim_id", "area")) |>
      dplyr::mutate(learner = nm)
    rm(idp, nvp); gc(verbose = FALSE)
  }
  dplyr::bind_rows(eff_all) |>
    dplyr::mutate(learner = factor(learner, levels = names(shrinkage_pairs)))
}

# least-squares fit of implied on raw within a group
shrinkage_fit_stats <- function(d) {
  m <- stats::lm(implied ~ raw, data = d)
  dplyr::tibble(slope = unname(stats::coef(m)[2]), intercept = unname(stats::coef(m)[1]),
                r2 = summary(m)$r.squared, resid_sd = stats::sd(stats::resid(m)),
                n_pairs = nrow(d))
}
