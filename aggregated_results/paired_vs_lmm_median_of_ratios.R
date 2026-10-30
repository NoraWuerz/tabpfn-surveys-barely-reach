# paired_vs_lmm_median_of_ratios.R
# Paired comparison of every estimator against the LMM: per area i,
# ratio_i = RRMSE_i(est) / RRMSE_i(lmm); point estimate = median_i(ratio_i),
# 95% percentile interval from a paired bootstrap over the Monte Carlo samples.
# Inputs:  datasets/<id>/merged/results.rds, settings.json, data/samples.parquet
# Output:  aggregated_results/tables/mc_paired_vs_ref_medratio.csv
# Run from the repository root.
suppressMessages({ library(dplyr); library(purrr); library(tidyr); library(jsonlite) })

ROOT    <- "."
OUT_DIR <- file.path(ROOT, "aggregated_results/tables")
B_BOOT  <- 500
BOOT_SEED <- 20260918

# populations whose merged/results.rds is present (README, step 4)
dataset_dirs <- list.dirs("datasets", recursive = FALSE)
dataset_ids  <- basename(dataset_dirs)[file.exists(file.path(dataset_dirs, "merged", "results.rds"))]
if (!length(dataset_ids)) stop("No datasets/<id>/merged/results.rds found (README, step 4).")
message("Populations with merged/results.rds: ", paste(dataset_ids, collapse = ", "))

# canonical estimator IDs -> raw column names in results.rds
alias <- c(direct = "direct", lmm = "lmm",
           rf = "rf", catboost = "catboost", tabpfn = "tabpfn",
           rf_group = "rf_id", catboost_group = "catboost_id",
           tabpfn_group = "tabpfn_id",
           merf = "merf", catboost_em = "catboost_em",
           tabpfn_em = "tabpfn_em")
alias <- setNames(names(alias), unname(alias))  # raw name -> canonical

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

  # median of per-area ratios est/lmm for one set of sample indices
  med_ratio <- function(idx) {
    rrmse <- lapply(P, function(M) {
      d <- M[, idx, drop = FALSE] - y
      100 * sqrt(rowMeans(d^2)) / y
    })
    ref <- rrmse[["lmm"]]
    out <- list()
    for (m in setdiff(names(rrmse), "lmm")) {
      r <- rrmse[[m]] / ref
      for (s in c("insample", "oos")) {
        ok <- scope_vec == s & is.finite(r) & ref > 0
        if (sum(ok) < 3) next
        out[[paste(m, s)]] <- tibble::tibble(canonical = m, scope = s,
                                             med_ratio = median(r[ok]))
      }
    }
    list_rbind(out)
  }

  point <- med_ratio(seq_len(S)) |> rename(ratio = med_ratio)
  set.seed(BOOT_SEED)
  boots <- map(seq_len(B_BOOT),
               \(b) med_ratio(sample.int(S, S, replace = TRUE))) |> list_rbind()
  ci <- boots |> group_by(canonical, scope) |>
    summarise(ratio_lo = unname(quantile(med_ratio, 0.025)),
              ratio_hi = unname(quantile(med_ratio, 0.975)),
              se_log   = sd(log(med_ratio)), .groups = "drop")
  point |> left_join(ci, by = c("canonical", "scope")) |>
    mutate(dataset = ds, significant = ratio_lo > 1 | ratio_hi < 1)
}

message("Median-of-ratios bootstrap (B = ", B_BOOT, ") ...")
res <- map(dataset_ids, \(ds) { message("  ", ds); one_dataset(ds) }) |> list_rbind()
# the direct estimator is not defined for out-of-sample areas
res <- res |> filter(!(canonical == "direct" & scope == "oos"))
write.csv(res, file.path(OUT_DIR, "mc_paired_vs_ref_medratio.csv"), row.names = FALSE)
message("written: ", file.path(OUT_DIR, "mc_paired_vs_ref_medratio.csv"))
