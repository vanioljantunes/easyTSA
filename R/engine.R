# ============================================================================
# engine.R  -  start the TSA program's calculation engine inside R
#
# The Copenhagen Trial Unit TSA program is a Java application. easyTSA does
# not reimplement any of its statistics: it starts the program's jar in a
# headless JVM (rJava), loads the .TSA analysis file with the program's own
# reader and asks the program's own classes for every number.
#
# The program is not bundled (its license forbids redistribution).
# tsa_setup() downloads it from its authors and remembers where it is; see
# tsa_jar() for how it is found.
# ============================================================================

.tsa_env <- new.env(parent = emptyenv())

#' Locate the TSA software
#'
#' The Copenhagen Trial Unit's TSA program is free to use but its license
#' does not allow redistribution, so it is not bundled. [tsa_setup()]
#' downloads it from <https://ctu.dk/tools> and remembers where it is. The
#' first existing `TSA.jar` among these is used: the `jar` argument,
#' `options(easyTSA.jar = "path/to/TSA.jar")`, the environment variable
#' `TSA_HOME` (the folder containing `TSA.jar` and `lib/`), and the
#' location saved by [tsa_setup()].
#'
#' @param jar Optional explicit path to `TSA.jar`.
#' @return Path to `TSA.jar`, or `""` when not found.
#' @examples
#' tsa_jar()
#' @export
tsa_jar <- function(jar = NULL) {
  home <- Sys.getenv("TSA_HOME")
  cand <- c(jar, getOption("easyTSA.jar"),
            if (nzchar(home)) file.path(home, "TSA.jar"),
            .tsa_config_read()$jar)
  if (!length(cand)) return("")
  cand <- cand[nzchar(cand) & file.exists(cand)]
  if (length(cand)) normalizePath(cand[1]) else ""
}

.tsa_missing_msg <- function() {
  paste0("TSA program not found. Run tsa_setup() to download it from the ",
         "Copenhagen Trial Unit, or point to an existing copy with ",
         "Sys.setenv(TSA_HOME = \"<folder containing TSA.jar>\") or ",
         "options(easyTSA.jar = \"<path>/TSA.jar\").")
}

#' Start (or reuse) the TSA calculation engine
#'
#' Starts a headless Java virtual machine with the TSA program's jar on the
#' classpath and keeps it for the session. Called automatically by
#' [tsa_run()]; call it yourself to check the installation.
#'
#' @param jar Path to `TSA.jar` (default from [tsa_jar()]).
#' @param restart Logical; discard the cached engine and reload the jar.
#' @return Invisibly, an environment with `jar`, `java_version`,
#'   `tsa_version` and `io` (the program's file reader object).
#' @examples
#' \dontrun{
#' tsa_setup()   # once per machine
#' tsa_engine()
#' }
#' @export
tsa_engine <- function(jar = NULL, restart = FALSE) {
  if (!restart && !is.null(.tsa_env$io) && identical(.tsa_env$jar, tsa_jar(jar))) {
    return(invisible(.tsa_env))
  }
  asked <- jar
  jar <- tsa_jar(jar)
  if (!nzchar(jar) && is.null(asked) && interactive() &&
      isTRUE(utils::askYesNo("TSA program not found. Download it now with tsa_setup()?"))) {
    tsa_setup()
    return(tsa_engine())
  }
  if (!nzchar(jar)) stop(.tsa_missing_msg(), call. = FALSE)
  .tsa_use_saved_java()
  if (!requireNamespace("rJava", quietly = TRUE)) {
    stop("Package 'rJava' is required to run the TSA program from R.", call. = FALSE)
  }
  libdir <- file.path(dirname(jar), "lib")
  cp <- c(jar, if (dir.exists(libdir)) list.files(libdir, "\\.(jar|zip)$", full.names = TRUE))
  ok <- tryCatch({
    rJava::.jinit(classpath = cp, parameters = "-Djava.awt.headless=true")
    TRUE
  }, error = function(e) e)
  if (!isTRUE(ok)) {
    stop("Could not start Java for the TSA program: ", conditionMessage(ok),
         "\nRun tsa_setup() to install Java, or set JAVA_HOME.",
         call. = FALSE)
  }
  rJava::.jaddClassPath(cp)
  io <- tryCatch(rJava::.jnew("io.NewIO"), error = function(e) e)
  if (inherits(io, "error")) {
    stop("TSA.jar loaded but its reader could not be created: ",
         conditionMessage(io), call. = FALSE)
  }
  # The program prints numerical diagnostics to the Java console; keep them
  # out of the R console unless options(easyTSA.verbose = TRUE).
  if (!isTRUE(getOption("easyTSA.verbose", FALSE))) .tsa_quiet_java()
  .tsa_env$jar <- jar
  .tsa_env$io <- io
  .tsa_env$java_version <- rJava::.jcall("java/lang/System", "S", "getProperty", "java.version")
  .tsa_env$tsa_version <- .tsa_jar_version(jar)
  invisible(.tsa_env)
}

.tsa_jar_version <- function(jar) {
  dn <- basename(dirname(jar))
  v <- regmatches(dn, regexpr("[0-9]+(\\.[0-9]+)+( *Beta)?", dn))
  if (length(v)) v else NA_character_
}

# Wrap a Java call so program errors reach the user with the program's text.
.tsa_call <- function(...) {
  tryCatch(rJava::.jcall(...), error = function(e) {
    stop("TSA program: ", conditionMessage(e), call. = FALSE)
  })
}

.tsa_quiet_java <- function() {
  sink_stream <- rJava::.jnew("java.io.PrintStream",
                              rJava::.jcast(rJava::.jnew("java.io.ByteArrayOutputStream"),
                                            "java.io.OutputStream"))
  rJava::.jcall("java/lang/System", "V", "setOut", sink_stream)
  rJava::.jcall("java/lang/System", "V", "setErr", sink_stream)
  invisible(TRUE)
}
