# 01_eusilc -- EU-SILC Austria (synthetic, emdi)

**Source.** `eusilcA_pop` from the R package emdi. Kreutzmann A-K, Pannier S,
Rojas-Perilla N, Schmid T, Templ M, Tzavidis N (2019). The R package emdi for
estimating and mapping regionally disaggregated indicators. Journal of
Statistical Software 91(7):1-33. https://doi.org/10.18637/jss.v091.i07

**Access.** CRAN, https://CRAN.R-project.org/package=emdi

**Terms.** GPL-2 (licence of the emdi package, which ships the data;
https://www.gnu.org/licenses/old-licenses/gpl-2.0.html). The files in `data/`
are derived from `eusilcA_pop` and are redistributed under the same licence
(text: `LICENSES/GPL-2.0.txt` in the repository root).
The data are synthetic, generated from the Austrian EU-SILC by the emdi authors.

## Deposit tier: population

`data/` holds the prepared source extract, the fixed population and the 50
stored sample draws; `results/` holds the unit-level predictions of the 11
estimators. The deposited files are a modified extract of the source, not the
provider's original files: extract definition, filters and counts are given in
SI Appendix, Section S3 of the paper.
