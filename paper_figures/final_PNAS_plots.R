# final_PNAS_plots.R
# All figures of the paper: main-text Figs. 1-5 and SI Figs. S1-S9, in PNAS
# format (column widths 8.7 / 11.4 / 17.8 cm, 7 pt base font, vector PDF).
# Figs. 1, 2, 3, 5, S1-S4, S8 and S9 are drawn from the aggregated tables;
# the implicit-shrinkage figures 4, S5-S7 from the unit-level samples and
# predictions of PUMS renters, CES and TIMSS (populations whose files are
# not present are skipped and their figure kept as deposited). File names
# carry the figure numbers of the paper (fig1_..fig5_, figS1_..figS9_).
# Inputs:  aggregated_results/tables/*.csv,
#          aggregated_results/plot_theme.R, functions/shrinkage_{effects,lmm_effects}.R,
#          datasets/{03_pums_rent,12_ces2024_policy,16_timss_are_math}/
# Output:  paper_figures/final_PNAS/fig<n>_*.pdf and figS<n>_*.pdf (+ .png previews),
#          aggregated_results/tables/shrinkage/<id>_slopes{,_lmm}.csv
# Run from the repository root.
suppressMessages({ library(dplyr); library(tidyr); library(ggplot2); library(purrr); library(tibble) })

REPO  <- "."
AGG   <- file.path(REPO, "aggregated_results/tables")
OUT   <- "paper_figures/final_PNAS"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
source(file.path(REPO, "aggregated_results/plot_theme.R"))  # method_meta, theme_base

CM <- 1 / 2.54
PNAS_1COL  <- 8.7  * CM
PNAS_15COL <- 11.4 * CM
PNAS_FULL  <- 17.8 * CM
BASE_PT    <- 7

# Shared performance palette: teal = good / better than the LMM,
# orange = poor / worse than the LMM.
PERF_TEAL         <- "#008B9A"
PERF_TEAL_LIGHT   <- "#b3dde2"
PERF_ORANGE       <- "#e08214"
PERF_ORANGE_LIGHT <- "#f6c98f"

theme_pnas <- function() {
  theme_base(base_size = BASE_PT) +
    theme(panel.grid.minor = element_blank(),
          strip.text = element_text(face = "bold", size = rel(1)),
          plot.margin = margin(2, 4, 2, 2))
}
save_pnas <- function(p, name, width, height) {
  ggsave(file.path(OUT, paste0(name, ".pdf")), p, width = width, height = height,
         units = "in", device = grDevices::cairo_pdf)
  ggsave(file.path(OUT, paste0(name, ".png")), p, width = width, height = height,
         units = "in", dpi = 300)
  cat(sprintf("%-28s %.1f x %.1f cm\n", name, width / CM, height / CM))
}

ds_lab <- c("01_eusilc"="EU-SILC", "02_fdz_bee"="FDZ BEE", "03_pums_rent"="PUMS rent",
  "04_pums_homevalue"="PUMS value", "05_evs62"="EVS 1962/63",
  "06_DHS_kenya_BMI_women"="KDHS women", "07_DHS_peru_hemoglobin_children"="Peru DHS",
  "08_recs_electricity"="RECS 2020", "09_pisa_esp_math"="PISA Spain",
  "10_afrobarometer_lpi"="Afrobarometer", "11_wvs7_trust"="WVS 7",
  "12_ces2024_policy"="CES 2024", "13_envipe_gasto"="ENVIPE", "14_lsms_pcexp"="LSMS-ISA",
  "15_pnadc_renda"="PNADC", "16_timss_are_math"="TIMSS UAE")
scope_lab <- c(insample = "A   Sampled (in-sample) areas",
               oos      = "B   Unsampled (out-of-sample) areas")

ds   <- read.csv(file.path(AGG, "dataset_stats.csv"))
rt   <- read.csv(file.path(AGG, "ratio_stats.csv"))

meth_lv <- c("Direct","LMM","RF","CatBoost","TabPFN","RF-ID","CatBoost-ID",
             "TabPFN-ID","MERF","CatBoost-EM","TabPFN-EM")

# ---- Fig. 1: accuracy heatmap, A in-sample / B out-of-sample ----------------
# Cell value = median RRMSE; cell colour = multiple of the best estimator in
# that population (row, per panel), best estimator boxed and bold. Rows are
# ordered by decreasing ICC (value in parentheses).
icc_map <- rt |> filter(scope == "insample") |>
  distinct(dataset, icc) |> arrange(icc)
row_lv_icc <- sprintf("%s (%.2f)", ds_lab[icc_map$dataset], icc_map$icc)
names(row_lv_icc) <- icc_map$dataset
d1 <- ds |>
  mutate(label = ifelse(canonical == "direct", "Direct", label),
         method_f = factor(label, levels = meth_lv),
         scope_f  = factor(scope_lab[scope], levels = scope_lab),
         ds_f = factor(row_lv_icc[dataset], levels = unname(row_lv_icc))) |>
  filter(!is.na(method_f)) |>
  group_by(scope, dataset) |>
  mutate(rel = median_rrmse / min(median_rrmse),
         best = median_rrmse == min(median_rrmse)) |>
  ungroup()
