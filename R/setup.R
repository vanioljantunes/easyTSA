# ============================================================================
# setup.R  -  install the TSA program and a Java runtime from inside R
#
# The TSA program's license forbids redistribution, so easyTSA never ships
# it. tsa_setup() downloads the official zip from the Copenhagen Trial Unit
# onto the user's own machine (after the user accepts the license), and
# provides a Java runtime through 'rJavaEnv' when none is available. The
# locations are remembered in a small config file under R_user_dir().
# ============================================================================

.tsa_url <- "https://tools.ctu.dk/downloads/TSA%200.9.5.10%20Beta.zip"
.tsa_java_version <- "17"

#' Install the TSA program (and Java) for easyTSA
#'
#' Downloads the Copenhagen Trial Unit TSA program (0.9.5.10 Beta) from its
#' official address, unzips it into a user folder, installs a Java runtime
#' (Amazon Corretto, through \pkg{rJavaEnv}) when no working Java is found,
#' and remembers both locations so that [tsa_run()] finds them in every
#' later session. Run it once per machine.
#'
#' The TSA program is free to use but its license does not allow
#' redistribution, which is why easyTSA downloads it from its authors
#' instead of bundling it. Before downloading you are asked to accept the
#' license; its full text is `license_agreement.pdf` in the installed
#' folder. easyTSA is not affiliated with or endorsed by the Copenhagen
#' Trial Unit.
#'
#' @param dir Folder to install the TSA program into.
#' @param java Logical; install a Java runtime when none works.
#' @param accept_license `TRUE` to accept the TSA license without a prompt
#'   (required in non-interactive sessions), `FALSE` to decline, `NULL` to
#'   ask.
#' @param force Logical; download again even when the program is found.
#' @param url Address of the TSA program zip.
#' @return Invisibly, the saved configuration (`jar`, `java_home`).
#' @seealso [tsa_remove()], [tsa_engine()]
#' @examples
#' \dontrun{
#' tsa_setup()
#' }
#' @export
tsa_setup <- function(dir = tools::R_user_dir("easyTSA", "data"), java = TRUE,
                      accept_license = NULL, force = FALSE, url = .tsa_url) {
  cfg <- .tsa_config_read()
  jar <- if (force) "" else tsa_jar()
  need_java <- isTRUE(java) && !.tsa_java_ok()
  if (!nzchar(jar) || need_java) {
    if (!.tsa_consent(accept_license, tsa = !nzchar(jar), java = need_java)) {
      stop("TSA license not accepted; nothing was downloaded.", call. = FALSE)
    }
  }
  if (!nzchar(jar)) {
    message("Downloading the TSA program from the Copenhagen Trial Unit ...")
    zip <- tempfile(fileext = ".zip")
    on.exit(unlink(zip), add = TRUE)
    old <- options(timeout = max(300, getOption("timeout")))
    on.exit(options(old), add = TRUE)
    utils::download.file(url, zip, mode = "wb", quiet = TRUE)
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    utils::unzip(zip, exdir = dir)
    jar <- .tsa_find_jar(dir)
    if (!nzchar(jar)) stop("The downloaded archive contains no TSA.jar: ", url, call. = FALSE)
    cfg$jar <- jar
  }
  if (need_java) {
    message("Installing Java ", .tsa_java_version, " (Amazon Corretto) for easyTSA ...")
    rJavaEnv::rje_consent(provided = TRUE)
    rJavaEnv::use_java(.tsa_java_version, quiet = TRUE)
    cfg$java_home <- Sys.getenv("JAVA_HOME")
  }
  .tsa_config_write(cfg)
  eng <- tsa_engine(jar = jar, restart = TRUE)
  message("TSA program ", eng$tsa_version, " ready (Java ", eng$java_version, ").\n",
          "  ", eng$jar)
  invisible(cfg)
}

