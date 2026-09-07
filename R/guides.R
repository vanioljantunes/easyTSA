# Long-form help pages, in the style of easydta.

#' Guide 1: workflow, from a meta object to a TSA plot
#'
#' @description
#' A Trial Sequential Analysis (TSA) asks whether a cumulative meta-analysis
#' has enough information to be trusted. `easyTSA` reads a fitted
#' `meta::metabin()` (or `metacont()`) object, so nothing has to be typed
#' twice.
#'
#' @section Step 1, fit the meta-analysis as usual:
#' ```r
#' library(meta); library(easyTSA)
#' m <- metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
#'              studlab = paste(author, year), sm = "RR",
#'              method = "MH", method.tau = "REML",
#'              random = TRUE, common = FALSE)
#' ```
#' Any `metabin` settings are respected: the Z-curve uses the same effect
#' measure, model and continuity correction as the forest plot.
#'
#' @section Step 2, create the TSA:
#' ```r
#' x <- tsa_create(m, rrr = 0.30, label.e = "ATB", label.c = "No ATB",
#'                 title = "PEECS after ESD")
#' x            # one-screen summary
#' summary(x)   # per-look table and TSA-adjusted CI
#' ```
#' The three decisions you must make are the anticipated effect (`rrr`, or
#' `md` for continuous data), the control-group risk (`control`, defaults to
#' the pooled control risk of `m`) and the heterogeneity adjustment
#' (`diversity`, defaults to the D-squared of `m`). Leaving `rrr` empty
#' uses the pooled estimate itself ("empirical"), which is the least
#' conservative choice; prefer a clinically minimal effect.
#'
#' @section Step 3, plot:
#' ```r
#' tsa_plot(x)
#' tsa_plot(x, show_labels = TRUE)
#' ```
#' See [easyTSA-3-plot] for every knob.
#'
#' @section Step 4, optional, open in the TSA program:
#' ```r
#' tsa_write(x, "peecs.TSA")   # file for the Java program
#' tsa_launch(x)               # writes and starts the program (needs Java)
#' ```
#'
#' @section Trial order:
#' Looks are ordered by `sortvar` (default: the `year` column of the data
#' used in `m`). Cumulative sample size is the information axis, as in the
#' TSA program's default ("sample size" scaling).
#'
#' @name easyTSA-1-workflow
NULL

#' Guide 2: what the numbers mean
#'
#' @description
#' Short account of the quantities computed by [tsa_create()], with the
#' TSA manual (Copenhagen Trial Unit, 2017) sections to read.
#'
#' @section Required information size (manual section 2.1):
#' The number of participants a single well-powered trial would need to
#' detect the anticipated effect:
#' \deqn{RIS = 4 (z_{1-\alpha/2} + z_{1-\beta})^2 \, \sigma^2 / \delta^2}
#' with, for binary data, \eqn{\delta = P_C - P_I} and
#' \eqn{\sigma^2 = \bar P (1 - \bar P)}, \eqn{\bar P = (P_C + P_I)/2}; for
#' continuous data \eqn{\delta} is the mean difference and \eqn{\sigma^2}
#' the variance. The result is then divided by \eqn{1 - D^2} to allow for
#' between-trial heterogeneity, where \eqn{D^2 = 1 - v_F / v_R} is the
#' diversity (ratio of common-effect to random-effects variances of the
#' pooled estimate). [tsa_ris()] and [tsa_diversity()] expose these.
#'
#' @section Z-curve:
#' At each look k (one per trial, in `sortvar` order) the pooled estimate of
#' the first k trials is recomputed with [meta::metacum()] and turned into
#' \eqn{Z_k = TE_k / SE_k}. Sign convention: for a `"negative"` outcome
#' (harm event) the sign is flipped, so positive Z always means "favours
#' intervention", as in the TSA program.
#'
#' @section Monitoring boundaries (manual section 2.2.4):
#' Lan-DeMets alpha-spending with the O'Brien-Fleming-type function
#' \eqn{\alpha(t) = 2 - 2\Phi(z_{1-\alpha/2} / \sqrt t)}, evaluated at the
#' information fractions \eqn{t_k = N_k / RIS}. The boundary at each look is
#' the Z value that spends exactly \eqn{\alpha(t_k) - \alpha(t_{k-1})},
#' found by the recursive numerical integration of Armitage, McPherson and
#' Rowe. Boundaries are truncated at 8, and looks beyond the RIS receive the
#' conventional \eqn{z_{1-\alpha/2}}. [tsa_bounds()].
#'
#' @section Futility boundaries, inner wedge (manual section 2.2.7):
#' Beta-spending with the same O'Brien-Fleming-type shape, computed under
#' the alternative hypothesis (drift \eqn{z_{1-\alpha/2} + z_{1-\beta}}).
#' Crossing the wedge before the RIS means the anticipated effect can be
#' rejected. The wedge is only drawn once it emerges above zero.
#' [tsa_futility()].
#'
#' @section TSA-adjusted confidence interval (manual section 6.2.1):
#' At the last look, the conventional \eqn{TE \pm 1.96\,SE} is replaced by
#' \eqn{TE \pm b_K\,SE}, where \eqn{b_K} is the monitoring boundary at that
#' look. It is wider before the RIS and identical afterwards.
#'
#' @section Differences from the TSA program:
#' The Z-curve uses the estimates of the \pkg{meta} object (any `method`,
#' `method.tau`, continuity correction), whereas the program has its own
#' fixed, DerSimonian-Laird, Sidik-Jonkman and Biggerstaff-Tweedie models.
#' Use `method.tau = "DL"` in `metabin()` to match the program's default
#' random-effects model. D-squared is also taken from the \pkg{meta}
#' variances. Boundaries agree with the program to about two decimals.
#'
#' @name easyTSA-2-theory
NULL

