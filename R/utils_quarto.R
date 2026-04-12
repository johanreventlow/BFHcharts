#' Quarto CLI Detection and Version Checking
#'
#' Internal utilities for detecting Quarto CLI availability,
#' finding the executable, and verifying version requirements.
#'
#' @name utils_quarto
#' @keywords internal
#' @noRd
NULL

# Session-level cache for Quarto availability checks
.quarto_cache <- new.env(parent = emptyenv())

#' Check if Quarto CLI is Available
#'
#' Checks if Quarto CLI is installed and accessible on the system,
#' and verifies that the version is >= 1.4.0 (required for Typst support).
#' Results are cached for the session to avoid repeated system calls.
#'
#' @param min_version Minimum required version as character (default: "1.4.0")
#' @param use_cache Logical; if TRUE (default), use cached result if available
#' @return Logical indicating whether Quarto is available and meets version requirement
#'
#' @keywords internal
quarto_available <- function(min_version = "1.4.0", use_cache = TRUE) {
  # Check cache first
  cache_key <- paste0("quarto_", min_version)
  if (use_cache && exists(cache_key, envir = .quarto_cache)) {
    return(get(cache_key, envir = .quarto_cache))
  }

  # Find quarto executable (resolves PATH + known locations)
  quarto_cmd <- find_quarto()

  # Try to run quarto --version
  version_output <- tryCatch(
    {
      system2(quarto_cmd, args = "--version", stdout = TRUE, stderr = TRUE)
    },
    error = function(e) NULL,
    warning = function(w) NULL
  )

  # Check if quarto command succeeded
  if (is.null(version_output) || length(version_output) == 0) {
    result <- FALSE
  } else {
    # Parse version string (e.g., "1.4.557" or "1.5.0")
    result <- check_quarto_version(version_output[1], min_version)
  }

  # Cache the result (cache both availability and path)
  assign(cache_key, result, envir = .quarto_cache)
  if (result) {
    assign("quarto_path", quarto_cmd, envir = .quarto_cache)
  }

  return(result)
}


#' Find Quarto CLI Executable
#'
#' Searches for Quarto in PATH and known installation locations (RStudio bundled,
#' standalone install). Caches the found path for session reuse.
#'
#' @return Character path to quarto executable, or "quarto" if not found
#'   (will fail gracefully at system2 call)
#' @keywords internal
find_quarto <- function() {
  # Return cached path if available
  if (exists("quarto_path", envir = .quarto_cache)) {
    return(get("quarto_path", envir = .quarto_cache))
  }

  # 1. Check if quarto is in PATH
  quarto_in_path <- Sys.which("quarto")
  if (nchar(quarto_in_path) > 0 && file.exists(quarto_in_path)) {
    assign("quarto_path", as.character(quarto_in_path), envir = .quarto_cache)
    return(as.character(quarto_in_path))
  }

  # 2. Check option (bruger kan saette options(bfhcharts.quarto_path = "..."))
  opt_path <- getOption("bfhcharts.quarto_path")
  if (!is.null(opt_path) && file.exists(opt_path)) {
    assign("quarto_path", opt_path, envir = .quarto_cache)
    return(opt_path)
  }

  # 3. Check environment variable
  env_path <- Sys.getenv("QUARTO_PATH", "")
  if (nchar(env_path) > 0 && file.exists(env_path)) {
    assign("quarto_path", env_path, envir = .quarto_cache)
    return(env_path)
  }

  # 4. Search known locations (Windows: RStudio bundled, standalone installs)
  if (.Platform$OS.type == "windows") {
    candidates <- c(
      # RStudio bundled (nyeste layout)
      file.path(Sys.getenv("ProgramFiles"),
                "RStudio/resources/app/bin/quarto/bin/quarto.exe"),
      # RStudio aeldre layout
      file.path(Sys.getenv("ProgramFiles"),
                "RStudio/bin/quarto/bin/quarto.exe"),
      # Posit-branded RStudio
      file.path(Sys.getenv("ProgramFiles"),
                "Posit/RStudio/resources/app/bin/quarto/bin/quarto.exe"),
      # Standalone Quarto install
      file.path(Sys.getenv("LOCALAPPDATA"),
                "Programs/Quarto/bin/quarto.exe"),
      file.path(Sys.getenv("ProgramFiles"), "Quarto/bin/quarto.exe")
    )
  } else {
    candidates <- c(
      # macOS / Linux
      "/usr/local/bin/quarto",
      "/opt/quarto/bin/quarto",
      file.path(Sys.getenv("HOME"), ".local/bin/quarto"),
      # RStudio bundled (macOS)
      "/Applications/RStudio.app/Contents/Resources/app/bin/quarto/bin/quarto"
    )
  }

  for (path in candidates) {
    if (file.exists(path)) {
      assign("quarto_path", path, envir = .quarto_cache)
      return(path)
    }
  }

  # Fallback: return "quarto" and let system2 fail with clear error
  "quarto"
}


#' Get Cached Quarto Path
#'
#' Returns the path to quarto executable found by \code{find_quarto()}.
#' Call \code{quarto_available()} first to ensure the path is resolved.
#'
#' @return Character path to quarto executable
#' @keywords internal
get_quarto_path <- function() {
  if (exists("quarto_path", envir = .quarto_cache)) {
    return(get("quarto_path", envir = .quarto_cache))
  }
  find_quarto()
}

#' Check Quarto Version Against Minimum
#'
#' @param version_string Version string from quarto --version (e.g., "1.4.557")
#' @param min_version Minimum required version (e.g., "1.4.0")
#' @return Logical indicating whether version meets requirement
#' @keywords internal
check_quarto_version <- function(version_string, min_version) {
  # Extract version numbers using regex
  # Matches patterns like "1.4.557", "1.4", "2.0.0" anywhere in the string
  # (handles "Quarto 1.4.557" format as well as plain "1.4.557")
  version_match <- regmatches(version_string,
    regexpr("[0-9]+\\.[0-9]+\\.?[0-9]*", version_string))

  if (length(version_match) == 0 || nchar(version_match) == 0) {
    # If we can't parse version, warn and return FALSE (fail safe)
    warning(
      "Could not parse Quarto version from: ", version_string, "\n",
      "  Unable to verify version requirement.",
      call. = FALSE
    )
    return(FALSE)
  }

  # Compare versions using package_version
  installed <- tryCatch(
    package_version(version_match),
    error = function(e) NULL
  )

  minimum <- tryCatch(
    package_version(min_version),
    error = function(e) NULL
  )

  if (is.null(installed) || is.null(minimum)) {
    # Fail-safe: if we can't parse version, return FALSE
    return(FALSE)
  }

  return(installed >= minimum)
}
