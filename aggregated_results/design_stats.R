# design_stats.R
# Design statistics of the fixed populations and stored sample draws, one row
# per population (source of SI Table S1): number of areas D, number of areas
# without any sampled unit (OOS), population size N, sample size n per Monte
# Carlo sample, mean / median / range of the per-area sample sizes n_i over the
# sampled areas, range of the per-area population sizes N_i, sampling rate
# (quoted in Materials and Methods) and the ICC of the target (from
# aggregated_results/tables/dataset_icc_r2.csv).
# Inputs:  datasets/<id>/settings.json, data/population.parquet, data/samples.parquet
#          (populations whose unit-level files are present, see README), and
#          aggregated_results/tables/dataset_icc_r2.csv
# Output:  aggregated_results/tables/design_stats.csv
# Run from the repository root:  Rscript aggregated_results/design_stats.R
suppressMessages({ library(dplyr); library(purrr); library(arrow); library(jsonlite) })

AGG <- "aggregated_results/tables"
OUT <- file.path(AGG, "design_stats.csv")

dataset_dirs <- list.dirs("datasets", recursive = FALSE)
has_data <- file.exists(file.path(dataset_dirs, "data", "population.parquet")) &
            file.exists(file.path(dataset_dirs, "data", "samples.parquet"))
dataset_dirs <- dataset_dirs[has_data]
if (!length(dataset_dirs)) stop("No datasets/<id>/data/{population,samples}.parquet found.")
message("Populations with unit-level files: ", paste(basename(dataset_dirs), collapse = ", "))

icc <- read.csv(file.path(AGG, "dataset_icc_r2.csv")) |> select(dataset, icc)


design_one <- function(dir) {
  ds  <- basename(dir)
  cfg <- fromJSON(file.path(dir, "settings.json"))
  g <- cfg$group_col
  pop <- read_parquet(file.path(dir, "data", "population.parquet"), col_select = g)
  smp <- read_parquet(file.path(dir, "data", "samples.parquet"), col_select = c("sim_id", g))
  pop[[g]] <- as.character(pop[[g]]); smp[[g]] <- as.character(smp[[g]])

  Ni <- pop |> count(.data[[g]], name = "N_i")
  # per-area sample sizes in every Monte Carlo sample; the design fixes them
  ni_all <- smp |> count(sim_id, .data[[g]], name = "n_i")
  ni_fixed <- ni_all |> group_by(.data[[g]]) |>
    summarise(fixed = n_distinct(n_i) == 1 & n() == n_distinct(smp$sim_id), .groups = "drop")
  n_per_sim <- smp |> count(sim_id) |> pull(n)
  ni <- ni_all |> filter(sim_id == 1)
  sampled_areas <- unique(smp[[g]])

  tibble(
    dataset   = ds,
    N         = nrow(pop),
    D         = nrow(Ni),
    D_oos     = sum(!Ni[[g]] %in% sampled_areas),
    n         = n_per_sim[1],
    n_fixed   = n_distinct(n_per_sim) == 1,
    ni_fixed  = all(ni_fixed$fixed),
    ni_min    = min(ni$n_i),
    ni_mean   = round(mean(ni$n_i), 1),
    ni_median = median(ni$n_i),
    ni_max    = max(ni$n_i),
    Ni_min    = min(Ni$N_i),
    Ni_max    = max(Ni$N_i),
    rate_pct  = round(100 * n_per_sim[1] / nrow(pop), 2)
  )
}

stats <- map(dataset_dirs, design_one) |> list_rbind() |>
  left_join(icc, by = "dataset") |>
  arrange(desc(icc))
if (!all(stats$n_fixed) || !all(stats$ni_fixed))
  warning("Per-area sample sizes are not constant across the Monte Carlo samples: ",
          paste(stats$dataset[!stats$n_fixed | !stats$ni_fixed], collapse = ", "))

write.csv(stats |> select(-n_fixed, -ni_fixed), OUT, row.names = FALSE)   # the two flags are consistency checks only
print(as.data.frame(stats |> select(-n_fixed, -ni_fixed)), row.names = FALSE)
cat("written:", OUT, "\n")
