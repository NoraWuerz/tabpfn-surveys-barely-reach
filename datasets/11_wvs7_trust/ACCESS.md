# 11_wvs7_trust -- World Values Survey wave 7

**Source.** Haerpfer C, Inglehart R, Moreno A, Welzel C, Kizilova K,
Diez-Medrano J, Lagos M, Norris P, Ponarin E, Puranen B (2022). World Values
Survey: Round Seven - Country-Pooled Datafile, Version 6.0. Madrid and Vienna:
JD Systems Institute and WVSA Secretariat. https://doi.org/10.14281/18241.20

**Access.** https://www.worldvaluessurvey.org/WVSDocumentationWV7.jsp (web
form; conditions of use accepted on download).

**Terms.** The conditions of use accepted on download prohibit passing the data
on to third parties.

## Deposit tier: code

The provider's terms prohibit redistribution. The deposit therefore contains
no unit-level files (neither the prepared population, the sample draws nor the
stored predictions, which contain the original target value of every unit),
only the preparation code and this access note. Results are available in
aggregated form in `aggregated_results/tables/` and Datasets S1-S4.

## Rebuilding the population

1. Obtain the source file as described above.
2. Run `data/prepare_source.R` (paths relative to the folder holding the
   downloaded file); it writes `WVS/wvs7_trust.parquet`.
3. Copy that file to `datasets/11_wvs7_trust/data/`.
4. Run the commented sampling block in `settings.R`, then `pipeline/01_data.R`.
   The seed in `settings.R` reproduces the population and the 50 sample draws
   used in the paper exactly.

Extract definition, filters and counts: SI Appendix, Section S3 of the paper.
