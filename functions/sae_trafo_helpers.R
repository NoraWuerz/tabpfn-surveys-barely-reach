# Helpers for the transformed nested error regression (models/lmm_logshift.R).
# Requires: nothing; sourced by the model script.

# Align the levels of the categorical covariates between sample and population.
#
# With the small sampling design a category level can be absent from a draw.
# saeTrafo::NER_Trafo fits nlme::lme on the sample and builds the population
# design matrix from the same model: a level that exists as a factor level but
# has no row gives an all-zero column ("Singularity in backsolve"), a level
# that occurs only in the population fails in model.matrix ("has new levels").
#
# The convention is the one of models/lmm.R: the effect of a level unobserved
# in the sample is set to zero. There this happens through the aliased
# coefficient; here the level is recoded in the population to the reference
# level (the first level observed in the sample), which is numerically the
# same because the reference level carries the dummy coefficient 0. Only the
# units of the missing level are affected.
align_cat_levels <- function(train, pop, cat_cols) {
  for (col in cat_cols) {
    present <- levels(droplevels(factor(train[[col]])))
    train[[col]] <- factor(as.character(train[[col]]), levels = present)
    p <- as.character(pop[[col]])
    p[!(p %in% present)] <- present[1]
    pop[[col]] <- factor(p, levels = present)
  }
  list(train = train, pop = pop)
}

# Expand the factors into numeric 0/1 dummies for saeTrafo::NER_Trafo.
#
# NER_Trafo with unit-level pop_data (framework_NER) allocates pop_mean.mat
# with length(mod_vars) + 1 columns -- one per VARIABLE of the formula -- but
# fills it from model.matrix(), which has one column per DUMMY. A factor with
# more than two levels therefore fails ("number of items to replace is not a
# multiple of replacement length"); a binary factor passes only because it
# yields exactly one dummy. With the dummies written out beforehand (treatment
# coding, reference = first level observed in the sample) every formula
# variable is exactly one column, and the model is identical to the factor
# model.
#
# The dummies are named d01, d02, ... deliberately short: saeTrafo deparses
# the right-hand side with width.cutoff = 500 and keeps only the first line;
# with 65 dummies (12_ces2024_policy) descriptive names would exceed that.
# The mapping dummy -> variable/level is returned as $dummy_map.
dummy_code <- function(train, pop, cat_cols, num_cols, y_col) {
  al <- align_cat_levels(train, pop, cat_cols)
  train <- al$train; pop <- al$pop
  map <- data.frame(dummy = character(0), variable = character(0), level = character(0))
  for (col in cat_cols) {
    for (lv in levels(train[[col]])[-1]) {
      nm <- sprintf("d%02d", nrow(map) + 1)
      train[[nm]] <- as.numeric(train[[col]] == lv)
      pop[[nm]]   <- as.numeric(pop[[col]] == lv)
      map[nrow(map) + 1, ] <- c(nm, col, lv)
    }
  }
  fixed <- reformulate(c(num_cols, map$dummy), response = y_col)
  if (length(deparse(fixed[[3]], width.cutoff = 500)) > 1)
    stop("formula longer than 500 characters -- saeTrafo would truncate it")
  list(train = train, pop = pop, fixed = fixed, dummy_map = map)
}

# Broadcast the area means (Domain/Mean) to the population units.
# Output contract: sim_id, unit_id, area, y_true, pred; areas without an
# estimate get NA.
area_means_to_units <- function(ind, sim_id, pop) {
  pred <- ind$Mean[match(as.character(pop[[group_col]]), as.character(ind$Domain))]
  tibble(sim_id,
         unit_id = pop[[unit_id]],
         area    = as.character(pop[[group_col]]),
         y_true  = pop[[y_col]],
         pred    = as.numeric(pred))
}