#' Guide 3: customising the plot
#'
#' @description
#' [tsa_plot()] returns a `ggplot`, so the usual `+` grammar applies on top
#' of its own arguments.
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
#' @section Adding layers:
#' ```r
#' tsa_plot(x) +
#'   ggplot2::theme_classic(base_size = 13) +
#'   ggplot2::annotate("text", x = 800, y = -5, label = "Inner wedge",
#'                     colour = "#c0392b")
#' ```
#'
#' @section Saving:
#' ```r
#' p <- tsa_plot(x)
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
#' free to use but may not be redistributed, so it is not bundled. Download
#' it from <https://ctu.dk/tsa/> (the zip contains `TSA.jar`, the user
#' manual and the license), unzip it, and point easyTSA to it:
#' ```r
#' Sys.setenv(TSA_HOME = "C:/Users/me/TSA 0.9.5.10 Beta")  # folder with TSA.jar
#' # or
#' options(easyTSA.jar = "C:/Users/me/TSA 0.9.5.10 Beta/TSA.jar")
#' ```
#'
#' @section Round trip:
#' ```r
#' tsa_write(x, "peecs.TSA")        # R -> program
#' d <- tsa_read("peecs.TSA")       # program -> R (trials data frame)
#' m2 <- meta::metabin(event.e, n.e, event.c, n.c, data = d,
#'                     studlab = studlab, sm = "RR")
#' ```
#' The file written by [tsa_write()] contains the trials, a conventional
#' boundary and an alpha-spending boundary with the same anticipated
#' effect (as a user-defined RRR), power and diversity (as a user-defined
#' heterogeneity correction, so the RIS matches). Open it in the program
#' with `File > Open`, then `Graphs > Perform calculations`.
#'
#' @section Launching:
#' [tsa_launch()] starts the program with `java -jar`. Java is not shipped:
#' install a runtime from https://adoptium.net or set `JAVA_HOME`. Without
#' Java or the program, [tsa_write()] still produces the file.
#'
#' @section Model mapping:
#' `common = TRUE, random = FALSE` in `metabin()` maps to the program's
#' Fixed Effect Model; `method.tau = "DL"` to Random-effects (DL);
#' `"SJ"` to Random-effects (SJ); any other estimator is written as DL,
#' with the R-side Z-curve keeping the estimator you chose.
#'
#' @name easyTSA-4-software
NULL
