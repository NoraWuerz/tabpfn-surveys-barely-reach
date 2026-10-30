# Preparation of the source file for 10_afrobarometer_lpi.
# Reads Afrobarometer/R9.Merge_39ctry.sav (merged Round 9 data set; path
# relative to the folder holding the downloaded file), keeps adult respondents
# with a valid Lived Poverty Index, at least one valid trust item and complete
# covariates in regions with at least 30 such respondents, and writes
# Afrobarometer/afrobarometer_r9.parquet, the extract read by the sampling
# block in settings.R.
library(dplyr)
library(haven)
library(arrow)

afro_raw <- read_sav("Afrobarometer/R9.Merge_39ctry.sav",
  col_select = c(RESPNO, COUNTRY, REGION, URBRUR, Q1, Q100, Q94, Q93A,
                 LivedPoverty, Q37A:Q37K))
nrow(afro_raw)   # 53444 respondents in 39 countries

# Target: LivedPoverty, the Lived Poverty Index (mean of items Q6a-Q6e, range 0-4).
# trust_idx, the mean of the trust items Q37a-Q37k (valid codes 0-3; 8/9/98/99
# = don't know / refused -> NA), is kept as a filter variable.
trust <- afro_raw %>% select(Q37A:Q37K) %>%
  mutate(across(everything(), ~ ifelse(.x %in% 0:3, .x, NA)))
afro_raw$trust_idx <- rowMeans(trust, na.rm = TRUE)

# REGION codes are country-specific -> region = COUNTRY_REGION
# Q1 (age): 998/999 = refused / don't know -> NA
# Q93A: 9994 = not asked in this country, 8/9 = don't know / refused -> NA
afro <- afro_raw %>%
  mutate(
    region  = paste(as.character(as_factor(COUNTRY)),
                    as.character(as_factor(REGION)), sep = "_"),
    country = as.character(as_factor(COUNTRY)),   # area
    age     = ifelse(Q1 %in% 18:110, as.numeric(Q1), NA),
    sex     = factor(ifelse(Q100 %in% 1:2, Q100, NA)),
    educ    = factor(ifelse(Q94 %in% 0:9, Q94, NA)),   # 10 education levels
    empl    = factor(ifelse(Q93A %in% 0:3, Q93A, NA)), # employment status
    urban   = factor(ifelse(URBRUR %in% c(1, 2), URBRUR, NA)),
    lpi     = ifelse(LivedPoverty >= 0 & LivedPoverty <= 4, LivedPoverty, NA)
  ) %>%
  filter(!is.na(lpi), !is.na(trust_idx), !is.na(age), !is.na(sex),
         !is.na(educ), !is.na(empl), !is.na(urban))
nrow(afro)   # 51002 before the region filter

# keep regions with at least 30 respondents
region_n <- table(afro$region)
length(region_n)   # 509 raw regions
afro <- afro[afro$region %in% names(region_n[region_n >= 30]), ] %>%
  droplevels() %>%
  transmute(idU = row_number(), region, country, lpi, trust_idx,
            age, sex, educ, empl, urban)
nrow(afro)                      # 49198
length(unique(afro$region))     # 421 regions
length(unique(afro$country))    # 38 countries (one country drops out because Q93A was not asked there)

write_parquet(afro, "Afrobarometer/afrobarometer_r9.parquet")
