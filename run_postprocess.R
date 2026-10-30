# Merge the estimator outputs of one or more populations into
# datasets/<dataset>/merged/results.rds (area means per Monte Carlo sample).
# Requires: datasets/<dataset>/results/*.parquet from run_model.R and the
#           TabPFN scripts. The aggregation scripts in aggregated_results/
#           read results.rds.
#
#   Rscript run_postprocess.R <dataset> [<dataset> ...]
args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("usage: Rscript run_postprocess.R <dataset> [...]")
root <- getwd()
for (dataset in args) {
  t0 <- Sys.time()
  cat(sprintf("\n===== %s  start %s =====\n", dataset, format(t0)))
  rm(list = setdiff(ls(), c("args", "dataset", "root", "t0")))
  setwd(root)
  source("pipeline/00_header.R")
  source(file.path("datasets", dataset, "settings.R"))
  source("pipeline/03_merge_results.R")
  cat(sprintf("===== %s  done, %.1f min =====\n", dataset,
              as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