p1 <- ggplot(d1, aes(method_f, ds_f, fill = pmin(rel, 2))) +
  geom_tile(colour = "grey75", linewidth = 0.25) +
  geom_tile(data = subset(d1, best), fill = NA, colour = "black", linewidth = 0.45) +
  geom_text(aes(label = sprintf("%.2f", median_rrmse),
                fontface = ifelse(best, "bold", "plain"),
                colour = rel < 1.12), size = 1.75) +
  scale_colour_manual(values = c(`FALSE` = "black", `TRUE` = "white"), guide = "none") +
  scale_fill_gradientn(colours = c(PERF_TEAL, PERF_TEAL_LIGHT, "white",
                                   PERF_ORANGE_LIGHT, PERF_ORANGE),
                       values = c(0, 0.2, 0.5, 0.8, 1), limits = c(1, 2),
                       breaks = c(1, 1.25, 1.5, 1.75, 2),
                       labels = c("1 (best)", "1.25x", "1.5x", "1.75x", ">=2x"),
                       name = paste0("Each cell shows the median area-level empirical RRMSE (%) over the 50 Monte Carlo samples;\n",
                                     "the colour scales this value relative to the population's best estimator, whose cell is boxed.   ")) +
  facet_wrap(~scope_f, ncol = 2, scales = "free_x") +
  scale_x_discrete(position = "top") +
  labs(x = NULL, y = NULL) +
  theme_minimal(base_size = BASE_PT) +
  theme(axis.text.x.top = element_text(angle = 45, hjust = 0, vjust = 0),
        panel.grid = element_blank(),
        legend.position = "bottom",
        legend.key.height = unit(0.25, "cm"), legend.key.width = unit(1.0, "cm"),
        strip.text = element_text(face = "bold", size = rel(1), hjust = 0),
        plot.margin = margin(4, 30, 2, 2, "pt"))
save_pnas(p1, "fig1_rrmse_heatmap", PNAS_FULL, 10.5 / 2.54)

# ---- Fig. 2: forest plot by estimator ---------------------------------------
# One block per estimator with the 16 populations ordered by decreasing ICC.
# x = median of the per-area ratios RRMSE_i(est)/RRMSE_i(LMM) with paired
# bootstrap intervals (mc_paired_vs_ref_medratio.csv); colour = resolution
# status against the LMM. Intervals/points beyond CAP are drawn as arrows.
# In-sample version in the main text, out-of-sample version in the SI.
mr <- read.csv(file.path(AGG, "mc_paired_vs_ref_medratio.csv"))
canon_lab <- c(direct = "Direct", rf = "RF", catboost = "CatBoost",
  tabpfn = "TabPFN", rf_group = "RF-ID", catboost_group = "CatBoost-ID",
  tabpfn_group = "TabPFN-ID", merf = "MERF", catboost_em = "CatBoost-EM",
  tabpfn_em = "TabPFN-EM")
res_lv  <- c("more accurate than the LMM", "indistinguishable", "less accurate than the LMM")
res_col <- setNames(c(PERF_TEAL, "grey25", PERF_ORANGE), res_lv)
icc_map <- rt |> filter(scope == "insample") |> distinct(dataset, icc) |> arrange(icc)
row_lv  <- ds_lab[icc_map$dataset]           # ascending -> highest ICC on top
# footnote (Markdown via ggtext) listing the ICC order of the populations
footer  <- paste0("**populations per block, ordered by decreasing ICC",
                  " (top to bottom):**<br>",
                  paste(rev(unname(row_lv))[1:5], collapse = ", "), ",<br>",
                  paste(rev(unname(row_lv))[6:11], collapse = ", "), ",<br>",
                  paste(rev(unname(row_lv))[12:16], collapse = ", "), ".")
CAP <- 2.5
forest_lv <- c("Direct", setdiff(meth_lv, "Direct"))

