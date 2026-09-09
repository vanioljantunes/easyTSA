#' Prophylactic antibiotics and post-ESD electrocoagulation syndrome
#'
#' Seven comparative studies (2 randomised, 5 observational) of prophylactic
#' antibiotics (ATB) versus no antibiotics around endoscopic submucosal
#' dissection (ESD), outcome post-ESD electrocoagulation syndrome (PEECS).
#' Main outcome of a MetaHub mentorship project (2026), used here as the
#' worked example. Event counts favour the intervention when the relative
#' risk is below 1 (`outcome = "negative"` in [tsa_run()]).
#'
#' @format A data frame with 7 rows and 9 columns:
#' \describe{
#'   \item{author}{First author.}
#'   \item{year}{Publication year (trial order for the TSA).}
#'   \item{event.e, n.e}{PEECS events and participants, ATB arm.}
#'   \item{event.c, n.c}{PEECS events and participants, no-ATB arm.}
#'   \item{design}{`"RCT"` or `"Observational"`.}
#'   \item{organ}{Organ treated by ESD.}
#'   \item{country}{Country.}
#' }
#' @source MetaHub mentorship project "ATB prophylaxis and PEECS after ESD",
#'   data extraction sheet `A_peecs` (2026-09).
#' @examples
#' atb_peecs
#' m <- meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
#'                    studlab = paste(author, year), sm = "RR")
#' tsa_request(m, control = 0.12, rrr = 0.30)
"atb_peecs"
