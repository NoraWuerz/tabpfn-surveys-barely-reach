# Preparation of the source file for 01_eusilc.
# Reads the synthetic population eusilcA_pop of the R package emdi (25,000
# households, 94 districts), converts the area columns to character and adds
# the unit id; writes datasets/01_eusilc/data/population.parquet, the
# population read by the sampling block in settings.R.
library(dplyr)
library(arrow)

data("eusilcA_pop", package = "emdi")

pop <- eusilcA_pop |>
  mutate(state = as.character(state), district = as.character(district),
         idU = row_number())

write_parquet(pop, "datasets/01_eusilc/data/population.parquet")