make_forest <- function(scope_) {
  d2 <- mr |>
    filter(scope == scope_) |>
    mutate(label = canon_lab[canonical],
           method_f = factor(label, levels = forest_lv),
           ds_f = factor(ds_lab[dataset], levels = unname(row_lv)),
           res = factor(case_when(significant & ratio < 1 ~ res_lv[1],
                                  !significant            ~ res_lv[2],
                                  TRUE                    ~ res_lv[3]), levels = res_lv),
           capped = ratio_hi > CAP,
           lo = pmin(ratio_lo, CAP), hi = pmin(ratio_hi, CAP)) |>
    filter(!is.na(method_f))
  d2$method_f <- droplevels(d2$method_f)
  shade <- data.frame(method_f = factor(
    levels(d2$method_f)[seq(2, nlevels(d2$method_f), by = 2)], levels = levels(d2$method_f)))
  ggplot(d2, aes(ratio, ds_f, colour = res)) +
    geom_rect(data = shade, inherit.aes = FALSE, fill = "grey95",
              xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf) +
    geom_vline(xintercept = 1, linetype = "dashed", colour = "grey40", linewidth = 0.3) +
    geom_errorbarh(data = subset(d2, !capped), aes(xmin = lo, xmax = hi),
                   height = 0, linewidth = 0.45) +
    geom_segment(data = subset(d2, capped), aes(x = lo, xend = hi, yend = ds_f),
                 linewidth = 0.45,
                 arrow = arrow(length = unit(3, "pt"), type = "closed")) +
    geom_point(data = subset(d2, ratio <= CAP), size = 0.8) +
    scale_colour_manual(values = res_col, name = NULL,
                        labels = c("more accurate", "indistinguishable",
                                   "less accurate")) +
    scale_x_log10(breaks = c(0.5, 0.75, 1, 1.5, 2, 2.5),
                  labels = c("0.5", "0.75", "1", "1.5", "2", ">2.5"),
                  limits = c(NA, CAP + 0.02)) +
    facet_grid(method_f ~ ., switch = "y") +
    labs(x = paste0("per-area RRMSE ratio to the LMM, median over areas",
                    " (log scale)\n",
                    "← more accurate than the LMM      less accurate →"),
         y = NULL,
         caption = footer) +
    theme_minimal(base_size = BASE_PT) +
    theme(axis.text.y = element_blank(),
          axis.ticks.y = element_blank(),
          panel.grid.minor = element_blank(),
          panel.grid.major.y = element_blank(),
          strip.placement = "outside",
          strip.text.y.left = element_text(face = "bold", angle = 0, hjust = 1),
          panel.spacing.y = unit(0, "cm"),
          plot.caption = ggtext::element_markdown(size = 5.5, hjust = 0,
                                                  colour = "grey25"),
          legend.position = "bottom")
}
save_pnas(make_forest("insample"), "fig2_paired_forest_insample", PNAS_1COL, 19 / 2.54)
save_pnas(make_forest("oos"),      "figS1_paired_forest_oos",      PNAS_1COL, 18 / 2.54)

# ---- SI figure: counts of resolved comparisons against the LMM --------------
# Per estimator, the number of populations in which it is resolved better /
# indistinguishable / resolved worse than the LMM (as in Fig. 2).
d_cnt <- mr |>
  mutate(method_f = factor(canon_lab[canonical], levels = rev(forest_lv)),
         scope_f  = factor(scope_lab[scope], levels = scope_lab),
         res = factor(case_when(significant & ratio < 1 ~ res_lv[1],
                                !significant            ~ res_lv[2],
                                TRUE                    ~ res_lv[3]),
                      levels = rev(res_lv))) |>
  filter(!is.na(method_f)) |>
  count(scope_f, method_f, res_f = res)
bar_col <- setNames(c(PERF_TEAL, "grey85", PERF_ORANGE), res_lv)
p_cnt <- ggplot(d_cnt, aes(n, method_f, fill = res_f)) +
  geom_col(width = 0.72, colour = "white", linewidth = 0.3) +
  geom_text(aes(label = n, group = res_f,
                colour = res_f == res_lv[2]),
            position = position_stack(vjust = 0.5), size = 2.1,
            show.legend = FALSE) +
  scale_colour_manual(values = c(`TRUE` = "grey25", `FALSE` = "white")) +
  scale_fill_manual(values = bar_col, name = NULL, breaks = res_lv,
                    labels = c("more accurate (interval excludes 1)",
                               "indistinguishable",
                               "less accurate (interval excludes 1)")) +
  facet_wrap(~scope_f, ncol = 2) +
  scale_x_continuous(breaks = c(0, 4, 8, 12, 16),
                     expand = expansion(mult = c(0, 0.02))) +
  labs(x = "number of populations (median of per-area RRMSE ratios vs. the LMM)",
       y = NULL) +
  theme_minimal(base_size = BASE_PT) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank(),
        panel.grid.major.y = element_blank(),
        strip.text = element_text(face = "bold", hjust = 0))
save_pnas(p_cnt, "figS2_paired_counts", PNAS_FULL, 6.2 / 2.54)

# ---- SI figure: relative-bias heatmap ---------------------------------------
# Layout as Fig. 1: cell value = median RB (%), diverging colour scale around
# 0 (orange = over-, teal = underestimation), capped at +-10 %.
d4h <- ds |>
  mutate(label = ifelse(canonical == "direct", "Direct", label),
         method_f = factor(label, levels = meth_lv),
         scope_f  = factor(scope_lab[scope], levels = scope_lab),
         ds_f = factor(row_lv_icc[dataset], levels = unname(row_lv_icc))) |>
  filter(!is.na(method_f))
p4 <- ggplot(d4h, aes(method_f, ds_f, fill = pmax(pmin(median_rb, 10), -10))) +
  geom_tile(colour = "grey75", linewidth = 0.25) +
  geom_text(aes(label = sprintf("%.1f", median_rb),
                colour = abs(median_rb) > 7), size = 1.9) +
  scale_colour_manual(values = c(`FALSE` = "black", `TRUE` = "white"),
                      guide = "none") +
  scale_fill_gradientn(colours = c(PERF_TEAL, "white", PERF_ORANGE),
                       values = c(0, 0.5, 1), limits = c(-10, 10),
                       breaks = c(-10, -5, 0, 5, 10),
                       labels = c("<= -10", "-5", "0", "+5", ">= +10"),
                       name = paste0("Each cell shows the median area-level relative bias (%) over the 50 Monte Carlo samples;\n",
                                     "orange = overestimation, teal = underestimation, white = unbiased.   ")) +
  facet_wrap(~scope_f, ncol = 2, scales = "free_x") +
  scale_x_discrete(position = "top") +
  labs(x = NULL, y = NULL) +
  theme_minimal(base_size = BASE_PT) +
  theme(axis.text.x.top = element_text(angle = 45, hjust = 0, vjust = 0),
        panel.grid = element_blank(),
        legend.position = "bottom",
        legend.key.height = unit(0.25, "cm"), legend.key.width = unit(1.0, "cm"),
        strip.text = element_text(face = "bold", size = rel(1), hjust = 0),
        plot.margin = margin(4, 30, 2, 2, "pt"))
