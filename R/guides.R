# Long-form help pages, in the style of easydta.

#' Guide 1: workflow, from a meta object to a TSA plot
#'
#' @description
#' `easyTSA` does not compute a Trial Sequential Analysis itself. It hands
#' your meta-analysis to the Copenhagen Trial Unit TSA program, lets the
#' program do every calculation, and brings the numbers back to R.
#'
#' @section Step 0, once per machine:
#' Download the TSA program and, if needed, a Java runtime:
#' ```r
#' tsa_setup()
#' ```
#' The locations are remembered for later sessions. See
#' [easyTSA-4-software] for the license.
#'
#' @section Step 1, fit the meta-analysis as usual:
#' ```r
#' library(meta); library(easyTSA)
#' m <- metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
#'              studlab = paste(author, year), sm = "RR")
#' ```
#' Only the trials (events, totals, labels, years) are taken from `m`. The
#' program fits its own model (DerSimonian-Laird by default) and applies its
#' own continuity correction.
#'
#' @section Step 2, run the program:
#' ```r
#' x <- tsa_run(m, label.e = "ATB", label.c = "No ATB", title = "PEECS after ESD")
#' x            # RIS, D2, conclusion, all from the program
#' summary(x)   # per-look table: N, information fraction, Z, boundaries
#' ```
#' Defaults are the program's defaults: two-sided 5% conventional boundary,
#' O'Brien-Fleming alpha-spending boundary on the sample-size axis, 80% power,
#' anticipated effect "Estimate" (from the meta-analysed data), heterogeneity
#' correction "Model Variance Based" (D-squared from the program's model),
#' inner wedge on.
#'
#' To use a clinically chosen effect instead:
#' ```r
#' tsa_run(m, control = 0.12, rrr = 0.30)          # RRR 30%, control risk 12%
#' tsa_run(m, control = 0.12, rrr = 0.30, diversity = 0.5)   # user D2
#' ```
#'
#' @section Step 3, plot:
#' ```r
#' tsa_plot(x)
#' tsa_plot(x, show_labels = TRUE)
#' ```
#' See [easyTSA-3-plot].
#'
#' @section Step 4, optional, open in the program's interface:
#' ```r
#' tsa_write(x, "peecs.TSA")   # same file the engine used
#' tsa_launch(x)               # starts the program; File > Open the file
#' ```
#'
#' @name easyTSA-1-workflow
NULL

#' Guide 2: what comes back, and which program option each default maps to
#'
#' @description
#' Every number in an `easytsa` object is produced by the TSA program's own
#' classes. This page lists what is returned and how the arguments of
#' [tsa_run()] correspond to the program's dialogs.
#'
#' @section Returned:
#' \describe{
#'   \item{`looks`}{One row per trial in the program's order (year, then
#'     alphabetical): cumulative participants, information fraction,
#'     cumulative Z (positive favours the intervention), monitoring boundary,
#'     inner-wedge value.}
#'   \item{`ris`}{Required information size (rounded up, and exact), the
#'     heterogeneity factor, the D-squared used, the control and
#'     intervention proportions and RRR used, alpha and beta.}
#'   \item{`pooled`}{Pooled effect, Z, D-squared, I-squared and tau of the
#'     program's model over all trials.}
#'   \item{`conclusion`}{Whether and where the Z-curve crossed the
#'     monitoring or futility boundary, or the RIS.}
#'   \item{`adjusted_ci`}{Conventional interval and the interval widened to
#'     the boundary of the last look.}
#' }
#'
#' @section Argument to program option:
#' \tabular{lll}{
#'   Argument \tab Program dialog \tab Default \cr
#'   `alpha` \tab Type 1 error, two-sided \tab 5% \cr
#'   `beta` \tab Power (inner wedge and information size) \tab 20% (80% power) \cr
#'   `rrr`, `control`, `intervention` \tab Relative risk reduction, incidence in each arm \tab Estimate \cr
#'   `diversity` \tab Heterogeneity correction \tab Model Variance Based \cr
#'   `futility` \tab Apply inner wedge, O'Brien-Fleming beta-spending \tab on \cr
#'   `model` \tab Effect model (Fixed, Random DL, SJ, BT) \tab Random-effects (DL) \cr
#'   `outcome` \tab Outcome type negative or positive \tab negative \cr
#'   information axis \tab Sample size \tab sample size (fixed) \cr
#'   alpha-spending function \tab O'Brien-Fleming \tab fixed
#' }
#'
#' @section Why the Z-curve differs from `meta`:
#' The program uses its own inverse-variance DerSimonian-Laird model and its
#' own continuity correction for zero-event trials, so the cumulative Z
#' values are not the ones `metacum()` would give. That is intended: the
#' result is what the TSA program reports.
#'
#' @name easyTSA-2-results
NULL

