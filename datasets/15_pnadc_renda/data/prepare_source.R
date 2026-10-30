# Preparation of the source file for 15_pnadc_renda.
# Reads the fixed-width microdata PNADC_2024_visita1.txt from the IBGE download
# PNADC_2024_visita1_20251119.zip (path relative to the folder holding the
# downloaded file; column positions from the accompanying dictionary) and writes
# PNADC/pnadc2024_renda.parquet (all eligible persons) and
# PNADC/pnadc2024_renda_reduced.parquet, the extract read by settings.R.
library(dplyr)
library(arrow)
library(readr)

zip <- "PNADC/PNADC_2024_visita1_20251119.zip"
unzip(zip, files = "PNADC_2024_visita1.txt", exdir = tempdir())

# Column positions (dictionary dicionario_PNADC_microdados_2024_visita1.xls)
pos <- fwf_positions(
  start     = c(6,    32,      94,      103,     106,     529,      530,      534,      575,      595),
  end       = c(7,    32,      94,      105,     106,     529,      531,      534,      582,      597),
  col_names = c("UF", "V1022", "V2007", "V2009", "V2010", "VD3004", "VD3005", "VD4002", "VD4020", "VD4035"))
raw <- read_fwf(file.path(tempdir(), "PNADC_2024_visita1.txt"), pos,
                col_types = cols(.default = col_character()), progress = FALSE)

# Employed persons aged 25-64 with positive effective monthly income from all
# jobs (VD4020, top-coded by IBGE), positive hours worked in the reference week
# (VD4035) and complete covariates
pnadc <- raw |>
  mutate(idade = as.numeric(V2009), renda = as.numeric(VD4020),
         horas = as.numeric(VD4035), anos = as.numeric(VD3005)) |>
  filter(VD4002 == "1", idade >= 25, idade <= 64,
         !is.na(renda), renda > 0, !is.na(horas), horas > 0, !is.na(anos),
         !is.na(V2007), !is.na(V2010), !is.na(VD3004), !is.na(V1022)) |>
  transmute(
    lrenda = log(renda),                   # target: log income
    renda, horas,
    uf     = UF,
    ufurb  = paste(UF, V1022, sep = "_"),  # area: federal unit x urban/rural
    idade,                                 # age
    anos,                                  # years of schooling (VD3005)
    sexo   = factor(V2007),
    raca   = factor(V2010),                # colour/race (official categories)
    nivel  = factor(VD3004),               # highest educational attainment
    urb    = factor(V1022)                 # urban (1) / rural (2)
  )
write_parquet(pnadc, "PNADC/pnadc2024_renda.parquet")

# Population: stratified simple random sample of 34 % within areas
set.seed(101023)
pnadc_red <- pnadc |>
  group_by(ufurb) |>
  slice_sample(prop = 0.34) |>
  ungroup()

# Race/colour categories with fewer than 800 persons are merged into "OTH"
rare <- names(which(table(pnadc_red$raca) < 800))
pnadc_red <- pnadc_red |>
  mutate(raca = factor(ifelse(as.character(raca) %in% rare, "OTH", as.character(raca))))

write_parquet(pnadc_red, "PNADC/pnadc2024_renda_reduced.parquet")
