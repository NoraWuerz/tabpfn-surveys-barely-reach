# Linear mixed model (lme4, REML, bobyqa optimizer).
# Requires: pipeline/00_header.R, the dataset settings.R and
#   pipeline/02_load_data.R sourced beforehand.
# Output contract: one row per unit per sim_id with columns
#   sim_id, unit_id, area, y_true, pred
# Writes: {dataset_dir}/results/lmm.parquet

run_lmm <- function(sim_id, seed) {
  set.seed(seed)
  train         <- samples[samples$sim_id == sim_id, ]
  pop           <- population

  # Use the population's factor levels for categorical covariates: a small
  # sample need not contain every category.
  for (col in covariates_cat) {
    train[[col]] <- factor(train[[col]], levels = levels(pop[[col]]))
  }

  model <- lme4::lmer(formula_lmm, data = train, REML = TRUE,
                      control = lme4::lmerControl(optimizer = "bobyqa"))

  # Manual prediction instead of predict(newdata = pop, allow.new.levels = TRUE):
  # if a category is unobserved in the sample, lme4 drops its fixed-effect
  # column and predict() fails. Fixed and random parts are therefore computed
  # separately; dropped columns and unsampled areas contribute 0.
  mm_pop     <- model.matrix(lme4::nobars(formula_lmm), data = pop)
  betas      <- lme4::fixef(model)
  keep_cols  <- intersect(colnames(mm_pop), names(betas))
  fixed_part <- as.numeric(mm_pop[, keep_cols, drop = FALSE] %*% betas[keep_cols])

  re        <- lme4::ranef(model)[[group_col]]
  re_vec    <- setNames(re[, 1], rownames(re))
  rand_part <- re_vec[as.character(pop[[group_col]])]
  rand_part[is.na(rand_part)] <- 0

  pred <- fixed_part + rand_part

  tibble(sim_id,
         unit_id   = pop[[unit_id]],
         area      = as.character(pop[[group_col]]),
         y_true    = pop[[y_col]],
         pred      = pred)
}

tic()
results <- pmap(sim_meta, run_lmm, .progress = TRUE) %>% 
  compact() %>% 
  list_rbind()
toc()

arrow::write_parquet(results, file.path(dataset_dir, "results", "lmm.parquet"))
