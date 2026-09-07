#' easyTSA: Trial Sequential Analysis for meta objects
#'
#' Runs Trial Sequential Analysis (TSA, Copenhagen Trial Unit) on
#' meta-analysis objects from the \pkg{meta} package, draws the TSA graph with
#' \pkg{ggplot2}, and exchanges `.TSA` files with the original Java program
#' (installed separately from <https://ctu.dk/tsa/>).
#'
#' @section Guides (read in order):
#' \enumerate{
#'   \item [easyTSA-1-workflow] -- from a `metabin` object to a TSA plot.
#'   \item [easyTSA-2-theory] -- what the RIS, boundaries and inner wedge are.
#'   \item [easyTSA-3-plot] -- customising the plot.
#'   \item [easyTSA-4-software] -- opening the analysis in the TSA program.
#' }
#'
#' @section Main functions:
#' \describe{
#'   \item{[tsa_create()]}{Run the TSA on a `metabin`/`metacont` object.}
#'   \item{[tsa_plot()]}{Draw the TSA graph (`ggplot`).}
#'   \item{[summary()]}{Per-look table and TSA-adjusted CI.}
#'   \item{[tsa_write()], [tsa_read()]}{Exchange `.TSA` files.}
#'   \item{[tsa_launch()]}{Start the TSA software (needs Java and the program).}
#' }
#'
#' @section Building blocks:
#' \describe{
#'   \item{[tsa_ris()], [tsa_diversity()]}{Required information size, D-squared.}
#'   \item{[tsa_bounds()], [tsa_futility()], [tsa_spending()]}{Lan-DeMets
#'     boundaries and spending functions.}
#' }
#'
#' @section Example data:
#' \describe{
#'   \item{[atb_peecs]}{Prophylactic antibiotics vs none for post-ESD
#'     electrocoagulation syndrome (7 studies).}
#' }
#'
#' @examples
#' m <- meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
#'                    studlab = paste(author, year), sm = "RR",
#'                    method = "MH", method.tau = "REML",
#'                    random = TRUE, common = FALSE)
#' x <- tsa_create(m, rrr = 0.30, label.e = "ATB", label.c = "No ATB",
#'                 title = "PEECS after ESD")
#' summary(x)
#' tsa_plot(x)
#'
#' @keywords internal
#' @importFrom ggplot2 .data
"_PACKAGE"
