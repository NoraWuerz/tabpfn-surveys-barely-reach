# Pipeline step 1: Population and sample generation — run ONCE per dataset.
# Requires: pipeline/00_header.R and the dataset settings.R sourced beforehand,
#           including its data-generation block (pop, samplesize, seed, n_sim).
# Writes:   {dataset_dir}/data/population.parquet
#           {dataset_dir}/data/samples.parquet
# Afterwards pipeline/02_load_data.R loads the data into the environment.

# Population -------------------------------------------------------------------

population <- pop |>
  mutate(idU = seq_len(n()),
         across(all_of(group_col), as.character),
         across(all_of(covariates_cat), as.factor),
         across(all_of(covariates_num), as.numeric)) |>
  as.data.frame()


# Simulation metadata ----------------------------------------------------------

set.seed(seed)
sim_meta <- tibble(
  sim_id = seq_len(n_sim),
  seed   = sample.int(1e6, n_sim)
)

# idU pool per district for fast sampling
id_pool <- population %>% 
  filter(.data[[group_col]] %in% names(samplesize)) %>% 
  split(x = .$idU, f = .[[group_col]])


# Build flat samples -----------------------------------------------------------

tic()
samples <- pmap(sim_meta, \(sim_id, seed) {
  set.seed(seed)
  smp_idx <- unlist(lapply(names(samplesize), \(d) {
    sample(id_pool[[d]], size = samplesize[d], replace = FALSE)
  }))
  smp        <- population[population$idU %in% smp_idx, ]
  smp$sim_id <- sim_id
  smp$seed   <- seed
  smp
}) |> list_rbind()
toc()


# Save -------------------------------------------------------------------------
pop_path     <- file.path(dataset_dir, "data", "population.parquet")
samples_path <- file.path(dataset_dir, "data", "samples.parquet")

if (!file.exists(pop_path))     arrow::write_parquet(population, pop_path)     else message("population.parquet already exists — skipping.")
if (!file.exists(samples_path)) arrow::write_parquet(samples,    samples_path) else message("samples.parquet already exists — skipping.")
