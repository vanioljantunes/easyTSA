# ============================================================================
# plot.R  -  tsa_plot(): the TSA graph with ggplot2
#
# Layout mirrors the TSA software:
#   x  = cumulative number of participants (linear)
#   y  = cumulative Z-score, positive = favours intervention
#   blue squares/line  = Z-curve
#   red diamonds/line  = Lan-DeMets monitoring boundaries (upper + lower)
#   red dashed wedge   = futility boundaries (inner wedge)
#   grey dashed        = conventional +/- 1.96
#   vertical line      = required information size (RIS)
# ============================================================================

#' Plot a Trial Sequential Analysis
#'
#' Draws the TSA graph (cumulative Z-curve, monitoring boundaries, inner
#' wedge, conventional limits and RIS) as a `ggplot` object, so any layer or
#' theme can be added afterwards.
#'
#' @param x An `easytsa` object from [tsa_run()].
#' @param title Plot title (default: the analysis title).
#' @param subtitle Subtitle; default is an automatic line with RIS, effect
#'   and diversity. Use `NULL` to suppress.
#' @param xlab,ylab Axis labels.
#' @param show_futility Draw the inner wedge (default: when computed).
#' @param show_conventional Draw the +/- 1.96 lines (default `TRUE`).
#' @param show_labels Label each look with its study name (default
#'   `FALSE`).
#' @param show_favours Print "Favours ..." labels on the y axis sides
#'   (default `TRUE`).
#' @param ris_label Text for the RIS line; `NULL` to suppress. Default
#'   `"RIS = <n>"`.
#' @param col_z,col_bound,col_futility,col_conv Colours.
#' @param ylim Limits of the y axis (default `c(-8, 8)`, as in TSA).
#' @param line_size,point_size Sizes.
#' @param x_pad Extra proportion of the x axis to the right of the RIS or of
#'   the last trial (default 0.05).
#' @param ... Ignored.
#'
#' @return A `ggplot` object.
#' @examples
#' # result produced by the TSA program on the bundled example (no Java needed)
#' x <- readRDS(system.file("extdata", "atb_peecs_result.rds", package = "easyTSA"))
#' tsa_plot(x)
#' tsa_plot(x, show_labels = TRUE, col_z = "black") +
#'   ggplot2::theme_classic()
#' @export
tsa_plot <- function(x, title = x$settings$title, subtitle = "auto",
                     xlab = "Cumulative number of participants",
                     ylab = "Cumulative Z-score",
                     show_futility = x$settings$futility,
                     show_conventional = TRUE, show_labels = FALSE,
                     show_favours = TRUE, ris_label = "auto",
                     col_z = "#1f4e9c", col_bound = "#c0392b",
                     col_futility = "#c0392b", col_conv = "grey40",
                     ylim = c(-8, 8), line_size = 0.7, point_size = 2.2,
                     x_pad = 0.05, ...) {
  if (!inherits(x, "easytsa")) stop("`x` must be an easytsa object.")
  L <- x$looks; B <- x$bounds; s <- x$settings
  conv <- stats::qnorm(1 - x$ris$alpha / 2)
  ris <- x$ris$ris
  xmax <- max(ris, max(L$n_cum)) * (1 + x_pad)

  # Z-curve, starting at the origin like the TSA software.
  zc <- data.frame(n = c(0, L$n_cum), z = c(0, pmin(pmax(L$z, ylim[1]), ylim[2])),
                   study = c("", L$studlab), look = c(0, L$k))
  # Monitoring boundaries: lines through the looks and the RIS point.
  bd <- B[order(B$n_cum), ]
  bd <- bd[bd$n_cum <= ris, ]
  bu <- bd[!is.na(bd$upper), ]
  bd_long <- rbind(
    data.frame(n = bu$n_cum, z = pmin(bu$upper, ylim[2]), side = "upper"),
    data.frame(n = bu$n_cum, z = pmax(-bu$upper, ylim[1]), side = "lower"))
  # Inner wedge.
  fw <- bd[!is.na(bd$futility), ]
  fut_long <- NULL
  if (isTRUE(show_futility) && nrow(fw) > 0) {
    # emerge from the x axis: interpolate the crossing before the first point
    first <- which(!is.na(bd$futility))[1]
    if (first > 1 && !any(fw$futility == 0)) {
      fw <- rbind(data.frame(n_cum = bd$n_cum[first - 1], upper = NA_real_,
                             futility = 0, virtual = TRUE, IF = NA, k = NA)[names(fw)], fw)
    }
    fut_long <- rbind(
      data.frame(n = fw$n_cum, z = fw$futility, side = "upper"),
      data.frame(n = fw$n_cum, z = -fw$futility, side = "lower"))
  }

  p <- ggplot2::ggplot() +
    ggplot2::geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.4)
  if (isTRUE(show_conventional)) {
    p <- p + ggplot2::geom_hline(yintercept = c(-conv, conv), colour = col_conv,
                                 linetype = "dashed", linewidth = 0.4)
  }
  p <- p +
    ggplot2::geom_vline(xintercept = ris, colour = "black", linewidth = 0.5) +
    ggplot2::geom_line(data = bd_long,
                       ggplot2::aes(x = .data$n, y = .data$z, group = .data$side),
                       colour = col_bound, linewidth = line_size) +
    ggplot2::geom_point(data = bd_long[bd_long$n < ris, ],
                        ggplot2::aes(x = .data$n, y = .data$z),
                        colour = col_bound, shape = 18, size = point_size + 1)
  if (!is.null(fut_long)) {
    p <- p + ggplot2::geom_line(
      data = fut_long,
      ggplot2::aes(x = .data$n, y = .data$z, group = .data$side),
      colour = col_futility, linetype = "longdash", linewidth = line_size)
  }
  p <- p +
    ggplot2::geom_line(data = zc, ggplot2::aes(x = .data$n, y = .data$z),
                       colour = col_z, linewidth = line_size) +
    ggplot2::geom_point(data = zc[-1, ], ggplot2::aes(x = .data$n, y = .data$z),
                        colour = col_z, shape = 15, size = point_size)
  if (isTRUE(show_labels)) {
    lab <- zc[-1, ]
    lab$hjust <- ifelse(lab$n > 0.8 * xmax, 1.1, -0.15)
    p <- p + ggplot2::geom_text(
      data = lab, ggplot2::aes(x = .data$n, y = .data$z, label = .data$study,
                               hjust = .data$hjust),
      size = 3, vjust = -0.6, colour = col_z)
  }
  if (!is.null(ris_label)) {
    if (identical(ris_label, "auto")) ris_label <- sprintf("RIS = %d", ris)
    p <- p + ggplot2::annotate("label", x = ris, y = ylim[2], label = ris_label,
                               vjust = 1, hjust = 1.05, size = 3.2)
  }
  if (isTRUE(show_favours)) {
    p <- p +
      ggplot2::annotate("text", x = xmax * 0.01, y = ylim[2] - 1.2, hjust = 0,
                        label = paste("Favours", s$label.e), size = 3.2,
                        fontface = "italic") +
      ggplot2::annotate("text", x = xmax * 0.01, y = ylim[1] + 1.2, hjust = 0,
                        label = paste("Favours", s$label.c), size = 3.2,
                        fontface = "italic")
  }
  if (identical(subtitle, "auto")) {
    r <- x$ris
    subtitle <- sprintf("TSA program, %s, %s. RIS %d (control %.1f%%, RRR %.0f%%, alpha %.0f%%, power %.0f%%, D2 %.0f%%)",
                        s$sm, s$model, ris, 100 * r$control, 100 * r$rrr,
                        100 * r$alpha, 100 * (1 - r$beta), 100 * r$d2)
  }
  p +
    ggplot2::scale_x_continuous(limits = c(0, xmax), expand = c(0, 0)) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::scale_y_continuous(limits = ylim, breaks = seq(ylim[1], ylim[2], 2)) +
    ggplot2::labs(title = title, subtitle = subtitle, x = xlab, y = ylab) +
    ggplot2::theme_bw() +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
                   plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30"))
}

#' @export
plot.easytsa <- function(x, ...) print(tsa_plot(x, ...))
