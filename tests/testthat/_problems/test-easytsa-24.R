# Extracted from test-easytsa.R:24

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "easyTSA", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
fit_peecs <- function() {
  meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
                studlab = paste(author, year), sm = "RR",
                method = "MH", method.tau = "REML",
                random = TRUE, common = FALSE)
}

# test -------------------------------------------------------------------------
f <- function(...) tsa_ris(...)$ris
expect_equal(f(control = 0.14, rrr = -0.20), 5218)
expect_equal(f(control = 0.276, rrr = 0.20, alpha = 0.01, beta = 0.10,
                 diversity = 0.49), 7150)
