# Population 12_ces2024_policy: policy conservatism index (cons_idx) by state;
# source: CES 2024 common content (Harvard Dataverse).
# Definitions used by every pipeline and model script; source this file first.

dataset_dir <- "datasets/12_ces2024_policy"
n_sim       <- 50
seed        <- 101023

y_col     <- "cons_idx"
group_col <- "state"
unit_id   <- "idU"

covariates_num <- c("age")
covariates_cat <- c("gender4", "educ", "race", "hispanic", "marstat", "faminc", "employ", "religpew", "urbancity", "child18", "union", "ownhome", "newsint")
covariates     <- c(covariates_num, covariates_cat)

formula_lmm      <- cons_idx ~ age + gender4 + educ + race + hispanic + marstat + faminc + employ + religpew + urbancity + child18 + union + ownhome + newsint + (1 | state)
formula_ml_group <- cons_idx ~ age + gender4 + educ + race + hispanic + marstat + faminc + employ + religpew + urbancity + child18 + union + ownhome + newsint + state
formula_ml       <- cons_idx ~ age + gender4 + educ + race + hispanic + marstat + faminc + employ + religpew + urbancity + child18 + union + ownhome + newsint


# Sample generation (run once; writes data/population.parquet and data/samples.parquet via pipeline/01_data.R)
# oos_share <- 0.20
# rate_lo   <- 0.01
# rate_hi   <- 0.03
# n_min     <- 3
#
# pop <- read_parquet(file.path("datasets", "12_ces2024_policy", "data", "population.parquet")) |>
#   mutate(
#     state = as.character(state),
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
# # then source pipeline/01_data.R -> writes to datasets/12_ces2024_policy/data/

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