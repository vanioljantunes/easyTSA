# ============================================================================
# write.R  -  .TSA file writer and reader
#
# File format: plain text, tab-separated key/value lines inside
# #METAANALYSIS, #TRIAL, #BOUNDARY and #GRAPH blocks, as in the files the
# TSA program saves (see its sample "High perioperative oxygen SSI.TSA").
# Numeric codes as observed in saved files:
#     outcomeType     1 negative, -1 positive
#     trialType       1 dichotomous, 2 continuous
#     effectModel     10 Fixed, 11 Random DL, 12 Random BT, 13 Combined,
#                     14 Hybrid DL, 15 Hybrid BT, 16 Random SJ
#     effectMeasure   1 RR, 2 RD, 3 OR, 4 MD, 6 Peto OR
#     boundary type   101 one-sided upper, 102 one-sided lower, 103 two-sided
#     oisType         602 user defined, 603 estimate
#     interventionEffectType 201 low-bias based, 202 user defined,
#                     203 empirical, 204 RRR user defined, 205 RRR low-bias
#     timeAxisScaling 302 sample size, 303 statistical information, 304 events
#     heterogeneityCorrection 401 variance based (D2 from data),
#                     404 user defined value
#     alphaSpendingFunction 501 O'Brien-Fleming
#     betaSpendingFunction  802 O'Brien-Fleming (from the sample file)
# ============================================================================

.tsa_line <- function(key, value) paste0(key, "\t", paste(value, collapse = "\t"))

