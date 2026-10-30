# Population 09_pisa_esp_math: mathematics score (math, PV1MATH) of students in Spain by region
# (19 autonomous communities); source: PISA 2022 student questionnaire file (OECD).
# Definitions used by every pipeline and model script; source this file first.

dataset_dir <- "datasets/09_pisa_esp_math"
n_sim       <- 50
seed        <- 920922

y_col     <- "math"
group_col <- "region"
unit_id   <- "idU"

covariates_num <- c("escs", "age")
covariates_cat <- c("sex", "immig", "grade_rep", "hisced")
covariates     <- c(covariates_num, covariates_cat)

formula_lmm      <- math ~ escs + age + sex + immig + grade_rep + hisced + (1 | region)
formula_ml_group <- math ~ escs + age + sex + immig + grade_rep + hisced + region
formula_ml       <- math ~ escs + age + sex + immig + grade_rep + hisced


# Sample generation (run once; writes data/population.parquet and data/samples.parquet via pipeline/01_data.R)
# oos_share <- 0.20
# rate_lo   <- 0.01
# rate_hi   <- 0.03
# n_min     <- 3
#
# pop <- read_parquet(file.path("datasets", "09_pisa_esp_math", "data", "pisa2022_esp_math.parquet")) |>
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
# # then source pipeline/01_data.R -> writes to datasets/09_pisa_esp_math/data/

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