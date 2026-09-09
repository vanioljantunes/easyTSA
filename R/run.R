# ============================================================================
# run.R  -  tsa_run(): meta object -> .TSA file -> TSA program -> results
#
# Every statistic in the returned object is produced by the program's own
# classes (data.MetaAnalysis, misc.BoundaryCalculations and the graph data
# the program fills for its own display). R only writes the analysis file,
# asks the program for numbers and arranges them in a data frame.
# ============================================================================

#' Run a Trial Sequential Analysis in the TSA program
#'
#' Writes the trials and settings of a [meta::metabin()] object to a `.TSA`
#' file, loads that file into the Copenhagen Trial Unit TSA program (run
#' headlessly inside R, see [tsa_engine()]), lets the program compute the
#' required information size, the cumulative Z-curve, the monitoring
#' boundaries, the inner wedge and the heterogeneity estimate, and returns
#' those numbers.
#'
#' @param m A `metabin` object. Trials, events and totals are taken from it;
#'   estimates are not (the program fits its own model).
#' @param rrr Anticipated relative risk reduction, e.g. `0.20`. Default
#'   `NULL` selects the program's "Estimate" option (empirical effect from
#'   the meta-analysed data).
#' @param control,intervention Anticipated event proportions of the two
#'   arms; alternative to `rrr`. Both `NULL` by default.
#' @param alpha Two-sided type I error (default 0.05).
#' @param beta Type II error (default 0.20 = 80 percent power).
#' @param diversity `"estimate"` (default, the program's "Model Variance
#'   Based" heterogeneity correction) or a number in `[0, 1)` used as a
#'   user-defined D-squared.
#' @param futility Logical, apply the inner wedge (beta-spending, default
#'   `TRUE`).
#' @param model Program model for the pooled estimate and Z-curve:
#'   `"random_dl"` (default, DerSimonian-Laird), `"random_sj"`,
#'   `"random_bt"`, `"fixed"`.
#' @param outcome `"negative"` (default: the event is a harm, a relative
#'   risk below 1 favours the intervention) or `"positive"`.
#' @param label.e,label.c,title Labels used in the file, print and plot.
#' @param file Path for the `.TSA` file. Default: a temporary file, deleted
#'   after the run unless `keep_file = TRUE`.
#' @param keep_file Keep the `.TSA` file (default `TRUE` when `file` is
#'   given).
#' @param jar Path to `TSA.jar`; default from [tsa_jar()].
#'
#' @return An object of class `"easytsa"`: `looks` (one row per trial in
#'   program order: `n_cum`, `IF`, `z`, `upper`, `futility`), `bounds`,
#'   `ris`, `pooled`, `conclusion`, `adjusted_ci`, `settings`, `file`,
#'   `engine`. Use [print()], [summary()], [tsa_plot()].
#'
#' @examples
#' \dontrun{
#' Sys.setenv(TSA_HOME = "C:/Users/me/TSA 0.9.5.10 Beta")
#' m <- meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
#'                    studlab = paste(author, year), sm = "RR")
#' x <- tsa_run(m, label.e = "ATB", label.c = "No ATB",
#'              title = "PEECS after ESD")
#' x
#' summary(x)
#' tsa_plot(x)
#' }
#' @export
tsa_run <- function(m, rrr = NULL, control = NULL, intervention = NULL,
                    alpha = 0.05, beta = 0.20, diversity = "estimate",
                    futility = TRUE,
                    model = c("random_dl", "random_sj", "random_bt", "fixed"),
                    outcome = c("negative", "positive"),
                    label.e = NULL, label.c = NULL, title = NULL,
                    file = NULL, keep_file = !is.null(file), jar = NULL) {
  model <- match.arg(model)
  outcome <- match.arg(outcome)
  req <- tsa_request(m, rrr = rrr, control = control, intervention = intervention,
                     alpha = alpha, beta = beta, diversity = diversity,
                     futility = futility, model = model, outcome = outcome,
                     label.e = label.e, label.c = label.c, title = title)
  eng <- tsa_engine(jar)
  if (is.null(file)) file <- tempfile(fileext = ".TSA")
  tsa_write(req, file)
  on.exit(if (!keep_file) unlink(file), add = TRUE)
  res <- .tsa_extract(eng, file, req)
  res$file <- if (keep_file) normalizePath(file) else NA_character_
  res
}

