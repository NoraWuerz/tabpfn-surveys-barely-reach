# icc_pooled_permutation_test.R
# Permutation test of the pooled association between the ID/EM ratio and the
# population ICC across the three learners: the ICC values are permuted over
# the populations jointly for all learners (same permutation, preserving their
# dependence); statistic = mean of the three Spearman coefficients.
# Inputs:  aggregated_results/tables/ratio_pairs_medratio.csv, dataset_icc_r2.csv
# Output:  console only. Run from the repository root.
AGG <- "aggregated_results/tables"
B    <- 100000
SEED <- 20260918
PAIRS <- c("rf_id_em", "catboost_id_em", "tabpfn_id_em")

rp  <- read.csv(file.path(AGG, "ratio_pairs_medratio.csv"))
icc <- read.csv(file.path(AGG, "dataset_icc_r2.csv"))[, c("dataset", "icc")]

set.seed(SEED)
for (sc in c("insample", "oos")) {
  x <- subset(rp, pair %in% PAIRS & scope == sc)
  w <- reshape(x[, c("dataset", "pair", "ratio")], idvar = "dataset",
               timevar = "pair", direction = "wide")
  names(w) <- sub("ratio.", "", names(w), fixed = TRUE)
  w <- merge(w, icc, by = "dataset")
  M <- as.matrix(w[, PAIRS]); ic <- w$icc; n <- nrow(w)

  rho <- apply(M, 2, function(y) cor(ic, y, method = "spearman"))
  obs <- mean(rho)
  perm <- replicate(B, {
    p <- sample(n)
    mean(apply(M, 2, function(y) cor(ic[p], y, method = "spearman")))
  })
  p_two <- (1 + sum(abs(perm) >= abs(obs))) / (B + 1)

  p_each <- sapply(PAIRS, function(k) {
    y <- M[, k]; r0 <- cor(ic, y, method = "spearman")
    pr <- replicate(10000, cor(sample(ic), y, method = "spearman"))
    (1 + sum(abs(pr) >= abs(r0))) / 10001
  })

  cat("\n===", sc, " n =", n, "\n")
  cat("rho      :", paste(sprintf("%s=%+.2f", PAIRS, rho), collapse = "  "), "\n")
  cat("p single :", paste(sprintf("%s=%.3f", PAIRS, p_each), collapse = "  "), "\n")
  cat(sprintf("pooled   : mean rho = %+.3f, p = %.4f (%d permutations)\n",
              obs, p_two, B))
}
