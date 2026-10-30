# Can a model pretrained on synthetic data accurately estimate statistics for places that surveys barely reach?

Replication package for the design-based simulation study. Sixteen fixed
populations built from survey microdata, 50 stored sample draws each, eleven
estimators of the area mean, and the code that produces every figure, the
computed SI table and the SI datasets of the paper.

## Layout

```
run_model.R                  run one or more R estimators for one population
run_postprocess.R            merge estimator outputs into merged/results.rds
tabpfn_login.py              one-time acceptance of the TabPFN-3.5 licence
pipeline/                    shared steps: packages, population/sample generation,
                             loading, merging
functions/                   tuning helpers (ranger, CatBoost), TabPFN-EM loop,
                             raw/implied area effects and LMM shrinkage factors
                             for the implicit-shrinkage figures
models/                      the eleven estimators (see table below) and the
                             LMM with log-shift transformation (SI only)
datasets/<id>/               one folder per population
  settings.R                 target, area, covariates, formulas, seed, and the
                             commented block that generated the sample draws
  settings.json              the same definitions for the Python scripts
  ACCESS.md                  data provider, licence, what is deposited
  data/prepare_source.R      source file -> prepared extract
  data/*.parquet             prepared extract, fixed population and the 50
                             sample draws (tier "population" only)
  results/*.parquet          unit-level predictions, one file per estimator
                             (tier "population" only)
aggregated_results/          cross-population aggregation: area-level
                             statistics, paired bootstrap, ID/EM ratios,
                             accuracy by area sample size, design statistics,
                             log-shift comparison, shrinkage calibration
  tables/                    the aggregated CSV tables behind all figures,
                             Table S1 and the numbers quoted in the Results
                             (shrinkage/ for the slopes printed in Figs. 4
                             and S5-S7)
paper_figures/               scripts and output for Figs. 1-5, S1-S9,
                             Table S1, Datasets S1-S4
  final_PNAS/                the figures (PDF + PNG, named by figure number;
                             Fig. S7 as PNG only, see below)
  tables/                    Table S1 as LaTeX
  SI_datasets/               Datasets S1-S4
pyproject.toml, uv.lock      Python environment (TabPFN, torch)
```

## Estimators

| Estimator (paper) | Script | Output file |
|---|---|---|
| Direct | `models/direct.R` | `direct.parquet` |
| LMM (BHF) | `models/lmm.R` | `lmm.parquet` |
| RF | `models/rf.R` | `rf.parquet` |
| RF-ID | `models/rf_id.R` | `rf_id.parquet` |
| MERF | `models/merf.R` | `merf.parquet` |
| CatBoost | `models/catboost.R` | `catboost.parquet` |
| CatBoost-ID | `models/catboost_id.R` | `catboost_id.parquet` |
| CatBoost-EM | `models/catboost_em.R` | `catboost_em.parquet` |
| TabPFN | `models/tabpfn_naive.py` | `tabpfn.parquet` |
| TabPFN-ID | `models/tabpfn_id.py` | `tabpfn_id.parquet` |
| TabPFN-EM | `models/tabpfn_em.R` | `tabpfn_em.parquet` |
| LMM log-shift (SI only) | `models/lmm_logshift.R` | `lmm_logshift.parquet` |

All estimators write one row per population unit and Monte Carlo sample with
the columns `sim_id, unit_id, area, y_true, pred`. The LMM with log-shift
transformation (`saeTrafo::NER_Trafo`, Wuerz et al. 2022) is not one of the
eleven estimators of the main text; it appears only in the SI comparison with
the LMM (Fig. S4) and uses `functions/sae_trafo_helpers.R`.

## Data access tiers

What each population folder contains follows the provider's terms
(SI Appendix, Table S3 of the paper). Each `datasets/<id>/ACCESS.md` gives the
full citation of the source, the download or access address, the terms of use
with the required acknowledgement, and the rebuild steps.

- **population** (01 EU-SILC, 03/04 PUMS, 08 RECS, 12 CES, 13 ENVIPE,
  14 LSMS-ISA, 15 PNADC): sources in the public domain or under licences that
  permit redistribution. Prepared extract, fixed population, the 50 sample
  draws and the outputs of all eleven estimators plus the log-shift LMM are
  included.
- **script** (10 Afrobarometer, 16 TIMSS): open download without
  registration, but redistribution is not covered by the provider's terms
  (Afrobarometer: copyright, redistribution not stated; TIMSS: written
  permission of the IEA required). Preparation code and download instructions
  (URL and file name) only.
- **code** (02 BEE, 05 EVS, 06 KDHS, 07 Peru DHS, 09 PISA, 11 WVS):
  redistribution prohibited. Preparation code and access instructions only.

