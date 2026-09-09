# ============================================================================
# tsa.R  -  tsa_create(): run a Trial Sequential Analysis on a meta object
#
# The object returned carries everything the plot, the summary and the .TSA
# writer need:
#   $looks    -- one row per cumulative look (trial order = sortvar)
#   $ris      -- output of tsa_ris()
#   $bounds   -- boundary table including the virtual look at IF = 1
#   $settings -- alpha, beta, model, outcome direction, labels
#   $meta     -- the original meta object
# ============================================================================

#' Trial Sequential Analysis of a meta-analysis object
#'
#' Runs a Trial Sequential Analysis (TSA) on an object created by
#' [meta::metabin()] or [meta::metacont()]: cumulative Z-curve in trial
#' order, required information size (RIS) with heterogeneity adjustment,
#' Lan-DeMets O'Brien-Fleming monitoring boundaries, futility boundaries
#' (inner wedge) and the TSA-adjusted confidence interval.
#'
#' @param m A `meta` object (`metabin` or `metacont`).
#' @param rrr Anticipated relative risk reduction (binary data), e.g. `0.20`.
#'   Default `NULL` is the "empirical" option of the TSA software: the
#'   event proportion of each arm is averaged over trials with the weights
#'   of the meta-analysis model, and the RRR is `1 - p_e / p_c`. This is
#'   generally optimistic; give a clinically minimal effect when you have
#'   one.
#' @param control Anticipated control event proportion (binary data).
#'   Default `NULL` uses the weight-averaged control-arm proportion of `m`.
#' @param intervention Anticipated intervention event proportion (binary
#'   data); alternative to `rrr`. Default `NULL`.
#' @param md,variance Anticipated mean difference and variance (continuous
#'   data). Defaults use the pooled estimate and the pooled within-trial
#'   variance.
#' @param alpha Two-sided type I error (default 0.05).
#' @param beta Type II error (default 0.20 = 80 percent power).
#' @param diversity Heterogeneity adjustment of the RIS: `"D2"` (default,
#'   diversity from `m`), `"I2"`, `"none"`, or a number in `[0, 1)`.
#' @param futility Logical, compute the inner wedge (default `TRUE`).
#' @param model `"random"` (default, if `m` has a random-effects model) or
#'   `"common"`; which pooled estimate feeds the Z-curve.
#' @param outcome `"negative"` (default; the event is a harm, so a relative
#'   risk below 1 favours the intervention) or `"positive"`. Controls the
#'   sign convention: positive Z always means "favours intervention".
#' @param sortvar Variable giving the trial order (usually publication
#'   year). Default: `year` column of the data used in `m`, else the order
#'   of `m`. Ties are broken alphabetically by study label (TSA program
#'   convention).
#' @param spending Spending function for both boundaries, see
#'   [tsa_spending()].
#' @param label.e,label.c Arm labels used in plots and files. Defaults
#'   come from `m` (`label.e`, `label.c`) or are `"Intervention"` /
#'   `"Control"`.
#' @param title Analysis title (default `m$outclab` or `"Meta-analysis"`).
#' @param ngrid Grid size for the boundary integration (see [tsa_bounds()]).
#'
#' @return An object of class `"easytsa"` (a list). Use [print()],
#'   [summary()], [tsa_plot()], [tsa_write()], [tsa_launch()].
#'
#' @examples
#' m <- meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
#'                    studlab = paste(author, year), sm = "RR",
#'                    method = "MH", method.tau = "REML",
#'                    random = TRUE, common = FALSE)
#' # empirical effect: weighted arm proportions from the meta output
#' x <- tsa_create(m, label.e = "ATB", label.c = "No ATB",
#'                 title = "PEECS after ESD")
#' x
#' summary(x)
#' # clinically anticipated effect instead
#' tsa_create(m, rrr = 0.30)
#' @export
tsa_create <- function(m, rrr = NULL, control = NULL, intervention = NULL,
                       md = NULL,
                       variance = NULL, alpha = 0.05, beta = 0.20,
                       diversity = "D2", futility = TRUE,
                       model = c("random", "common"),
                       outcome = c("negative", "positive"),
                       sortvar = NULL, spending = "obf",
                       label.e = NULL, label.c = NULL, title = NULL,
                       ngrid = 801) {
  if (!inherits(m, "meta")) stop("`m` must be a meta object (metabin/metacont).")
  is_bin <- inherits(m, "metabin")
  is_cont <- inherits(m, "metacont")
  if (!is_bin && !is_cont) stop("Only metabin and metacont objects are supported.")
  model <- match.arg(model)
  outcome <- match.arg(outcome)
  if (model == "random" && !isTRUE(m$random)) {
    model <- "common"
    message("`m` has no random-effects model; using common-effect Z-curve.")
  }
  if (is_bin && !(m$sm %in% c("RR", "OR", "RD"))) {
    stop("Binary data: `sm` must be RR, OR or RD.")
  }

  # ---- trial order ------------------------------------------------------
  k <- m$k.all
  if (is.null(sortvar)) {
    sortvar <- if (!is.null(m$data) && "year" %in% names(m$data)) {
      m$data$year
    } else if (!is.null(m$data) && ".year" %in% names(m$data)) {
      m$data$.year
    } else {
      seq_len(k)
    }
  }
  if (length(sortvar) != k) stop("`sortvar` must have one value per study.")
  # Ties within a year are broken alphabetically by study label, as the
  # TSA program does.
  ord <- order(sortvar, m$studlab)
  studlab <- m$studlab[ord]
  n_trial <- (m$n.e + m$n.c)[ord]
  year <- sortvar[ord]

  # ---- cumulative meta-analysis ------------------------------------------
  rank_pos <- integer(k); rank_pos[ord] <- seq_len(k)
  mc <- meta::metacum(m, pooled = model, sortvar = rank_pos)
  TE <- mc$TE[seq_len(k)]
  seTE <- mc$seTE[seq_len(k)]
  z <- TE / seTE
  sign <- if (outcome == "negative") -1 else 1
  z_plot <- sign * z

  # ---- anticipated effect and RIS ---------------------------------------
  div_value <- switch(as.character(diversity),
    D2 = tsa_diversity(m),
    I2 = if (is.finite(m$I2)) max(0, m$I2) else 0,
    none = 0,
    as.numeric(diversity))
  if (!is.finite(div_value) || div_value >= 1) {
    stop("Diversity must be a number in [0, 1).")
  }
  te_pooled <- if (model == "random") m$TE.random else m$TE.common
  if (is_bin) {
    # Weighted arm proportions from the meta output (TSA "empirical"
    # effect): each arm's event proportion averaged with the trial weights
    # of the chosen model.
    w <- if (model == "random") m$w.random else m$w.common
    w <- w / sum(w)
    p_c_w <- sum(w * m$event.c / m$n.c)
    p_e_w <- sum(w * m$event.e / m$n.e)
    if (is.null(control)) control <- p_c_w
    if (is.null(rrr) && is.null(intervention)) {
      intervention <- p_e_w
      rrr <- 1 - intervention / control
      effect_type <- "empirical"
    } else if (!is.null(intervention)) {
      rrr <- 1 - intervention / control
      effect_type <- "user"
    } else {
      effect_type <- "user"
    }
    ris <- tsa_ris(control = control, rrr = rrr, alpha = alpha,
                   beta = beta, diversity = div_value)
    ris$arm_weights <- data.frame(studlab = m$studlab, weight = w,
                                  p.e = m$event.e / m$n.e,
                                  p.c = m$event.c / m$n.c)
  } else {
    if (is.null(md)) { md <- te_pooled; effect_type <- "empirical" }
    else effect_type <- "user"
    if (is.null(variance)) {
      df <- (m$n.e - 1) + (m$n.c - 1)
      variance <- sum(((m$n.e - 1) * m$sd.e^2 + (m$n.c - 1) * m$sd.c^2)) /
        sum(df)
    }
    ris <- tsa_ris(md = md, variance = variance, alpha = alpha,
                   beta = beta, diversity = div_value)
  }

  # ---- looks and boundaries ---------------------------------------------
  n_cum <- cumsum(n_trial)
  IF <- n_cum / ris$ris
  looks <- data.frame(
    k = seq_len(k), studlab = studlab, year = year, n = n_trial,
    n_cum = n_cum, IF = IF, TE = TE, seTE = seTE, z = z, z_plot = z_plot,
    stringsAsFactors = FALSE
  )
  bounds <- .tsa_boundaries(looks, ris$ris, alpha, beta, futility,
                            spending, ngrid)
  looks$upper <- bounds$upper[seq_len(k)]
  looks$futility <- bounds$futility[seq_len(k)]

  # ---- labels ------------------------------------------------------------
  if (is.null(label.e)) label.e <- if (!is.null(m$label.e) && nzchar(m$label.e)) m$label.e else "Intervention"
  if (is.null(label.c)) label.c <- if (!is.null(m$label.c) && nzchar(m$label.c)) m$label.c else "Control"
  if (is.null(title)) title <- if (!is.null(m$outclab) && nzchar(m$outclab)) m$outclab else "Meta-analysis"

  out <- list(
    looks = looks, bounds = bounds, ris = ris,
    settings = list(alpha = alpha, beta = beta, model = model,
                    outcome = outcome, futility = futility,
                    spending = spending, diversity = diversity,
                    diversity_value = div_value, effect_type = effect_type,
                    sm = m$sm, type = if (is_bin) "binary" else "continuous",
                    label.e = label.e, label.c = label.c, title = title),
    meta = m
  )
  class(out) <- "easytsa"
  out$conclusion <- .tsa_conclusion(out)
  out$adjusted_ci <- .tsa_adjusted_ci(out)
  out
}

