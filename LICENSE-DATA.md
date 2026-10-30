# Licences of the non-code content

The code in this repository (all `.R` and `.py` files) is
licensed under the MIT License, see `LICENSE`.

## Results produced by the authors: CC BY 4.0

The following are licensed under the Creative Commons Attribution 4.0
International License (CC BY 4.0, https://creativecommons.org/licenses/by/4.0/):

- `datasets/<id>/results/` -- predictions of the eleven estimators and of the
  LMM with log-shift transformation (SI Fig. S4)
- `aggregated_results/tables/`
- `paper_figures/` -- figures, LaTeX Table S1, and Datasets S1-S4

Please cite the paper when reusing them.

## Data from third-party sources: terms of the source

The prepared extracts, fixed populations and sample draws in
`datasets/<id>/data/` are modified extracts of third-party data. They are not
relicensed by the authors; the terms of the respective source apply, as stated
with the required acknowledgement in each `datasets/<id>/ACCESS.md`:

| Population | Terms of the source |
|---|---|
| 01 EU-SILC Austria (emdi) | GPL-2, see `LICENSES/GPL-2.0.txt` |
| 03, 04 ACS PUMS | public domain (U.S. federal government work) |
| 08 RECS | public domain (U.S. federal government work) |
| 12 CES | CC0 1.0 |
| 13 ENVIPE | INEGI terms of free use, attribution |
| 14 LSMS-ISA | CC0 |
| 15 PNADC | IBGE, attribution |

No unit-level data are deposited for the other eight populations (02, 05, 06,
07, 09, 10, 11, 16); see their `ACCESS.md`.

## TabPFN weights

The TabPFN-3.5 weights are not part of this repository. They are downloaded
from Prior Labs and are subject to the Prior Labs TabPFN-3.5 licence, see
`README.md`.
