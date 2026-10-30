# Preparation of the source file for 14_lsms_pcexp.
# Reads LSMS-Nigeria/Household_dataset.dta (LSMS-ISA harmonised panel v2.0,
# household file; path relative to the folder holding the downloaded file),
# keeps the latest wave of each country, households with positive consumption
# and complete covariates in admin-2 districts with at least 30 such
# households, and writes LSMS-Nigeria/lsms_pcexp.parquet, the extract read by
# the sampling block in settings.R.
library(dplyr)
library(haven)
library(arrow)

lsms_raw <- read_dta("LSMS-Nigeria/Household_dataset.dta")
nrow(lsms_raw)                      # 148421 household-wave observations
table(lsms_raw$country, lsms_raw$wave)

# panel data: keep only the last wave of each country
lsms_last <- lsms_raw %>% group_by(country) %>% summarise(w = max(wave, na.rm = TRUE))
lsms <- lsms_raw %>%
  inner_join(lsms_last, by = "country") %>%
  filter(wave == w) %>%
  mutate(
    # admin_1/admin_2 are coded per country -> combine with country
    area1 = paste0(country, "_", as.integer(admin_1)),   # admin-1 region (area)
    area2 = paste0(country, "_", as.integer(admin_1), "_", as.integer(admin_2)),
    urban = as.integer(urban),
    elec  = as.integer(hh_electricity_access)
  ) %>%
  filter(!is.na(totcons_USD), totcons_USD > 0, !is.na(hh_size), !is.na(urban),
         !is.na(elec), !is.na(hh_dependency_ratio), !is.na(hh_asset_index),
         !is.na(HDDS), !is.na(hh_formal_education), !is.na(nonfarm_enterprise)) %>%
  transmute(
    # totcons_USD is already per capita ("Consumption aggregate per capita, in USD");
    # do not divide by hh_size again
    lpcexp = log(totcons_USD),                 # target: log per-capita consumption (USD)
    totcons_USD, country, area1, area2,
    hh_size, dep = hh_dependency_ratio, asset = hh_asset_index, hdds = HDDS,
    urban = factor(urban), elec = factor(elec),
    educ  = factor(hh_formal_education), nonfarm = factor(nonfarm_enterprise)
  )
nrow(lsms)   # 20252

# keep admin_2 districts with at least 30 households
lsms_tb2 <- table(lsms$area2)
lsms2 <- lsms %>% filter(area2 %in% names(lsms_tb2)[lsms_tb2 >= 30])
length(unique(lsms$area1))    # 53 admin_1
length(lsms_tb2)              # 485 admin_2, 218 of them with at least 30 cases
nrow(lsms2)                   # 16515

write_parquet(lsms2, "LSMS-Nigeria/lsms_pcexp.parquet")
