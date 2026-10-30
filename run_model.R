# Run one or more R estimators for one population.
#
#   Rscript run_model.R <dataset> <model> [<model> ...]
#   e.g.  Rscript run_model.R 03_pums_rent lmm rf catboost_em
#
# <model> is the file name in models/ without extension. Each model script
# writes datasets/<dataset>/results/<name>.parquet with one row per
# population unit and Monte Carlo sample (sim_id, unit_id, area, y_true, pred).
# The TabPFN variants are run with Python / R as described in README.md.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) stop("usage: Rscript run_model.R <dataset> <model> [...]")
dataset <- args[1]; models <- args[-1]
root <- getwd()
for (m in models) {
  t0 <- Sys.time()
  cat(sprintf("\n===== %s / %s  start %s =====\n", dataset, m, format(t0)))
  rm(list = setdiff(ls(), c("args", "dataset", "models", "m", "root", "t0")))
  setwd(root)
  source("pipeline/00_header.R")
  source(file.path("datasets", dataset, "settings.R"))
  source("pipeline/02_load_data.R")
  source(file.path("models", paste0(m, ".R")))
  cat(sprintf("===== %s / %s  done, %.1f min =====\n", dataset, m,
              as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
