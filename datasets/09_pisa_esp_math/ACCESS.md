# 09_pisa_esp_math -- PISA 2022 Spain

**Source.** OECD (2023). PISA 2022 Database: Student Questionnaire Data File.
Paris: OECD Publishing.

**Access.** https://www.oecd.org/pisa/data/2022database/ (file
`STU_QQQ_SPSS.zip`). The download is free of charge, but requires a web form
(institution, contact details, research project) and acceptance of the "Terms
of Use for the Data Access and Research Information Survey on PISA".

**Terms.** The terms of use accepted on download prohibit passing the data on:
"The PISA Data must not be distributed, disclosed, or made available to any
third party." They also prohibit any attempt to re-identify participants or
schools and require that the OECD be acknowledged as the source in all uses of
the data as follows: "Programme for International Student Assessment (PISA)
Organisation for Economic Co-operation and Development (OECD), Paris".

## Deposit tier: code

The provider's terms prohibit redistribution. The deposit therefore contains
no unit-level files (neither the prepared population, the sample draws nor the
stored predictions, which contain the original target value of every unit),
only the preparation code and this access note. Results are available in
aggregated form in `aggregated_results/tables/` and Datasets S1-S4.

## Rebuilding the population

1. Obtain the source file as described above.
2. Run `data/prepare_source.R` (paths relative to the folder holding the
   downloaded file); it writes `PISA/pisa2022_esp_math.parquet`.
3. Copy that file to `datasets/09_pisa_esp_math/data/`.
4. Run the commented sampling block in `settings.R`, then `pipeline/01_data.R`.
   The seed in `settings.R` reproduces the population and the 50 sample draws
   used in the paper exactly.

Extract definition, filters and counts: SI Appendix, Section S3 of the paper.
