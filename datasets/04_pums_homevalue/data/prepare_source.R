# Preparation of the source file for 04_pums_homevalue.
# Downloads the ACS 2023 1-year PUMS via tidycensus (Census API key required),
# keeps owner-occupied units with a positive property value, draws a stratified
# 2 % subsample by state and adds the state names; writes
# datasets/04_pums_homevalue/data/pums_valp.parquet (full download) and
# pums_valp_reduced.parquet, the population read by the sampling block in
# settings.R.
pacman::p_load(tidycensus, dplyr, tidyr, arrow)
census_api_key("xxxx", install = TRUE, overwrite = TRUE)

pums <- get_pums(variables = c("VALP", "TEN", "AGEP", "NP", "BDSP", "RMSP", "YRBLT"),
                 state     = "all",
                 year      = 2023,
                 survey    = "acs1")
# save the full download locally
arrow::write_parquet(pums, "datasets/04_pums_homevalue/data/pums_valp.parquet")

# keep owner-occupied units (TEN 1 or 2) with a positive property value
pums_valp <- pums %>%
  filter(TEN %in% c(1, 2), !is.na(VALP), VALP > 0)

# stratified 2 % subsample by state
set.seed(123)
pums_sim <- pums_valp |>
  dplyr::group_by(STATE) |>
  dplyr::slice_sample(prop = 0.02) |>
  dplyr::ungroup()

# add state names and abbreviations
variables <- tidycensus::pums_variables %>%
  filter(year == 2023, survey == "acs1", var_code == "STATE") %>%
  select(val_label, val_min) %>%
  mutate(STATE = val_min, .before = 01) %>%
  select(-val_min) %>%
  tidyr::separate(val_label, into = c("STATE_NAME", "STATE_ABBR"), sep = "/")

pums_sim <- pums_sim %>% left_join(variables, by = "STATE")

# save reduced file
arrow::write_parquet(pums_sim, "datasets/04_pums_homevalue/data/pums_valp_reduced.parquet")
