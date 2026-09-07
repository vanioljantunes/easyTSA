# ============================================================================
# boundaries.R  -  Lan-DeMets alpha-spending and beta-spending boundaries
#
# Reference: TSA User Manual (Copenhagen Trial Unit, 2017), sections
#   2.2.4 (alpha-spending), 2.2.7 (beta-spending / inner wedge).
#
# The engine is the classic recursive numerical integration of the
# sub-density of a Brownian motion observed at information fractions
# t_1 < ... < t_K (Armitage, McPherson & Rowe 1969; Lan & DeMets 1983).
# Work is done on the partial-sum scale S(t) ~ N(theta * t, t), and
# boundaries are reported on the Z scale (Z_k = S_k / sqrt(t_k)).
# Boundaries are truncated at +/- 8, exactly as the TSA software does.
# ============================================================================

#' Alpha- and beta-spending functions
#'
#' `tsa_spending()` evaluates the O'Brien-Fleming-type (Lan-DeMets) or
#' Pocock-type spending function at information fraction `t`.
#'
#' @param t Information fraction(s) in `(0, 1]`.
#' @param error Total error to be spent (`alpha` for significance
#'   boundaries, `beta` for futility boundaries).
#' @param type `"obf"` (default, O'Brien-Fleming-type, the only function
#'   offered by the TSA software) or `"pocock"`.
#'
#' @return Numeric vector, cumulative error spent at each `t`.
#' @examples
#' tsa_spending(c(0.25, 0.5, 1), error = 0.05)
#' @export
tsa_spending <- function(t, error, type = c("obf", "pocock")) {
  type <- match.arg(type)
  t <- pmin(pmax(t, 1e-8), 1)
  if (type == "obf") {
    2 * (1 - stats::pnorm(stats::qnorm(1 - error / 2) / sqrt(t)))
  } else {
    error * log(1 + (exp(1) - 1) * t)
  }
}

# Grid used by the recursion. Wide enough for drifted processes.
.ld_grid <- function(ngrid, tmax, drift) {
  half <- 8 * sqrt(tmax) + abs(drift) * tmax
  seq(-half, half, length.out = ngrid)
}

# Trapezoid integral of f over x restricted by a logical mask.
.ld_int <- function(x, f, mask = NULL) {
  if (!is.null(mask)) f <- f * mask
  h <- x[2] - x[1]
  h * (sum(f) - 0.5 * (f[1] + f[length(f)]))
}

# Propagate the (sub-)density from look k-1 to look k.
.ld_step <- function(x, dens, dt, drift) {
  h <- x[2] - x[1]
  kern <- outer(x, x, function(new, old)
    stats::dnorm(new - old, mean = drift * dt, sd = sqrt(dt)))
  as.vector(kern %*% dens) * h
}

