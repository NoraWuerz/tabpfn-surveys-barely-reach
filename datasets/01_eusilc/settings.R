# Population 01_eusilc: equivalised household income (eqIncome) by district;
# source: synthetic EU-SILC Austria population (R package emdi, eusilcA_pop).
# Definitions used by every pipeline and model script; source this file first.

dataset_dir <- "datasets/01_eusilc"
n_sim       <- 50
seed        <- 123

y_col     <- "eqIncome"
group_col <- "district"
unit_id   <- "idU"

covariates_num <- c("eqsize", "cash", "rent", "tax_adj")
covariates_cat <- c("gender")
covariates     <- c(covariates_num, covariates_cat)

formula_lmm      <- eqIncome ~ eqsize + cash + rent + tax_adj + gender + (1 | district)
formula_ml_group <- eqIncome ~ eqsize + cash + rent + tax_adj + gender + district
formula_ml       <- eqIncome ~ eqsize + cash + rent + tax_adj + gender


# Sample generation (run once; writes data/population.parquet and data/samples.parquet via pipeline/01_data.R)
# oos_share <- 0.20
# rate_lo   <- 0.01
# rate_hi   <- 0.03
# n_min     <- 3
#
# pop <- read_parquet(file.path("datasets", "01_eusilc", "data", "population.parquet")) |>
#   mutate(
#     district = as.character(district),
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
# # then source pipeline/01_data.R -> writes to datasets/01_eusilc/data/

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
