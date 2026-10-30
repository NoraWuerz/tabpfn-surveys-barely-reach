# 06_DHS_kenya_BMI_women -- Kenya DHS 2022, women

**Source.** Kenya National Bureau of Statistics and ICF (2023). Kenya
Demographic and Health Survey 2022. Nairobi and Rockville, MD: KNBS and ICF.

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

1. Obtain the source file as described above.
2. Run `data/prepare_source.R` (paths relative to the folder holding the
   downloaded file); it writes `DHS/dhs_kenya_bmi_women.parquet`.
3. Copy that file to `datasets/06_DHS_kenya_BMI_women/data/`.
4. Run the commented sampling block in `settings.R`, then `pipeline/01_data.R`.
   The seed in `settings.R` reproduces the population and the 50 sample draws
   used in the paper exactly.

Extract definition, filters and counts: SI Appendix, Section S3 of the paper.
