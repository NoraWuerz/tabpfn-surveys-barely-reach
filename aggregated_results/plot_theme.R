# plot_theme.R
# Shared ggplot2 theme and the canonical estimator taxonomy (labels, families,
# variants, colours) used by the aggregation and figure scripts.
# Requires: nothing (sourced by aggregated_results/*.R and
#           paper_figures/final_PNAS_plots.R after ggplot2 and dplyr are loaded).
# Provides: theme_base() (ggplot2 base theme; theme_pnas() in final_PNAS_plots.R
#           adds the PNAS font size and margins),
#           method_meta (canonical id, label, family, variant, colour),
#           method_colour_vals, resolve_method().

theme_base <- function(base_size = 9, base_family = "") {
  theme_minimal(base_size = base_size, base_family = base_family) +
    theme(
      axis.text.x     = element_text(hjust = 1),
      legend.position = "bottom",
      legend.text     = element_text(size = rel(0.9)),
      legend.title    = element_text(size = rel(0.9)),
      plot.title      = element_text(face = "bold", size = rel(1.05)),
      strip.text      = element_text(face = "bold", size = rel(1))
    )
}

# ---- Canonical estimator taxonomy -------------------------------------------
# One row of label / family / variant / colour per canonical estimator id.
# Each script maps its result file names to these ids via an alias table.
method_meta <- tibble::tribble(
  ~canonical,       ~label,        ~family,    ~variant, ~color_can,
  "lmm",            "LMM",         "lmm",      "EM",     "#888888",
  "rf",             "RF",          "rf",       "Naive",  "#A22200",
  "rf_group",       "RF-ID",       "rf",       "ID",     "#CC7052",
  "merf",           "MERF",        "rf",       "EM",     "#DD937B",
  "catboost",       "CatBoost",    "catboost", "Naive",  "#723351",
  "catboost_group", "CatBoost-ID", "catboost", "ID",     "#AE6987",
  "catboost_em",    "CatBoost-EM", "catboost", "EM",     "#E9B1C8",
  "tabpfn",         "TabPFN",      "tabpfn",   "Naive",  "#256e7a",
  "tabpfn_group",   "TabPFN-ID",   "tabpfn",   "ID",     "#60A1AA",
  "tabpfn_em",      "TabPFN-EM",   "tabpfn",   "EM",     "#B4D5DA"
)

method_colour_vals <- setNames(method_meta$color_can, method_meta$label)

# Map the `method` column via an alias table (result file name -> canonical id)
# to the taxonomy (method_f, variant_f, colour). Stops on unmapped names
# instead of silently dropping rows.
resolve_method <- function(data, alias, meta = method_meta) {
  unmapped <- setdiff(unique(data$method), names(alias))
  if (length(unmapped) > 0) {
    stop("resolve_method(): unmapped method keys, extend the alias table: ",
         paste(unmapped, collapse = ", "))
  }
  data |>
    dplyr::mutate(canonical = alias[method]) |>
    dplyr::left_join(meta, by = "canonical") |>
    dplyr::mutate(method_f  = factor(label, levels = meta$label),
                  variant_f = factor(variant, levels = unique(meta$variant)))
}
