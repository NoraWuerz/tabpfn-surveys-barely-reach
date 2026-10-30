# Preparation of the source file for 08_recs_electricity.
# Reads RECS/recs2020_public_v7.csv (RECS 2020 public-use microdata; path
# relative to the folder holding the downloaded file), selects and recodes the
# model variables and writes RECS/recs2020_electricity.parquet, the extract
# read by the sampling block in settings.R.
library(dplyr)
library(arrow)

recs_raw <- read.csv("RECS/recs2020_public_v7.csv")
nrow(recs_raw)                         # 18496 households, 799 variables
length(unique(recs_raw$state_name))    # 51 (50 states + DC)

# FUELHEAT = 99 ("other fuel", 8 households) -> 7 (wood/other);
# FUELHEAT = -2 ("not applicable", no heating) is kept as its own level
recs <- recs_raw %>%
  mutate(FUELHEAT = ifelse(FUELHEAT == 99, 7, FUELHEAT)) %>%
  transmute(
    idU      = row_number(),
    state    = as.character(state_name),
    kwh      = KWH,                      # electricity use, kWh/year (target)
    sqft     = TOTSQFT_EN,               # heated/cooled floor area
    hhsize   = NHSLDMEM,                 # household size
    hhage    = HHAGE,                    # age of householder
    yearmade = as.numeric(YEARMADERANGE),# year-built class 1..9 (ordinal)
    income   = as.numeric(MONEYPY),      # income class 1..16 (ordinal)
    typehuq  = factor(TYPEHUQ),          # housing type
    fuelheat = factor(FUELHEAT),         # main heating fuel
    urban    = factor(UATYP10),          # urban/cluster/rural
    educ     = factor(EDUCATION),        # education
    hdd65    = HDD65,                    # heating degree days (not a covariate)
    cdd65    = CDD65                     # cooling degree days (not a covariate)
  ) %>%
  filter(kwh > 0)
nrow(recs)

write_parquet(recs, "RECS/recs2020_electricity.parquet")