#' Lan-DeMets significance boundaries
#'
#' Computes the two-sided (symmetric) or one-sided monitoring boundaries on
#' the Z scale for looks at information fractions `t`, spending `alpha`
#' according to `spending`. Two-sided boundaries follow the Lan-DeMets
#' program convention (Reboussin et al. 2000, also used by the TSA software
#' and the ldbounds package): a one-sided recursion spending `alpha / 2`,
#' mirrored. Four equally spaced looks at `alpha = 0.05` give
#' 4.333, 2.963, 2.359, 2.014.
#'
#' @param t Increasing vector of information fractions in `(0, 1]`.
#' @param alpha Total two-sided type I error (default 0.05).
#' @param sides `2` (default) or `1`.
#' @param spending Spending function, see [tsa_spending()].
#' @param ngrid Grid size of the numerical integration (default 801, which
#'   reproduces the TSA software to about two decimals).
#' @param trunc Truncation of the boundary (default 8, as in TSA).
#'
#' @return Numeric vector of boundary values (positive; the lower boundary
#'   is its negative when `sides = 2`).
#' @examples
#' tsa_bounds(c(0.25, 0.5, 0.75, 1))
#' @export
tsa_bounds <- function(t, alpha = 0.05, sides = 2, spending = "obf",
                       ngrid = 801, trunc = 8) {
  stopifnot(all(diff(t) > 0), all(t > 0), all(t <= 1))
  K <- length(t)
  # Symmetric two-sided bounds: one-sided recursion spending alpha / 2 per
  # side, as in the Lan-DeMets program (Reboussin et al. 2000) and ldbounds.
  a_side <- if (sides == 2) alpha / 2 else alpha
  spent <- tsa_spending(t, a_side, spending)
  incr <- diff(c(0, spent))
  x <- .ld_grid(ngrid, max(t), 0)
  b <- numeric(K)
  dens <- NULL
  for (k in seq_len(K)) {
    if (k == 1) {
      dens <- stats::dnorm(x, 0, sqrt(t[1]))
    } else {
      dens <- .ld_step(x, dens, t[k] - t[k - 1], 0)
    }
    tail_prob <- function(z) .ld_int(x, dens, x >= z * sqrt(t[k]))
    if (incr[k] <= 1e-10 || tail_prob(trunc) >= incr[k]) {
      b[k] <- trunc
    } else {
      b[k] <- stats::uniroot(function(z) tail_prob(z) - incr[k],
                             c(0, trunc), tol = 1e-6)$root
    }
    dens <- dens * (x < b[k] * sqrt(t[k]))
  }
  b
}

#' Lan-DeMets futility boundaries (inner wedge)
#'
#' Computes the non-superiority (futility) boundaries for the positive side of
#' a two-sided design, spending `beta` with a beta-spending function under
#' the alternative hypothesis that the true drift equals the anticipated
#' effect. The inner wedge shown by the TSA software mirrors this boundary
#' to the negative side (non-inferiority).
#'
#' @param t Increasing vector of information fractions in `(0, 1]`.
#' @param upper Significance boundaries at the same looks (from
#'   [tsa_bounds()]).
#' @param alpha Two-sided type I error used for `upper`.
#' @param beta Type II error (1 - power).
#' @param spending Beta-spending function, see [tsa_spending()].
#' @param ngrid,trunc As in [tsa_bounds()].
#'
#' @return Numeric vector of futility boundaries on the Z scale. Values are
#'   `NA` where the boundary is not defined (negative, i.e. before the wedge
#'   emerges) and equal `upper` where the two boundaries meet.
#' @examples
#' t <- c(0.25, 0.5, 0.75, 1)
#' tsa_futility(t, tsa_bounds(t))
#' @export
tsa_futility <- function(t, upper, alpha = 0.05, beta = 0.2,
                         spending = "obf", ngrid = 801, trunc = 8) {
  stopifnot(length(t) == length(upper))
  K <- length(t)
  drift <- stats::qnorm(1 - alpha / 2) + stats::qnorm(1 - beta)
  spent <- tsa_spending(t, beta, spending)
  incr <- diff(c(0, spent))
  x <- .ld_grid(ngrid, max(t), drift)
  fut <- numeric(K)
  dens <- NULL
  for (k in seq_len(K)) {
    if (k == 1) {
      dens <- stats::dnorm(x, drift * t[1], sqrt(t[1]))
    } else {
      dens <- .ld_step(x, dens, t[k] - t[k - 1], drift)
    }
    low_prob <- function(z) .ld_int(x, dens, x <= z * sqrt(t[k]))
    if (incr[k] <= 1e-10 || low_prob(-trunc) >= incr[k]) {
      fut[k] <- -trunc
    } else if (low_prob(upper[k]) <= incr[k]) {
      fut[k] <- upper[k]
    } else {
      fut[k] <- stats::uniroot(function(z) low_prob(z) - incr[k],
                               c(-trunc, upper[k]), tol = 1e-6)$root
    }
    lo <- fut[k] * sqrt(t[k]); hi <- upper[k] * sqrt(t[k])
    dens <- dens * (x > lo & x < hi)
  }
  fut[fut < 0] <- NA_real_
  fut
}
