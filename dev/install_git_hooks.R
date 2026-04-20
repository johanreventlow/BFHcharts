#!/usr/bin/env Rscript
# ==============================================================================
# install_git_hooks.R
# ==============================================================================
# Installerer BFHcharts git-hooks ved at oprette symlinks fra .git/hooks/
# til dev/git-hooks/. Idempotent — kan koeres flere gange uden sideeffekter.
#
# Usage:
#   Rscript dev/install_git_hooks.R
#   Rscript dev/install_git_hooks.R --force   # Overskriv eksisterende hooks
#   Rscript dev/install_git_hooks.R --uninstall
#
# Hooks installeret:
#   - pre-commit: dev/git-hooks/pre-commit (blokerer main-commits + lintr/styler)
#   - pre-push:   dev/git-hooks/pre-push   (blokerer main-push + lintr + testthat)
# ==============================================================================

install_git_hooks <- function(force = FALSE, uninstall = FALSE) {
  project_root <- tryCatch(
    {
      trimws(system2("git", c("rev-parse", "--show-toplevel"),
        stdout = TRUE, stderr = TRUE
      ))
    },
    error = function(e) {
      stop("Ikke i et git repository: ", conditionMessage(e))
    }
  )

  hooks_source <- file.path(project_root, "dev", "git-hooks")
  hooks_target <- file.path(project_root, ".git", "hooks")

  if (!dir.exists(hooks_source)) {
    stop("dev/git-hooks/ findes ikke — er du i BFHcharts-repoet?")
  }

  if (!dir.exists(hooks_target)) {
    stop(".git/hooks/ findes ikke — er dette et git repository?")
  }

  VALID_GIT_HOOKS <- c(
    "applypatch-msg", "pre-applypatch", "post-applypatch",
    "pre-commit", "pre-merge-commit", "prepare-commit-msg", "commit-msg",
    "post-commit", "pre-rebase", "post-checkout", "post-merge",
    "pre-push", "pre-receive", "update", "proc-receive", "post-receive",
    "post-update", "reference-transaction", "push-to-checkout",
    "pre-auto-gc", "post-rewrite", "sendemail-validate",
    "fsmonitor-watchman", "p4-changelist", "p4-prepare-changelist",
    "p4-post-changelist", "p4-pre-submit", "post-index-change"
  )
  available_files <- list.files(hooks_source, full.names = FALSE)
  hook_files <- intersect(available_files, VALID_GIT_HOOKS)

  ignored <- setdiff(available_files, hook_files)
  ignored <- ignored[!grepl("\\.(md|txt|sample)$", ignored)]
  if (length(ignored) > 0) {
    message(sprintf(
      "  (ignoreret — ikke i VALID_GIT_HOOKS-allowlist) %s",
      paste(ignored, collapse = ", ")
    ))
  }

  if (length(hook_files) == 0) {
    message("Ingen hooks fundet i dev/git-hooks/")
    return(invisible(NULL))
  }

  for (hook_name in hook_files) {
    target_path <- file.path(hooks_target, hook_name)
    source_path <- file.path(hooks_source, hook_name)

    if (uninstall) {
      if (file.exists(target_path)) {
        file.remove(target_path)
        message(sprintf("✗ Fjernet: .git/hooks/%s", hook_name))
      } else {
        message(sprintf("  (skipped) %s findes ikke", hook_name))
      }
      next
    }

    if (file.exists(target_path)) {
      existing_link <- tryCatch(Sys.readlink(target_path), error = function(e) "")
      if (nzchar(existing_link)) {
        resolved <- if (startsWith(existing_link, "/")) {
          existing_link
        } else {
          file.path(hooks_target, existing_link)
        }
        resolved_norm <- tryCatch(
          normalizePath(resolved, mustWork = FALSE),
          error = function(e) resolved
        )
        source_norm <- normalizePath(source_path, mustWork = FALSE)
        if (resolved_norm == source_norm) {
          message(sprintf("✓ %s: symlink allerede korrekt", hook_name))
          next
        }
      }

      if (!force) {
        message(sprintf(
          "⚠ %s findes allerede i .git/hooks/ — brug --force for at overskrive",
          hook_name
        ))
        next
      }

      file.remove(target_path)
    }

    relative_source <- file.path("..", "..", "dev", "git-hooks", hook_name)
    ok <- file.symlink(relative_source, target_path)

    if (ok) {
      Sys.chmod(target_path, mode = "0755")
      message(sprintf("✓ Installeret: .git/hooks/%s → %s", hook_name, relative_source))
    } else {
      warning(sprintf("Kunne ikke oprette symlink for %s", hook_name), call. = FALSE)
    }
  }

  if (!uninstall) {
    message("")
    message("═════════════════════════════════════════════════════════════════")
    message(" Git hooks installeret!")
    message("═════════════════════════════════════════════════════════════════")
    message(" Test hook:             PREPUSH_MODE=fast git push --dry-run")
    message(" Bypass:                SKIP_PREPUSH=1 git push")
    message(" Fuld testthat:         PREPUSH_MODE=full git push (default)")
    message("")
  }

  invisible(TRUE)
}

if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  force_flag <- "--force" %in% args
  uninstall_flag <- "--uninstall" %in% args

  install_git_hooks(force = force_flag, uninstall = uninstall_flag)
}
