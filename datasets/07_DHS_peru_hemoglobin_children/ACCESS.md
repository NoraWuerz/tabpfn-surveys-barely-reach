# 07_DHS_peru_hemoglobin_children -- Peru DHS (ENDES) 2009, children

**Source.** Instituto Nacional de Estadistica e Informatica (INEI) and ICF
(2009). Peru Continuous Demographic and Health Survey (ENDES) 2009: Children's
Recode. Lima and Rockville, MD: INEI and The DHS Program.

**Access.** The DHS Program, https://dhsprogram.com (registration and project
approval).

**Terms.** DHS terms of use: the data may not be passed on to others.

## Deposit tier: code

The provider's terms prohibit redistribution. The deposit therefore contains
no unit-level files (neither the prepared population, the sample draws nor the
stored predictions, which contain the original target value of every unit),
only the preparation code and this access note. Results are available in
aggregated form in `aggregated_results/tables/` and Datasets S1-S4.

## Rebuilding the population

1. Obtain the children's recode file `PEKR5IFL.DTA` as described above.
2. Set `raw_kr` to its path and run the commented preparation block in
   `settings.R` (for this population the preparation code is part of
   `settings.R`; `data/prepare_source.R` points there). It writes
   `datasets/07_DHS_peru_hemoglobin_children/data/dhs_peru_hb_children.parquet`.
3. Run the commented sampling block in `settings.R`, then `pipeline/01_data.R`.
   The seed in `settings.R` reproduces the population and the 50 sample draws
   used in the paper exactly.

Extract definition, filters and counts: SI Appendix, Section S3 of the paper.
