# ============================================================================
# launch.R  -  open the TSA software (Java, user-installed) on a .TSA file
# ============================================================================

#' Locate the TSA software
#'
#' The Copenhagen Trial Unit's TSA program is free to use but its license
#' does not allow redistribution, so it is not bundled. Download it from
#' <https://ctu.dk/tsa/> and tell easyTSA where `TSA.jar` lives with the
#' environment variable `TSA_HOME` (the folder containing `TSA.jar`), or
#' `options(easyTSA.jar = "path/to/TSA.jar")`, or the `jar` argument of
#' [tsa_launch()]. Running it requires a Java runtime (Java 8 or later).
#'
#' @param jar Optional explicit path to `TSA.jar`.
#' @return Path to `TSA.jar`, or `""` when not found.
#' @examples
#' tsa_jar()
#' @export
tsa_jar <- function(jar = NULL) {
  home <- Sys.getenv("TSA_HOME")
  cand <- c(jar, getOption("easyTSA.jar"),
            if (nzchar(home)) file.path(home, "TSA.jar"))
  if (!length(cand)) return("")
  cand <- cand[nzchar(cand) & file.exists(cand)]
  if (length(cand)) normalizePath(cand[1]) else ""
}

#' Launch the TSA software
#'
#' Writes the analysis to a `.TSA` file (when an `easytsa` object is given)
#' and starts the Copenhagen Trial Unit TSA program with Java (see
#' [tsa_jar()] for where the program must be installed). The file is then
#' opened from inside the program (`File > Open`); the path is printed and
#' copied to the clipboard when possible.
#'
#' @param x An `easytsa` object or the path to an existing `.TSA` file.
#' @param file Where to write the `.TSA` file when `x` is an object
#'   (default: a temporary file).
#' @param java Java executable (default: `JAVA_HOME/bin/java` if set,
#'   otherwise `java` on the PATH).
#' @param jar Path to `TSA.jar`; default from [tsa_jar()].
#' @param wait Wait for the program to close (default `FALSE`).
#' @return The `.TSA` path, invisibly. Errors when Java or the TSA program
#'   is not found (the `.TSA` file is still written).
#' @examples
#' \dontrun{
#' m <- meta::metabin(event.e, n.e, event.c, n.c, data = atb_peecs,
#'                    studlab = paste(author, year), sm = "RR")
#' x <- tsa_create(m, rrr = 0.30)
#' tsa_launch(x, file = "peecs.TSA")
#' }
#' @export
tsa_launch <- function(x, file = tempfile(fileext = ".TSA"), java = NULL,
                       jar = NULL, wait = FALSE) {
  path <- if (inherits(x, "easytsa")) tsa_write(x, file) else x
  if (!file.exists(path)) stop("File not found: ", path)
  path <- normalizePath(path)
  if (is.null(java)) {
    jh <- Sys.getenv("JAVA_HOME")
    java <- if (nzchar(jh)) file.path(jh, "bin", "java") else Sys.which("java")
  }
  if (!nzchar(java) || (!file.exists(java) && !nzchar(Sys.which(java)))) {
    stop("Java not found. Install a Java runtime (https://adoptium.net) ",
         "or pass `java = `. The .TSA file was written to:\n  ", path)
  }
  jar <- tsa_jar(jar)
  if (!nzchar(jar)) {
    stop("TSA.jar not found. Download TSA from https://ctu.dk/tsa/ and set ",
         "TSA_HOME (folder with TSA.jar) or options(easyTSA.jar = ...). ",
         "The .TSA file was written to:\n  ", path)
  }
  message("TSA file: ", path, "\nOpen it in the program with File > Open.")
  try(utils::writeClipboard(path), silent = TRUE)
  old <- setwd(dirname(jar)); on.exit(setwd(old))
  system2(java, c("-jar", shQuote(basename(jar))), wait = wait,
          stdout = FALSE, stderr = FALSE)
  invisible(path)
}
