# Population 07_DHS_peru_hemoglobin_children: altitude-adjusted haemoglobin (g/dl) of children
# aged 6-59 months by department; source: Peru Continuous DHS 2009, Children's Recode (The DHS Program).
# Definitions used by every pipeline and model script; source this file first.

dataset_dir <- "datasets/07_DHS_peru_hemoglobin_children"
n_sim       <- 50
seed        <- 470929

y_col     <- "hb"      # haemoglobin in g/dl, altitude-adjusted (hw56 / 10)
group_col <- "dept"    # 25 Peruvian departments (v024)
unit_id   <- "idU"

covariates_num <- c("agem")                              # child's age in months
covariates_cat <- c("csex", "urban", "wealth", "meduc")  # child's sex, urban/rural, wealth quintile, mother's education
covariates     <- c(covariates_num, covariates_cat)

formula_lmm      <- hb ~ agem + csex + urban + wealth + meduc + (1 | dept)
formula_ml_group <- hb ~ agem + csex + urban + wealth + meduc + dept
formula_ml       <- hb ~ agem + csex + urban + wealth + meduc


# Sample generation (run once; exactly the code that produced data/population.parquet and
# data/samples.parquet via pipeline/01_data.R; the raw KR file is not part of the repository)
# library(haven)
#
# # Raw KR file is outside the repository (DHS microdata, not redistributable)
# raw_kr <- "<path to the raw DHS file PEKR5IFL.DTA>"
#
# kr <- read_dta(raw_kr, col_select = c("v024", "v025", "v106", "v190", "b4", "hw1", "hw55", "hw56"))
#
# # Population: children aged 6-59 months with a valid haemoglobin measurement.
# #   hw55 == 0     measured (otherwise dead, absent, refused, ...)
# #   hw56 < 9990   valid value (>= 9990 are DHS special codes), in g/dl * 10
# #   2 <= hb <= 20 plausibility bounds; the altitude adjustment occasionally yields
# #                 impossible values (here: -1.7 and 21.5 g/dl)
# pop <- kr |>
#   transmute(
#     dept   = tolower(as.character(as_factor(v024))),
#     agem   = as.numeric(hw1),
#     csex   = factor(tolower(as.character(as_factor(b4))),    levels = c("male", "female")),
#     urban  = factor(tolower(as.character(as_factor(v025))),  levels = c("urban", "rural")),
#     wealth = factor(tolower(as.character(as_factor(v190))),  levels = c("poorest", "poorer", "middle", "richer", "richest")),
#     meduc  = factor(tolower(as.character(as_factor(v106))),  levels = c("no education", "primary", "secondary", "higher")),
#     measured = as.numeric(hw55) == 0,
#     hb_raw   = as.numeric(hw56)
#   ) |>
#   filter(measured, !is.na(agem), agem >= 6, agem <= 59, !is.na(hb_raw), hb_raw < 9990) |>
#   mutate(hb = hb_raw / 10) |>
#   filter(hb >= 2, hb <= 20) |>
#   transmute(idU = row_number(), dept, agem, csex, urban, wealth, meduc, hb)
#
# dir.create(file.path("datasets", "07_DHS_peru_hemoglobin_children", "data"), showWarnings = FALSE)
# arrow::write_parquet(pop, file.path("datasets", "07_DHS_peru_hemoglobin_children", "data", "dhs_peru_hb_children.parquet"))
#
# # Out-of-sample areas and sample sizes per area
# oos_share <- 0.20
# rate_lo   <- 0.01
# rate_hi   <- 0.03
# n_min     <- 3
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
# # then source pipeline/01_data.R -> writes to datasets/07_DHS_peru_hemoglobin_children/data/

# Writes settings.json for the Python scripts (run once)
# jsonlite::write_json(
#   list(y_col = y_col, group_col = group_col, unit_id = unit_id,
#        x_cols_num = as.list(covariates_num), x_cols_cat = as.list(covariates_cat),
#        covariates = covariates),
#   path = file.path(dataset_dir, "settings.json"), auto_unbox = TRUE)