# Boundary table: actual looks with IF < 1, plus a virtual look at IF = 1
# so the boundary lines reach the RIS. Looks past the RIS get the
# conventional boundary (alpha fully spent), as in the TSA software.
.tsa_boundaries <- function(looks, ris, alpha, beta, futility, spending,
                            ngrid) {
  k <- nrow(looks)
  IF <- looks$IF
  inside <- IF < 1
  t_in <- IF[inside]
  t_all <- c(t_in, 1)
  upper_in <- tsa_bounds(t_all, alpha = alpha, spending = spending,
                         ngrid = ngrid)
  fut_in <- if (futility) {
    tsa_futility(t_all, upper_in, alpha = alpha, beta = beta,
                 spending = spending, ngrid = ngrid)
  } else rep(NA_real_, length(t_all))
  conv <- stats::qnorm(1 - alpha / 2)
  upper <- rep(conv, k); fut <- rep(NA_real_, k)
  upper[inside] <- upper_in[seq_along(t_in)]
  fut[inside] <- fut_in[seq_along(t_in)]
  data.frame(
    k = c(looks$k, NA), IF = c(IF, 1), n_cum = c(looks$n_cum, ris),
    upper = c(upper, upper_in[length(t_all)]),
    futility = c(fut, fut_in[length(t_all)]),
    virtual = c(rep(FALSE, k), TRUE)
  )
}

