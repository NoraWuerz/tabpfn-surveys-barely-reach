# 10_afrobarometer_lpi -- Afrobarometer Round 9

**Source.** Afrobarometer (2025). Afrobarometer Round 9 Merged Dataset (39
Countries, 2021-2023). Release updated 4 June 2025.

**Access.** Open download without registration,
https://www.afrobarometer.org/data/merged-data/

File used:
https://www.afrobarometer.org/wp-content/uploads/2025/06/R9.Merge_39ctry.20Nov23.final_.release_Updated.4Jun25-3.sav

Save it as `Afrobarometer/R9.Merge_39ctry.sav` (the name `data/prepare_source.R` reads).

**Terms.** Data usage and access policy,
https://www.afrobarometer.org/data/data-usage-and-access-policy/ : the data are
protected by copyright; publications must acknowledge the source ("Afrobarometer
Data, [Countries], Round 9, 2021-2023, available at
http://www.afrobarometer.org"), and copies of publications are to be sent to
Afrobarometer. The policy does not state that the files may be passed on.

## Deposit tier: script

Because redistribution is not stated to be permitted, the deposit contains no
unit-level files (neither the prepared population, the sample draws nor the
stored predictions, which contain the original target value of every unit),
only the download instructions above and the preparation code. Results are
available in aggregated form in `aggregated_results/tables/` and
Datasets S1-S4.

## Rebuilding the population

1. Obtain the source file as described above.
2. Run `data/prepare_source.R` (paths relative to the folder holding the
   downloaded file); it writes `Afrobarometer/afrobarometer_r9.parquet`.
3. Copy that file to `datasets/10_afrobarometer_lpi/data/`.
4. Run the commented sampling block in `settings.R`, then `pipeline/01_data.R`.
   The seed in `settings.R` reproduces the population and the 50 sample draws
   used in the paper exactly.

Extract definition, filters and counts: SI Appendix, Section S3 of the paper.
