fit_peecs <- function() {
  meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
                studlab = paste(author, year), sm = "RR",
                method = "MH", method.tau = "REML",
                random = TRUE, common = FALSE)
}

test_that("RIS matches the TSA manual formula and sample file", {
  # Sample file: control 16.36%, RRR 20%, alpha 5%, power 80%, D2 = 0.67
  r <- tsa_ris(control = 0.1636, rrr = 0.20)
  z <- qnorm(0.975) + qnorm(0.8)
  pbar <- (0.1636 + 0.1636 * 0.8) / 2
  expect_equal(r$ris_fixed, 4 * z^2 * pbar * (1 - pbar) / (0.1636 * 0.2)^2)
  r2 <- tsa_ris(control = 0.1636, rrr = 0.20, diversity = 0.67)
  expect_equal(r2$ris, ceiling(r$ris_fixed / 0.33))
})

test_that("RIS reproduces the worked examples of the TSA manual (section 5)", {
  f <- function(...) tsa_ris(...)$ris
  # 5.2 smoking cessation: control 14%, 20% relative benefit increase
  expect_equal(f(control = 0.14, rrr = -0.20), 5218)
  # 5.3 atrial fibrillation: control 27.6%, RRR 20%, alpha 1%, beta 10%, D2 49%
  expect_equal(f(control = 0.276, rrr = 0.20, alpha = 0.01, beta = 0.10,
                 diversity = 0.49), 7150, tolerance = 0.001)
  # 5.5 tuberculosis: control 5%, RRR 25%, D2 20%
  expect_equal(f(control = 0.05, rrr = 0.25, diversity = 0.20), 10508)
  # 5.4 myocardial infarction: control 3.9%, RRR 33% (inputs rounded in text)
  expect_equal(f(control = 0.039, rrr = 0.33), 5942, tolerance = 0.01)
})

test_that("O'Brien-Fleming boundaries reproduce known values", {
  # Equally spaced looks, alpha 0.05 two-sided (Lan-DeMets OBF-type):
  # reference from ldbounds/gsDesign: 4.333, 2.963, 2.359, 2.014
  b <- tsa_bounds(c(0.25, 0.5, 0.75, 1))
  expect_equal(b, c(4.333, 2.963, 2.359, 2.014), tolerance = 0.01)
  # single look at full information is the conventional value
  expect_equal(tsa_bounds(1), qnorm(0.975), tolerance = 0.005)
  # spending alpha/2 per side: single look, one-sided alpha 0.025
  expect_equal(tsa_bounds(1, sides = 1, alpha = 0.025), qnorm(0.975), tolerance = 0.005)
  # very early looks are truncated at 8
  expect_equal(tsa_bounds(c(0.01, 1))[1], 8)
})

test_that("futility boundary is below the upper boundary and emerges late", {
  t <- c(0.2, 0.4, 0.6, 0.8, 1)
  up <- tsa_bounds(t)
  fu <- tsa_futility(t, up)
  ok <- !is.na(fu)
  expect_true(all(fu[ok] <= up[ok] + 1e-6))
  expect_true(is.na(fu[1]))
  expect_true(fu[5] <= up[5])
  expect_true(fu[5] > 1)
})

test_that("tsa_create runs on the PEECS example", {
  m <- fit_peecs()
  x <- tsa_create(m, rrr = 0.30, label.e = "ATB", label.c = "No ATB")
  expect_s3_class(x, "easytsa")
  expect_equal(nrow(x$looks), 7)
  expect_equal(x$looks$year, sort(atb_peecs$year))
  expect_equal(x$looks$studlab[2], "Hastier-De Chelle A 2022")
  sub <- atb_peecs[atb_peecs$year <= 2017 | atb_peecs$author == "Hastier-De Chelle A", ]
  m2 <- meta::metabin(event.e, n.e, event.c, n.c, data = sub,
                      studlab = paste(author, year), sm = "RR", method = "MH",
                      method.tau = "REML", random = TRUE, common = FALSE)
  expect_equal(x$looks$z[2], m2$TE.random / m2$seTE.random)
  expect_equal(x$looks$n_cum[7], sum(atb_peecs$n.e + atb_peecs$n.c))
  # negative outcome: Z sign flipped so that RR < 1 gives positive Z
  expect_true(x$looks$z_plot[7] > 0)
  expect_equal(x$looks$z[7], m$TE.random / m$seTE.random)
  expect_true(all(x$looks$upper >= qnorm(0.975) - 1e-6))
  expect_output(print(x), "RIS")
  expect_output(summary(x), "TSA-adjusted")
})

test_that("empirical effect and common model fall back sensibly", {
  m <- meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
                     studlab = paste(author, year), sm = "RR",
                     random = FALSE, common = TRUE)
  expect_message(x <- tsa_create(m), "common")
  expect_equal(x$settings$model, "common")
  expect_equal(x$settings$effect_type, "empirical")
  w <- m$w.common / sum(m$w.common)
  pc <- sum(w * atb_peecs$event.c / atb_peecs$n.c)
  pe <- sum(w * atb_peecs$event.e / atb_peecs$n.e)
  expect_equal(x$ris$control, pc)
  expect_equal(x$ris$rrr, 1 - pe / pc)
  x2 <- tsa_create(m, control = 0.10, intervention = 0.07)
  expect_equal(x2$ris$rrr, 0.3)
  expect_equal(x2$settings$effect_type, "user")
})

test_that("plot builds", {
  x <- tsa_create(fit_peecs(), rrr = 0.30)
  p <- tsa_plot(x, show_labels = TRUE)
  expect_s3_class(p, "ggplot")
  expect_silent(ggplot2::ggplot_build(p))
  p2 <- tsa_plot(x, show_futility = FALSE, subtitle = NULL, ris_label = NULL)
  expect_s3_class(p2, "ggplot")
})

test_that(".TSA round trip and sample file parsing", {
  x <- tsa_create(fit_peecs(), rrr = 0.30, title = "PEECS")
  f <- tsa_write(x, tempfile(fileext = ".TSA"))
  txt <- readLines(f)
  expect_true(any(grepl("^#METAANALYSIS BEGIN", txt)))
  expect_equal(sum(grepl("^#TRIAL BEGIN", txt)), 7)
  expect_true(any(grepl("^interventionEffectType\t204", txt)))
  expect_true(any(grepl("^heterogeneityCorrection\t404", txt)))
  expect_true(any(grepl("^betaSpendingFunction\t802", txt)))
  d <- tsa_read(f)
  o <- order(atb_peecs$year, paste(atb_peecs$author, atb_peecs$year))
  expect_equal(d$event.e, atb_peecs$event.e[o])
  expect_equal(attr(d, "settings")$identifier, "PEECS")

  s <- tsa_read(system.file("extdata", "atb_peecs.TSA", package = "easyTSA"))
  expect_equal(nrow(s), 7)
  expect_equal(s$studlab[1], "Lee SP 2017")
})

test_that("tsa_launch errors cleanly without java or the program", {
  x <- tsa_create(fit_peecs(), rrr = 0.30)
  expect_error(tsa_launch(x, java = "no-such-java-binary"), "Java not found")
  withr::with_envvar(c(TSA_HOME = ""), withr::with_options(
    list(easyTSA.jar = NULL), expect_equal(tsa_jar(), "")))
})
