# Population 02_fdz_bee: crop yield per hectare (EF7) by federal state (EF2);
# source: BEE 2017 Public Use File (Research Data Centres of the German statistical offices).
# Definitions used by every pipeline and model script; source this file first.

dataset_dir <- "datasets/02_fdz_bee"
n_sim       <- 50
# seed chosen so that every level of the four categorical covariates occurs in all 50 draws
seed        <- 654261

y_col     <- "EF7"   # EF7: yield per hectare
group_col <- "EF2"   # EF2: federal state
unit_id   <- "unit_id"

covariates_num <- c("EF6")                        # EF6: plot size
covariates_cat <- c("EF4", "EF8", "EF11", "EF12")   # crop type, cultivation method, organic farming, tillage
covariates     <- c(covariates_num, covariates_cat)

formula_lmm      <- EF7 ~ EF6 + EF4 + EF8 + EF11 + EF12 + (1 | EF2)
formula_ml_group <- EF7 ~ EF6 + EF4 + EF8 + EF11 + EF12 + EF2
formula_ml       <- EF7 ~ EF6 + EF4 + EF8 + EF11 + EF12


# Sample generation (run once; writes data/population.parquet and data/samples.parquet via pipeline/01_data.R)
# oos_share <- 0.20
# rate_lo   <- 0.01
# rate_hi   <- 0.03
# n_min     <- 3
#
# pop <- read_parquet(file.path("datasets", "02_fdz_bee", "data", "BEE_PUF_2017.parquet")) |>
#   mutate(
#     EF2 = as.character(EF2),
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
# # then source pipeline/01_data.R -> writes to datasets/02_fdz_bee/data/

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
