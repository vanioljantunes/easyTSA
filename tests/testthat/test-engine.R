# Program-backed tests. Golden values were read from the TSA program's own
# interface (version 0.9.5.10 Beta) for the bundled example with the
# alpha-spending boundary set to: RRR user-defined 31.98% (control 28.17%,
# intervention 19.16%), alpha 5%, power 80%, D2 user-defined 35.62%.

test_that("tsa_run reproduces the program's numbers (user-defined effect and D2)", {
  skip_if_no_tsa()
  x <- tsa_run(fit_peecs(), control = 0.2817, intervention = 0.1916,
               diversity = 0.3562, label.e = "ATB", label.c = "No ATB")
  expect_s3_class(x, "easytsa")
  expect_equal(x$ris$ris, 1086)
  expect_equal(x$ris$ris_exact, 1085.741, tolerance = 1e-3)
  expect_equal(x$ris$adjustment, 1.5533, tolerance = 1e-3)
  expect_equal(x$looks$studlab,
               c("Lee SP 2017", "Hastier-De Chelle A 2022", "Shichijo S 2022",
                 "Liao F 2024", "Qiu J 2024", "Chen T 2025", "Zhao YR 2025"))
  expect_equal(x$looks$n_cum, c(100, 326, 706, 1258, 1813, 1894, 2156))
  expect_equal(x$looks$IF[1:3], c(0.0921, 0.3003, 0.6502), tolerance = 1e-3)
  expect_equal(x$looks$z, c(4.1589, 0.0294, 0.6366, 1.3564, 0.8429, 1.4737, 1.6337),
               tolerance = 1e-3)
  expect_equal(x$looks$upper[1:3], c(7.2927, 3.9272, 2.5472), tolerance = 1e-3)
  expect_equal(x$looks$upper[4:7], rep(qnorm(0.975), 4))
  expect_true(is.na(x$looks$futility[1]))
  expect_equal(x$looks$futility[3], 1.126, tolerance = 5e-3)
  expect_true(is.na(x$looks$futility[2]))
  expect_equal(x$pooled$d2, 0.56756, tolerance = 1e-4)
  expect_equal(x$pooled$effect, 0.7355, tolerance = 1e-3)
  expect_equal(x$settings$effect_type, "user")
  expect_output(print(x), "TSA program")
  expect_output(summary(x), "TSA-adjusted")
})

test_that("program estimates effect and heterogeneity by default", {
  skip_if_no_tsa()
  x <- tsa_run(fit_peecs())
  expect_equal(x$settings$effect_type, "estimate")
  # program "Low Bias Based" effect: crude control proportion, intervention
  # from the pooled RR, plus "Model Variance Based" D2
  expect_equal(x$ris$d2, 0.56756, tolerance = 1e-4)
  expect_equal(x$ris$ris_exact, 6495.7, tolerance = 1e-3)
  expect_equal(x$ris$adjustment, 2.3125, tolerance = 1e-3)
  expect_equal(x$ris$control, 0.1235, tolerance = 1e-3)
  expect_equal(x$ris$intervention, 0.0908, tolerance = 2e-3)
  expect_equal(x$looks$upper[2], 8)
})

test_that("file is kept when asked and reloads in the reader", {
  skip_if_no_tsa()
  f <- tempfile(fileext = ".TSA")
  x <- tsa_run(fit_peecs(), file = f)
  expect_true(file.exists(f))
  expect_equal(x$file, normalizePath(f))
  d <- tsa_read(f)
  expect_equal(nrow(d), 7)
})

test_that("tsa_create is a deprecated alias", {
  skip_if_no_tsa()
  expect_warning(x <- tsa_create(fit_peecs()), "deprecated")
  expect_s3_class(x, "easytsa")
})
