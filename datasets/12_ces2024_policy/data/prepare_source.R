# Preparation of the source file for 12_ces2024_policy.
# Reads CES/CCES24_Common_OUTPUT_vv_topost_final.csv (CES 2024 common content;
# path relative to the folder holding the downloaded file), builds the policy
# conservatism index from 35 binary items, keeps respondents with at least 30
# valid items, year of birth and county, collapses rare covariate categories
# and writes CES/ces2024_policy.parquet, the extract read by the sampling block
# in settings.R.
library(dplyr)
library(arrow)
library(data.table)

# collapse factor levels with fewer than min_n cases into "OTH"
collapse_rare <- function(x, min_n = 500) {
  x <- as.character(x); tb <- table(x)
  x[x %in% names(tb)[tb < min_n]] <- "OTH"
  factor(x)
}

# target: policy conservatism index from 35 binary items (1 = support, 2 = oppose),
# recoded so that the conservative position = 1
cons_support <- c("CC24_321b","CC24_321d","CC24_323b","CC24_323c","CC24_324b","CC24_324c",
                  "CC24_326d","CC24_326f","CC24_328c","CC24_328d","CC24_340e","CC24_340f",
                  "CC24_341a")
cons_oppose  <- c("CC24_321a","CC24_321c","CC24_321e","CC24_321f","CC24_323a","CC24_323d",
                  "CC24_323f","CC24_324a","CC24_324d","CC24_326a","CC24_326b","CC24_326c",
                  "CC24_326e","CC24_328a","CC24_328b","CC24_328e","CC24_340a","CC24_340b",
                  "CC24_340c","CC24_341b","CC24_341c","CC24_341d")
ces_items <- c(cons_support, cons_oppose)
ces_demo  <- c("birthyr","gender4","educ","race","hispanic","marstat","faminc_new","employ",
               "religpew","urbancity","child18","union","ownhome","newsint","pid7","ideo5",
               "inputstate","cdid119","countyfips")

ces_raw <- fread("CES/CCES24_Common_OUTPUT_vv_topost_final.csv",
                 select = c(ces_items, ces_demo), showProgress = FALSE)
nrow(ces_raw)   # 60000

# 8 = skipped, 9 = not asked -> NA
ces_b <- sapply(ces_items, function(v) { z <- as.numeric(ces_raw[[v]]); z[!(z %in% c(1,2))] <- NA; z })
ces_c <- ces_b
for (v in cons_support) ces_c[, v] <- ifelse(ces_b[, v] == 1, 1, 0)
for (v in cons_oppose)  ces_c[, v] <- ifelse(ces_b[, v] == 2, 1, 0)
ces_nvalid <- rowSums(!is.na(ces_c))

ces <- ces_raw %>%
  mutate(
    cons_idx = ifelse(ces_nvalid >= 30, rowMeans(ces_c, na.rm = TRUE), NA_real_), # index only if at least 30 of 35 items valid
    age      = 2024 - birthyr,
    # cdid119 is the district number within the state -> combine with the state
    state  = sprintf("%02d", as.integer(inputstate)),   # area
    cd     = paste0(sprintf("%02d", as.integer(inputstate)), "-",
                    sprintf("%02d", as.integer(cdid119))),
    county = sprintf("%05d", as.integer(countyfips))
  ) %>%
  filter(!is.na(cons_idx), !is.na(age), !is.na(countyfips)) %>%
  mutate(
    gender4 = collapse_rare(gender4), educ = collapse_rare(educ),
    race = collapse_rare(race), hispanic = collapse_rare(hispanic),
    marstat = collapse_rare(marstat), faminc = collapse_rare(faminc_new),
    employ = collapse_rare(employ), religpew = collapse_rare(religpew),
    urbancity = collapse_rare(urbancity), child18 = collapse_rare(child18),
    union = collapse_rare(union), ownhome = collapse_rare(ownhome),
    newsint = collapse_rare(newsint), pid7f = collapse_rare(pid7)
  ) %>%
  select(cons_idx, age, gender4, educ, race, hispanic, marstat, faminc, employ,
         religpew, urbancity, child18, union, ownhome, newsint, pid7f,
         state, cd, county) %>%
  na.omit()
nrow(ces)                        # 59586
length(unique(ces$cd))           # 436
length(unique(ces$county))       # 2704

# the extract keeps the three area levels state, cd and county; pid7f (party
# identification) is not a covariate of the study
write_parquet(ces, "CES/ces2024_policy.parquet")