save_pnas(p4, "figS9_rb_heatmap", PNAS_FULL, 10.5 / 2.54)

# ---- SI figure: log-shift robustness heatmap --------------------------------
# Median RRMSE of the LMM, the LMM with log-shift transformation and TabPFN-ID
# (aggregated_results/tables/logshift_stats.csv, values at two decimals
# as printed), three columns per panel, A in-sample / B out-of-sample. Cell
# colour = multiple of the population's best estimator in Fig. 1 (eleven
# estimators, per panel), so that the LMM and TabPFN-ID cells carry the same
# colour as in Fig. 1; a cell is boxed and bold only if it is also the best
# against all estimators of Fig. 1.
ls_lab <- c(lmm = "LMM", lmm_logshift = "LMM, log-shift", tabpfn_id = "TabPFN-ID")
fig1_min <- d1 |> group_by(scope, dataset) |>
  summarise(fig1_min = min(median_rrmse), .groups = "drop")
dl <- read.csv(file.path(AGG, "logshift_stats.csv")) |>
  filter(method %in% names(ls_lab)) |>
  mutate(median_rrmse = round(median_rrmse, 2),
         method_f = factor(ls_lab[method], levels = unname(ls_lab)),
         scope_f  = factor(scope_lab[scope], levels = scope_lab),
         ds_f     = factor(row_lv_icc[dataset], levels = unname(row_lv_icc))) |>
  left_join(fig1_min, by = c("scope", "dataset"))
stopifnot(nrow(dl) == 96, !anyNA(dl$fig1_min))
# consistency: LMM and TabPFN-ID equal their Fig. 1 values at two decimals
chk <- dl |> filter(method != "lmm_logshift") |>
  inner_join(d1 |> filter(label %in% c("LMM", "TabPFN-ID")) |>
               transmute(scope, dataset, method_f = factor(label, levels = unname(ls_lab)),
                         fig1_val = median_rrmse),
             by = c("scope", "dataset", "method_f")) |>
  filter(abs(median_rrmse - round(fig1_val, 2)) > 0.005)
if (nrow(chk)) { print(chk); stop("logshift_stats.csv and dataset_stats.csv differ") }
dl <- dl |>
  group_by(scope, dataset) |>
  mutate(rel  = pmax(median_rrmse / fig1_min, 1),
         best = median_rrmse <= round(fig1_min, 2) + 1e-9 &
                median_rrmse == min(median_rrmse)) |>
  ungroup() |>
  # fixed drawing order (population by decreasing ICC, panel, column) so that
  # the rendered file is reproducible
  arrange(desc(as.integer(ds_f)), scope, method_f)
pL <- ggplot(dl, aes(method_f, ds_f, fill = pmin(rel, 2))) +
  geom_tile(colour = "grey75", linewidth = 0.25) +
  geom_tile(data = subset(dl, best), fill = NA, colour = "black", linewidth = 0.45) +
  geom_text(aes(label = sprintf("%.2f", median_rrmse),
                fontface = ifelse(best, "bold", "plain"),
                colour = rel < 1.12), size = 1.75) +
  scale_colour_manual(values = c(`FALSE` = "black", `TRUE` = "white"), guide = "none") +
  scale_fill_gradientn(colours = c(PERF_TEAL, PERF_TEAL_LIGHT, "white",
                                   PERF_ORANGE_LIGHT, PERF_ORANGE),
                       values = c(0, 0.2, 0.5, 0.8, 1), limits = c(1, 2),
                       breaks = c(1, 1.25, 1.5, 1.75, 2),
                       labels = c("1 (best)", "1.25x", "1.5x", "1.75x", ">=2x"),
                       name = paste0("Each cell shows the median area-level empirical RRMSE (%) over the 50 Monte Carlo\n",
                                     "samples; the colour scales this value relative to the population's best estimator in Fig. 1.\n",
                                     "A boxed cell is the best of all estimators, the log-shift LMM included.")) +
  facet_wrap(~scope_f, ncol = 2) +
  scale_x_discrete(position = "top") +
  labs(x = NULL, y = NULL) +
  theme_minimal(base_size = BASE_PT) +
  theme(axis.text.x.top = element_text(angle = 45, hjust = 0, vjust = 0),
        panel.grid = element_blank(),
        legend.position = "bottom",
        legend.title.position = "top",
        legend.key.height = unit(0.25, "cm"), legend.key.width = unit(1.0, "cm"),
        legend.title = element_text(size = rel(0.9)),
        strip.text = element_text(face = "bold", size = rel(1), hjust = 0),
        strip.clip = "off",
        plot.margin = margin(4, 40, 2, 2, "pt"))
