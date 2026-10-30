# 02_fdz_bee -- FDZ BEE 2017

**Source.** Forschungsdatenzentren der Statistischen Aemter des Bundes und der
Laender (2017). Besondere Ernte- und Qualitaetsermittlung (BEE), Public Use
File, reporting year 2017.

**Access.** Research Data Centres of the Federal Statistical Office and the
statistical offices of the Laender, https://www.forschungsdatenzentrum.de
(registration).

**Terms.** Users may not pass the data on to third parties.

## Deposit tier: code

The provider's terms prohibit redistribution. The deposit therefore contains
no unit-level files (neither the prepared population, the sample draws nor the
stored predictions, which contain the original target value of every unit),
only the preparation code and this access note. Results are available in
aggregated form in `aggregated_results/tables/` and Datasets S1-S4.

## Rebuilding the population

1. Obtain the source file as described above.
2. Run `data/prepare_source.R` (paths relative to the folder holding the
   downloaded file); it writes `FDZ-BEE/BEE_PUF_2017.parquet`.
3. Copy that file to `datasets/02_fdz_bee/data/`.
4. Run the commented sampling block in `settings.R`, then `pipeline/01_data.R`.
   The seed in `settings.R` reproduces the population and the 50 sample draws
   used in the paper exactly.

Extract definition, filters and counts: SI Appendix, Section S3 of the paper.