For the script and code tiers no unit-level file is deposited: neither the
prepared population, the sample draws nor the stored predictions, which
contain the original target value of every population unit. Their results
enter the deposit only in aggregated form (`aggregated_results/tables/`,
Datasets S1-S4). To rebuild such a population, follow `ACCESS.md`: obtain the
source file, run `data/prepare_source.R`, copy its output to
`datasets/<id>/data/`, then run the commented sampling block in `settings.R`
followed by `pipeline/01_data.R`; the seeds in `settings.R` reproduce the
stored draws exactly. This chain was re-run from the raw files for the eight
populations of these tiers and reproduces the prepared extracts, populations
and sample draws used in the paper.

Note on 05 EVS: the population of the paper excludes the five households
with a negative net income (32,489 -> 32,484 households; SI Appendix,
Section S3). The filter is part of the sampling block in
`datasets/05_evs62/settings.R`.

## Reproducing the results

1. R packages are loaded (and installed if missing) by `pipeline/00_header.R`
   via `pacman`. The Python environment for TabPFN is created with
   `uv sync` from `pyproject.toml` / `uv.lock` (TabPFN 9.0, weights
   TabPFN-3.5, run locally on a GPU; `device = "cpu"` in the three TabPFN
   scripts runs them without one, much more slowly). The weights are not part of this
   repository: `tabpfn` downloads them on first use from
   https://huggingface.co/Prior-Labs/tabpfn_3_5 (file
   `tabpfn-v3.5-20260909.safetensors`), and they are subject to the Prior Labs
   TabPFN-3.5 licence stated there. The licence has to be accepted once
   before the first TabPFN run: `uv run python tabpfn_login.py` opens the
   browser for login and acceptance and caches the API key (alternatively,
   set the environment variable `TABPFN_TOKEN`).
   The package versions behind the results are those of SI Appendix, Table S4
   (R 4.5.1; tabpfn 9.0.0 and torch 2.6.0+cu124 as pinned in uv.lock).
   Steps 2-4 are run once per population; `<id>` is the folder name under
   `datasets/` (the commands below show `03_pums_rent` as the example, one of
   the populations whose unit-level files are deposited).
2. R estimators, one population at a time:
   `Rscript run_model.R <id> direct lmm rf rf_id merf catboost catboost_id catboost_em lmm_logshift`
   e.g. `Rscript run_model.R 03_pums_rent direct lmm`
3. TabPFN variants:
   `uv run python models/tabpfn_naive.py datasets/<id>`
   `uv run python models/tabpfn_id.py datasets/<id>`
   `Rscript run_model.R <id> tabpfn_em`
4. Merge per population: `Rscript run_postprocess.R <id> [<id> ...]`
   (writes `datasets/<id>/merged/results.rds`).
5. Aggregate across populations (from the repository root):
   `Rscript aggregated_results/area_stats.R` (area-level statistics, paired bootstrap, ICC, ID/EM ratios)
   `Rscript aggregated_results/paired_vs_lmm_median_of_ratios.R` (paired bootstrap vs. the LMM)
   `Rscript aggregated_results/pairs_median_of_ratios.R` (ID/EM and ID/naive ratios)
   `Rscript aggregated_results/areasize_stats.R` (accuracy by area sample size, Fig. 5)
   `Rscript aggregated_results/design_stats.R` (design statistics, Table S1)
   `Rscript aggregated_results/logshift_stats.R` (LMM vs. log-shift LMM, Fig. S4)
   `Rscript aggregated_results/shrinkage_calibration.R` (implicit-shrinkage slopes vs. the LMM, Fig. S8 and Dataset S4)
6. Figures, table and SI datasets:
   `Rscript paper_figures/final_PNAS_plots.R` (all figures: Figs. 1-5, S1-S9),
   `Rscript paper_figures/make_tables.R` (Table S1),
   `Rscript paper_figures/icc_pooled_permutation_test.R` (permutation test, Results),
   `Rscript paper_figures/make_si_datasets.R` (Datasets S1-S4).

The figure script writes to `paper_figures/final_PNAS/`, the table script to
`paper_figures/tables/`. Step 6 runs from the deposited aggregated tables
alone for Figs. 1, 2, 3, 5, S1-S4, S8, S9, Table S1, the permutation test and
Datasets S1-S4, so these can be rebuilt for all sixteen populations without
any unit-level data. The implicit-shrinkage figures (Figs. 4, S5-S7) are
drawn by the same script from unit-level samples and predictions: for PUMS
(Figs. 4, S5) and CES (Fig. S6) these are deposited; TIMSS (Fig. S7) can be
reproduced only after rebuilding its population from the downloaded data and
rerunning the estimators, so the script skips it when the files are absent
and its figure is deposited as produced by the authors (as are its slope
tables in `aggregated_results/tables/shrinkage/`). Fig. S7 is deposited as
PNG only: in the vector PDF every point (one per in-sample school and Monte
Carlo sample) would be readable, i.e. per-area sample statistics of a
population whose unit-level data are not redistributable. Step 5 covers the populations whose
`merged/results.rds` (or, for `design_stats.R`, `logshift_stats.R` and
`shrinkage_calibration.R`, whose unit-level files) are present, i.e. the ones
rebuilt with steps 2-4; the deposited tables in
`aggregated_results/tables/` were produced from all sixteen.

