# Preparation of the source file for 02_fdz_bee.
# Reads FDZ-BEE/BEE_PUF_2017.csv (Public Use File of the Besondere Ernte- und
# Qualitaetsermittlung 2017, Research Data Centres of the German statistical
# offices; path relative to the folder holding the downloaded file) and writes
# FDZ-BEE/BEE_PUF_2017.parquet, the extract read by settings.R.
library(dplyr)
library(arrow)

bee <- read.csv("FDZ-BEE/BEE_PUF_2017.csv", sep = ";", fileEncoding = "latin1",
                stringsAsFactors = FALSE)

# EF10 (ecological farming) is dropped; fields with any other missing value are removed.
bee <- bee[complete.cases(bee[, -10]), -10]
bee$unit_id <- seq_len(nrow(bee))

# EF12 == 20 is a residual tillage code too rare to occur in every sample.
bee <- bee |> filter(EF12 != 20)

# Codes -> labels of the FDZ codebook. The German labels are kept verbatim
# because the factor levels are ordered alphabetically by label below; translating
# them would change the level order and hence the category coding seen by the
# models. Translations: crop = winter wheat / rye and winter meslin / winter
# barley / winter rapeseed; method = sample cut / full harvest; precrop = the
# preceding crop (98 = not stated, 99 = other); organic = yes / no / not stated;
# tillage = without plough / with plough / not stated.
state <- c("1" = "Schleswig-Holstein", "3" = "Niedersachsen", "5" = "Nordrhein-Westfalen",
           "6" = "Hessen", "7" = "Rheinland-Pfalz", "8" = "Baden-Württemberg",
           "9" = "Bayern", "10" = "Saarland", "12" = "Brandenburg",
           "13" = "Mecklenburg-Vorpommern", "14" = "Sachsen", "15" = "Sachsen-Anhalt",
           "16" = "Thüringen")
crop  <- c("1" = "Winterweizen", "2" = "Roggen und Wintermenggetreide",
           "3" = "Wintergerste", "4" = "Winterraps")
method <- c("1" = "Probeschnitt", "2" = "Volldrusch")
precrop <- c("1" = "Winterweizen einschließlich Dinkel", "2" = "Sommerweizen",
             "3" = "Roggen und Wintermenggetreide", "4" = "Triticale", "5" = "Wintergerste",
             "6" = "Sommergerste", "7" = "Hafer", "8" = "Körnermais", "9" = "Silomais",
             "10" = "Leguminosen", "11" = "Feldgras/ Grasanbau", "12" = "Kartoffeln",
             "13" = "Zuckerrüben", "14" = "Erbsen", "15" = "Winterraps",
             "98" = "Keine Angabe", "99" = "Andere Vorfrucht")
organic <- c("1" = "ja", "2" = "nein", "99" = "Keine Angabe")
tillage <- c("1" = "ohne Pflugeinsatz", "2" = "mit Pflugeinsatz", "99" = "Keine Angabe")

# factor levels in case-insensitive alphabetical order (locale independent)
lev <- function(x) { u <- unique(unname(x)); u[order(tolower(u), method = "radix")] }
bee <- bee |>
  mutate(
    EF2  = factor(state[as.character(EF2)],    levels = lev(state)),
    EF4  = factor(crop[as.character(EF4)],     levels = lev(crop)),
    EF5  = enc2utf8(EF5),   # variety name (not used as covariate)
    EF8  = factor(method[as.character(EF8)],   levels = lev(method)),
    EF9  = factor(precrop[as.character(EF9)],  levels = lev(precrop)),
    EF11 = factor(organic[as.character(EF11)], levels = lev(organic)),
    EF12 = factor(tillage[as.character(EF12)], levels = lev(tillage))
  )

write_parquet(bee, "FDZ-BEE/BEE_PUF_2017.parquet")
