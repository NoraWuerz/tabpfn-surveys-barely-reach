# TabPFN-ID: TabPFN with the area identifier as categorical feature.
# Usage: python models/tabpfn_id.py <dataset_dir> [<out_name>], run from the
# project root; reads {dataset_dir}/settings.json and data/*.parquet.
# Output contract: one row per unit per sim_id with columns
#   sim_id, unit_id, area, y_true, pred
# Writes: {dataset_dir}/results/{out_name}.parquet (default tabpfn_id)

import sys
import random
from pathlib import Path
import pyarrow as pa
import pyarrow.parquet as pq
import numpy as np
import pandas as pd
import torch
import json
from pytictoc import TicToc
t = TicToc()

# ── paths ─────────────────────────────────────────────────────────────────────
root        = Path.cwd()
dataset_dir = root / sys.argv[1]
results_dir = dataset_dir / "results"
# optional second argument: output file name without .parquet
out_name    = sys.argv[2] if len(sys.argv) > 2 else "tabpfn_id"


# ── general setting information ────────────────────────────────────────────────
with open(Path(dataset_dir) / "settings.json") as f:
    s = json.load(f)

y_col      = s["y_col"]
group_col  = s["group_col"]
unit_id    = s["unit_id"]
x_cols_num = s["x_cols_num"]
x_cols_cat = s["x_cols_cat"]
x_cols     = s["covariates"]


# ── model factory ─────────────────────────────────────────────────────────────
# Seeds fix the random state, but TabPFN predictions can differ minimally
# between GPU models (floating-point behaviour of the CUDA kernels), so small
# deviations from the deposited results are expected on other hardware.
device = "cuda"   # "cpu" runs without a GPU (much slower); the paper used a GPU

from tabpfn import TabPFNRegressor
from tabpfn.constants import ModelVersion

def make_model(seed):
    # TabPFN v3.5 for all three TabPFN variants (naive, -ID, -EM)
    return TabPFNRegressor.create_default_for_version(ModelVersion.V3_5,
                                                    device=device,
                                                    random_state=seed)

# ── data ──────────────────────────────────────────────────────────────────────
population = pq.read_table(dataset_dir / "data/population.parquet").to_pandas()
samples    = pq.read_table(dataset_dir / "data/samples.parquet").to_pandas()
sim_meta   = samples[["sim_id", "seed"]].drop_duplicates().reset_index(drop=True)

# The area identifier is prefixed so that it is never parseable as a number:
# TabPFN treats a numeric-looking column with many levels as NUMERICAL even
# when passed as a pandas Categorical, whereas a string column declared as
# categorical stays CATEGORICAL for any number of levels.
AREA_PREFIX = "a_"

area_levels = sorted((AREA_PREFIX + population[group_col].astype(str)).unique())

def build_x(df: pd.DataFrame) -> pd.DataFrame:
    num = df[x_cols_num].reset_index(drop=True)
    # .astype("category") is required: TabPFN only treats columns with pandas
    # category dtype as categorical, otherwise digit-coded categories would be
    # read as numeric.
    cat = df[x_cols_cat].astype(str).astype("category").reset_index(drop=True)
    gr  = pd.Series(
        pd.Categorical(AREA_PREFIX + df[group_col].astype(str),
                       categories=area_levels, ordered=False),
        name="gr"
    ).reset_index(drop=True)
    return pd.concat([num, cat, gr], axis=1)

pop_x = build_x(population)

print(f"Device: {device} | population: {len(population)} | simulations: {len(sim_meta)}")

# ── simulation loop ───────────────────────────────────────────────────────────


results = []

for i, row in enumerate(sim_meta.itertuples(index=False), 1):
    sim_id = int(row.sim_id)
    seed   = int(row.seed)

    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)

    smp           = samples[samples["sim_id"] == sim_id].reset_index(drop=True)

    t.tic()
    model = make_model(seed)
    model.fit(build_x(smp), smp[y_col].astype(float).to_numpy())
    pred = model.predict(pop_x)
    t.toc()

    results.append(pd.DataFrame({
        "sim_id":    sim_id,
        "unit_id":   population[unit_id].values,
        "area":      population[group_col].astype(str).values,
        "y_true":    population[y_col].astype(float).values,
        "pred":      pred,
    }))

    if i % 10 == 0 or i == len(sim_meta):
        print(f"  {i}/{len(sim_meta)} simulations done")

# ── save ──────────────────────────────────────────────────────────────────────
out = pd.concat(results, ignore_index=True)
pq.write_table(pa.Table.from_pandas(out, preserve_index=False), results_dir / f"{out_name}.parquet")