save_pnas(pL, "figS4_logshift_heatmap", PNAS_15COL, 9.5 / 2.54)

# ---- Fig. 3: ID/EM ratio against ICC ----------------------------------------
# Median of the per-area ratios RRMSE_i(ID)/RRMSE_i(EM) with paired bootstrap
# intervals (ratio_pairs_medratio.csv); panels A in-sample / B out-of-sample.
rp <- read.csv(file.path(AGG, "ratio_pairs_medratio.csv"))
icc_join <- rt |> filter(scope == "insample") |> distinct(dataset, icc)
pair_lab <- c(rf_id_em = "RF-ID / MERF",
              catboost_id_em = "CatBoost-ID / CatBoost-EM",
              tabpfn_id_em = "TabPFN-ID / TabPFN-EM")
pair_cols   <- setNames(c("#CC7052", "#AE6987", "#60A1AA"), unname(pair_lab))
pair_shapes <- setNames(c(17, 15, 19), unname(pair_lab))
d5 <- rp |> filter(pair %in% names(pair_lab)) |>
  mutate(pair_label = factor(pair_lab[pair], levels = unname(pair_lab)),
         scope_f = factor(scope_lab[scope], levels = scope_lab)) |>
  left_join(icc_join, by = "dataset")
# Spearman coefficients per learner and panel, annotated in the line colour
ann5 <- d5 |> group_by(scope_f, pair_label) |>
  summarise(rho = cor(icc, ratio, method = "spearman"), .groups = "drop") |>
  mutate(y = c(2.85, 2.45, 2.1)[as.integer(pair_label)],
         lab = sprintf("ρ = %+.2f", rho))
p5 <- ggplot(d5, aes(icc, ratio, colour = pair_label, shape = pair_label)) +
  geom_text(data = ann5, aes(x = Inf, y = y, label = lab, colour = pair_label),
            hjust = 1.05, size = 2.3, show.legend = FALSE,
            inherit.aes = FALSE) +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40",
             linewidth = 0.3) +
  geom_errorbar(aes(ymin = ratio_lo, ymax = ratio_hi),
                width = 0, linewidth = 0.3, alpha = 0.55) +
  geom_point(size = 1.3) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.45) +
  scale_colour_manual(values = pair_cols, name = NULL) +
  scale_shape_manual(values = pair_shapes, name = NULL) +
  scale_y_log10() +
  facet_wrap(~scope_f, ncol = 2) +
  labs(x = "ICC of the target conditional on the covariates",
       y = "median per-area RRMSE ratio -ID / -EM (log scale)") +
  theme_pnas() +
  theme(legend.position = "right",
        legend.key.size = unit(0.8, "lines"),
        strip.text = element_text(face = "bold", hjust = 0))
save_pnas(p5, "fig3_icc_ratio", PNAS_FULL, 6.0 / 2.54)


# ---- SI figure: -ID and -EM against the naive learner -----------------------
# Median of the per-area ratios RRMSE_i(-ID)/RRMSE_i(naive) and
# RRMSE_i(-EM)/RRMSE_i(naive) per population against the ICC. Panels:
# A/B = in-sample (-ID, -EM), C/D = out-of-sample (-ID, -EM).
learner_of <- c(rf_id_naive = "RF", catboost_id_naive = "CatBoost", tabpfn_id_naive = "TabPFN",
                rf_em_naive = "RF", catboost_em_naive = "CatBoost", tabpfn_em_naive = "TabPFN")
treat_of   <- c(rf_id_naive = "ID", catboost_id_naive = "ID", tabpfn_id_naive = "ID",
                rf_em_naive = "EM", catboost_em_naive = "EM", tabpfn_em_naive = "EM")
panel_lab  <- c(ID.insample = "A   -ID / naive, sampled areas",
                EM.insample = "B   -EM / naive, sampled areas",
                ID.oos      = "C   -ID / naive, unsampled areas",
                EM.oos      = "D   -EM / naive, unsampled areas")
learner_cols   <- setNames(c("#CC7052", "#AE6987", "#60A1AA"), c("RF", "CatBoost", "TabPFN"))
learner_shapes <- setNames(c(17, 15, 19), c("RF", "CatBoost", "TabPFN"))

dN <- rp |> filter(pair %in% names(learner_of)) |>
  mutate(learner = factor(learner_of[pair], levels = names(learner_cols)),
         panel_f = factor(panel_lab[paste(treat_of[pair], scope, sep = ".")],
                          levels = unname(panel_lab))) |>
  left_join(icc_join, by = "dataset")
annN <- dN |> group_by(panel_f, learner) |>
  summarise(rho = cor(icc, ratio, method = "spearman"), .groups = "drop") |>
  mutate(vj = c(1.6, 3.1, 4.6)[as.integer(learner)],
         lab = sprintf("ρ = %+.2f", rho))
