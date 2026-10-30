# Population 05_evs62: household net income (EAH150) by region (federal state x municipality size class);
# source: EVS 1962/63 household Public Use File (Research Data Centres of the German statistical offices).
# The population excludes the five households with a negative net income (see the
# filter in the sample-generation block): 32,489 -> 32,484 households.
# Definitions used by every pipeline and model script; source this file first.

dataset_dir <- "datasets/05_evs62"
n_sim       <- 50
seed        <- 196263

y_col     <- "EAH150"   # EAH150: household net income
group_col <- "region"   # federal state x municipality size class
unit_id   <- "idU"

covariates_num <- c("EAH010", "EAH012", "EAH019", "EAH030")
covariates_cat <- c("EAH005", "EAH009", "EAH020", "EAH024")
covariates     <- c(covariates_num, covariates_cat)

formula_lmm      <- EAH150 ~ EAH010 + EAH012 + EAH019 + EAH030 + EAH005 + EAH009 + EAH020 + EAH024 + (1 | region)
formula_ml_group <- EAH150 ~ EAH010 + EAH012 + EAH019 + EAH030 + EAH005 + EAH009 + EAH020 + EAH024 + region
formula_ml       <- EAH150 ~ EAH010 + EAH012 + EAH019 + EAH030 + EAH005 + EAH009 + EAH020 + EAH024


# Sample generation (run once; writes data/population.parquet and data/samples.parquet via pipeline/01_data.R)
# oos_share <- 0.20
# rate_lo   <- 0.01
# rate_hi   <- 0.03
# n_min     <- 3
#
# pop <- read_parquet(file.path("datasets", "05_evs62", "data", "evs62_income.parquet")) |>
#   # Drop the five households with a negative net income (-128,056 to -46 DM).
#   # The log and log-shift transformations of the competing estimators shift
#   # the target by |min(y)| + 1 whenever such a unit is sampled, which lets a
#   # single unit dominate the transformed scale; the population of the paper
#   # is therefore defined without them (32,484 households, one with EAH150 = 0).
#   filter(.data[[y_col]] >= 0) |>
#   mutate(
#     region = as.character(region),
#     across(all_of(covariates_cat), as.factor)
#   )
#
# areas <- sort(unique(pop[[group_col]]))
# Ni    <- table(pop[[group_col]])
#
# set.seed(seed)
# oos_areas <- sample(areas, round(oos_share * length(areas)))
# ins_areas <- setdiff(areas, oos_areas)
#
# # Lower bound n_min, but never draw more units than the area has --
# # otherwise sample() without replacement fails.
# rate <- runif(length(ins_areas), rate_lo, rate_hi)
# Nin  <- as.integer(Ni[ins_areas])
# ni   <- pmax(pmin(n_min, Nin), round(rate * Nin))
#
# samplesize <- setNames(rep(0L, length(areas)), areas)
# samplesize[ins_areas] <- as.integer(ni)
#
# # then source pipeline/01_data.R -> writes to datasets/05_evs62/data/

# Writes settings.json for the Python scripts (run once)
# jsonlite::write_json(
#   list(
#     y_col      = y_col,
#     group_col  = group_col,
#     unit_id    = unit_id,
#     x_cols_num = as.list(covariates_num),
#     x_cols_cat = as.list(covariates_cat),
#     covariates = covariates
#   ),
#   path       = file.path(dataset_dir, "settings.json"),
#   auto_unbox = TRUE
# )
