# ============================================================================
# write.R  -  .TSA file writer and reader
#
# File format: plain text, tab-separated key/value lines inside
# #METAANALYSIS, #TRIAL, #BOUNDARY and #GRAPH blocks, as in the files the
# TSA program saves. Numeric codes as observed in saved files:
#     outcomeType     1 negative, -1 positive
#     trialType       1 dichotomous, 2 continuous
#     effectModel     10 Fixed, 11 Random DL, 12 Random BT, 16 Random SJ
#     effectMeasure   1 RR, 2 RD, 3 OR, 4 MD, 6 Peto OR
#     boundary type   103 two-sided
#     oisType         603 estimate
#     interventionEffectType 204 RRR user defined, 205 RRR low-bias based (program estimates)
#     timeAxisScaling 302 sample size
#     heterogeneityCorrection 401 model variance based (program estimates),
#                     404 user defined value
#     alphaSpendingFunction 501 O'Brien-Fleming
#     betaSpendingFunction  802 O'Brien-Fleming
# ============================================================================

.tsa_line <- function(key, value) paste0(key, "\t", paste(value, collapse = "\t"))

#' Write a .TSA file for the Copenhagen Trial Unit TSA software
#'
#' Serialises the trials and settings of a [tsa_request()] (or of an
#' `easytsa` result that still carries its request) into the text format the
#' TSA program reads, with one conventional boundary and one alpha-spending
#' boundary carrying the anticipated effect, power and heterogeneity choices.
#'
#' @param x A `tsa_request` or `easytsa` object.
#' @param file Output path (extension `.TSA` is added when missing).
#' @param boundary_name Name of the alpha-spending boundary in the file.
#'
#' @return The path, invisibly.
#' @examples
#' m <- meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
#'                    studlab = paste(author, year), sm = "RR")
#' req <- tsa_request(m, label.e = "ATB", label.c = "No ATB")
#' f <- tsa_write(req, tempfile(fileext = ".TSA"))
#' readLines(f)[1:15]
#' @export
tsa_write <- function(x, file, boundary_name = NULL) {
  if (!grepl("\\.tsa$", file, ignore.case = TRUE)) file <- paste0(file, ".TSA")
  if (inherits(x, "easytsa")) {
    if (is.null(x$request)) stop("This easytsa object carries no request; write from tsa_request().")
    x <- x$request
  }
  if (!inherits(x, "tsa_request")) {
    stop("`x` must be a tsa_request (see tsa_request()) or an easytsa object.", call. = FALSE)
  }
  s <- x$settings; trials <- x$trials

  effect_model <- switch(s$model, fixed = 10, random_dl = 11, random_bt = 12,
                         random_sj = 16, 11)
  effect_measure <- switch(s$sm, RR = 1, RD = 2, OR = 3, 1)
  zero_handling <- if (isTRUE(s$incr > 0)) "Constant" else "Ignore"
  ci <- switch(as.character(s$level), "0.95" = "CI_950", "0.99" = "CI_990",
               "0.995" = "CI_995", "0.999" = "CI_999", "CI_950")

  out <- c(
    "#METAANALYSIS BEGIN",
    .tsa_line("identifier", s$title),
    .tsa_line("outcomeType", if (s$outcome == "negative") 1 else -1),
    .tsa_line("trialType", 1),
    .tsa_line("effectModel", effect_model),
    .tsa_line("effectMeasure", effect_measure),
    .tsa_line("zeroEventHandling", zero_handling),
    .tsa_line("zeroEventValue", s$incr),
    .tsa_line("ignoreZeroEventsTrials", "false"),
    .tsa_line("confidenceInterval", ci),
    .tsa_line("confidenceIntervalAlphaSpendingBoundary", ""),
    .tsa_line("group1", s$label.e),
    .tsa_line("group2", s$label.c),
    .tsa_line("comment", "Written by easyTSA"),
    "#METAANALYSIS END", ""
  )

  trials <- trials[order(trials$year, trials$studlab), ]
  for (i in seq_len(nrow(trials))) {
    out <- c(out,
      "#TRIAL BEGIN",
      .tsa_line("sort", "dichotomous"),
      .tsa_line("year", trials$year[i]),
      .tsa_line("study", trials$studlab[i]),
      .tsa_line("interventionEvent", format(trials$event.e[i], nsmall = 1)),
      .tsa_line("interventionTotal", format(trials$n.e[i], nsmall = 1)),
      .tsa_line("controlEvent", format(trials$event.c[i], nsmall = 1)),
      .tsa_line("controlTotal", format(trials$n.c[i], nsmall = 1)),
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

  user_effect <- identical(s$effect_type, "user")
  user_d2 <- !identical(s$diversity, "estimate")
  if (is.null(boundary_name)) {
    boundary_name <- sprintf("%s, D2 %s, power %.0f%%",
      if (user_effect) sprintf("RRR %.0f%%", 100 * s$rrr) else "RRR estimated",
      if (user_d2) sprintf("%.0f%%", 100 * s$diversity) else "estimated",
      100 * (1 - s$beta))
  }
  out <- c(out,
    "#BOUNDARY BEGIN",
    .tsa_line("sort", "sequential dichotome"),
    .tsa_line("identifier", boundary_name),
    .tsa_line("type", 103),
    .tsa_line("type1error", format(alpha_pct, nsmall = 1)),
    .tsa_line("oisType", 603),
    .tsa_line("manualOIS", "0.0"),
    .tsa_line("type2error", format(beta_pct, nsmall = 1)),
    .tsa_line("interventionEffectType", if (user_effect) 204 else 205),
    # in "estimate" mode the program replaces these; crude pooled proportions
    # are written as placeholders (zeros make the program's estimator loop)
    .tsa_line("interventionEffect", round(100 * if (user_effect) s$intervention else
                                          sum(trials$event.e) / sum(trials$n.e), 2)),
    .tsa_line("controlEffect", round(100 * if (user_effect) s$control else
                                     sum(trials$event.c) / sum(trials$n.c), 2)),
    .tsa_line("timeAxisScaling", 302),
    .tsa_line("heterogeneityCorrection", if (user_d2) 404 else 401),
    .tsa_line("heterogeneityCorrectionValue", if (user_d2) round(s$diversity, 4) else "0.0"),
    .tsa_line("alphaSpendingFunction", 501),
    if (isTRUE(s$futility)) .tsa_line("betaSpendingFunction", 802),
    .tsa_line("trials", paste0("(", trials$year, ")", trials$studlab)),
    graph(boundary_name, c(255, 0, 0)),
    "#BOUNDARY END", "")
  writeLines(out, file, useBytes = FALSE)
  invisible(file)
}

#' Read a .TSA file into a data frame
#'
#' Parses the trials of a `.TSA` file (TSA program format) into a data
#' frame ready for [meta::metabin()]. Settings of the meta-analysis block
#' are returned as attributes.
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
