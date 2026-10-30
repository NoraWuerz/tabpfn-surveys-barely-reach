# pairs_median_of_ratios.R
# Pairwise comparisons of estimator variants (ID vs EM, ID vs naive, EM vs
# naive per learner): per area i, ratio_i = RRMSE_i(num) / RRMSE_i(den);
# point = median_i(ratio_i), 95% interval from a paired bootstrap over samples.
# Inputs:  datasets/<id>/merged/results.rds, settings.json, data/samples.parquet
# Output:  aggregated_results/tables/ratio_pairs_medratio.csv
# Run from the repository root.
suppressMessages({ library(dplyr); library(purrr); library(tidyr); library(jsonlite) })

ROOT      <- "."
OUT_DIR   <- file.path(ROOT, "aggregated_results/tables")
B_BOOT    <- 500
BOOT_SEED <- 20260918

# populations whose merged/results.rds is present (README, step 4)
dataset_dirs <- list.dirs("datasets", recursive = FALSE)
dataset_ids  <- basename(dataset_dirs)[file.exists(file.path(dataset_dirs, "merged", "results.rds"))]
if (!length(dataset_ids)) stop("No datasets/<id>/merged/results.rds found (README, step 4).")
message("Populations with merged/results.rds: ", paste(dataset_ids, collapse = ", "))

alias <- c(direct = "direct", lmm = "lmm",
           rf = "rf", catboost = "catboost", tabpfn = "tabpfn",
           rf_id = "rf_group", catboost_id = "catboost_group",
           tabpfn_id = "tabpfn_group",
           `merf` = "merf", catboost_em = "catboost_em",
           tabpfn_em = "tabpfn_em")   # raw name -> canonical

pairs <- tibble::tribble(
  ~pair,              ~num,             ~den,
  "rf_id_em",         "rf_group",       "merf",
  "catboost_id_em",   "catboost_group", "catboost_em",
  "tabpfn_id_em",     "tabpfn_group",   "tabpfn_em",
  "rf_id_naive",      "rf_group",       "rf",
  "catboost_id_naive","catboost_group", "catboost",
  "tabpfn_id_naive",  "tabpfn_group",   "tabpfn",
  "rf_em_naive",      "merf",           "rf",
  "catboost_em_naive","catboost_em",    "catboost",
  "tabpfn_em_naive",  "tabpfn_em",      "tabpfn"
)

one_dataset <- function(ds) {
  dir <- file.path(ROOT, "datasets", ds)
  am  <- readRDS(file.path(dir, "merged", "results.rds"))$area_means |>
    mutate(area = as.character(area))
  raw_cols <- intersect(names(alias), names(am))
  sims  <- sort(unique(am$sim_id)); S <- length(sims)
  areas <- sort(unique(am$area))
  ybar  <- am |> group_by(area) |> summarise(y = mean(y_true), .groups = "drop")
  y     <- ybar$y[match(areas, ybar$area)]
  cfg   <- fromJSON(file.path(dir, "settings.json"))
  ss    <- arrow::read_parquet(file.path(dir, "data/samples.parquet"),
                               col_select = c("sim_id", cfg$group_col)) |>
    filter(sim_id == 1) |> count(.data[[cfg$group_col]]) |>
    mutate(area = as.character(.data[[cfg$group_col]]))
  scope_vec <- if_else(areas %in% ss$area, "insample", "oos")

  P <- lapply(raw_cols, function(m) {
    w <- am |> select(sim_id, area, all_of(m)) |>
      pivot_wider(names_from = sim_id, values_from = all_of(m))
    M <- as.matrix(w[match(areas, w$area), as.character(sims), drop = FALSE])
    storage.mode(M) <- "double"; M
  })
  names(P) <- unname(alias[raw_cols])

  med_ratios <- function(idx) {
    rrmse <- lapply(P, function(M) {
      d <- M[, idx, drop = FALSE] - y
      100 * sqrt(rowMeans(d^2)) / y
    })
    out <- list()
    for (k in seq_len(nrow(pairs))) {
      nm <- pairs$num[k]; dn <- pairs$den[k]
      if (!nm %in% names(rrmse) || !dn %in% names(rrmse)) next
      r <- rrmse[[nm]] / rrmse[[dn]]
      for (sc in c("insample", "oos")) {
        ok <- scope_vec == sc & is.finite(r) & rrmse[[dn]] > 0
        if (sum(ok) < 3) next
        out[[paste(pairs$pair[k], sc)]] <-
          tibble::tibble(pair = pairs$pair[k], scope = sc,
                         med_ratio = median(r[ok]))
      }
    }
    list_rbind(out)
  }

  point <- med_ratios(seq_len(S)) |> rename(ratio = med_ratio)
  set.seed(BOOT_SEED)
  boots <- map(seq_len(B_BOOT),
               \(b) med_ratios(sample.int(S, S, replace = TRUE))) |> list_rbind()
  ci <- boots |> group_by(pair, scope) |>
    summarise(ratio_lo = unname(quantile(med_ratio, 0.025)),
              ratio_hi = unname(quantile(med_ratio, 0.975)), .groups = "drop")
  point |> left_join(ci, by = c("pair", "scope")) |>
    mutate(dataset = ds,
           em_better_ci = ratio_lo > 1,   # read for num = ID, den = EM
           id_better_ci = ratio_hi < 1)
}

message("Median-of-ratios bootstrap for ", nrow(pairs), " pairs (B = ", B_BOOT, ") ...")
res <- map(dataset_ids, \(ds) { message("  ", ds); one_dataset(ds) }) |> list_rbind()
write.csv(res, file.path(OUT_DIR, "ratio_pairs_medratio.csv"), row.names = FALSE)
message("written: ", file.path(OUT_DIR, "ratio_pairs_medratio.csv"))