## Figures and tables

The figure files are named by their number in the paper:

| Paper | File in `paper_figures/final_PNAS/` | Script |
|---|---|---|
| Fig. 1 | `fig1_rrmse_heatmap` | `paper_figures/final_PNAS_plots.R` |
| Fig. 2 | `fig2_paired_forest_insample` | `paper_figures/final_PNAS_plots.R` |
| Fig. 3 | `fig3_icc_ratio` | `paper_figures/final_PNAS_plots.R` |
| Fig. 4 | `fig4_pums_shrinkage` | `paper_figures/final_PNAS_plots.R` (unit-level data of 03) |
| Fig. 5 | `fig5_samplesize_ratio` | `paper_figures/final_PNAS_plots.R` |
| Fig. S1 | `figS1_paired_forest_oos` | `paper_figures/final_PNAS_plots.R` |
| Fig. S2 | `figS2_paired_counts` | `paper_figures/final_PNAS_plots.R` |
| Fig. S3 | `figS3_naive_ratio` | `paper_figures/final_PNAS_plots.R` |
| Fig. S4 | `figS4_logshift_heatmap` | `paper_figures/final_PNAS_plots.R` |
| Fig. S5 | `figS5_pums_shrinkage` | `paper_figures/final_PNAS_plots.R` (unit-level data of 03) |
| Fig. S6 | `figS6_ces_shrinkage` | `paper_figures/final_PNAS_plots.R` (unit-level data of 12) |
| Fig. S7 | `figS7_timss_shrinkage` (PNG only) | `paper_figures/final_PNAS_plots.R` (unit-level data of 16, not deposited) |
| Fig. S8 | `figS8_shrinkage_calibration` | `paper_figures/final_PNAS_plots.R` |
| Fig. S9 | `figS9_rb_heatmap` | `paper_figures/final_PNAS_plots.R` |

The implied and raw area effects of Figs. 4 and S5-S8 come from
`functions/shrinkage_effects.R`, the grey LMM reference lines and the LMM
slopes of Fig. S8 from `functions/shrinkage_lmm_effects.R`.

| Paper | File in `paper_figures/tables/` | Source table |
|---|---|---|
| Table S1 (populations and design) | `table_S1_populations.tex` | `aggregated_results/tables/design_stats.csv` |

Table 1 of the main text and SI Tables S2-S5 (covariates, access conditions,
software, tuning protocol) are descriptive and typed in the manuscript. The
numbers quoted in the Results are read from the aggregated tables; the
scripts of steps 5 and 6 print the ones that are not a table entry (Spearman
coefficients, permutation p-values, counts of resolved comparisons, the
ratios per size class quoted with Fig. 5, the
deviations of the implicit shrinkage from the LMM's).

## Licence

Code: MIT License (`LICENSE`). Results produced by the authors (predictions,
aggregated tables, figures, Table S1, Datasets S1-S4): CC BY 4.0. Prepared
extracts of third-party data keep the terms of their source (GPL-2 for
01 EU-SILC, see `LICENSES/GPL-2.0.txt`). Details: `LICENSE-DATA.md` and
`datasets/<id>/ACCESS.md`.

## Notes

- `datasets/03_pums_rent` and `04_pums_homevalue`: the Census API key in
  `prepare_source.R` is a placeholder ("xxxx"); a free key is obtained at
  https://api.census.gov/data/key_signup.html. The same files are also
  available without a key from the Census FTP server.

## Citation

If you use the code, the prepared populations or the results, please cite
the paper and this repository:

> Würz N, Popp S, Schmid T (2026). Can a model pretrained on synthetic data
> accurately estimate statistics for places that surveys barely reach?
> Manuscript submitted for publication.

> Würz N, Popp S, Schmid T (2026). Replication package for "Can a model
> pretrained on synthetic data accurately estimate statistics for places that
> surveys barely reach?". GitHub repository,
> https://github.com/NoraWuerz/tabpfn-surveys-barely-reach; Zenodo DOI to
> follow on publication.

The journal reference and the Zenodo DOI will be filled in once available.
