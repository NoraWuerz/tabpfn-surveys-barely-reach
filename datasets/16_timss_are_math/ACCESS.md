# 16_timss_are_math -- TIMSS 2023, United Arab Emirates, grade 8

**Source.** Mullis IVS, von Davier M, Foy P, Fishbein B, Reynolds KA, Wry E
(2024). TIMSS 2023 International Database. Chestnut Hill, MA: Boston College,
TIMSS & PIRLS International Study Center.

**Access.** Open download without registration, https://timss2023.org/data/

File used: https://timss2023.org/wp-content/uploads/data/T23_Data_R_G8.zip
(R version, grade 8; keep it as `TIMSS2023/T23_Data_R_G8.zip`).

**Terms.** IEA copyright notice and disclaimer (https://timss2023.org/data/):
use for non-commercial, educational and research purposes; redistribution
requires the written permission of the IEA
(https://www.iea.nl/data-tools/permission-requests). Acknowledgement: "SOURCE:
IEA's Trends in International Mathematics and Science Study - TIMSS 2023.
Copyright (c) 2025 International Association for the Evaluation of Educational
Achievement (IEA)."

## Deposit tier: script

Because redistribution requires the written permission of the IEA, the deposit
contains no unit-level files (neither the prepared population, the sample
draws nor the stored predictions, which contain the original target value of
every unit), only the download instructions above and the preparation code.
Results are available in aggregated form in `aggregated_results/tables/`
and Datasets S1-S4. The TIMSS shrinkage figure (SI Appendix, Fig. S7, drawn by
`paper_figures/final_PNAS_plots.R`) needs the unit-level files and is reproduced
only after rebuilding the population and rerunning the estimators; until then
the script skips it and the deposited figure stands. That figure is deposited
as PNG only: a vector PDF would expose every plotted point, i.e. sample
statistics per school and Monte Carlo sample.

## Rebuilding the population

1. Obtain the source file as described above.
2. Run `data/prepare_source.R` (paths relative to the folder holding the
   downloaded file); it writes `TIMSS2023/timss2023_are_math.parquet`.
3. Copy that file to `datasets/16_timss_are_math/data/`.
4. Run the commented sampling block in `settings.R`, then `pipeline/01_data.R`.
   The seed in `settings.R` reproduces the population and the 50 sample draws
   used in the paper exactly.

Extract definition, filters and counts: SI Appendix, Section S3 of the paper.