.tsa_conclusion <- function(x) {
  L <- x$looks
  last <- L[nrow(L), ]
  conv <- stats::qnorm(1 - x$settings$alpha / 2)
  crossed_any <- which(abs(L$z_plot) >= L$upper)
  fut_ok <- !is.na(L$futility)
  fut_cross <- which(fut_ok & abs(L$z_plot) <= L$futility & L$IF < 1)
  status <- if (length(crossed_any)) {
    dir <- if (L$z_plot[crossed_any[1]] > 0) x$settings$label.e else x$settings$label.c
    sprintf("Monitoring boundary for benefit of %s crossed at look %d (%s).",
            dir, crossed_any[1], L$studlab[crossed_any[1]])
  } else if (length(fut_cross)) {
    sprintf("Futility boundary crossed at look %d (%s): the anticipated effect can be rejected.",
            fut_cross[1], L$studlab[fut_cross[1]])
  } else if (last$IF >= 1) {
    if (abs(last$z) >= conv) "RIS reached; conventional significance without boundary crossing."
    else "RIS reached without crossing any boundary: no significant effect of the anticipated size."
  } else {
    "Inconclusive: neither the monitoring nor the futility boundaries were crossed, and the RIS was not reached."
  }
  list(status = status,
       crossed = length(crossed_any) > 0, futile = length(fut_cross) > 0,
       ris_reached = last$IF >= 1, first_cross = crossed_any[1],
       first_futile = fut_cross[1])
}

