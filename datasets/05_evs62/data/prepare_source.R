# Preparation of the source file for 05_evs62.
# Reads FDZ-EVS/EVS62H_PUF.csv (EVS 1962/63 household public use file; path
# relative to the folder holding the downloaded file), builds the area
# (federal state x municipality size class), keeps areas with at least 30
# households, recodes rare categories and writes FDZ-EVS/evs62_income.parquet,
# the extract read by the sampling block in settings.R.
library(dplyr)
library(arrow)

EVS <- read.csv("FDZ-EVS/EVS62H_PUF.csv")
nrow(EVS)

# area = federal state (EAH035) x municipality size class (EAH001);
# keep areas with at least 30 households
EVS$region <- paste(EVS$EAH035, EVS$EAH001, sep = "_")
region_n <- table(EVS$region)
EVS_comp <- EVS[EVS$region %in% names(region_n[region_n >= 30]), ]
nrow(EVS_comp)
length(unique(EVS_comp$region))

# Recode rare or invalid categories of the categorical covariates:
# EAH024 = 6 ("?" in the codebook, i.e. missing) -> NA, rows dropped
# EAH005 = 3 (agricultural workers) -> 1 (workers outside agriculture)
# EAH020 = 6 (single parent, children both under and over 18) -> 3 (couple, same age mix)
# EAH024 = 3 (car at start, sold without replacement) -> 1 (car at start, no new purchase)
EVS_comp$EAH024[EVS_comp$EAH024 == 6] <- NA
EVS_comp <- EVS_comp[!is.na(EVS_comp$EAH024), ]
EVS_comp$EAH005[EVS_comp$EAH005 == 3] <- 1
EVS_comp$EAH020[EVS_comp$EAH020 == 6] <- 3
EVS_comp$EAH024[EVS_comp$EAH024 == 3] <- 1
nrow(EVS_comp)

# categorical covariates as factors: social status of head, sex of head,
# household type, car ownership
EVS_comp$EAH005 <- as.factor(EVS_comp$EAH005)
EVS_comp$EAH009 <- as.factor(EVS_comp$EAH009)
EVS_comp$EAH020 <- as.factor(EVS_comp$EAH020)
EVS_comp$EAH024 <- as.factor(EVS_comp$EAH024)

# save the prepared data set (target EAH150, area, and the covariates: age of
# head, household size, number of children, number of earners, the four factors)
EVS_export <- EVS_comp %>%
  transmute(idU = row_number(), region,
            EAH150, EAH010, EAH012, EAH019, EAH030,
            EAH005, EAH009, EAH020, EAH024)
write_parquet(EVS_export, "FDZ-EVS/evs62_income.parquet")
