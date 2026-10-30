# Preparation of the source file for 03_pums_rent.
# Downloads the ACS 2023 1-year PUMS via tidycensus (Census API key required),
# keeps renters with a positive rent, draws a stratified 6 % subsample by state
# and adds the state names; writes datasets/03_pums_rent/data/pums_rent.parquet
# (full download) and pums_rent_reduced.parquet, the population read by the
# sampling block in settings.R.
pacman::p_load(tidycensus, dplyr, tidyr, arrow)
census_api_key("xxxx", install = TRUE, overwrite = TRUE)

pums <- get_pums(variables = c("AGEP", "NP", "BDSP", "RMSP", "YRBLT", "RNTP", "TEN"),
                 state     = "all",
                 year      = 2023,
                 survey    = "acs1")
# save the full download locally
arrow::write_parquet(pums, "datasets/03_pums_rent/data/pums_rent.parquet")

# keep renters (TEN == 3) with a positive rent
pums_rent <- pums %>%
  filter(TEN == 3, !is.na(RNTP), RNTP > 0)

# stratified 6 % subsample by state
set.seed(123)
pums_sim <- pums_rent |>
  dplyr::group_by(STATE) |>
  dplyr::slice_sample(prop = 0.06) |>
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
arrow::write_parquet(pums_sim, "datasets/03_pums_rent/data/pums_rent_reduced.parquet")
