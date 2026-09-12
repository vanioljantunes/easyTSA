#' easyTSA: Trial Sequential Analysis for meta objects, computed by the TSA program
#'
#' Runs Trial Sequential Analysis (TSA) on meta-analysis objects from the
#' \pkg{meta} package by driving the Copenhagen Trial Unit TSA program
#' itself. The trials are written to the program's `.TSA` file, the program
#' (downloaded by [tsa_setup()], run headlessly through \pkg{rJava}) computes the
#' required information size, the cumulative Z-curve, monitoring and
#' futility boundaries and heterogeneity, and the results come back to R as
#' a tidy object with a \pkg{ggplot2} plot. No statistic is recomputed in R.
#'
#' @section Guides (read in order):
#' \enumerate{
#'   \item [easyTSA-1-workflow] -- setup and the three calls.
#'   \item [easyTSA-2-results] -- what comes back, argument to program option.
#'   \item [easyTSA-3-plot] -- customising the plot.
#'   \item [easyTSA-4-software] -- the TSA program and the engine.
#' }
#'
#' @section Main functions:
#' \describe{
#'   \item{[tsa_run()]}{Run the TSA program on a `metabin` object.}
#'   \item{[tsa_plot()]}{Draw the TSA graph (`ggplot`).}
#'   \item{[summary()]}{Per-look table and adjusted CI.}
#'   \item{[tsa_request()], [tsa_write()], [tsa_read()]}{Build and exchange
#'     `.TSA` files without running the program.}
#'   \item{[tsa_setup()], [tsa_remove()]}{Install or remove the TSA program
#'     and Java.}
#'   \item{[tsa_engine()], [tsa_jar()], [tsa_launch()]}{Locate, start and
#'     open the program.}
#' }
#'
#' @section Example data:
#' \describe{
#'   \item{[atb_peecs]}{Prophylactic antibiotics vs none for post-ESD
#'     electrocoagulation syndrome (7 studies).}
#' }
#'
#' @examples
#' \dontrun{
#' tsa_setup()   # once per machine
#' m <- meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
#'                    studlab = paste(author, year), sm = "RR")
#' x <- tsa_run(m, label.e = "ATB", label.c = "No ATB", title = "PEECS after ESD")
#' summary(x)
#' tsa_plot(x)
#' }
#'
#' @keywords internal
#' @importFrom ggplot2 .data
"_PACKAGE"
