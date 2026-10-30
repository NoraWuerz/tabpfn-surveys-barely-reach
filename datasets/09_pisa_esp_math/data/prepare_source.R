# Preparation of the source file for 09_pisa_esp_math.
# Reads PISA/CY08MSP_STU_QQQ.SAV (OECD PISA 2022 student questionnaire; path
# relative to the folder holding the downloaded file), keeps the students
# tested in Spain with complete target and covariates in schools with at least
# 10 such students, and writes PISA/pisa2022_esp_math.parquet, the extract
# read by the sampling block in settings.R. The target is the first plausible
# value in mathematics (PV1MATH).
library(dplyr)
library(haven)
library(arrow)

pisa_raw <- read_sav("PISA/CY08MSP_STU_QQQ.SAV",
  col_select = c(CNT, CNTSCHID, REGION, ST004D01T, AGE, ESCS, IMMIG, REPEAT,
                 HISCED, PV1MATH))
nrow(pisa_raw)   # 613744

# Spain only
# HISCED = 1 ("less than ISCED 1") -> 2 ("ISCED 1")
# schools with fewer than 10 students are dropped
pisa <- pisa_raw %>%
  filter(as.character(CNT) == "ESP") %>%
  filter(!is.na(PV1MATH), !is.na(ESCS), !is.na(AGE), !is.na(IMMIG),
         !is.na(REPEAT), !is.na(HISCED), !is.na(ST004D01T)) %>%
  mutate(HISCED = ifelse(HISCED == 1, 2, HISCED)) %>%
  transmute(
    school    = as.character(CNTSCHID),
    region    = as.character(as_factor(REGION)), # 19 autonomous communities (area)
    math      = as.numeric(PV1MATH),             # target
    escs      = as.numeric(ESCS),                # socio-economic status (OECD index)
    age       = as.numeric(AGE),
    sex       = factor(ST004D01T),
    immig     = factor(IMMIG),                   # native / 2nd / 1st generation
    grade_rep = factor(REPEAT),                  # grade repeated
    hisced    = factor(HISCED)                   # highest parental education
  )
school_n <- table(pisa$school)
pisa <- pisa[pisa$school %in% names(school_n[school_n >= 10]), ] %>%
  droplevels() %>% mutate(idU = row_number()) %>% relocate(idU)
nrow(pisa)                       # 28475
length(unique(pisa$school))      # 929

write_parquet(pisa, "PISA/pisa2022_esp_math.parquet")
