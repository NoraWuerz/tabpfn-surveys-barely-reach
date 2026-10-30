# Preparation of the source file for 06_DHS_kenya_BMI_women.
# Reads KEPR8CDT/KEPR8CFL.DTA (DHS Kenya 2022 household member recode, PR; path
# to the downloaded file to be set below), keeps women aged 15-49 with a valid
# BMI and complete covariates and writes DHS/dhs_kenya_bmi_women.parquet, the
# extract read by the sampling block in settings.R.
library(dplyr)
library(haven)
library(arrow)

dhs_path <- "<path to the raw DHS file KEPR8CDT/KEPR8CFL.DTA>"
dhs <- read_dta(dhs_path, col_select = c(hv001, hv002, hvidx, hv024, hv025,
                                          hv105, hv106, hv270, ha40))
nrow(dhs)  # 156571 household members

# ha40 = BMI with two implied decimals (2279 -> 22.79);
# values >= 9000 are flags (not measured / implausible) -> NA
dhs_women <- dhs %>%
  mutate(
    bmi    = ifelse(!is.na(ha40) & ha40 < 9000, as.numeric(ha40) / 100, NA_real_),
    county = as.character(as_factor(hv024)),   # 47 counties
    age    = as.numeric(hv105),
    urban  = factor(as_factor(hv025), levels = c("urban", "rural")),
    educ   = factor(recode(as.character(as_factor(hv106)),
             "no education, preschool/early childhood education" = "none",
             "primary" = "primary", "secondary" = "secondary", "higher" = "higher"),
             levels = c("none", "primary", "secondary", "higher")),
    wealth = factor(as.character(as_factor(hv270)),
             levels = c("poorest", "poorer", "middle", "richer", "richest"))
  ) %>%
  filter(!is.na(bmi), age >= 15, age <= 49) %>%
  filter(complete.cases(across(c(age, urban, educ, wealth)))) %>%
  droplevels()
nrow(dhs_women)  # 17268 women with a valid BMI

# save the prepared data set
dhs_export <- dhs_women %>%
  transmute(idU = row_number(), county, bmi, age, urban, educ, wealth)
write_parquet(dhs_export, "DHS/dhs_kenya_bmi_women.parquet")
