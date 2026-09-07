# ============================================================================
# ris.R  -  Required information size (RIS) and diversity (D^2)
#
# TSA manual eq. (1):  IS = 2 (z_{1-a/2} + z_{1-b})^2 * 2 sigma^2 / delta^2
#   binary:     delta = P_C - P_I,  sigma^2 = P*(1 - P*),  P* = (P_C + P_I)/2
#   continuous: delta = MD,          sigma^2 = variance
# Heterogeneity adjustment: IS_adj = IS / (1 - D^2),  D^2 = 1 - v_F / v_R
# ============================================================================

#' Required information size
#'
#' Sample-size style required information size for a meta-analysis, following
#' the TSA manual (Copenhagen Trial Unit, 2017), equation 1, with optional
#' heterogeneity adjustment.
#'
#' @param control Anticipated control-group event proportion (binary data).
#' @param rrr Anticipated relative risk reduction (e.g. `0.20`), binary data.
#' @param md Anticipated mean difference (continuous data).
#' @param variance Anticipated variance of the outcome (continuous data).
#' @param alpha Two-sided type I error (default 0.05).
#' @param beta Type II error (default 0.20, i.e. 80 percent power).
#' @param diversity Heterogeneity measure used for the adjustment
#'   (`D^2` or `I^2`, in `[0, 1)`). Default 0 (no adjustment).
#'
#' @return A list with `ris` (adjusted, rounded up), `ris_fixed`,
#'   `adjustment`, `delta`, `sigma2` and the inputs.
#' @examples
#' tsa_ris(control = 0.1636, rrr = 0.20)
#' tsa_ris(control = 0.1636, rrr = 0.20, diversity = 0.67)
#' tsa_ris(md = 5, variance = 15^2)
#' @export
tsa_ris <- function(control = NULL, rrr = NULL, md = NULL, variance = NULL,
                    alpha = 0.05, beta = 0.20, diversity = 0) {
  z <- stats::qnorm(1 - alpha / 2) + stats::qnorm(1 - beta)
  if (!is.null(md)) {
    stopifnot(!is.null(variance), md != 0)
    delta <- abs(md); sigma2 <- variance
    intervention <- NULL
  } else {
    stopifnot(!is.null(control), !is.null(rrr), rrr != 0)
    intervention <- control * (1 - rrr)
    delta <- abs(control - intervention)
    pbar <- (control + intervention) / 2
    sigma2 <- pbar * (1 - pbar)
  }
  ris_fixed <- 4 * z^2 * sigma2 / delta^2
  stopifnot(diversity >= 0, diversity < 1)
  adj <- 1 / (1 - diversity)
  list(ris = ceiling(ris_fixed * adj), ris_fixed = ris_fixed,
       adjustment = adj, diversity = diversity,
       delta = delta, sigma2 = sigma2,
       control = control, intervention = intervention, rrr = rrr,
       md = md, variance = variance, alpha = alpha, beta = beta)
}

#' Diversity (D-squared) of a meta object
#'
#' `D^2 = 1 - v_F / v_R`, where `v_F` and `v_R` are the variances of the
#' pooled estimate under the common-effect and random-effects models.
#' This is the heterogeneity measure the TSA software uses to inflate the
#' required information size (TSA manual, section 2.1.2).
#'
#' @param m A `meta` object (e.g. from [meta::metabin()]).
#' @return Numeric in `[0, 1)`.
#' @examples
#' m <- meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
#'                    studlab = paste(author, year), sm = "RR")
#' tsa_diversity(m)
#' @export
tsa_diversity <- function(m) {
  vF <- m$seTE.common^2
  vR <- m$seTE.random^2
  if (is.null(vF) || is.null(vR) || !is.finite(vR) || vR <= 0) return(0)
  max(0, 1 - vF / vR)
}
