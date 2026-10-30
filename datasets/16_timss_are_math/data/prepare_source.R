# Preparation of the source file for 16_timss_are_math.
# Reads the grade-8 student file of the United Arab Emirates (R Data/bsgarem8.rdata)
# from the IEA download T23_Data_R_G8.zip (path relative to the folder holding
# the downloaded file) and writes TIMSS2023/timss2023_are_math.parquet, the
# extract read by settings.R.
library(dplyr)
library(arrow)

zip <- "TIMSS2023/T23_Data_R_G8.zip"
unzip(zip, files = "R Data/bsgarem8.rdata", exdir = tempdir(), junkpaths = TRUE)
load(file.path(tempdir(), "bsgarem8.rdata"))          # object BSGAREM8
stu <- BSGAREM8

# Questionnaire codes 9 = omitted or invalid -> NA
to_factor <- function(x) { x <- as.numeric(x); x[x == 9] <- NA; factor(x) }

timss <- stu |>
  transmute(
    school = sprintf("ARE_%05d", as.integer(IDSCHOOL)),   # area: school within the UAE
    math   = as.numeric(BSMMAT01),    # first plausible value, mathematics (target)
    sci    = as.numeric(BSSSCI01),    # first plausible value, science (not used)
    age    = as.numeric(BSDAGE),      # age in years (the code 99 of four students is kept as in the study population)
    sex    = factor(as.numeric(ITSEX)),
    books  = to_factor(BSBG04),       # books at home
    lang   = to_factor(BSBG03),       # language of test spoken at home
    pared  = to_factor(BSDGEDUP),     # parents' highest education
    her    = to_factor(BSDGHER),      # home educational resources index
    expect = to_factor(BSBG07)        # expected own education
  ) |>
  filter(complete.cases(pick(everything())))

write_parquet(timss, "TIMSS2023/timss2023_are_math.parquet")
