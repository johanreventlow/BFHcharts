# ============================================================================
# Graphics Device Helper
# ============================================================================
#
# Provides with_clean_graphics() wrapper that ensures tests which render
# plots do not leak open graphics devices or leave Rplots.pdf behind.
#
# Reference: openspec/changes/2026-05-01-cleanup-test-artifacts-and-repo-hygiene
# Spec: test-infrastructure

#' Run code with graphics device cleanup on exit
#'
#' Opens an explicit null/void device before running code, records all
#' devices open at entry, and closes any newly opened devices on exit.
#' Emits a warning if leaked devices are detected so the test can be
#' diagnosed without silently swallowing the leak.
#'
#' Rplots.pdf is created by R when a plot is printed without an open
#' device. This wrapper prevents that by redirecting rendering to a
#' temporary file that is cleaned up on exit.
#'
#' @param code Expression to evaluate inside a clean graphics context.
#' @return The value of \code{code}, invisibly.
#' @keywords internal
with_clean_graphics <- function(code) {
  # Record devices open before we start
  before <- dev.list()

  # Open a temporary device so R does not create Rplots.pdf
  tmp <- tempfile(fileext = ".pdf")
  grDevices::pdf(tmp, width = 7, height = 5)
  our_dev <- dev.cur()

  on.exit(
    {
      after <- dev.list()
      # Close any device that was not open before (excluding ours)
      new_devs <- setdiff(after, c(before, our_dev))
      if (length(new_devs) > 0) {
        warning(
          "with_clean_graphics: ", length(new_devs),
          " graphics device(s) left open by test code will be closed.",
          call. = FALSE
        )
        for (d in new_devs) tryCatch(dev.off(d), error = function(e) NULL)
      }
      # Close our own device
      if (our_dev %in% dev.list()) {
        tryCatch(dev.off(our_dev), error = function(e) NULL)
      }
      # Remove temp file
      unlink(tmp)
    },
    add = TRUE
  )

  force(code)
}