#' Describe an analysis without running it
#'
#' Builds the request object that [tsa_write()] serialises and [tsa_run()]
#' executes. Useful to write a `.TSA` file for the program's interface
#' without having the program installed.
#'
#' @inheritParams tsa_run
#' @return An object of class `"tsa_request"`.
#' @examples
#' m <- meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
#'                    studlab = paste(author, year), sm = "RR")
#' req <- tsa_request(m, rrr = 0.30, label.e = "ATB", label.c = "No ATB")
#' tsa_write(req, tempfile(fileext = ".TSA"))
#' @export
tsa_request <- function(m, rrr = NULL, control = NULL, intervention = NULL,
                        alpha = 0.05, beta = 0.20, diversity = "estimate",
                        futility = TRUE, model = "random_dl",
                        outcome = "negative", label.e = NULL, label.c = NULL,
                        title = NULL) {
  if (!inherits(m, "metabin")) {
    stop("`m` must be a metabin object (binary outcomes). Continuous outcomes ",
         "are not supported yet.", call. = FALSE)
  }
  if (!(m$sm %in% c("RR", "OR", "RD"))) stop("`sm` must be RR, OR or RD.", call. = FALSE)
  stopifnot(alpha > 0, alpha < 1, beta > 0, beta < 1)
  if (!identical(diversity, "estimate")) {
    diversity <- as.numeric(diversity)
    if (!is.finite(diversity) || diversity < 0 || diversity >= 1) {
      stop("`diversity` must be \"estimate\" or a number in [0, 1).", call. = FALSE)
    }
  }
  effect_type <- "estimate"
  if (!is.null(rrr) || !is.null(intervention)) {
    if (is.null(control)) {
      stop("Give `control` (anticipated control-arm proportion) together with `rrr` or `intervention`.",
           call. = FALSE)
    }
    if (is.null(intervention)) intervention <- control * (1 - rrr)
    if (is.null(rrr)) rrr <- 1 - intervention / control
    effect_type <- "user"
  } else if (!is.null(control)) {
    stop("`control` alone is not enough; add `rrr` or `intervention`.", call. = FALSE)
  }
  year <- if (!is.null(m$data) && "year" %in% names(m$data)) m$data$year else seq_len(m$k.all)
  if (is.null(label.e)) label.e <- if (!is.null(m$label.e) && nzchar(m$label.e)) m$label.e else "Intervention"
  if (is.null(label.c)) label.c <- if (!is.null(m$label.c) && nzchar(m$label.c)) m$label.c else "Control"
  if (is.null(title)) title <- if (!is.null(m$outclab) && nzchar(m$outclab)) m$outclab else "Meta-analysis"
  structure(list(
    meta = m,
    trials = data.frame(studlab = m$studlab, year = year,
                        event.e = m$event.e, n.e = m$n.e,
                        event.c = m$event.c, n.c = m$n.c,
                        stringsAsFactors = FALSE),
    settings = list(alpha = alpha, beta = beta, diversity = diversity,
                    futility = futility, model = model, outcome = outcome,
                    effect_type = effect_type, rrr = rrr, control = control,
                    intervention = intervention, sm = m$sm,
                    incr = if (is.numeric(m$incr)) m$incr else 0.5,
                    level = if (is.numeric(m$level)) m$level else 0.95,
                    label.e = label.e, label.c = label.c, title = title)
  ), class = "tsa_request")
}

# ---- extraction from the program ---------------------------------------------