pN <- ggplot(dN, aes(icc, ratio, colour = learner, shape = learner)) +
  geom_text(data = annN, aes(x = Inf, y = Inf, label = lab, colour = learner, vjust = vj),
            hjust = 1.05, size = 2.3, show.legend = FALSE, inherit.aes = FALSE) +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40", linewidth = 0.3) +
  geom_errorbar(aes(ymin = ratio_lo, ymax = ratio_hi), width = 0, linewidth = 0.3, alpha = 0.55) +
  geom_point(size = 1.3) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.45) +
  scale_colour_manual(values = learner_cols, name = NULL) +
  scale_shape_manual(values = learner_shapes, name = NULL) +
  scale_y_log10() +
  facet_wrap(~panel_f, ncol = 2, scales = "free_y") +
  labs(x = "ICC of the target conditional on the covariates",
       y = "median per-area RRMSE ratio to the naive learner (log scale)") +
  theme_pnas() +
  theme(legend.position = "bottom",
        strip.text = element_text(face = "bold", hjust = 0)) +
  guides(colour = guide_legend(nrow = 1))
save_pnas(pN, "figS3_naive_ratio", PNAS_FULL, 14.0 / 2.54)

# ---- Fig. 5: accuracy relative to the LMM by area sample size ---------------
# Source: aggregated_results/tables/areasize_dataset_medians.csv
# (aggregated_results/areasize_stats.R): per population and size class
# the median over its areas of the per-area RMSE ratio to the LMM for
# TabPFN-ID, MERF and CatBoost-EM (the RMSE and RRMSE ratios of an area are
# identical). Boxes over the populations represented in a class.
dm <- read.csv(file.path(AGG, "areasize_dataset_medians.csv"), encoding = "UTF-8")
size_lv <- c("0 (unsampled)", "≤ 3", "4–5", "6–10", "11–20", "> 20")
meth5   <- c("TabPFN-ID", "MERF", "CatBoost-EM")
d6 <- dm |>
  mutate(size_f = factor(size_f, levels = size_lv),
         method_f = factor(method_f, levels = meth5))
stopifnot(!anyNA(d6$size_f), !anyNA(d6$method_f))
cls6 <- d6 |> filter(method_f == meth5[1]) |> count(size_f, name = "n_ds")
x_lab6 <- setNames(sprintf("%s\n%d populations", cls6$size_f, cls6$n_ds),
                   as.character(cls6$size_f))
p6 <- ggplot(d6, aes(size_f, median_ratio, fill = method_f)) +
  geom_hline(yintercept = 1, linetype = "dashed", colour = "grey40", linewidth = 0.3) +
  geom_boxplot(outlier.shape = NA, position = position_dodge(width = 0.78),
               width = 0.68, linewidth = 0.3, alpha = 0.9, colour = "grey25") +
  geom_point(aes(group = method_f),
             position = position_jitterdodge(jitter.width = 0.22, jitter.height = 0,
                                             dodge.width = 0.78, seed = 42),
             size = 1.0, alpha = 0.7, colour = "grey15", shape = 16) +
  scale_fill_manual(values = method_colour_vals[meth5], name = NULL) +
  scale_x_discrete(labels = x_lab6) +
  scale_y_log10(breaks = c(0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.2, 1.5, 2, 3)) +
  labs(x = expression("Area sample size" ~ n[i] ~ "(0 = unsampled area)"),
       y = "per-area RRMSE ratio to the LMM,\nmedian over areas (log scale)") +
  theme_pnas() +
  theme(axis.text.x = element_text(hjust = 0.5),
        legend.position = "right",
        legend.key.size = unit(0.8, "lines"))
save_pnas(p6, "fig5_samplesize_ratio", PNAS_FULL, 6.0 / 2.54)

# Numbers quoted with Fig. 5: ratio to the LMM of the "typical" population per
# size class, i.e. the median over populations of the per-population medians.
cat("\n--- Fig. 5: median over populations of the per-population median ratio to the LMM ---\n")
print(d6 |> group_by(size_f, method_f) |>
        summarise(n_datasets = n(), typical_ratio = round(median(median_ratio), 3), .groups = "drop") |>
        pivot_wider(names_from = method_f, values_from = typical_ratio) |>
        as.data.frame(), row.names = FALSE)

# ---- Figs. 4, S5-S7: implicit shrinkage per population ----------------------
# For PUMS renters (Fig. 4: n_i <= 5 group only, 1x3 panels; Fig. S5: all n_i
# groups, 3x3), CES 2024 (Fig. S6) and TIMSS UAE (Fig. S7): implied against
# raw area effect of each -ID learner, one point per in-sample area and Monte
# Carlo sample (functions/shrinkage_effects.R), least-squares fit in red with
# slope and R^2, and the LMM's shrinkage factor from the same construction as
# a grey line (functions/shrinkage_lmm_effects.R). Needs the unit-level files
# of the population; populations without them are skipped and their figure
# stays as deposited (TIMSS; PNG only, the vector PDF would expose the
# per-school points of a non-redistributable population). The slopes behind
# the figures are written to
# aggregated_results/tables/shrinkage/<id>_slopes{,_lmm}.csv.
source("functions/shrinkage_effects.R")
source("functions/shrinkage_lmm_effects.R")
SHR_TAB <- file.path(AGG, "shrinkage")
dir.create(SHR_TAB, showWarnings = FALSE, recursive = TRUE)
SI_TEXTWIDTH_IN <- 172 / 25.4         # print width of the SI Appendix (A4, 1.9 cm margins)
LMM_GREY <- "grey50"

