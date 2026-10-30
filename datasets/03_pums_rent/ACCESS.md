# 03_pums_rent -- ACS 2023 1-year PUMS

**Source.** U.S. Census Bureau (2024). American Community Survey (ACS) 2023
1-Year Public Use Microdata Sample (PUMS).

**Access.** Open download, https://www.census.gov/programs-surveys/acs/microdata.html
(FTP server without key; `data/prepare_source.R` uses the Census API, for which
a free key is needed: https://api.census.gov/data/key_signup.html).

**Terms.** Work of the U.S. federal government, public domain (17 U.S.C. 105).
Redistribution permitted. Suggested acknowledgement: "Source: U.S. Census
Bureau, ACS 2023 1-year PUMS; modified extract."
The deposited files were built from data obtained through the Census Bureau
Data API but are not endorsed or certified by the Census Bureau.

## Deposit tier: population

`data/` holds the prepared source extract, the fixed population and the 50
stored sample draws; `results/` holds the unit-level predictions of the 11
estimators. The deposited files are a modified extract of the source, not the
provider's original files: extract definition, filters and counts are given in
SI Appendix, Section S3 of the paper.
