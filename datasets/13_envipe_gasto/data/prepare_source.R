# Preparation of the source file for 13_envipe_gasto.
# Reads the ENVIPE 2024 microdata tables tper_vic1, tsdem, thogar and tvivienda
# (CSV; paths relative to the folder holding the downloaded files), merges them,
# keeps households with positive spending on protection against crime and
# complete covariates in municipios with at least 30 such households, and
# writes ENVIPE/envipe2024_gasto.parquet, the extract read by the sampling block
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

env_per <- fread("ENVIPE/tper_vic1_envipe2024/conjunto_de_datos/conjunto_de_datos_tper_vic1_envipe2024.csv",
                 select = c("ID_VIV","ID_HOG","ID_PER","CVE_ENT","NOM_ENT","CVE_MUN",
                            "SEXO","EDAD","AP4_12"), showProgress = FALSE)
env_sdem <- fread("ENVIPE/tsdem_envipe2024/conjunto_de_datos/conjunto_de_datos_tsdem_envipe2024.csv",
                  select = c("ID_VIV","ID_HOG","ID_PER","NIV","PAREN"), showProgress = FALSE)
env_hog <- fread("ENVIPE/thogar_envipe2024/conjunto_de_datos/conjunto_de_datos_thogar_envipe2024.csv",
                 select = c("ID_VIV","ID_HOG","TOT_PER"), showProgress = FALSE)
env_viv <- fread("ENVIPE/tvivienda_envipe2024/conjunto_de_datos/conjunto_de_datos_tvivienda_envipe2024.csv",
                 select = c("ID_VIV","AP1_1","DOMINIO"), showProgress = FALSE)
nrow(env_per)   # 89630

# target AP4_12: spending on protection against crime (pesos); 9999999 = don't know -> NA;
# the question is only asked of households that took protective measures,
# and only positive amounts are kept
env <- env_per %>%
  left_join(env_sdem, by = c("ID_VIV","ID_HOG","ID_PER")) %>%
  left_join(env_hog,  by = c("ID_VIV","ID_HOG")) %>%
  left_join(env_viv,  by = "ID_VIV") %>%
  mutate(
    gasto = suppressWarnings(as.numeric(AP4_12)),
    edad  = suppressWarnings(as.numeric(EDAD)),
    niv   = suppressWarnings(as.numeric(NIV)),
    tot   = suppressWarnings(as.numeric(TOT_PER)),
    ent   = sprintf("%02d", as.integer(CVE_ENT)),   # state (area)
    # CVE_MUN is only unique within the state -> combine with CVE_ENT
    mun   = paste0(sprintf("%02d", as.integer(CVE_ENT)), sprintf("%03d", as.integer(CVE_MUN)))
  ) %>%
  filter(!is.na(gasto), gasto > 0, gasto != 9999999,
         !is.na(edad), !is.na(niv), niv <= 90, !is.na(tot), !is.na(AP1_1)) %>%
  transmute(
    lgasto = log(gasto), gasto, ent, mun, edad, tot,
    sexo  = factor(SEXO),
    niv   = collapse_rare(niv, 200),      # education level
    paren = collapse_rare(PAREN, 200),    # relationship to household head
    clase = collapse_rare(AP1_1, 200),    # dwelling class
    dom   = factor(DOMINIO)               # domain (urban/complementary/rural)
  )
nrow(env)   # 27832

# keep municipios with at least 30 cases
env_tb  <- table(env$mun)
env_mun <- env %>% filter(mun %in% names(env_tb)[env_tb >= 30])
length(env_tb)            # 1085 municipios with cases
sum(env_tb >= 30)         # 192 with at least 30 cases
nrow(env_mun)             # 20428

write_parquet(env_mun, "ENVIPE/envipe2024_gasto.parquet")
