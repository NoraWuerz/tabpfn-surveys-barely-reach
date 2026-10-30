# shrinkage_lmm_effects.R
# -----------------------------------------------------------------------------
# LMM counterpart of the implicit-shrinkage analysis of the -ID learners
# (functions/shrinkage_effects.R). The LMM is refitted on every Monte Carlo
# sample as in models/lmm.R (lme4, REML, bobyqa); for each in-sample area i
# and sample s:
#
#   raw_is     = mean_s(y) - mean_s(X beta)   sample mean of y minus sample mean
#                                             of the fixed part (unshrunken
#                                             effect; analogue of "y minus
#                                             naive prediction")
#   implied_is = u_hat_i                      EBLUP of the random intercept =
#                                             mean over the population units of
#                                             (pred_lmm - X beta), constant
#                                             within the area
#
# The slope of implied on raw is the LMM's shrinkage factor,
# gamma_i = n_i sigma_u^2 / (n_i sigma_u^2 + sigma_e^2), averaged over the
# areas of an n_i group. It is drawn as the grey reference line in every
# learner panel of Figs. 4 and S5-S7 and is the x-axis of Fig. S8.
#
# Factor levels and aliased fixed-effect columns are treated as in
# models/lmm.R (levels aligned to the population; missing coefficients = 0).
# -----------------------------------------------------------------------------
lmm_shrinkage_effects <- function(dsdir, settings_file) {
  e <- new.env()
  sys.source(settings_file, envir = e)   # y_col, group_col, unit_id, covariates_cat, formula_lmm
  pop <- arrow::read_parquet(file.path(dsdir, "data/population.parquet"))
  smp <- arrow::read_parquet(file.path(dsdir, "data/samples.parquet"))
  for (col in e$covariates_cat) {
    lv <- if (is.factor(pop[[col]])) levels(pop[[col]]) else sort(unique(pop[[col]]))
    smp[[col]] <- factor(smp[[col]], levels = lv)
  }
  fixed_formula <- lme4::nobars(e$formula_lmm)

  one_sim <- function(s) {
    train <- smp[smp$sim_id == s, ]
    m <- lme4::lmer(e$formula_lmm, data = train, REML = TRUE,
                    control = lme4::lmerControl(optimizer = "bobyqa"))
    mm    <- stats::model.matrix(fixed_formula, data = train)
    betas <- lme4::fixef(m)
    keep  <- intersect(colnames(mm), names(betas))
    fixed <- as.numeric(mm[, keep, drop = FALSE] %*% betas[keep])
    re    <- lme4::ranef(m)[[e$group_col]]
    u_hat <- setNames(re[, 1], rownames(re))
    area  <- as.character(train[[e$group_col]])
    d <- data.frame(area = area, y = train[[e$y_col]], fixed = fixed)
    agg <- stats::aggregate(cbind(y, fixed) ~ area, data = d, FUN = mean)
    n_i <- as.integer(table(area)[agg$area])
    data.frame(sim_id = s, area = agg$area, n_i = n_i,
               raw = agg$y - agg$fixed, implied = unname(u_hat[agg$area]),
               stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, lapply(sort(unique(smp$sim_id)), one_sim))
  tibble::as_tibble(out)
}

# Slope and intercept of the LMM line per n_i group (the column ni_grp must be
# set beforehand, as for the learners).
lmm_shrinkage_slopes <- function(lmm_eff) {
  lmm_eff |>
    dplyr::group_by(ni_grp) |>
    dplyr::summarise(intercept = stats::coef(stats::lm(implied ~ raw))[1],
                     slope     = stats::coef(stats::lm(implied ~ raw))[2],
                     r2        = summary(stats::lm(implied ~ raw))$r.squared,
                     n_pairs   = dplyr::n(), .groups = "drop")
}
