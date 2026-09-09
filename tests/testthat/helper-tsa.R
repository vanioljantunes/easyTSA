skip_if_no_tsa <- function() {
  if (!nzchar(tsa_jar())) testthat::skip("TSA program not found (set TSA_HOME)")
  if (!requireNamespace("rJava", quietly = TRUE)) testthat::skip("rJava not installed")
  ok <- tryCatch({ tsa_engine(); TRUE }, error = function(e) FALSE)
  if (!ok) testthat::skip("TSA engine could not start (Java missing?)")
}

fit_peecs <- function() {
  meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
                studlab = paste(author, year), sm = "RR")
}

stored_result <- function() {
  f <- system.file("extdata", "atb_peecs_result.rds", package = "easyTSA")
  if (!nzchar(f)) testthat::skip("stored result not available")
  readRDS(f)
}
