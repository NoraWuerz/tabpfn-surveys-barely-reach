# TabPFN-EM: EM-style algorithm with TabPFN as base learner and
# lme4 for the area random effects.
# Requires: working directory = project root with the Python environment in
# .venv (created by `uv sync`); sourced by models/tabpfn_em.R.
# Writes: nothing (defines tabpfn_em_fit() and tabpfn_em_predict()).

# ── Python / reticulate setup (TabPFN) ────────────────────────────────────────
library(reticulate)
# An explicit path is required: use_virtualenv(".venv") would be read by
# reticulate as a named virtualenv under ~/.virtualenvs.
use_virtualenv(file.path(getwd(), ".venv"), required = TRUE)


.tabpfn_py    <- import("tabpfn")
.tabpfn_const <- import("tabpfn.constants")

.make_tabpfn <- function(seed = NULL, device = "cuda", cat_idx = NULL) {
  seed_py <- if (!is.null(seed)) as.integer(seed) else NULL
  # TabPFN v3.5, as in models/tabpfn_naive.py and models/tabpfn_id.py; device = "cuda" or "cpu"
  .tabpfn_py$TabPFNRegressor$create_default_for_version(
    .tabpfn_const$ModelVersion$V3_5,
    device                       = device,
    random_state                 = seed_py,
    categorical_features_indices = cat_idx
  )
}

# Convert R data frame to a plain matrix for Python (factors → character)
.to_numpy <- function(df) {
  df |>
    dplyr::mutate(dplyr::across(where(is.factor), as.character))
}

# 0-based positions of the categorical columns, determined before the factors
# are converted to character. The data frame reaches TabPFN with object
# columns (no category dtype), so without this explicit declaration a
# digit-coded categorical covariate would be treated as numeric.
.cat_idx <- function(df) {
  is_cat <- vapply(df, function(col) is.factor(col) || is.character(col), logical(1))
  idx    <- which(is_cat) - 1L
  # as.list: reticulate would pass a single index (population with exactly one
  # categorical covariate) as a bare Python int, and TabPFN iterates over it
  # ("'int' object is not iterable").
  if (length(idx) == 0L) NULL else as.list(as.integer(idx))
}

# ── CV predictions (held-out) for TabPFN ──────────────────────────────────────
.get_cv_predictions_tabpfn <- function(X, y, nfold, device, seed = NULL) {
  X_mat <- .to_numpy(X)
  cat_i <- .cat_idx(X)
  n     <- nrow(X_mat)

  folds <- sample(rep(seq_len(nfold), length.out = n))
  preds <- numeric(n)

  for (k in seq_len(nfold)) {
    train_idx <- which(folds != k)
    test_idx  <- which(folds == k)

    reg <- .make_tabpfn(seed = seed, device = device, cat_idx = cat_i)
    reg$fit(X_mat[train_idx, , drop = FALSE], y[train_idx])
    preds[test_idx] <- as.numeric(reg$predict(X_mat[test_idx, , drop = FALSE]))
  }
  preds
}

# ── TabPFN-EM functions ─────────────────────────────────────────────────────────
tabpfn_em_fit <- function(train, y_col, x_cols, group_col,
                          max_iter, tol, cv_folds, device, seed = NULL) {
  
  y    <- train[[y_col]]
  area <- factor(train[[group_col]])
  D    <- nlevels(area)

  u_hat    <- setNames(rep(0, D), levels(area))
  gll_prev <- -Inf

  for (iter in seq_len(max_iter)) {
    y_star <- y - u_hat[as.character(area)]

    f_oob <- .get_cv_predictions_tabpfn(
      train[, x_cols, drop = FALSE], y_star,
      nfold = cv_folds, device = device, seed = seed
    )

    fit_df <- train |> dplyr::mutate(f_oob = f_oob, area_factor = area)

    lmm <- lme4::lmer(y ~ -1 + (1 | area_factor),
                      data = fit_df,
                      REML = FALSE,
                      offset = f_oob,
                      control = lme4::lmerControl(optimizer = "bobyqa"))
    
    re        <- lme4::ranef(lmm)$area_factor
    u_hat_new <- setNames(re[, 1], rownames(re))
    
    gll <- as.numeric(logLik(lmm))
    if (!is.infinite(gll_prev)) {
      rel_change <- abs(gll - gll_prev) / abs(gll_prev)
      if (rel_change < tol) {
        u_hat <- u_hat_new
        break
      }
    }

    u_hat    <- u_hat_new
    gll_prev <- gll
  }

  y_star_final <- y - u_hat[as.character(area)]

  # Final model trained on full data with converged y_star (analogous to CatBoost EM)
  final_reg <- .make_tabpfn(seed = seed, device = device, cat_idx = .cat_idx(train[, x_cols, drop = FALSE]))
  final_reg$fit(.to_numpy(train[, x_cols, drop = FALSE]), y_star_final)

  list(model      = final_reg,
       u_hat      = u_hat,
       x_cols     = x_cols,
       group_col  = group_col,
       sigma2_u   = as.numeric(lme4::VarCorr(lmm)$area_factor),
       sigma2     = sigma(lmm)^2,
       iterations = iter)
}

tabpfn_em_predict <- function(fit_obj, new_data) {
  f_hat     <- as.numeric(fit_obj$model$predict(.to_numpy(new_data[, fit_obj$x_cols, drop = FALSE])))
  u_contrib <- fit_obj$u_hat[as.character(new_data[[fit_obj$group_col]])]
  u_contrib[is.na(u_contrib)] <- 0
  as.numeric(f_hat + u_contrib)
}