# TSA-adjusted CI at the last look: TE +/- boundary * seTE.
.tsa_adjusted_ci <- function(x) {
  L <- x$looks
  last <- L[nrow(L), ]
  zb <- if (last$IF < 1) last$upper else stats::qnorm(1 - x$settings$alpha / 2)
  lo <- last$TE - zb * last$seTE
  hi <- last$TE + zb * last$seTE
  conv <- stats::qnorm(1 - x$settings$alpha / 2)
  backtrans <- x$settings$sm %in% c("RR", "OR", "HR")
  f <- if (backtrans) exp else identity
  data.frame(
    type = c("conventional", "TSA-adjusted"),
    estimate = f(last$TE),
    lower = f(c(last$TE - conv * last$seTE, lo)),
    upper = f(c(last$TE + conv * last$seTE, hi)),
    z_boundary = c(conv, zb)
  )
}

#' @export
print.easytsa <- function(x, digits = 3, ...) {
  s <- x$settings; r <- x$ris; L <- x$looks; last <- L[nrow(L), ]
  cat("Trial Sequential Analysis:", s$title, "\n")
  cat(sprintf("  %s vs %s, %s, %s model, %d trials, %d participants\n",
              s$label.e, s$label.c, s$sm, s$model, nrow(L), last$n_cum))
  if (s$type == "binary") {
    cat(sprintf("  Anticipated effect (%s): control %.2f%%, intervention %.2f%%, RRR %.1f%%\n",
                if (s$effect_type == "empirical") "empirical, weighted arms" else "user",
                100 * r$control, 100 * r$intervention, 100 * r$rrr))
  } else {
    cat(sprintf("  Anticipated effect: MD %.3g (%s), variance %.3g\n",
                r$md, s$effect_type, r$variance))
  }
  cat(sprintf("  alpha %.3g (two-sided), power %.0f%%, %s spending\n",
              s$alpha, 100 * (1 - s$beta), toupper(s$spending)))
  cat(sprintf("  Diversity adjustment: %s = %.1f%% (factor %.2f)\n",
              if (is.character(s$diversity)) s$diversity else "user",
              100 * s$diversity_value, r$adjustment))
  cat(sprintf("  RIS = %d (fixed-effect RIS = %.0f); information fraction %.1f%%\n",
              r$ris, r$ris_fixed, 100 * last$IF))
  cat(sprintf("  Cumulative Z = %.2f; boundary at last look = %.2f\n",
              last$z_plot, last$upper))
  cat("  Conclusion:", x$conclusion$status, "\n")
  invisible(x)
}

#' Summary of a Trial Sequential Analysis
#'
#' Prints the per-look table (cumulative sample size, information fraction,
#' cumulative Z, boundaries) and the conventional vs TSA-adjusted confidence
#' interval of the final estimate.
#'
#' @param object An `easytsa` object.
#' @param digits Digits for printing.
#' @param ... Ignored.
#' @return Invisibly, a list with `looks` and `adjusted_ci`.
#' @export
summary.easytsa <- function(object, digits = 3, ...) {
  print(object)
  L <- object$looks
  tab <- data.frame(
    Look = L$k, Study = L$studlab, Year = L$year, N = L$n_cum,
    IF = round(L$IF, 3), Z = round(L$z_plot, digits),
    Boundary = round(L$upper, digits),
    Futility = round(L$futility, digits),
    stringsAsFactors = FALSE
  )
  cat("\nCumulative looks (Z > 0 favours", object$settings$label.e, "):\n")
  print(tab, row.names = FALSE, na.print = "")
  cat("\nFinal estimate (", object$settings$sm, "):\n", sep = "")
  ci <- object$adjusted_ci
  ci[-1] <- lapply(ci[-1], round, digits)
  print(ci, row.names = FALSE)
  invisible(list(looks = tab, adjusted_ci = object$adjusted_ci))
}
