# 15_pnadc_renda -- PNADC 2024

**Source.** Instituto Brasileiro de Geografia e Estatistica (2025). Pesquisa
Nacional por Amostra de Domicilios Continua 2024, Visita 1: Microdados. Rio de
Janeiro: IBGE.

**Access.** Open download, https://ftp.ibge.gov.br/Trabalho_e_Rendimento/
(overview: https://www.ibge.gov.br/estatisticas/sociais/trabalho/).

**Terms.** Public data: the IBGE download server states "Todos os arquivos
aqui disponiveis sao publicos" (all files available here are public), and
IBGE's open-data plan (Plano de Dados Abertos) defines its open licence as
free use, reuse and redistribution with attribution. Use and redistribution
permitted with attribution of IBGE as source. Acknowledgement: "Source: IBGE,
PNADC 2024 visit 1 microdata; modified extract (filters per SI Appendix,
Section S3)."

## Deposit tier: population

`data/` holds the prepared source extract, the fixed population and the 50
stored sample draws; `results/` holds the unit-level predictions of the 11
estimators. The deposited files are a modified extract of the source, not the
provider's original files: extract definition, filters and counts are given in
SI Appendix, Section S3 of the paper.
