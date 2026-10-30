# make_tables.R
# Builds the one SI table whose entries are computed from the simulation, as a
# LaTeX float identical to the one in the SI Appendix:
#   Table S1 (tab:datasets)    the sixteen populations and the sampling design
#                              from aggregated_results/tables/design_stats.csv
# The remaining SI tables (S2 covariates, S3 access conditions, S4 software,
# S5 tuning protocol) and Table 1 of the main text are descriptive and typed
# directly in the manuscript.
# Requires: aggregated_results/tables/design_stats.csv (design_stats.R)
# Writes:   paper_figures/tables/table_S1_populations.tex
# Run from the repository root:  Rscript paper_figures/make_tables.R
suppressMessages({ library(dplyr); library(tidyr) })

AGG <- "aggregated_results/tables"
OUT <- "paper_figures/tables"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

# display names, citation keys, target and area labels as printed in the SI
meta <- tibble::tribble(
  ~dataset,                          ~name,                    ~cite,                   ~target,                      ~area,
  "16_timss_are_math",               "TIMSS 2023 UAE",         "mullis2024timss",       "mathematics score",          "school",
  "01_eusilc",                       "EU-SILC Austria",        "kreutzmann2019emdi",    "equivalised income",         "district",
  "11_wvs7_trust",                   "WVS wave 7",             "haerpfer2022wvs7",      "institutional trust",        "country",
  "03_pums_rent",                    "PUMS 2023 renters$^{\\dagger}$", "census2024pums", "rent",                      "state",
  "02_fdz_bee",                      "FDZ BEE 2017",           "fdz_bee2017",           "yield per hectare",          "federal state",
  "10_afrobarometer_lpi",            "Afrobarometer R9",       "afrobarometer2025r9",   "Lived Poverty Index",        "country",
  "15_pnadc_renda",                  "PNADC 2024$^{\\dagger}$", "ibge2025pnadc",        "log labour income",          "state $\\times$ urban/rural",
  "08_recs_electricity",             "RECS 2020",              "eia2022recs",           "electricity use",            "state",
  "04_pums_homevalue",               "PUMS 2023 owners$^{\\dagger}$", "census2024pums", "home value",                 "state",
  "14_lsms_pcexp",                   "LSMS-ISA v2.0",          "lsms2025isa",           "log per-capita consumption", "admin-1 region",
  "09_pisa_esp_math",                "PISA 2022 Spain",        "oecd2023pisa",          "mathematics score",          "autonomous community",
  "07_DHS_peru_hemoglobin_children", "Peru DHS 2009 children", "inei2010endes",         "hemoglobin",                 "department",
  "06_DHS_kenya_BMI_women",          "KDHS 2022 women",        "knbs2023kdhs",          "body mass index",            "county",
  "05_evs62",                        "EVS 1962/63",            "fdz_evs1963",           "net household income",       "state $\\times$ size class",
  "12_ces2024_policy",               "CES 2024",               "kuriwaki2025ces",       "policy conservatism",        "state",
  "13_envipe_gasto",                 "ENVIPE 2024",            "inegi2024envipe",       "log protection spending",    "state"
)
fmt_int <- function(x) formatC(x, format = "d", big.mark = "{,}")

# ---- Table S1: populations and design ---------------------------------------
dsg <- read.csv(file.path(AGG, "design_stats.csv"))
missing <- setdiff(meta$dataset, dsg$dataset)
if (length(missing)) stop("design_stats.csv lacks: ", paste(missing, collapse = ", "))
t1 <- meta |> inner_join(dsg, by = "dataset") |> arrange(desc(icc))
rows1 <- sprintf("%s \\citep{%s} & %s & %s & %d & %d & %s & %s & %.1f & %.1f & %d--%d & %s--%s & %.3f \\\\",
                 t1$name, t1$cite, t1$target, t1$area, t1$D, t1$D_oos, fmt_int(t1$N), fmt_int(t1$n),
                 t1$ni_mean, t1$ni_median, t1$ni_min, t1$ni_max, fmt_int(t1$Ni_min), fmt_int(t1$Ni_max),
                 t1$icc)
tab1 <- c(
  "\\begin{table}[H]",
  "\\centering",
  "\\scriptsize",
  "\\setlength{\\tabcolsep}{3.5pt}",
  "\\caption{Design-based populations under the common, deliberately small",
  "sampling design of this study.",
  "$D$ is the number of areas and ``OOS'' the number of areas that receive no",
  "sampled unit in any replication; $N$ and $n$ are population and sample",
  "size; $\\bar n_i$ and $\\tilde n_i$ are the mean and median per-area sample",
  "size over the in-sample areas, and the range columns give the per-area",
  "minima and maxima of the sample and population sizes; ICC is the intraclass",
  "correlation of the",
  "target in the fixed population from a linear mixed model with that",
  "population's covariates and an area random intercept. All quantities refer",
  "to the fixed populations and stored sample draws of this study. Rows",
  "are ordered by decreasing ICC, the canonical order of all figures and",
  "tables.}",
  "\\label{tab:datasets}",
  "\\begin{tabular}{@{}lllrrrrrrrrr@{}}",
  "\\toprule",
  "Population & Target & Area & $D$ & OOS & $N$ & $n$ & $\\bar n_i$ & $\\tilde n_i$ & $n_i$ range & $N_i$ range & ICC \\\\",
  "\\midrule",
  rows1,
  "\\bottomrule",
  "\\end{tabular}",
  "\\par\\smallskip",
  "{\\raggedright\\scriptsize $^{\\dagger}$\\,population reduced by stratified",
  "sampling within areas to below 50{,}000 units.\\par}",
  "\\end{table}")
writeLines(tab1, file.path(OUT, "table_S1_populations.tex"))

cat(rows1, sep = "\n")
cat("\nwritten:", file.path(OUT, "table_S1_populations.tex"), "\n")