shrinkage_panel <- function(eff, lab, lmm_sl, lmm_lab, facet, alpha, size,
                            xlab, ylab, base_size, margins = FALSE) {
  p <- ggplot(eff, aes(raw, implied)) +
    geom_hline(yintercept = 0, colour = "grey85", linewidth = 0.3) +
    geom_vline(xintercept = 0, colour = "grey85", linewidth = 0.3) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed",
                colour = "grey40", linewidth = 0.35) +
    geom_point(aes(colour = learner), alpha = alpha, size = size,
               show.legend = FALSE) +
    scale_colour_manual(values = shrinkage_id_cols) +
    geom_abline(data = lmm_sl, aes(slope = slope, intercept = intercept),
                colour = LMM_GREY, linewidth = 0.5) +
    geom_smooth(method = "lm", se = FALSE, linewidth = 0.5, colour = "#C0392B") +
    facet +
    geom_text(data = lab, aes(label = txt), x = -Inf, y = Inf, hjust = -0.08,
              vjust = 1.25, size = 2.4, colour = "#C0392B", lineheight = 0.95) +
    geom_text(data = lmm_lab, aes(label = txt), x = Inf, y = -Inf, hjust = 1.08,
              vjust = -0.7, size = 2.4, colour = LMM_GREY) +
    labs(x = xlab, y = ylab) +
    theme_base(base_size = base_size) +
    theme(legend.position = "none", panel.grid.minor = element_blank())
  if (margins) p <- p + theme(plot.margin = margin(2, 4, 2, 2))
  p
}
save_shrinkage <- function(p, name, width, height, dpi) {
  ggsave(file.path(OUT, paste0(name, ".pdf")), p, width = width, height = height,
         units = "in", device = grDevices::cairo_pdf)
  ggsave(file.path(OUT, paste0(name, ".png")), p, width = width, height = height,
         units = "in", dpi = dpi)
  cat(sprintf("%-28s %.1f x %.1f cm\n", name, width / CM, height / CM))
}

# name_si:    SI layout (print width 172 mm, 8 pt, PNG at 400 dpi), Figs. S6, S7
# name_full:  PNAS full-width version with all n_i groups, Fig. S5 (PUMS)
# name_small: main-text version, first n_i group only, Fig. 4 (PUMS)
make_shrinkage_figures <- function(id, name_si = NULL, name_full = NULL,
                                   name_small = NULL, unit = "") {
  dsdir <- file.path("datasets", id)
  if (!shrinkage_has_data(dsdir)) {
    message(id, ": unit-level files not present, shrinkage figure(s) kept as deposited.")
    return(invisible(NULL))
  }
  eff <- shrinkage_effects(dsdir)
  cat(id, ": in-sample areas:", n_distinct(eff$area), " n_i range:", range(eff$n_i), "\n")
  # n_i groups only if n_i varies; single stratum otherwise (TIMSS, n_i = 2/3)
  if (length(unique(eff$n_i)) >= 3) {
    eff$ni_grp <- droplevels(shrinkage_groups(eff$n_i))
  } else {
    eff$ni_grp <- factor(sprintf("n_i = %s", paste(sort(unique(eff$n_i)), collapse = "/")))
  }
  slopes <- eff |> group_by(learner, ni_grp) |>
    group_modify(~ shrinkage_fit_stats(.x)) |> ungroup() |> select(-intercept)
  write.csv(slopes, file.path(SHR_TAB, paste0(id, "_slopes.csv")), row.names = FALSE)
  lab <- slopes |> mutate(txt = sprintf("slope %.2f\nR2 %.2f", slope, r2))

  lmm_eff <- lmm_shrinkage_effects(dsdir, file.path(dsdir, "settings.R"))
  lmm_eff$ni_grp <- if (nlevels(eff$ni_grp) > 1) {
    factor(shrinkage_groups(lmm_eff$n_i), levels = levels(eff$ni_grp))
  } else factor(levels(eff$ni_grp)[1], levels = levels(eff$ni_grp))
  lmm_slopes <- lmm_shrinkage_slopes(lmm_eff)
  lmm_lab    <- lmm_slopes |> mutate(txt = sprintf("LMM slope %.2f", slope))
  write.csv(lmm_slopes, file.path(SHR_TAB, paste0(id, "_slopes_lmm.csv")), row.names = FALSE)
  cat("\nimplied-vs-raw slopes (a value < 1 = shrinkage):\n")
  print(as.data.frame(slopes |> mutate(across(where(is.numeric), ~ round(.x, 3)))), row.names = FALSE)
  print(as.data.frame(lmm_slopes |> mutate(across(where(is.numeric), ~ round(.x, 3)))), row.names = FALSE)

  xlab_full <- "raw area effect (sample mean of y minus sample mean of naive prediction)"
  ylab_full <- "implied area effect of the -ID variant"
  if (!is.null(name_si)) {
    pp <- shrinkage_panel(eff, lab, lmm_slopes, lmm_lab, facet_grid(ni_grp ~ learner),
                          alpha = 0.25, size = 0.45, xlab_full, ylab_full, base_size = 8)
    save_shrinkage(pp, name_si, SI_TEXTWIDTH_IN, 1.1 + 1.45 * nlevels(eff$ni_grp), dpi = 400)
  }
  if (!is.null(name_full)) {
    pp <- shrinkage_panel(eff, lab, lmm_slopes, lmm_lab, facet_grid(ni_grp ~ learner),
                          alpha = 0.25, size = 0.45, xlab_full, ylab_full,
                          base_size = BASE_PT, margins = TRUE)
    save_shrinkage(pp, name_full, PNAS_FULL, 5.4, dpi = 300)
  }
  if (!is.null(name_small)) {
    grp1 <- levels(eff$ni_grp)[1]
    ps <- shrinkage_panel(eff |> filter(ni_grp == grp1), lab |> filter(ni_grp == grp1),
                          lmm_slopes |> filter(ni_grp == grp1), lmm_lab |> filter(ni_grp == grp1),
                          facet_grid(. ~ learner), alpha = 0.3, size = 0.5,
                          paste0("raw area effect (sample mean of y minus sample mean of naive prediction",
                                 if (nzchar(unit)) paste0(", ", unit), ")"),
                          paste0("implied area effect\nof the -ID variant",
                                 if (nzchar(unit)) paste0(" (", unit, ")")),
                          base_size = BASE_PT, margins = TRUE)
    save_shrinkage(ps, name_small, PNAS_FULL, 2.6, dpi = 300)
  }
  invisible(eff)
}

