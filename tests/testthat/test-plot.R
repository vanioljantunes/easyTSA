test_that("plot builds from a stored program result without the program", {
  x <- stored_result()
  expect_s3_class(x, "easytsa")
  p <- tsa_plot(x, show_labels = TRUE)
  expect_s3_class(p, "ggplot")
  expect_silent(ggplot2::ggplot_build(p))
  p2 <- tsa_plot(x, show_futility = FALSE, subtitle = NULL, ris_label = NULL,
                 col_z = "black")
  expect_s3_class(p2, "ggplot")
  expect_output(print(x), "RIS")
  expect_output(summary(x), "Boundary")
})
