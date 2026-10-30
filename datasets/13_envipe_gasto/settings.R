# Population 13_envipe_gasto: log household expenditure on protection against crime (lgasto) by state (ent);
# source: ENVIPE 2024 public-use microdata (INEGI).
# Definitions used by every pipeline and model script; source this file first.

dataset_dir <- "datasets/13_envipe_gasto"
n_sim       <- 50
seed        <- 101023

y_col     <- "lgasto"
group_col <- "ent"
unit_id   <- "idU"

covariates_num <- c("edad", "tot")
covariates_cat <- c("sexo", "niv", "paren", "clase", "dom")
covariates     <- c(covariates_num, covariates_cat)

formula_lmm      <- lgasto ~ edad + tot + sexo + niv + paren + clase + dom + (1 | ent)
formula_ml_group <- lgasto ~ edad + tot + sexo + niv + paren + clase + dom + ent
formula_ml       <- lgasto ~ edad + tot + sexo + niv + paren + clase + dom


# Sample generation (run once; writes data/population.parquet and data/samples.parquet via pipeline/01_data.R)
# oos_share <- 0.20
# rate_lo   <- 0.01
# rate_hi   <- 0.03
# n_min     <- 3
#
# pop <- read_parquet(file.path("datasets", "13_envipe_gasto", "data", "population.parquet")) |>
#   mutate(
#     ent = as.character(ent),
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
# # then source pipeline/01_data.R -> writes to datasets/13_envipe_gasto/data/

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