make_shrinkage_figures("03_pums_rent", name_full = "figS5_pums_shrinkage",
                       name_small = "fig4_pums_shrinkage", unit = "USD")
make_shrinkage_figures("12_ces2024_policy", name_si = "figS6_ces_shrinkage")
make_shrinkage_figures("16_timss_are_math", name_si = "figS7_timss_shrinkage")

# ---- Fig. S8: calibration of the implicit shrinkage against the LMM ---------
# Source: aggregated_results/tables/shrinkage_calibration.csv
# (aggregated_results/shrinkage_calibration.R): per population, size group and
# -ID learner the learner's slope against the LMM's slope; one panel per
# learner, one point per population x group, shape = group.
sc <- read.csv(file.path(AGG, "shrinkage_calibration.csv")) |>
  mutate(learner = factor(learner, levels = names(shrinkage_pairs)),
         ni_grp  = factor(ni_grp, levels = c("n_i <= 5", "n_i 6-14", "n_i >= 15")))
stopifnot(!anyNA(sc$learner), !anyNA(sc$ni_grp))
dev_sc <- sc |> mutate(dev = slope - lmm_slope) |> group_by(learner) |>
  summarise(n = n(), mean_abs_dev = mean(abs(dev)), median_dev = median(dev),
            n_within_0.1 = sum(abs(dev) <= 0.1), median_r2 = median(r2), .groups = "drop")
cat("\n--- Fig. S8: deviation of the learner slope from the LMM slope ---\n")
print(as.data.frame(dev_sc |> mutate(across(where(is.numeric), ~ round(.x, 3)))), row.names = FALSE)
lab_sc <- dev_sc |> mutate(txt = sprintf("mean |diff| %.2f", mean_abs_dev))
lim_sc <- c(0, max(1, max(sc$slope, sc$lmm_slope)))
pS <- ggplot(sc, aes(lmm_slope, slope, colour = learner, shape = ni_grp)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey40", linewidth = 0.35) +
  geom_point(size = 1.6, alpha = 0.85) +
  geom_text(data = lab_sc, aes(label = txt), x = 0.02, y = lim_sc[2] * 0.97, hjust = 0, vjust = 1,
            size = 2.4, colour = "grey25", inherit.aes = FALSE) +
  scale_colour_manual(values = shrinkage_id_cols, guide = "none") +
  scale_shape_manual(values = c("n_i <= 5" = 16, "n_i 6-14" = 17, "n_i >= 15" = 15),
                     name = "per-area sample size",
                     labels = c(expression(n[i] <= 5), expression(n[i] ~ "6–14"), expression(n[i] >= 15))) +
  coord_equal(xlim = lim_sc, ylim = lim_sc) +
  facet_wrap(~ learner, ncol = 3) +
  labs(x = "shrinkage factor of the LMM (slope of û on the raw effect)",
       y = "implicit shrinkage factor of the -ID variant\n(slope of implied on raw effect)") +
  theme_base(base_size = BASE_PT) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"), plot.margin = margin(2, 4, 2, 2))
save_pnas(pS, "figS8_shrinkage_calibration", PNAS_FULL, 7.6 / 2.54)

# Numbers quoted in the Results with Fig. S3: in how many populations the
# identifier (-ID) or the random effect (-EM) improves on the naive learner,
# the range of the ratios, and their Spearman correlation with the ICC.
statsN <- dN |> group_by(scope, pair) |>
  summarise(n_better = sum(ratio < 1), n_resolved_better = sum(ratio_hi < 1),
            n_worse = sum(ratio > 1), n_resolved_worse = sum(ratio_lo > 1),
            min_ratio = min(ratio), max_ratio = max(ratio),
            rho_icc = cor(icc, ratio, method = "spearman"), .groups = "drop")
cat("\n--- -ID / -EM against the naive learner (n = 16 populations per row) ---\n")
print(as.data.frame(statsN |> mutate(across(where(is.numeric), ~ round(.x, 2)))), row.names = FALSE)

cat("\nDone. Output in", OUT, "\n")