#' Remove the TSA program installed by tsa_setup()
#'
#' Deletes the TSA program folder and easyTSA's saved configuration. The
#' Java runtime cached by \pkg{rJavaEnv} is kept; remove it with
#' `rJavaEnv::java_clear()`.
#'
#' @param dir The folder given to [tsa_setup()].
#' @return `TRUE`, invisibly.
#' @examples
#' \dontrun{
#' tsa_remove()
#' }
#' @export
tsa_remove <- function(dir = tools::R_user_dir("easyTSA", "data")) {
  unlink(dir, recursive = TRUE)
  unlink(.tsa_config_file())
  message("Removed the TSA program (", dir, ") and easyTSA's configuration.")
  invisible(TRUE)
}

.tsa_consent <- function(accept_license, tsa = TRUE, java = FALSE) {
  message(
    if (tsa) paste0(
      "easyTSA will download the TSA program (0.9.5.10 Beta) from the Copenhagen\n",
      "Trial Unit (https://ctu.dk/tools). It is free for personal, academic and\n",
      "commercial use. Its license forbids redistributing, modifying or reverse\n",
      "engineering it, comes with no warranty, and is governed by Danish law. Full\n",
      "text: license_agreement.pdf in the installed folder; tsa_remove() uninstalls.\n"),
    if (java) "A Java runtime (Amazon Corretto) will be installed through rJavaEnv.\n")
  if (isTRUE(accept_license)) return(TRUE)
  if (isFALSE(accept_license)) return(FALSE)
  if (!interactive()) {
    stop("Non-interactive session: call tsa_setup(accept_license = TRUE) to accept ",
         "the TSA license and download.", call. = FALSE)
  }
  isTRUE(utils::askYesNo("Accept the TSA license and download?"))
}

.tsa_config_dir <- function() {
  getOption("easyTSA.config_dir", tools::R_user_dir("easyTSA", "config"))
}

.tsa_config_file <- function() file.path(.tsa_config_dir(), "config.dcf")

.tsa_config_read <- function() {
  f <- .tsa_config_file()
  if (!file.exists(f)) return(list())
  as.list(read.dcf(f, keep.white = c("jar", "java_home"))[1, ])
}

.tsa_config_write <- function(cfg) {
  cfg <- cfg[vapply(cfg, function(v) length(v) == 1 && !is.na(v) && nzchar(v), logical(1))]
  if (!length(cfg)) {
    unlink(.tsa_config_file())
    return(invisible(cfg))
  }
  dir.create(.tsa_config_dir(), recursive = TRUE, showWarnings = FALSE)
  # keep.white stops write.dcf() from folding long paths at their spaces
  write.dcf(as.data.frame(cfg, stringsAsFactors = FALSE), .tsa_config_file(),
            keep.white = names(cfg))
  invisible(cfg)
}

# TSA.jar sits either at the top of the archive or inside one folder.
.tsa_find_jar <- function(dir) {
  f <- list.files(dir, "^TSA\\.jar$", recursive = TRUE, full.names = TRUE)
  if (length(f)) normalizePath(f[which.min(nchar(f))]) else ""
}

# Java saved by tsa_setup() is used only when the user has not set JAVA_HOME.
# It must be in place before rJava starts the JVM.
.tsa_use_saved_java <- function() {
  if (nzchar(Sys.getenv("JAVA_HOME"))) return(invisible(FALSE))
  jh <- .tsa_config_read()$java_home
  if (is.null(jh) || !dir.exists(jh)) return(invisible(FALSE))
  Sys.setenv(JAVA_HOME = jh,
             PATH = paste(file.path(jh, "bin"), Sys.getenv("PATH"), sep = .Platform$path.sep))
  invisible(TRUE)
}

.tsa_java_bin <- function() {
  .tsa_use_saved_java()
  jh <- Sys.getenv("JAVA_HOME")
  if (nzchar(jh)) {
    exe <- file.path(jh, "bin", if (.Platform$OS.type == "windows") "java.exe" else "java")
    if (file.exists(exe)) return(exe)
  }
  unname(Sys.which("java"))
}

.tsa_java_ok <- function() {
  java <- .tsa_java_bin()
  if (!nzchar(java)) return(FALSE)
  out <- tryCatch(suppressWarnings(system2(java, "-version", stdout = TRUE, stderr = TRUE)),
                  error = function(e) NULL)
  !is.null(out) && is.null(attr(out, "status")) && any(grepl("version", out))
}