#' Write a .TSA file for the Copenhagen Trial Unit TSA software
#'
#' Serialises the trials and settings of an `easytsa` object into the text
#' format read by the TSA program (version 0.9.5.10 Beta), including one
#' conventional boundary and one alpha-spending boundary with the same
#' anticipated effect, diversity and power used in R.
#'
#' @param x An `easytsa` object.
#' @param file Output path (extension `.TSA` is added when missing).
#' @param diversity_mode `"variance"` (default) lets the TSA program
#'   estimate the heterogeneity correction (D2) from its own model ("Model
#'   Variance Based"). `"user"` writes the diversity value used in R as a
#'   user-defined correction instead, so the RIS in the program matches R
#'   exactly.
#' @param boundary_name Name of the alpha-spending boundary in the file.
#'
#' @return The path, invisibly.
#' @examples
#' m <- meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
#'                    studlab = paste(author, year), sm = "RR")
#' x <- tsa_create(m, rrr = 0.30)
#' f <- tsa_write(x, tempfile(fileext = ".TSA"))
#' readLines(f)[1:15]
#' @export
tsa_write <- function(x, file, diversity_mode = c("variance", "user"),
                      boundary_name = NULL) {
  if (!inherits(x, "easytsa")) stop("`x` must be an easytsa object.")
  diversity_mode <- match.arg(diversity_mode)
  if (!grepl("\\.tsa$", file, ignore.case = TRUE)) file <- paste0(file, ".TSA")
  m <- x$meta; s <- x$settings; r <- x$ris; L <- x$looks
  is_bin <- s$type == "binary"

  effect_model <- if (s$model == "common") 10 else switch(
    m$method.tau, DL = 11, SJ = 16, 11)
  effect_measure <- switch(s$sm, RR = 1, RD = 2, OR = 3, MD = 4, 1)
  zero_handling <- if (is_bin && isTRUE(m$incr > 0)) "Constant" else "Ignore"
  zero_value <- if (is_bin && is.numeric(m$incr)) m$incr else 0
  ci <- switch(as.character(m$level), "0.95" = "CI_950", "0.99" = "CI_990",
               "0.995" = "CI_995", "0.999" = "CI_999", "CI_950")

  out <- c(
    "#METAANALYSIS BEGIN",
    .tsa_line("identifier", s$title),
    .tsa_line("outcomeType", if (s$outcome == "negative") 1 else -1),
    .tsa_line("trialType", if (is_bin) 1 else 2),
    .tsa_line("effectModel", effect_model),
    .tsa_line("effectMeasure", effect_measure),
    .tsa_line("zeroEventHandling", zero_handling),
    .tsa_line("zeroEventValue", zero_value),
    .tsa_line("ignoreZeroEventsTrials", "false"),
    .tsa_line("confidenceInterval", ci),
    .tsa_line("confidenceIntervalAlphaSpendingBoundary", ""),
    .tsa_line("group1", s$label.e),
    .tsa_line("group2", s$label.c),
    .tsa_line("comment", "Written by easyTSA"),
    "#METAANALYSIS END", ""
  )

  ord <- match(L$studlab, m$studlab)
  for (i in seq_len(nrow(L))) {
    j <- ord[i]
    trial <- if (is_bin) c(
      "#TRIAL BEGIN",
      .tsa_line("sort", "dichotomous"),
      .tsa_line("year", L$year[i]),
      .tsa_line("study", L$studlab[i]),
      .tsa_line("interventionEvent", format(m$event.e[j], nsmall = 1)),
      .tsa_line("interventionTotal", format(m$n.e[j], nsmall = 1)),
      .tsa_line("controlEvent", format(m$event.c[j], nsmall = 1)),
      .tsa_line("controlTotal", format(m$n.c[j], nsmall = 1))
    ) else c(
      "#TRIAL BEGIN",
      .tsa_line("sort", "continuous"),
      .tsa_line("year", L$year[i]),
      .tsa_line("study", L$studlab[i]),
      .tsa_line("interventionGroupSize", format(m$n.e[j], nsmall = 1)),
      .tsa_line("interventionMeanReponse", m$mean.e[j]),
      .tsa_line("interventionStandardDeviation", m$sd.e[j]),
      .tsa_line("controlGroupSize", format(m$n.c[j], nsmall = 1)),
      .tsa_line("controlMeanReponse", m$mean.c[j]),
      .tsa_line("controlStandardDeviation", m$sd.c[j])
    )
    out <- c(out, trial,
             .tsa_line("isHighQuality", "true"),
             .tsa_line("isForcefullyIgnored", "false"),
             .tsa_line("comment", ""),
             "#TRIAL END", "")
  }

  alpha_pct <- 100 * s$alpha; beta_pct <- 100 * s$beta
  conv_name <- sprintf("%g%%", alpha_pct)
  graph <- function(id, rgb) c(
    "#GRAPH BEGIN", .tsa_line("id", id), .tsa_line("color", rgb),
    .tsa_line("graphLineType", "Full"), .tsa_line("graphIconType", "Diamond Fill"),
    .tsa_line("graphIconSize", 6), .tsa_line("doShow", "true"), "#GRAPH END")
  out <- c(out,
    "#BOUNDARY BEGIN",
    .tsa_line("sort", "conventional"),
    .tsa_line("identifier", conv_name),
    .tsa_line("type", 103),
    .tsa_line("type1error", format(alpha_pct, nsmall = 1)),
    graph(conv_name, c(155, 0, 0)),
    "#BOUNDARY END", "")

  het_code <- if (diversity_mode == "user") 404 else 401
  het_value <- if (diversity_mode == "user") round(s$diversity_value, 4) else 0
  if (is.null(boundary_name)) {
    boundary_name <- if (is_bin) {
      sprintf("RRR %.0f%%, D2 %.0f%%, power %.0f%%", 100 * r$rrr,
              100 * s$diversity_value, 100 * (1 - s$beta))
    } else {
      sprintf("MD %.3g, D2 %.0f%%, power %.0f%%", r$md,
              100 * s$diversity_value, 100 * (1 - s$beta))
    }
  }
  seq_block <- c(
    "#BOUNDARY BEGIN",
    .tsa_line("sort", if (is_bin) "sequential dichotome" else "sequential continuous"),
    .tsa_line("identifier", boundary_name),
    .tsa_line("type", 103),
    .tsa_line("type1error", format(alpha_pct, nsmall = 1)),
    .tsa_line("oisType", 603),
    .tsa_line("manualOIS", "0.0"),
    .tsa_line("type2error", format(beta_pct, nsmall = 1))
  )
  seq_block <- c(seq_block, if (is_bin) c(
    .tsa_line("interventionEffectType", 204),
    .tsa_line("interventionEffect", round(100 * r$intervention, 2)),
    .tsa_line("controlEffect", round(100 * r$control, 2))
  ) else c(
    .tsa_line("meanType", 202),
    .tsa_line("mean", r$md),
    .tsa_line("varianceType", 202),
    .tsa_line("variance", r$variance)
  ))
  seq_block <- c(seq_block,
    .tsa_line("timeAxisScaling", 302),
    .tsa_line("heterogeneityCorrection", het_code),
    .tsa_line("heterogeneityCorrectionValue", het_value),
    .tsa_line("alphaSpendingFunction", 501),
    if (isTRUE(s$futility)) .tsa_line("betaSpendingFunction", 802),
    .tsa_line("trials", paste0("(", L$year, ")", L$studlab)),
    graph(boundary_name, c(255, 0, 0)),
    "#BOUNDARY END", "")
  out <- c(out, seq_block)
  writeLines(out, file, useBytes = FALSE)
  invisible(file)
}

