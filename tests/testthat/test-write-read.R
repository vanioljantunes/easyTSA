test_that("tsa_request validates inputs", {
  m <- fit_peecs()
  expect_s3_class(tsa_request(m), "tsa_request")
  expect_error(tsa_request(m, rrr = 0.3), "control")
  expect_error(tsa_request(m, control = 0.1), "rrr")
  expect_error(tsa_request(m, diversity = 1.2), "diversity")
  r <- tsa_request(m, control = 0.10, intervention = 0.07)
  expect_equal(r$settings$rrr, 0.3)
  expect_equal(r$settings$effect_type, "user")
  r2 <- tsa_request(m, control = 0.10, rrr = 0.3)
  expect_equal(r2$settings$intervention, 0.07)
})

test_that("tsa_write emits the program's codes and tsa_read round-trips", {
  m <- fit_peecs()
  f <- tsa_write(tsa_request(m, title = "PEECS"), tempfile(fileext = ".TSA"))
  txt <- readLines(f)
  expect_true(any(grepl("^#METAANALYSIS BEGIN", txt)))
  expect_equal(sum(grepl("^#TRIAL BEGIN", txt)), 7)
  expect_true(any(grepl("^effectModel\t11", txt)))
  expect_true(any(grepl("^interventionEffectType\t205", txt)))
  expect_true(any(grepl("^heterogeneityCorrection\t401", txt)))
  expect_true(any(grepl("^betaSpendingFunction\t802", txt)))
  d <- tsa_read(f)
  o <- order(atb_peecs$year, paste(atb_peecs$author, atb_peecs$year))
  expect_equal(d$event.e, atb_peecs$event.e[o])
  expect_equal(d$studlab[2], "Hastier-De Chelle A 2022")
  expect_equal(attr(d, "settings")$identifier, "PEECS")

  f2 <- tsa_write(tsa_request(m, control = 0.2817, intervention = 0.1916,
                              diversity = 0.3562, futility = FALSE),
                  tempfile(fileext = ".TSA"))
  txt2 <- readLines(f2)
  expect_true(any(grepl("^interventionEffectType\t204", txt2)))
  expect_true(any(grepl("^controlEffect\t28.17", txt2)))
  expect_true(any(grepl("^heterogeneityCorrection\t404", txt2)))
  expect_true(any(grepl("^heterogeneityCorrectionValue\t0.3562", txt2)))
  expect_false(any(grepl("^betaSpendingFunction", txt2)))

  s <- tsa_read(system.file("extdata", "atb_peecs.TSA", package = "easyTSA"))
  expect_equal(nrow(s), 7)
})

test_that("engine reports missing program clearly", {
  withr::with_envvar(c(TSA_HOME = ""), withr::with_options(list(
    easyTSA.jar = NULL, easyTSA.config_dir = tempfile("easyTSA-cfg")), {
    expect_equal(tsa_jar(), "")
    expect_error(tsa_engine(jar = "no-such-TSA.jar"), "tsa_setup")
    expect_error(tsa_run(fit_peecs(), jar = "no-such-TSA.jar"), "TSA_HOME")
  }))
})
