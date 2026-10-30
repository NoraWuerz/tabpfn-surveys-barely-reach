# Preparation of the source file for 11_wvs7_trust.
# Reads WVS_Wave_7_sas_v6_0.sas7bdat (WVS wave 7, SAS version 6.0; path
# relative to the folder holding the downloaded file), builds the institutional
# trust index, keeps respondents with complete information in regions with at
# least 30 such respondents, and writes WVS/wvs7_trust.parquet, the extract
# read by the sampling block in settings.R.
library(dplyr)
library(haven)
library(arrow)

wvs_raw <- read_sas(
  "WVS/F00010735-WVS_Cross-National_Wave_7_sas_v6_0/WVS_Wave_7_sas_v6_0.sas7bdat",
  col_select = c(paste0("Q", 64:73), "Q49", "Q50", "B_COUNTRY_ALPHA",
                 "N_REGION_ISO", "Q260", "Q262", "Q275", "Q273", "Q279",
                 "Q287", "Q288", "H_URBRURAL"))
nrow(wvs_raw)   # 97220

# negative codes are missing-value flags (-1 don't know, -2 no answer, -4 not asked, -5 missing) -> NA
neg2na <- function(x) { x <- as.numeric(x); x[x < 0] <- NA; x }

# target: trust in ten institutions (Q64-Q73), scale 1 = a great deal .. 4 = none at all,
# reversed (5 - x) so that high values mean high trust;
# index only for respondents with at least 7 of the 10 items valid
wvs_trust <- 5 - sapply(paste0("Q", 64:73), function(v) neg2na(wvs_raw[[v]]))
wvs_nvalid <- rowSums(!is.na(wvs_trust))

# region = country x N_REGION_ISO; lifesat and finsat are kept as filter variables
wvs <- wvs_raw %>%
  mutate(
    trust_idx = ifelse(wvs_nvalid >= 7, rowMeans(wvs_trust, na.rm = TRUE), NA),
    lifesat   = neg2na(Q49),          # life satisfaction 1-10
    finsat    = neg2na(Q50),          # satisfaction with financial situation 1-10
    country   = as.character(B_COUNTRY_ALPHA),   # area
    reg       = neg2na(N_REGION_ISO),
    age       = neg2na(Q262),  inc   = neg2na(Q288),
    sex       = neg2na(Q260),  educ  = neg2na(Q275),
    marst     = neg2na(Q273),  empl  = neg2na(Q279),
    class     = neg2na(Q287),  urban = neg2na(H_URBRURAL)
  ) %>%
  filter(!is.na(trust_idx), !is.na(lifesat), !is.na(finsat), !is.na(reg),
         !is.na(age), !is.na(sex), !is.na(educ), !is.na(marst), !is.na(empl),
         !is.na(class), !is.na(inc), !is.na(urban)) %>%
  mutate(region = paste0(country, "_", reg))

# keep regions with at least 30 respondents
wvs_tb <- table(wvs$region)
wvs <- wvs %>%
  filter(region %in% names(wvs_tb)[wvs_tb >= 30]) %>%
  transmute(region, country, trust_idx, lifesat, finsat, age, inc,
            sex = factor(sex), educ = factor(educ), marst = factor(marst),
            empl = factor(empl), class = factor(class), urban = factor(urban))
nrow(wvs)                         # 76156
length(unique(wvs$region))        # 729 regions
length(unique(wvs$country))       # 62 countries

write_parquet(wvs, "WVS/wvs7_trust.parquet")