#' Read a .TSA file into a data frame
#'
#' Parses the trials of a `.TSA` file (TSA software format) into a data
#' frame ready for [meta::metabin()] or [meta::metacont()]. Settings of the
#' meta-analysis block are returned as attributes.
#'
#' @param file Path to a `.TSA` file.
#' @return A data frame with `studlab`, `year` and either
#'   `event.e, n.e, event.c, n.c` or `n.e, mean.e, sd.e, n.c, mean.c, sd.c`.
#'   Attribute `"settings"` holds the meta-analysis block as a named list.
#' @examples
#' f <- system.file("extdata", "atb_peecs.TSA", package = "easyTSA")
#' d <- tsa_read(f)
#' d
#' attr(d, "settings")$identifier
#' @export
tsa_read <- function(file) {
  lines <- readLines(file, warn = FALSE, encoding = "UTF-8")
  parse_block <- function(b) {
    kv <- strsplit(b, "\t", fixed = TRUE)
    stats::setNames(lapply(kv, function(v) if (length(v) > 1) v[-1] else ""),
                    vapply(kv, `[`, "", 1))
  }
  blocks <- function(tag) {
    st <- grep(paste0("^#", tag, " BEGIN"), lines)
    en <- grep(paste0("^#", tag, " END"), lines)
    Map(function(a, b) parse_block(lines[(a + 1):(b - 1)]), st, en)
  }
  ma <- blocks("METAANALYSIS")[[1]]
  trials <- blocks("TRIAL")
  num <- function(key) as.numeric(vapply(trials, function(t) t[[key]][1], ""))
  chr <- function(key) vapply(trials, function(t) t[[key]][1], "")
  d <- if (identical(ma$trialType, "2")) data.frame(
    studlab = chr("study"), year = num("year"),
    n.e = num("interventionGroupSize"), mean.e = num("interventionMeanReponse"),
    sd.e = num("interventionStandardDeviation"),
    n.c = num("controlGroupSize"), mean.c = num("controlMeanReponse"),
    sd.c = num("controlStandardDeviation"), stringsAsFactors = FALSE
  ) else data.frame(
    studlab = chr("study"), year = num("year"),
    event.e = num("interventionEvent"), n.e = num("interventionTotal"),
    event.c = num("controlEvent"), n.c = num("controlTotal"),
    stringsAsFactors = FALSE
  )
  d$ignored <- chr("isForcefullyIgnored") == "true"
  attr(d, "settings") <- ma
  d
}