.tsa_extract <- function(eng, file, req) {
  J <- rJava::.jcall
  io <- eng$io
  ma <- .tsa_call(io, "Ldata/MetaAnalysis;", "loadMetaAnalysis",
                  rJava::.jnew("java.io.File", normalizePath(file)))

  # trials in program order
  tr <- .tsa_call(ma, "[Ldata/TrialInterface;", "getTrialArray")
  trials <- data.frame(
    k = seq_along(tr),
    studlab = vapply(tr, function(t) J(t, "S", "getStudy"), ""),
    year = vapply(tr, function(t) J(t, "I", "getYear"), 1L),
    n = vapply(tr, function(t) J(t, "D", "getTrialSize"), 0),
    stringsAsFactors = FALSE)

  # the alpha-spending boundary written by tsa_write()
  bl <- .tsa_call(ma, "[Ldata/Boundary;", "getBoundaryArray")
  sorts <- vapply(bl, function(b) J(b, "I", "getBoundarySort"), 1L)
  if (!any(sorts == 1002L)) stop("TSA program: no alpha-spending boundary in the file.", call. = FALSE)
  b <- bl[[which(sorts == 1002L)[1]]]
  asb <- rJava::.jcast(b, "data.AlphaSpendingBoundary")
  sb  <- rJava::.jcast(b, "data.SequentialBoundary")
  sbd <- rJava::.jcast(b, "data.SequentialBoundaryDich")
  .tsa_call(sbd, "V", "calculateEffect", ma)

  ris   <- .tsa_call("misc.BoundaryCalculations", "D", "getInformationSize", asb, ma)
  hetf  <- .tsa_call("misc.BoundaryCalculations", "D", "getHeterogeneityCorrection", asb, ma)
  tt    <- .tsa_call("misc.BoundaryCalculations", "[D", "getTArray", sb, ma)
  ctrl  <- .tsa_call(sbd, "D", "getControlEffect") / 100
  intv  <- .tsa_call(sbd, "D", "getInterventionEffect") / 100
  a     <- .tsa_call(asb, "D", "getAlpha")
  bta   <- .tsa_call(asb, "D", "getBeta")

  # monitoring boundary and inner wedge: let the program fill its own graph
  # objects, exactly as its interface does, then read the points back.
  n_cum <- cumsum(trials$n)
  .tsa_call(b, "V", "resetGraph")
  g <- .tsa_call(b, "Ldata/graphs/NewGraph;", "getGraph")
  .tsa_call("misc.BoundaryCalculations", "V", "setBoundaryGraphData",
            b, ma, rJava::.jarray(tt), rJava::.jarray(n_cum), g, ris)
  pts <- function(gr) {
    sh <- J(gr, "[Ldata/graphs/GraphShape;", "getGraphShapes")
    data.frame(x = vapply(sh, function(s) J(s, "D", "getXCoord"), 0),
               y = vapply(sh, function(s) J(s, "D", "getYCoord"), 0))
  }
  all_g <- .tsa_call(g, "[Ldata/graphs/NewGraph;", "getAllGraphs")
  ids <- vapply(all_g, function(gr) J(gr, "S", "getIdentifier"), "")
  is_wedge <- grepl("^Inner Wedge", ids)
  gl <- lapply(all_g, pts)
  upper_pts <- gl[[which(!is_wedge & vapply(gl, function(d) any(d$y > 0), TRUE))[1]]]
  wedge_pts <- if (any(is_wedge)) {
    w <- gl[is_wedge]
    w[[which(vapply(w, function(d) any(d$y > 0), TRUE))[1]]]
  } else NULL
  conv <- stats::qnorm(1 - a / 2)
  last_at <- function(d, x) { i <- which(round(d$x) == round(x)); if (length(i)) d$y[max(i)] else NA_real_ }
  upper <- vapply(n_cum, function(x) last_at(upper_pts, x), 0)
  # looks the program does not draw: truncated at 8 before the RIS (its
  # own truncation value), conventional value after the RIS
  upper[is.na(upper)] <- ifelse(tt[is.na(upper)] < 1, 8, conv)
  fut <- if (!is.null(wedge_pts) && isTRUE(req$settings$futility)) {
    vapply(n_cum, function(x) last_at(wedge_pts, x), 0)
  } else rep(NA_real_, length(n_cum))
  fut[!is.na(fut) & fut <= 0] <- NA_real_

  # cumulative Z-curve as the program draws it (oriented: + favours intervention)
  .tsa_call("misc.BoundaryCalculations", "V", "setDiscreteZCurve", ma, rJava::.jarray(tt), ris)
  g  <- .tsa_call(ma, "Ldata/graphs/NewGraph;", "getZCurveGraphData")
  sh <- .tsa_call(g, "[Ldata/graphs/GraphShape;", "getGraphShapes")
  zx <- vapply(sh, function(s) J(s, "D", "getXCoord"), 0)
  zy <- vapply(sh, function(s) J(s, "D", "getYCoord"), 0)
  keep <- zx > 0
  zx <- zx[keep]; zy <- zy[keep]
  z <- zy[match(round(n_cum), round(zx))]

  looks <- data.frame(trials, n_cum = n_cum, IF = tt, z = z, upper = upper,
                      futility = fut, stringsAsFactors = FALSE)

  ris_int <- ceiling(ris)
  bx <- upper_pts[upper_pts$x > 0, ]
  bx <- bx[!duplicated(bx$x, fromLast = TRUE), ]
  bounds <- data.frame(n_cum = c(bx$x, ris), upper = c(bx$y, conv),
                       futility = NA_real_, virtual = c(rep(FALSE, nrow(bx)), TRUE))
  if (!is.null(wedge_pts)) {
    wx <- wedge_pts[wedge_pts$y >= 0, ]
    bounds$futility <- vapply(bounds$n_cum, function(x) {
      i <- which(round(wx$x) == round(x)); if (length(i)) wx$y[max(i)] else NA_real_
    }, 0)
    # the point where the wedge emerges from the axis
    x0 <- wx$x[wx$y == 0]
    if (length(x0)) bounds <- rbind(bounds, data.frame(n_cum = x0[1], upper = NA_real_,
                                                       futility = 0, virtual = TRUE))
  }
  bounds <- bounds[order(bounds$n_cum), ]
  bounds$IF <- bounds$n_cum / ris
  bounds$k <- match(round(bounds$n_cum), round(n_cum))

  pooled <- list(
    effect = .tsa_call(ma, "D", "getPooledEffect"),
    z = .tsa_call(ma, "D", "getZScore"),
    d2 = .tsa_call(ma, "D", "getDiversity"),
    i2 = .tsa_call(ma, "D", "getInconsistency"),
    tau = .tsa_call(ma, "D", "getTau"),
    model = req$settings$model)

  d2_used <- if (identical(req$settings$diversity, "estimate")) pooled$d2 else req$settings$diversity
  out <- list(
    looks = looks, bounds = bounds,
    ris = list(ris = ris_int, ris_exact = ris, adjustment = hetf, d2 = d2_used,
               control = ctrl, intervention = intv, rrr = 1 - intv / ctrl,
               alpha = a, beta = bta),
    pooled = pooled,
    settings = c(req$settings, list(type = "binary", diversity_value = d2_used)),
    request = req,
    engine = list(jar = eng$jar, tsa_version = eng$tsa_version,
                  java_version = eng$java_version)
  )
  class(out) <- "easytsa"
  out$conclusion <- .tsa_conclusion(out)
  out$adjusted_ci <- .tsa_adjusted_ci(out)
  out
}