#' Guide 3: customising the plot
#'
#' @description
#' [tsa_plot()] draws the program's numbers with `ggplot2`, so the usual `+`
#' grammar applies on top of its own arguments.
#'
#' @section Arguments:
#' ```r
#' tsa_plot(x,
#'   title = "PEECS after ESD", subtitle = NULL,   # NULL removes the auto line
#'   xlab = "Participants", ylab = "Cumulative Z",
#'   show_futility = FALSE,                        # hide the inner wedge
#'   show_conventional = FALSE,                    # hide +/- 1.96
#'   show_labels = TRUE,                           # study names on the curve
#'   show_favours = FALSE,                         # hide "Favours ..." text
#'   ris_label = "RIS (D2-adjusted)",              # or NULL
#'   col_z = "black", col_bound = "firebrick", col_futility = "grey50",
#'   ylim = c(-6, 6), line_size = 0.9, point_size = 2.5)
#' ```
#'
#' @section Adding layers and saving:
#' ```r
#' p <- tsa_plot(x) + ggplot2::theme_classic(base_size = 13)
#' ggplot2::ggsave("tsa_peecs.png", p, width = 9, height = 5.5, dpi = 300)
#' ```
#'
#' @section Reading the graph:
#' Blue squares are the cumulative Z after each trial. Red diamonds are the
#' monitoring boundaries; crossing them is significance adjusted for
#' repeated testing. The dashed red wedge is futility. The vertical line is
#' the RIS; beyond it the boundaries collapse to the conventional 1.96.
#'
#' @name easyTSA-3-plot
NULL

#' Guide 4: the TSA program
#'
#' @description
#' The Copenhagen Trial Unit's TSA program (Java, version 0.9.5.10 Beta) is
#' free to use but may not be redistributed, so it is not bundled.
#' [tsa_setup()] downloads it from the Copenhagen Trial Unit
#' (<https://ctu.dk/tools>; the zip contains `TSA.jar`, `lib/`, the user
#' manual and the license) after you accept the license, installs Java
#' through \pkg{rJavaEnv} when none works, and remembers both:
#' ```r
#' tsa_setup()
#' tsa_engine()   # starts the program's engine inside R; errors explain what is missing
#' ```
#' An existing installation can be used instead with
#' `Sys.setenv(TSA_HOME = "<folder with TSA.jar>")` or
#' `options(easyTSA.jar = "<path>/TSA.jar")`. easyTSA is not affiliated with
#' the Copenhagen Trial Unit.
#'
#' @section How it runs:
#' [tsa_run()] writes the `.TSA` file, and the program (loaded through
#' `rJava`, headless, no window) reads that file with its own reader and
#' computes the required information size, boundaries, inner wedge and
#' Z-curve with its own classes. The same file opens unchanged in the
#' program's interface (`File > Open`).
#'
#' @section Round trip:
#' ```r
#' tsa_write(tsa_request(m, control = 0.12, rrr = 0.30), "peecs.TSA")  # no program needed
#' d <- tsa_read("peecs.TSA")       # trials back into R
#' ```
#'
#' @name easyTSA-4-software
NULL
