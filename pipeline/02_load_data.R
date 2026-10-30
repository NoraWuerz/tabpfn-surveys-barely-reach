# Pipeline step 2: Load generated data into the global environment.
# Requires: pipeline/01_data.R has been run at least once for this dataset.
# Provides: population, samples, sim_meta

data_dir   <- file.path(dataset_dir, "data")
population <- arrow::read_parquet(file.path(data_dir, "population.parquet"))
samples    <- arrow::read_parquet(file.path(data_dir, "samples.parquet"))
sim_meta   <- dplyr::distinct(samples, sim_id, seed)