.tsa_conclusion <- function(x) {
  L <- x$looks
  last <- L[nrow(L), ]
  conv <- stats::qnorm(1 - x$ris$alpha / 2)
  crossed <- which(abs(L$z) >= L$upper & L$IF < 1)
  fut_cross <- which(!is.na(L$futility) & abs(L$z) <= L$futility & L$IF < 1)
  status <- if (length(crossed)) {
    dir <- if (L$z[crossed[1]] > 0) x$settings$label.e else x$settings$label.c
    sprintf("Monitoring boundary for benefit of %s crossed at look %d (%s).",
            dir, crossed[1], L$studlab[crossed[1]])
  } else if (length(fut_cross)) {
    sprintf("Futility boundary crossed at look %d (%s): the anticipated effect can be rejected.",
            fut_cross[1], L$studlab[fut_cross[1]])
  } else if (last$IF >= 1) {
    if (abs(last$z) >= conv) "RIS reached; conventional significance without boundary crossing."
    else "RIS reached without crossing any boundary: no significant effect of the anticipated size."
  } else {
    "Inconclusive: neither the monitoring nor the futility boundaries were crossed, and the RIS was not reached."
  }
  list(status = status, crossed = length(crossed) > 0, futile = length(fut_cross) > 0,
       ris_reached = last$IF >= 1, first_cross = crossed[1], first_futile = fut_cross[1])
}

# Boundary-adjusted CI at the last look, from the program's pooled estimate,
# its Z and the boundary it computed for that look.
.tsa_adjusted_ci <- function(x) {
  L <- x$looks; last <- L[nrow(L), ]
  sm <- x$settings$sm
  est <- x$pooled$effect
  te <- if (sm %in% c("RR", "OR")) log(est) else est
  se <- abs(te / x$pooled$z)
  conv <- stats::qnorm(1 - x$ris$alpha / 2)
  zb <- if (last$IF < 1) last$upper else conv
  f <- if (sm %in% c("RR", "OR")) exp else identity
  data.frame(type = c("conventional", "TSA-adjusted"),
             estimate = f(te),
             lower = f(c(te - conv * se, te - zb * se)),
             upper = f(c(te + conv * se, te + zb * se)),
             z_boundary = c(conv, zb))
}

#' @rdname tsa_run
#' @param ... Passed to [tsa_run()].
#' @export
tsa_create <- function(m, ...) {
  .Deprecated("tsa_run")
  tsa_run(m, ...)
}

#' @export
print.easytsa <- function(x, digits = 3, ...) {
  s <- x$settings; r <- x$ris; L <- x$looks; last <- L[nrow(L), ]
  cat("Trial Sequential Analysis (TSA program", x$engine$tsa_version, "):", s$title, "\n")
  cat(sprintf("  %s vs %s, %s, %s, %d trials, %d participants\n",
              s$label.e, s$label.c, s$sm, s$model, nrow(L), as.integer(last$n_cum)))
  cat(sprintf("  Anticipated effect (%s): control %.2f%%, intervention %.2f%%, RRR %.1f%%\n",
              if (s$effect_type == "estimate") "estimated by TSA" else "user",
              100 * r$control, 100 * r$intervention, 100 * r$rrr))
  cat(sprintf("  alpha %.3g (two-sided), power %.0f%%, O'Brien-Fleming spending\n",
              r$alpha, 100 * (1 - r$beta)))
  cat(sprintf("  Heterogeneity correction (%s): D2 = %.1f%% (factor %.2f)\n",
              if (identical(s$diversity, "estimate")) "model variance based" else "user",
              100 * r$d2, r$adjustment))
  cat(sprintf("  RIS = %d; information fraction %.1f%%\n", r$ris, 100 * last$IF))
  cat(sprintf("  Pooled %s = %.3f, Z = %.2f; boundary at last look = %.2f\n",
              s$sm, x$pooled$effect, last$z, last$upper))
  cat("  Conclusion:", x$conclusion$status, "\n")
  invisible(x)
}

#' Summary of a Trial Sequential Analysis
#'
#' Per-look table (cumulative participants, information fraction, cumulative
#' Z, boundaries) and the conventional versus boundary-adjusted confidence
#' interval, all as computed by the TSA program.
#'
#' @param object An `easytsa` object.
#' @param digits Digits for printing.
#' @param ... Ignored.
#' @return Invisibly, a list with `looks` and `adjusted_ci`.
#' @export
summary.easytsa <- function(object, digits = 3, ...) {
  print(object)
  L <- object$looks
  tab <- data.frame(Look = L$k, Study = L$studlab, Year = L$year, N = as.integer(L$n_cum),
                    IF = round(L$IF, 3), Z = round(L$z, digits),
                    Boundary = round(L$upper, digits), Futility = round(L$futility, digits),
                    stringsAsFactors = FALSE)
  cat("\nCumulative looks (Z > 0 favours", object$settings$label.e, "):\n")
  print(tab, row.names = FALSE, na.print = "")
  cat("\nFinal estimate (", object$settings$sm, "):\n", sep = "")
  ci <- object$adjusted_ci
  ci[-1] <- lapply(ci[-1], round, digits)
  print(ci, row.names = FALSE)
  invisible(list(looks = tab, adjusted_ci = object$adjusted_ci))
}
