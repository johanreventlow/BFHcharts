# ==============================================================================
# INTELLIGENT LABEL PLACEMENT SYSTEM - STANDALONE VERSION
# ==============================================================================
#
# Intelligent label placement system med NPC-koordinater og multi-level
# collision avoidance.
#
# Kan genbruges i ethvert R plotting projekt til at placere labels ved
# horisontale linjer uden overlaps.
#
# FEATURES:
# - Ingen overlaps mellem labels eller med linjer
# - Multi-level collision avoidance (3 niveauer)
# - Auto-adaptive parametre baseret på font sizes
# - Device-independent (NPC koordinater 0-1)
# - Robust på tværs af ggplot2 versioner
# - Edge case handling (sammenfaldende linjer, bounds violations)
# - TTL-baseret cache management (forhindrer memory creep)
# - Auto-purge strategi med configurable limits
#
# DEPENDENCIES:
# - ggplot2
# - stringr
#
# USAGE:
# library(ggplot2)
#
# # Opret plot
# p <- ggplot(mtcars, aes(x = wt, y = mpg)) +
#   geom_point() +
#   geom_hline(yintercept = 20, color = "blue") +
#   geom_hline(yintercept = 25, color = "red") +
#   theme_minimal()
#
# # Opret NPC mapper
# mapper <- npc_mapper_from_plot(p)
#
# # Definer labels (marquee format)
# label_A <- "{.8 **CL**}  \n{.24 **20 mpg**}"
# label_B <- "{.8 **Target**}  \n{.24 **25 mpg**}"
#
# # Auto-beregn label height
# label_height <- estimate_label_height_npc(label_A)
#
# # Placer labels
# result <- place_two_labels_npc(
#   yA_npc = mapper$y_to_npc(20),
#   yB_npc = mapper$y_to_npc(25),
#   label_height_npc = label_height,
#   gap_line = label_height * 0.08,     # 8% af label height
#   gap_labels = label_height * 0.3,    # 30% af label height
#   priority = "A",
#   pref_pos = c("under", "under")
# )
#
# # Konverter NPC tilbage til data coordinates
# yA_data <- mapper$npc_to_y(result$yA)
# yB_data <- mapper$npc_to_y(result$yB)
#
# EXPORTS:
# Core placement functions:
# - npc_mapper_from_plot()
# - estimate_label_height_npc()
# - place_two_labels_npc()
# - propose_single_label()
# - clamp01()
#
# Cache management API:
# - get_placement_cache_stats()        # Get combined cache statistics
# - purge_expired_cache_entries()       # Manual TTL-based purge
# - clear_all_placement_caches()        # Clear all caches (testing)
# - configure_placement_cache()         # Configure TTL/limits globally
#
# CACHE CONFIGURATION:
# Default configuration (suitable for most Shiny sessions):
# - TTL: 300 seconds (5 minutes)
# - Max size: 100 entries per cache (panel_height + grob_height)
# - Purge interval: Every 50 cache operations
# - Strategy: TTL-based expiration + FIFO when max size exceeded
#
# For short-lived sessions (quick interactions):
#   configure_placement_cache(ttl_seconds = 60, max_cache_size = 50)
#
# For long-running sessions (persistent dashboards):
#   configure_placement_cache(ttl_seconds = 600, max_cache_size = 200)
#
# Monitor cache health:
#   stats <- get_placement_cache_stats()
#   cat("Hit rate:", round(stats$panel_cache$hit_rate * 100, 1), "%\n")
#   cat("Memory:", stats$total_memory_kb, "KB\n")
#
# ==============================================================================


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

#' Clamp værdi til interval `[0, 1]`
#'
#' @param x Numerisk værdi eller vektor
#' @return Værdi begrænset til `[0, 1]`
clamp01 <- function(x) {
  # Input validation
  if (is.null(x) || length(x) == 0) {
    stop("clamp01: x må ikke være NULL eller tom")
  }

  if (!is.numeric(x)) {
    stop("clamp01: x skal være numerisk, modtog: ", class(x)[1])
  }

  if (any(!is.finite(x[!is.na(x)]))) {
    warning("clamp01: Ikke-finite værdier (Inf/-Inf) detekteret")
    x[!is.finite(x)] <- NA_real_
  }

  pmax(0, pmin(1, x))
}

#' Clamp værdi til custom bounds interval
#'
#' Bruges til at sikre at labels respekterer panel padding (pad_top/pad_bot)
#' også ved flip-scenarios.
#'
#' @param x Numerisk værdi eller vektor
#' @param low_bound Nedre grænse
#' @param high_bound Øvre grænse
#' @return Værdi begrænset til `[low_bound, high_bound]`
clamp_to_bounds <- function(x, low_bound, high_bound) {
  # Input validation
  if (is.null(x) || length(x) == 0) {
    stop("clamp_to_bounds: x må ikke være NULL eller tom")
  }

  if (!is.numeric(x) || !is.numeric(low_bound) || !is.numeric(high_bound)) {
    stop("clamp_to_bounds: Alle parametre skal være numeriske")
  }

  if (low_bound >= high_bound) {
    stop("clamp_to_bounds: low_bound skal være mindre end high_bound")
  }

  pmax(low_bound, pmin(high_bound, x))
}


# ==============================================================================
# NPC MAPPING
# ==============================================================================

#' Opret NPC mapper fra ggplot object
#'
#' Denne funktion bygger ggplot og udtræker scale information for at konvertere
#' mellem data-koordinater og NPC (Normalized Parent Coordinates, 0-1).
#'
#' @param p ggplot object
#' @param panel Panel nummer (default = 1)
#'
#' @return List med:
#'   - `y_to_npc`: function(y_data) → NPC
#'   - `npc_to_y`: function(npc) → y_data
#'   - `limits`: c(ymin, ymax)
#'   - `trans_name`: transformation navn (fx "identity", "log10")
#'
#' Opret NPC mapper fra et pre-built ggplot object (PERFORMANCE OPTIMIZED)
#'
#' Denne funktion accepterer et allerede bygget plot (ggplot_built object)
#' og opretter samme mapper som npc_mapper_from_plot(), men uden overhead
#' fra at bygge plottet igen.
#'
#' @param built_plot ggplot_built object fra ggplot2::ggplot_build()
#' @param panel Panel index (default 1)
#' @param original_plot Optional: Original ggplot object (kun nødvendigt for fallback scale extraction)
#'
#' @return List med y_to_npc og npc_to_y funktioner
#'
#' @keywords internal
npc_mapper_from_built <- function(built_plot, panel = 1, original_plot = NULL) {
  # Validate built plot object
  if (is.null(built_plot) || !inherits(built_plot, "ggplot_built")) {
    stop("npc_mapper_from_built: built_plot skal være et ggplot_built object")
  }

  # Validate panel parameter
  if (!is.numeric(panel) || length(panel) != 1 || panel < 1 || panel != floor(panel)) {
    stop("npc_mapper_from_built: panel skal være et positivt heltal, modtog: ", panel)
  }

  if (is.null(built_plot$layout) || is.null(built_plot$layout$panel_params)) {
    stop("npc_mapper_from_built: Plot mangler layout information")
  }

  # Validate panel exists
  if (panel > length(built_plot$layout$panel_params)) {
    stop(sprintf(
      "npc_mapper_from_built: Panel %d eksisterer ikke (plot har kun %d panels)",
      panel, length(built_plot$layout$panel_params)
    ))
  }

  # Prøv forskellige metoder til at få panel params (robust på tværs af ggplot2 versioner)
  pp <- tryCatch(
    {
      built_plot$layout$panel_params[[panel]]
    },
    error = function(e) {
      tryCatch(
        {
          built_plot$layout$panel_scales_y[[panel]]
        },
        error = function(e2) NULL
      )
    }
  )

  if (is.null(pp)) {
    stop("Kunne ikke hente panel parameters fra built plot. Tjek ggplot2 version.")
  }

  # Udtræk limits og transformation
  get_scale_info <- function(pp, original_plot) {
    lims <- NULL
    trans <- NULL
    trans_name <- "identity"

    # Prøv struktureret y scale i panel params
    if (!is.null(pp$y) && !is.null(pp$y$range)) {
      lims <- tryCatch(pp$y$range$range, error = function(e) NULL)
      trans <- tryCatch(pp$y$trans, error = function(e) NULL)
      if (!is.null(trans)) {
        trans_name <- if (is.character(trans)) trans else if (!is.null(trans$name)) trans$name else "identity"
      }
    }

    if (is.null(lims) && !is.null(pp$y.range)) {
      lims <- pp$y.range
    }

    # Fallback til original plot scale (hvis tilgængeligt)
    if (is.null(lims) && !is.null(original_plot)) {
      y_scales <- Filter(function(s) "y" %in% s$aesthetics, original_plot$scales$scales)
      if (length(y_scales) > 0) {
        lims <- y_scales[[1]]$get_limits()
        trans <- y_scales[[1]]$trans
        if (!is.null(trans)) {
          trans_name <- if (!is.null(trans$name)) trans$name else "identity"
        }
      }
    }

    if (is.null(lims) || length(lims) != 2) {
      stop("Kunne ikke bestemme y-akse limits fra built plot.")
    }

    # Trans function
    trans_fun <- if (!is.null(trans) && !is.null(trans$transform)) {
      trans$transform
    } else {
      function(x) x
    }

    # Inverse trans function
    inv_trans_fun <- if (!is.null(trans) && !is.null(trans$inverse)) {
      trans$inverse
    } else {
      function(x) x
    }

    list(lims = lims, trans = trans_fun, inv_trans = inv_trans_fun, trans_name = trans_name)
  }

  info <- get_scale_info(pp, original_plot)
  ymin <- info$lims[1]
  ymax <- info$lims[2]

  if (!is.finite(ymin) || !is.finite(ymax) || ymax <= ymin) {
    stop("Ugyldige y-akse limits: [", ymin, ", ", ymax, "]")
  }

  # Y-data → NPC mapper
  y_to_npc <- function(y) {
    if (any(is.na(y))) {
      result <- rep(NA_real_, length(y))
      valid <- !is.na(y)
      if (any(valid)) {
        yt <- info$trans(y[valid])
        y0 <- info$trans(ymin)
        y1 <- info$trans(ymax)

        # Protect against division by zero
        if (abs(y1 - y0) < .Machine$double.eps) {
          stop(sprintf(
            "Y-akse range er praktisk talt nul efter transformation: y0=%.10f, y1=%.10f",
            y0, y1
          ))
        }

        result[valid] <- (yt - y0) / (y1 - y0)
      }
      return(result)
    }
    yt <- info$trans(y)
    y0 <- info$trans(ymin)
    y1 <- info$trans(ymax)

    # Protect against division by zero
    if (abs(y1 - y0) < .Machine$double.eps) {
      stop(sprintf(
        "Y-akse range er praktisk talt nul efter transformation: y0=%.10f, y1=%.10f",
        y0, y1
      ))
    }

    (yt - y0) / (y1 - y0)
  }

  # NPC → Y-data inverse mapper
  npc_to_y <- function(npc) {
    if (any(is.na(npc))) {
      result <- rep(NA_real_, length(npc))
      valid <- !is.na(npc)
      if (any(valid)) {
        y0 <- info$trans(ymin)
        y1 <- info$trans(ymax)
        yt <- y0 + npc[valid] * (y1 - y0)
        result[valid] <- info$inv_trans(yt)
      }
      return(result)
    }
    y0 <- info$trans(ymin)
    y1 <- info$trans(ymax)
    yt <- y0 + npc * (y1 - y0)
    info$inv_trans(yt)
  }

  list(
    y_to_npc = y_to_npc,
    npc_to_y = npc_to_y,
    limits = c(ymin, ymax),
    trans_name = info$trans_name
  )
}

#' @examples
#' p <- ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point()
#' mapper <- npc_mapper_from_plot(p)
#' mapper$y_to_npc(20) # Konverter 20 mpg til NPC
#' mapper$npc_to_y(0.5) # Konverter 0.5 NPC til mpg
npc_mapper_from_plot <- function(p, panel = 1) {
  # Validate ggplot object
  if (is.null(p) || !inherits(p, "ggplot")) {
    stop("npc_mapper_from_plot: p skal være et ggplot object, modtog: ", class(p)[1])
  }

  # Validate panel parameter
  if (!is.numeric(panel) || length(panel) != 1 || panel < 1 || panel != floor(panel)) {
    stop("npc_mapper_from_plot: panel skal være et positivt heltal, modtog: ", panel)
  }

  # Build plot med fejlhåndtering
  b <- tryCatch(
    {
      ggplot2::ggplot_build(p)
    },
    error = function(e) {
      stop("npc_mapper_from_plot: Kunne ikke bygge ggplot object. Fejl: ", e$message)
    }
  )

  # Delegate til optimized version
  npc_mapper_from_built(b, panel = panel, original_plot = p)
}


# ==============================================================================
# LABEL HEIGHT ESTIMATION
# ==============================================================================

# ==============================================================================
# GROB HEIGHT CACHE - TTL-BASERET MEMORY MANAGEMENT
# ==============================================================================

# Global memoization cache for grob height measurements
# Created once at package/script load time
.grob_height_cache <- new.env(parent = emptyenv())

# Cache configuration med TTL og size limits
.grob_cache_config <- list(
  enabled = TRUE, # Master switch: Set to FALSE to disable cache completely
  ttl_seconds = 300, # 5 minutes (layout genbruges typisk inden for få minutter)
  max_cache_size = 100, # Max entries før forced purge
  purge_check_interval = 50 # Check for expired entries hver N'te operation
)

# Cache statistics tracking
.grob_cache_stats <- list(
  hits = 0L,
  misses = 0L,
  operations = 0L,
  last_purge_time = Sys.time()
)

#' Clear grob height cache
#'
#' Rydder den interne cache for label height estimationer.
#' Nyttigt efter ændringer til label placement konfiguration
#' (fx height_safety_margin) for at sikre at nye værdier anvendes.
#'
#' Denne funktion rydder cachen for både `estimate_label_height_npc()` og
#' `.estimate_label_height_npc_internal()`, og nulstiller cache statistik.
#'
#' @return Invisible: antal cache entries der blev ryddet
#'
#' @examples
#' \dontrun{
#' # Efter config ændring
#' override_label_placement_config(height_safety_margin = 1.5)
#' clear_grob_height_cache()
#'
#' # Check cache status efter clear
#' get_grob_cache_stats() # cache_size skal være 0
#' }
#'
#' @export
clear_grob_height_cache <- function() {
  # Clear all data entries (preserve metadata)
  all_keys <- ls(.grob_height_cache)
  data_keys <- all_keys[!grepl("^\\.", all_keys)]
  entries_cleared <- length(data_keys)
  rm(list = data_keys, envir = .grob_height_cache)

  # Reset statistics
  .grob_cache_stats$hits <<- 0L
  .grob_cache_stats$misses <<- 0L
  .grob_cache_stats$operations <<- 0L
  .grob_cache_stats$last_purge_time <<- Sys.time()

  message(sprintf("Ryddet %d cache entries for label height estimationer", entries_cleared))
  invisible(entries_cleared)
}

#' Safely update cache stats (handles locked bindings)
#'
#' @param stat_name Name of statistic to update ("hits", "misses", "operations")
#' @param value New value or increment amount
#' @param cache_type "grob" or "panel"
#' @param increment If TRUE, add value to current; if FALSE, set to value
#' @keywords internal
safe_update_cache_stat <- function(stat_name, value, cache_type = "grob", increment = TRUE) {
  tryCatch(
    {
      ns <- asNamespace("SPCify")
      stats_name <- if (cache_type == "grob") ".grob_cache_stats" else ".panel_cache_stats"

      # Ensure binding is unlocked
      if (bindingIsLocked(stats_name, ns)) {
        unlockBinding(stats_name, ns)
      }

      # Get stats object
      stats_obj <- get(stats_name, envir = ns)

      # Update value
      if (increment) {
        stats_obj[[stat_name]] <- stats_obj[[stat_name]] + value
      } else {
        stats_obj[[stat_name]] <- value
      }

      # Assign back
      assign(stats_name, stats_obj, envir = ns)
    },
    error = function(e) {
      # Silent failure - stats are not critical
      NULL
    }
  )
}

#' Get grob cache statistics
#'
#' @return List with cache_size, hits, misses, hit_rate, memory_estimate
#' @keywords internal
get_grob_cache_stats <- function() {
  all_keys <- ls(.grob_height_cache)
  data_keys <- all_keys[!grepl("^\\.", all_keys)]

  hits <- .grob_cache_stats$hits
  misses <- .grob_cache_stats$misses
  total_ops <- hits + misses

  # Estimate memory usage (rough approximation)
  # Each entry: ~200 bytes (key) + ~100 bytes (value) + ~50 bytes (timestamp)
  memory_bytes <- length(data_keys) * 350

  list(
    cache_size = length(data_keys),
    cache_hits = hits,
    cache_misses = misses,
    hit_rate = if (total_ops > 0) hits / total_ops else 0,
    memory_estimate_kb = round(memory_bytes / 1024, 2),
    operations_since_last_purge = .grob_cache_stats$operations,
    last_purge_time = .grob_cache_stats$last_purge_time,
    config = .grob_cache_config
  )
}

#' Purge expired entries from grob height cache
#'
#' @param force Logical: If TRUE, purge all entries regardless of TTL
#' @return Integer: Number of entries purged
#' @keywords internal
purge_grob_cache_expired <- function(force = FALSE) {
  all_keys <- ls(.grob_height_cache)
  data_keys <- all_keys[!grepl("^\\.", all_keys)]

  if (length(data_keys) == 0) {
    return(0L)
  }

  current_time <- Sys.time()
  ttl_seconds <- .grob_cache_config$ttl_seconds
  purged_count <- 0L

  if (force) {
    # Force purge: Remove all entries
    rm(list = data_keys, envir = .grob_height_cache)
    purged_count <- length(data_keys)
  } else {
    # TTL-based purge: Check timestamps
    for (key in data_keys) {
      timestamp_key <- paste0(".", key, "_timestamp")

      if (exists(timestamp_key, envir = .grob_height_cache)) {
        timestamp <- .grob_height_cache[[timestamp_key]]
        age_seconds <- as.numeric(difftime(current_time, timestamp, units = "secs"))

        if (age_seconds > ttl_seconds) {
          rm(list = c(key, timestamp_key), envir = .grob_height_cache)
          purged_count <- purged_count + 1L
        }
      } else {
        # No timestamp - legacy entry, remove it
        rm(list = key, envir = .grob_height_cache)
        purged_count <- purged_count + 1L
      }
    }
  }

  # Update statistics
  .grob_cache_stats$operations <<- 0L
  .grob_cache_stats$last_purge_time <<- current_time

  return(purged_count)
}

#' Auto-purge grob cache if needed
#'
#' Checks if purge is needed based on:
#' 1. Operation count (every N operations)
#' 2. Cache size (if exceeds max_cache_size)
#'
#' @keywords internal
auto_purge_grob_cache <- function() {
  # Increment operation counter
  .grob_cache_stats$operations <<- .grob_cache_stats$operations + 1L

  all_keys <- ls(.grob_height_cache)
  data_keys <- all_keys[!grepl("^\\.", all_keys)]
  current_size <- length(data_keys)

  # Check if max size exceeded - FORCED purge (FIFO strategy)
  if (current_size >= .grob_cache_config$max_cache_size) {
    # Forced purge: Remove oldest entries to bring size down to 75% of max
    target_size <- floor(.grob_cache_config$max_cache_size * 0.75)
    entries_to_remove <- current_size - target_size

    # Get entries with timestamps and sort by age
    entries_with_time <- list()
    for (key in data_keys) {
      timestamp_key <- paste0(".", key, "_timestamp")
      if (exists(timestamp_key, envir = .grob_height_cache)) {
        entries_with_time[[key]] <- .grob_height_cache[[timestamp_key]]
      } else {
        entries_with_time[[key]] <- Sys.time() - 999999 # Very old
      }
    }

    # Sort by timestamp (oldest first)
    sorted_keys <- names(sort(unlist(entries_with_time)))
    keys_to_remove <- head(sorted_keys, entries_to_remove)

    # Remove oldest entries
    for (key in keys_to_remove) {
      timestamp_key <- paste0(".", key, "_timestamp")
      rm(list = c(key, timestamp_key), envir = .grob_height_cache, inherits = FALSE)
    }

    return(invisible(NULL))
  }

  # Check if periodic purge needed (every N operations)
  if (.grob_cache_stats$operations >= .grob_cache_config$purge_check_interval) {
    purge_grob_cache_expired(force = FALSE)
  }

  invisible(NULL)
}

#' Configure grob height cache TTL and limits
#'
#' @param ttl_seconds TTL for cache entries in seconds (default 300 = 5 min)
#' @param max_cache_size Maximum number of cache entries (default 100)
#' @param purge_check_interval Operations between purge checks (default 50)
#' @return Invisible: Previous configuration
#' @export
configure_grob_cache <- function(
    enabled = NULL,
    ttl_seconds = NULL,
    max_cache_size = NULL,
    purge_check_interval = NULL) {
  old_config <- .grob_cache_config

  if (!is.null(enabled)) {
    if (!is.logical(enabled)) {
      stop("enabled skal være TRUE eller FALSE")
    }
    .grob_cache_config$enabled <<- enabled
  }

  if (!is.null(ttl_seconds)) {
    if (!is.numeric(ttl_seconds) || ttl_seconds <= 0) {
      stop("ttl_seconds skal være et positivt tal")
    }
    .grob_cache_config$ttl_seconds <<- ttl_seconds
  }

  if (!is.null(max_cache_size)) {
    if (!is.numeric(max_cache_size) || max_cache_size < 10) {
      stop("max_cache_size skal være mindst 10")
    }
    .grob_cache_config$max_cache_size <<- as.integer(max_cache_size)
  }

  if (!is.null(purge_check_interval)) {
    if (!is.numeric(purge_check_interval) || purge_check_interval < 1) {
      stop("purge_check_interval skal være mindst 1")
    }
    .grob_cache_config$purge_check_interval <<- as.integer(purge_check_interval)
  }

  invisible(old_config)
}

# ==============================================================================
# PANEL HEIGHT CACHE - TTL-BASERET MEMORY MANAGEMENT
# ==============================================================================

# Global cache for panel height measurements
# Avoids expensive grid.draw() operations for repeated measurements
.panel_height_cache <- new.env(parent = emptyenv())

# Cache configuration med TTL og size limits
.panel_cache_config <- list(
  enabled = TRUE, # Master switch: Set to FALSE to disable cache completely
  ttl_seconds = 300, # 5 minutes (samme som grob cache)
  max_cache_size = 100, # Max entries før forced purge
  purge_check_interval = 50 # Check for expired entries hver N'te operation
)

# Cache statistics tracking
.panel_cache_stats <- list(
  hits = 0L,
  misses = 0L,
  operations = 0L,
  last_purge_time = Sys.time()
)

#' Clear panel height cache (for testing or memory management)
#'
#' @keywords internal
clear_panel_height_cache <- function() {
  # Clear all data entries (preserve metadata)
  all_keys <- ls(.panel_height_cache)
  data_keys <- all_keys[!grepl("^\\.", all_keys)]
  rm(list = data_keys, envir = .panel_height_cache)

  # Reset statistics
  .panel_cache_stats$hits <<- 0L
  .panel_cache_stats$misses <<- 0L
  .panel_cache_stats$operations <<- 0L
  .panel_cache_stats$last_purge_time <<- Sys.time()

  invisible(NULL)
}

#' Get panel height cache statistics
#'
#' @return List with cache_size, hits, misses, hit_rate, memory_estimate
#' @keywords internal
get_panel_height_cache_stats <- function() {
  all_keys <- ls(.panel_height_cache)
  data_keys <- all_keys[!grepl("^\\.", all_keys)]

  hits <- .panel_cache_stats$hits
  misses <- .panel_cache_stats$misses
  total_ops <- hits + misses

  # Estimate memory usage (rough approximation)
  # Each entry: ~300 bytes (digest key) + ~50 bytes (numeric value) + ~50 bytes (timestamp)
  memory_bytes <- length(data_keys) * 400

  list(
    cache_size = length(data_keys),
    cache_hits = hits,
    cache_misses = misses,
    hit_rate = if (total_ops > 0) hits / total_ops else 0,
    memory_estimate_kb = round(memory_bytes / 1024, 2),
    operations_since_last_purge = .panel_cache_stats$operations,
    last_purge_time = .panel_cache_stats$last_purge_time,
    config = .panel_cache_config
  )
}

#' Purge expired entries from panel height cache
#'
#' @param force Logical: If TRUE, purge all entries regardless of TTL
#' @return Integer: Number of entries purged
#' @keywords internal
purge_panel_cache_expired <- function(force = FALSE) {
  all_keys <- ls(.panel_height_cache)
  data_keys <- all_keys[!grepl("^\\.", all_keys)]

  if (length(data_keys) == 0) {
    return(0L)
  }

  current_time <- Sys.time()
  ttl_seconds <- .panel_cache_config$ttl_seconds
  purged_count <- 0L

  if (force) {
    # Force purge: Remove all entries
    rm(list = data_keys, envir = .panel_height_cache)
    purged_count <- length(data_keys)
  } else {
    # TTL-based purge: Check timestamps
    for (key in data_keys) {
      timestamp_key <- paste0(".", key, "_timestamp")

      if (exists(timestamp_key, envir = .panel_height_cache)) {
        timestamp <- .panel_height_cache[[timestamp_key]]
        age_seconds <- as.numeric(difftime(current_time, timestamp, units = "secs"))

        if (age_seconds > ttl_seconds) {
          rm(list = c(key, timestamp_key), envir = .panel_height_cache)
          purged_count <- purged_count + 1L
        }
      } else {
        # No timestamp - legacy entry, remove it
        rm(list = key, envir = .panel_height_cache)
        purged_count <- purged_count + 1L
      }
    }
  }

  # Update statistics
  .panel_cache_stats$operations <<- 0L
  .panel_cache_stats$last_purge_time <<- current_time

  return(purged_count)
}

#' Auto-purge panel height cache if needed
#'
#' Checks if purge is needed based on:
#' 1. Operation count (every N operations)
#' 2. Cache size (if exceeds max_cache_size)
#'
#' @keywords internal
auto_purge_panel_cache <- function() {
  # Increment operation counter
  .panel_cache_stats$operations <<- .panel_cache_stats$operations + 1L

  all_keys <- ls(.panel_height_cache)
  data_keys <- all_keys[!grepl("^\\.", all_keys)]
  current_size <- length(data_keys)

  # Check if max size exceeded - FORCED purge (FIFO strategy)
  if (current_size >= .panel_cache_config$max_cache_size) {
    # Forced purge: Remove oldest entries to bring size down to 75% of max
    target_size <- floor(.panel_cache_config$max_cache_size * 0.75)
    entries_to_remove <- current_size - target_size

    # Get entries with timestamps and sort by age
    entries_with_time <- list()
    for (key in data_keys) {
      timestamp_key <- paste0(".", key, "_timestamp")
      if (exists(timestamp_key, envir = .panel_height_cache)) {
        entries_with_time[[key]] <- .panel_height_cache[[timestamp_key]]
      } else {
        entries_with_time[[key]] <- Sys.time() - 999999 # Very old
      }
    }

    # Sort by timestamp (oldest first)
    sorted_keys <- names(sort(unlist(entries_with_time)))
    keys_to_remove <- head(sorted_keys, entries_to_remove)

    # Remove oldest entries
    for (key in keys_to_remove) {
      timestamp_key <- paste0(".", key, "_timestamp")
      rm(list = c(key, timestamp_key), envir = .panel_height_cache, inherits = FALSE)
    }

    return(invisible(NULL))
  }

  # Check if periodic purge needed (every N operations)
  if (.panel_cache_stats$operations >= .panel_cache_config$purge_check_interval) {
    purge_panel_cache_expired(force = FALSE)
  }

  invisible(NULL)
}

#' Configure panel height cache TTL and limits
#'
#' @param enabled Enable or disable panel cache completely (default TRUE)
#' @param ttl_seconds TTL for cache entries in seconds (default 300 = 5 min)
#' @param max_cache_size Maximum number of cache entries (default 100)
#' @param purge_check_interval Operations between purge checks (default 50)
#' @return Invisible: Previous configuration
#' @export
configure_panel_cache <- function(
    enabled = NULL,
    ttl_seconds = NULL,
    max_cache_size = NULL,
    purge_check_interval = NULL) {
  old_config <- .panel_cache_config

  if (!is.null(enabled)) {
    if (!is.logical(enabled)) {
      stop("enabled skal være TRUE eller FALSE")
    }
    .panel_cache_config$enabled <<- enabled
  }

  if (!is.null(ttl_seconds)) {
    if (!is.numeric(ttl_seconds) || ttl_seconds <= 0) {
      stop("ttl_seconds skal være et positivt tal")
    }
    .panel_cache_config$ttl_seconds <<- ttl_seconds
  }

  if (!is.null(max_cache_size)) {
    if (!is.numeric(max_cache_size) || max_cache_size < 10) {
      stop("max_cache_size skal være mindst 10")
    }
    .panel_cache_config$max_cache_size <<- as.integer(max_cache_size)
  }

  if (!is.null(purge_check_interval)) {
    if (!is.numeric(purge_check_interval) || purge_check_interval < 1) {
      stop("purge_check_interval skal være mindst 1")
    }
    .panel_cache_config$purge_check_interval <<- as.integer(purge_check_interval)
  }

  invisible(old_config)
}

# ==============================================================================
# UNIFIED CACHE MANAGEMENT API
# ==============================================================================

#' Unlock cache bindings for runtime modification (test helper)
#'
#' Explicitly unlocks cache config and stats bindings to allow runtime modification.
#' Useful in test contexts where .onLoad() may not have run or when bindings
#' get re-locked.
#'
#' @return Invisible: TRUE if successful, FALSE otherwise
#' @export
#'
#' @examples
#' # In tests:
#' unlock_placement_cache_bindings()
#' configure_panel_cache(enabled = FALSE)
unlock_placement_cache_bindings <- function() {
  ns <- asNamespace("SPCify")

  success <- TRUE
  tryCatch(
    {
      # Unlock stats
      if (exists(".panel_cache_stats", envir = ns, inherits = FALSE)) {
        unlockBinding(".panel_cache_stats", ns)
      }
      if (exists(".grob_cache_stats", envir = ns, inherits = FALSE)) {
        unlockBinding(".grob_cache_stats", ns)
      }

      # Unlock configs
      if (exists(".panel_cache_config", envir = ns, inherits = FALSE)) {
        unlockBinding(".panel_cache_config", ns)
      }
      if (exists(".grob_cache_config", envir = ns, inherits = FALSE)) {
        unlockBinding(".grob_cache_config", ns)
      }
    },
    error = function(e) {
      warning("Failed to unlock cache bindings: ", e$message)
      success <<- FALSE
    }
  )

  invisible(success)
}

#' Get combined placement cache statistics
#'
#' Returns statistics from both panel height and grob height caches in a unified format.
#'
#' @return List with panel_cache and grob_cache statistics
#' @export
#'
#' @examples
#' stats <- get_placement_cache_stats()
#' cat(
#'   "Panel cache:", stats$panel_cache$cache_size, "entries,",
#'   round(stats$panel_cache$hit_rate * 100, 1), "% hit rate\n"
#' )
#' cat(
#'   "Grob cache:", stats$grob_cache$cache_size, "entries,",
#'   round(stats$grob_cache$hit_rate * 100, 1), "% hit rate\n"
#' )
get_placement_cache_stats <- function() {
  list(
    panel_cache = get_panel_height_cache_stats(),
    grob_cache = get_grob_cache_stats(),
    total_memory_kb = get_panel_height_cache_stats()$memory_estimate_kb +
      get_grob_cache_stats()$memory_estimate_kb
  )
}

#' Purge expired entries from all placement caches
#'
#' Runs TTL-based purge on both panel height and grob height caches.
#'
#' @param force Logical: If TRUE, purge all entries regardless of TTL
#' @return Named list with purge counts for each cache
#' @export
#'
#' @examples
#' # TTL-based purge (removes only expired entries)
#' purged <- purge_expired_cache_entries()
#' cat(
#'   "Purged", purged$panel_cache, "panel entries and",
#'   purged$grob_cache, "grob entries\n"
#' )
#'
#' # Force purge (clears all caches)
#' purged <- purge_expired_cache_entries(force = TRUE)
purge_expired_cache_entries <- function(force = FALSE) {
  list(
    panel_cache = purge_panel_cache_expired(force = force),
    grob_cache = purge_grob_cache_expired(force = force)
  )
}

#' Clear all placement caches
#'
#' Removes all cached entries and resets statistics for both panel height
#' and grob height caches. Use for testing or troubleshooting.
#'
#' @export
#'
#' @examples
#' clear_all_placement_caches()
clear_all_placement_caches <- function() {
  clear_panel_height_cache()
  clear_grob_height_cache()
  invisible(NULL)
}

#' Configure all placement caches
#'
#' Sets TTL and size limits for both panel height and grob height caches.
#' Applies same configuration to both caches for consistency.
#'
#' @param ttl_seconds TTL for cache entries in seconds (default 300 = 5 min)
#' @param max_cache_size Maximum number of cache entries per cache (default 100)
#' @param purge_check_interval Operations between purge checks (default 50)
#' @return Invisible: Named list with previous configurations
#' @export
#'
#' @examples
#' # Configure for short-lived Shiny sessions (1 minute TTL)
#' configure_placement_cache(ttl_seconds = 60, max_cache_size = 50)
#'
#' # Configure for long-running sessions (10 minutes TTL, larger cache)
#' configure_placement_cache(ttl_seconds = 600, max_cache_size = 200)
configure_placement_cache <- function(
    ttl_seconds = NULL,
    max_cache_size = NULL,
    purge_check_interval = NULL) {
  old_configs <- list(
    panel_cache = configure_panel_cache(
      ttl_seconds = ttl_seconds,
      max_cache_size = max_cache_size,
      purge_check_interval = purge_check_interval
    ),
    grob_cache = configure_grob_cache(
      ttl_seconds = ttl_seconds,
      max_cache_size = max_cache_size,
      purge_check_interval = purge_check_interval
    )
  )

  invisible(old_configs)
}

#' Mål faktisk panel højde fra ggplot
#'
#' Ekstraherer den faktiske panel viewport højde fra et ggplot object.
#' Dette sikrer at NPC-normalisering sker mod korrekt reference (panel, ikke device).
#'
#' @param p ggplot object
#' @param panel Panel index (default 1)
#' @param device_width Device width i inches (default 7, bruges kun hvis ingen device er åben)
#' @param device_height Device height i inches (default 7, bruges kun hvis ingen device er åben)
#'
#' @return Panel højde i inches, eller NULL hvis måling fejler
#'
#' @details
#' Denne funktion løser problemet hvor ROOT viewport er hele device-fladen
#' (inkl. margener), mens labels skal normaliseres mod panel-området.
#'
#' Strategien er:
#' 1. Build ggplot → gtable
#' 2. Find panel viewport navn fra layout
#' 3. Render på current device (eller temp device hvis ingen er åben)
#' 4. Navigate til panel viewport
#' 5. Mål højde i inches
#' 6. Clean up temp device (hvis oprettet)
#'
#' VIGTIGT: Fra 2025-01-05 er funktionen device-aware:
#' - Hvis en device er åben: Brug den (respekter caller's viewport)
#' - Hvis ingen device: Åbn temp device med device_width x device_height
#'
#' Mål panel højde fra pre-built ggplot (PERFORMANCE OPTIMIZED)
#'
#' Denne funktion accepterer et pre-built plot og gtable og måler panel højden
#' uden at bygge plottet igen.
#'
#' @param built_plot ggplot_built object fra ggplot2::ggplot_build()
#' @param gtable gtable object fra ggplot2::ggplot_gtable() (optional, genereres hvis NULL)
#' @param panel Panel index (default 1)
#' @param device_width Device width i inches (kun hvis ingen device er åben)
#' @param device_height Device height i inches (kun hvis ingen device er åben)
#'
#' @return Panel højde i inches, eller NULL hvis måling fejler
#'
#' @keywords internal
measure_panel_height_from_built <- function(built_plot, gtable = NULL, panel = 1, device_width = 7, device_height = 7, use_cache = TRUE) {
  tryCatch(
    {
      # Validate input
      if (!inherits(built_plot, "ggplot_built")) {
        stop("built_plot skal være et ggplot_built object")
      }

      # Build gtable hvis ikke allerede gjort
      if (is.null(gtable)) {
        gtable <- ggplot2::ggplot_gtable(built_plot)
      }

      # Delegate til shared implementation
      measure_panel_height_from_gtable(gtable, panel, device_width, device_height, use_cache)
    },
    error = function(e) {
      warning("Kunne ikke måle panel højde: ", e$message)
      return(NULL)
    }
  )
}

#' Mål panel højde fra gtable (SHARED IMPLEMENTATION)
#'
#' @keywords internal
measure_panel_height_from_gtable <- function(gt, panel = 1, device_width = 7, device_height = 7, use_cache = TRUE) {
  # PERFORMANCE: Cache panel height measurements to avoid expensive grid.draw() operations
  # Konstruer cache key fra gtable layout structure
  if (use_cache) {
    # Build stable cache key from layout dimensions
    # Include: layout structure, heights, panel index, device dimensions
    layout_digest <- digest::digest(list(
      layout = gt$layout,
      heights = as.character(gt$heights),
      widths = as.character(gt$widths),
      panel = panel,
      device_width = device_width,
      device_height = device_height
    ))

    cache_key <- paste0("panel_height_", layout_digest)

    # Check if cache is enabled (PHASE 0 DIAGNOSTIC)
    if (.panel_cache_config$enabled) {
      # Check cache
      if (exists(cache_key, envir = .panel_height_cache)) {
        # Cache hit - update statistics and return cached value
        safe_update_cache_stat("hits", 1L, "panel", increment = TRUE)
        return(.panel_height_cache[[cache_key]])
      }

      # Cache miss - update statistics
      safe_update_cache_stat("misses", 1L, "panel", increment = TRUE)

      # Auto-purge check before adding new entry
      auto_purge_panel_cache()
    }
  }

  # Find panel viewport navn fra gtable layout
  panel_layout <- gt$layout[gt$layout$name == "panel", , drop = FALSE]

  if (nrow(panel_layout) == 0) {
    stop("Kunne ikke finde panel i plot layout")
  }

  if (panel > nrow(panel_layout)) {
    stop(sprintf("Panel %d findes ikke (plot har %d panels)", panel, nrow(panel_layout)))
  }

  # Construct panel viewport navn (typisk format: "panel.t-l-b-r")
  panel_row <- panel_layout[panel, , drop = FALSE]
  panel_vp_name <- sprintf(
    "panel.%s-%s-%s-%s",
    panel_row$t, panel_row$l,
    panel_row$b, panel_row$r
  )

  # VIGTIGT: Brug ALTID en off-screen PDF device for measurements
  # Dette forhindrer synlig rendering når scripts kører med aktiv device
  #
  # Gem den nuværende device
  current_dev <- grDevices::dev.cur()

  # Open temporary PDF device for measurement (off-screen)
  # NOTE: Vi bruger PDF fordi det er deterministisk (ikke skærmafhængigt)
  temp_file <- tempfile(fileext = ".pdf")
  grDevices::pdf(file = temp_file, width = device_width, height = device_height)
  temp_dev <- grDevices::dev.cur()

  on.exit(
    {
      # Luk vores temp device hvis den stadig er aktiv
      if (grDevices::dev.cur() == temp_dev) {
        grDevices::dev.off()
      }

      # Vend tilbage til oprindelig device hvis den var reel (ikke null og ikke vores temp)
      # Vi ignorerer device 2 hvis current_dev var 1, da ggplot_build() ofte åbner en temp device
      if (current_dev > 1 && current_dev != temp_dev) {
        if (current_dev %in% grDevices::dev.list()) {
          tryCatch(
            {
              grDevices::dev.set(current_dev)
            },
            error = function(e) {
              # Ignorer hvis device ikke findes
            }
          )
        }
      }

      # Slet temp fil
      unlink(temp_file, force = TRUE)
    },
    add = TRUE
  )

  # Render plot til device
  grid::grid.newpage()
  grid::grid.draw(gt)

  # Force all grobs to be evaluated
  grid::grid.force()

  # Navigate til panel viewport
  # NOTE: seekViewport() finder viewport i hele tree
  tryCatch(
    {
      grid::seekViewport(panel_vp_name)
    },
    error = function(e) {
      # Fallback: prøv generisk "panel" navn
      grid::seekViewport("panel")
    }
  )

  # Mål højde i current (panel) viewport
  panel_height <- grid::convertHeight(
    grid::unit(1, "npc"),
    "inches",
    valueOnly = TRUE
  )

  # Navigate tilbage til ROOT
  grid::upViewport(0)

  # Store in cache with timestamp (only if cache is enabled)
  if (use_cache && .panel_cache_config$enabled) {
    .panel_height_cache[[cache_key]] <- panel_height
    # Store timestamp for TTL tracking
    timestamp_key <- paste0(".", cache_key, "_timestamp")
    .panel_height_cache[[timestamp_key]] <- Sys.time()
  }

  return(panel_height)
}

#' @examples
#' p <- ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point()
#' panel_h <- measure_panel_height_inches(p)
#' # Returns ca. 6.48 inches for standard 7x7 device (minus margener)
#'
#' # Med custom device size
#' pdf("test.pdf", width = 12, height = 4)
#' panel_h <- measure_panel_height_inches(p) # Uses current 12x4 device
#' # Returns ca. 3.6 inches (4 inches minus margener)
#' dev.off()
measure_panel_height_inches <- function(p, panel = 1, device_width = 7, device_height = 7, use_cache = TRUE) {
  tryCatch(
    {
      # Validate input
      if (!inherits(p, "ggplot")) {
        stop("p skal være et ggplot object")
      }

      # Build plot structure
      b <- ggplot2::ggplot_build(p)
      gt <- ggplot2::ggplot_gtable(b)

      # Delegate til shared implementation
      measure_panel_height_from_gtable(gt, panel, device_width, device_height, use_cache)
    },
    error = function(e) {
      warning(
        "measure_panel_height_inches fejlede: ", e$message,
        " - returnerer NULL"
      )
      return(NULL)
    }
  )
}

#' INTERN: Mål label højde med aktiv device (ingen device management)
#'
#' Forventer at en graphics device allerede er åben.
#' Håndterer caching men IKKE device lifecycle.
#'
#' @keywords internal
.estimate_label_height_npc_internal <- function(
    text,
    style,
    panel_height_inches = NULL,
    device_width = NULL,
    device_height = NULL,
    marquee_size = NULL,
    fallback_npc = 0.13,
    use_cache = TRUE,
    return_details = FALSE) {
  # Generate cache key including height_safety_margin
  if (use_cache) {
    style_hash <- digest::digest(list(
      style$p$margin,
      style$p$align,
      style$p$lineheight
    ), algo = "xxhash32")

    # Hent height_safety_margin for cache key
    safety_margin_for_key <- if (exists("get_label_placement_config", mode = "function")) {
      cfg <- get_label_placement_config()
      value <- cfg[["height_safety_margin"]]
      if (is.null(value)) 1.05 else value
    } else if (exists("get_label_placement_param", mode = "function")) {
      get_label_placement_param("height_safety_margin")
    } else {
      1.05
    }

    cache_key <- digest::digest(list(
      text = text,
      style = style_hash,
      panel_height = if (!is.null(panel_height_inches)) {
        round(panel_height_inches, 4)
      } else {
        "viewport"
      },
      device_width = if (!is.null(device_width)) {
        round(device_width, 2)
      } else {
        "default"
      },
      device_height = if (!is.null(device_height)) {
        round(device_height, 2)
      } else {
        "default"
      },
      marquee_size = if (!is.null(marquee_size)) {
        round(marquee_size, 2)
      } else {
        "default"
      },
      return_details = return_details,
      safety_margin = round(safety_margin_for_key, 4) # FIX: Cache invalidation ved config change
    ), algo = "xxhash32")

    # Check if cache is enabled (PHASE 0 DIAGNOSTIC)
    if (.grob_cache_config$enabled) {
      # Check cache
      cached_result <- .grob_height_cache[[cache_key]]
      if (!is.null(cached_result)) {
        # Cache hit - update statistics
        safe_update_cache_stat("hits", 1L, "grob", increment = TRUE)
        return(cached_result)
      }

      # Cache miss - update statistics
      safe_update_cache_stat("misses", 1L, "grob", increment = TRUE)

      # Auto-purge check before adding new entry
      auto_purge_grob_cache()
    }
  }

  # PHASE 1 DIAGNOSTIC: Capture device context before measurement
  dev_info <- list(
    dev_cur = grDevices::dev.cur(),
    dev_size = grDevices::dev.size(),
    dev_size_px = grDevices::dev.size("px"),
    timestamp = Sys.time()
  )

  # PHASE 1 DIAGNOSTIC: Capture viewport state
  vp_info <- tryCatch(
    {
      list(
        current_vp = grid::current.vpPath(),
        vp_width = as.numeric(grid::convertWidth(grid::unit(1, "npc"), "inches", valueOnly = TRUE)),
        vp_height = as.numeric(grid::convertHeight(grid::unit(1, "npc"), "inches", valueOnly = TRUE))
      )
    },
    error = function(e) {
      list(current_vp = "ERROR", vp_width = NA, vp_height = NA, error = e$message)
    }
  )

  # Create grob and measure (assumes active device exists)
  # FIX: Apply marquee_size scaling to style if provided
  # marquee_grob uses style-based sizing, not explicit size parameter
  if (!is.null(marquee_size)) {
    # Scale all font sizes in style by marquee_size / default_size ratio
    # Default geom_marquee size is approximately 6, so we scale from that baseline
    size_scale <- marquee_size / 6

    # Modify style to apply size scaling
    # We need to scale all font-related attributes
    style <- marquee::modify_style(
      style,
      "body",
      size = marquee_size # This should set the base font size
    )
  }

  g <- marquee::marquee_grob(
    text = text,
    x = 0.5,
    y = 0.5,
    style = style
  )

  # CRITICAL FIX: Force grob rendering by calling makeContent
  # Marquee grobs use lazy evaluation and may not have dimensions until rendered
  tryCatch(
    {
      g_rendered <- grid::makeContent(g)
      h_native <- grid::grobHeight(g_rendered)
    },
    error = function(e) {
      # Fallback to direct measurement if makeContent fails
      h_native <<- grid::grobHeight(g)
    }
  )

  # PHASE 1 DIAGNOSTIC: Print comprehensive debug info
  h_native_value <- as.numeric(h_native)
  h_native_unit <- attr(h_native, "unit")
  text_preview <- substring(gsub("\n", " ", text), 1, 30)

  message(sprintf(
    "[GROB_DEBUG] Text: '%s...' | Native: %s (%.6f %s)",
    text_preview, as.character(h_native), h_native_value, h_native_unit
  ))
  message(sprintf(
    "[DEVICE_DEBUG] Device: #%d | Size: %.3f × %.3f inches | Viewport: %s (%.3f × %.3f in)",
    dev_info$dev_cur, dev_info$dev_size[1], dev_info$dev_size[2],
    as.character(vp_info$current_vp), vp_info$vp_width, vp_info$vp_height
  ))

  # Convert to NPC
  if (!is.null(panel_height_inches)) {
    h_inches <- grid::convertHeight(h_native, "inches", valueOnly = TRUE)
    h_npc <- h_inches / panel_height_inches
    message(sprintf(
      "[GROB_DEBUG] Panel-based: h_inches=%.4f (from native %.6f), panel_height=%.4f, h_npc=%.4f",
      h_inches, h_native_value, panel_height_inches, h_npc
    ))
  } else {
    h_npc <- grid::convertHeight(h_native, "npc", valueOnly = TRUE)
    h_inches <- grid::convertHeight(h_native, "inches", valueOnly = TRUE)
    message(sprintf(
      "[GROB_DEBUG] Viewport-based: h_npc=%.4f, h_inches=%.4f (from native %.6f)",
      h_npc, h_inches, h_native_value
    ))
  }

  # Safety margin from config
  safety_margin <- if (exists("get_label_placement_config", mode = "function")) {
    cfg <- get_label_placement_config()
    value <- cfg[["height_safety_margin"]]
    if (is.null(value)) 1.05 else value
  } else if (exists("get_label_placement_param", mode = "function")) {
    get_label_placement_param("height_safety_margin")
  } else {
    1.05
  }
  h_npc <- h_npc * safety_margin
  h_inches_with_margin <- h_inches * safety_margin

  # Validation
  if (!is.finite(h_npc) || h_npc <= 0) {
    warning(
      "Grob-måling gav invalid værdi (", round(h_npc, 4), "), bruger fallback."
    )
    if (return_details) {
      return(list(
        npc = fallback_npc,
        inches = NA_real_,
        panel_height_inches = panel_height_inches
      ))
    }
    return(fallback_npc)
  }

  # Warn if very large
  if (h_npc > 0.5 && !is.null(panel_height_inches)) {
    warning(
      sprintf(
        "Label optager %.1f%% af panel højde (%.2f inches). ",
        h_npc * 100, panel_height_inches
      )
    )
  }

  # Prepare result
  if (return_details) {
    result <- list(
      npc = as.numeric(h_npc),
      inches = as.numeric(h_inches_with_margin),
      panel_height_inches = panel_height_inches
    )
  } else {
    result <- as.numeric(h_npc)
  }

  # Cache result with timestamp (only if cache is enabled)
  if (use_cache && .grob_cache_config$enabled) {
    .grob_height_cache[[cache_key]] <- result
    # Store timestamp for TTL tracking
    timestamp_key <- paste0(".", cache_key, "_timestamp")
    .grob_height_cache[[timestamp_key]] <- Sys.time()
  }

  return(result)
}

#' Batch-mål flere label højder med én device session
#'
#' @param texts Character vector af marquee-formaterede tekster
#' @param style marquee style object (delt for alle labels)
#' @param panel_height_inches Panel højde i inches
#' @param fallback_npc Fallback værdi hvis måling fejler
#' @param use_cache Om cache skal bruges
#' @param return_details Om der skal returneres liste med details
#'
#' @return List af målinger (samme format som estimate_label_height_npc)
#'
#' @details
#' PERFORMANCE: Åbner kun én device for alle målinger i stedet for N devices.
#' Dette giver betydelig performance improvement ved multiple labels (2+).
#'
#' Typisk use case: Måling af CL og Target labels samtidigt
#' - Gamle approach: 2 device åbninger (~20-40ms overhead)
#' - Ny approach: 1 device åbning (~10-20ms overhead)
#' - Saving: ~50% reduction i device overhead
#'
#' @keywords internal
estimate_label_heights_npc <- function(
    texts,
    style = NULL,
    panel_height_inches = NULL,
    device_width = NULL,
    device_height = NULL,
    marquee_size = NULL,
    fallback_npc = 0.13,
    use_cache = TRUE,
    return_details = FALSE) {
  # Default style hvis ikke angivet
  if (is.null(style)) {
    style <- marquee::modify_style(
      marquee::classic_style(),
      "p",
      margin = marquee::trbl(0),
      align = "right"
    )
  }

  # VIGTIGT: Brug ALTID en off-screen device for measurements
  # Dette forhindrer synlig rendering når scripts kører med aktiv device
  #
  # FIX: Brug faktisk device størrelse til målinger for korrekt scaling
  # Hvis device_width/height er angivet, brug dem. Ellers fallback til 16:9 format (8×4.5")
  #
  # Gem reference til nuværende device
  current_dev <- grDevices::dev.cur()

  # Bestem device størrelse til målinger
  # VIGTIGT: Fallback til 8×4.5 inches burde IKKE ske i production (viewport guard sikrer device)
  using_fallback <- is.null(device_width) || is.null(device_height)

  if (using_fallback && getOption("spc.debug.label_placement", FALSE)) {
    message(
      "[LABEL_HEIGHT_ESTIMATE] WARNING: No actual device dimensions provided - ",
      "using fallback 8×4.5\" (this should not happen in production with viewport guard)"
    )
  }

  meas_width <- if (!is.null(device_width)) device_width else 8
  meas_height <- if (!is.null(device_height)) device_height else 4.5

  # Open ONE off-screen SVG device for all measurements
  temp_svg <- tempfile(fileext = ".svg")
  suppressMessages(
    grDevices::svg(filename = temp_svg, width = meas_width, height = meas_height)
  )
  temp_dev <- grDevices::dev.cur()

  # Ensure cleanup of temp file
  on.exit(
    {
      unlink(temp_svg, force = TRUE)
    },
    add = TRUE,
    after = FALSE
  )

  # Measure all texts with shared device
  results <- lapply(texts, function(text) {
    tryCatch(
      {
        .estimate_label_height_npc_internal(
          text = text,
          style = style,
          panel_height_inches = panel_height_inches,
          device_width = device_width,
          device_height = device_height,
          marquee_size = marquee_size,
          fallback_npc = fallback_npc,
          use_cache = use_cache,
          return_details = return_details
        )
      },
      error = function(e) {
        warning(
          "Grob-baseret højdemåling fejlede: ", e$message,
          " - bruger fallback"
        )
        if (return_details) {
          list(npc = fallback_npc, inches = NA_real_, panel_height_inches = panel_height_inches)
        } else {
          fallback_npc
        }
      }
    )
  })

  # Luk off-screen device hvis den stadig er aktiv
  if (grDevices::dev.cur() == temp_dev) {
    grDevices::dev.off()
  }

  # Vend tilbage til oprindelig device hvis den var reel (ikke null og ikke vores temp)
  if (current_dev > 1 && current_dev != temp_dev) {
    if (current_dev %in% grDevices::dev.list()) {
      tryCatch(
        {
          grDevices::dev.set(current_dev)
        },
        error = function(e) {
          # Ignorer hvis device ikke findes
        }
      )
    }
  }

  return(results)
}

#' Estimér label højde fra marquee markup VED FAKTISK GROB-MÅLING
#'
#' Opretter et marquee grob med de faktiske styles og måler højden præcist.
#' Dette giver korrekt højde på alle panelstørrelser uden magic numbers.
#'
#' @param text Marquee string med font size markup (fx "{.8 **Header**}  \n{.24 **Value**}")
#' @param style marquee style object (default: classic_style med right align)
#' @param panel_height_inches Panel højde i inches (hvis kendt, ellers NULL for auto-detect)
#' @param fallback_npc Fallback værdi hvis grob-måling fejler (default 0.13)
#' @param return_details Hvis TRUE, returnér list med npc, inches og panel_height (default FALSE)
#'
#' @return Hvis return_details=FALSE: Numerisk værdi med label højde i NPC (0-1)
#'         Hvis return_details=TRUE: List med:
#'           - npc: Label højde i NPC koordinater
#'           - inches: Label højde i inches (absolut)
#'           - panel_height_inches: Panel højde i inches
#'
#' @details
#' Denne funktion erstatter den tidligere estimation-baserede tilgang med
#' faktisk måling. Det eliminerer alle magic numbers (pt_to_npc_factor,
#' line_spacing, safety_margin) og giver præcis højde på:
#' - Små paneler (facetter)
#' - Store paneler
#' - Forskellige base_size værdier
#' - Forskellige font families
#'
#' @examples
#' label <- "{.8 **CL**}  \n{.24 **45%**}"
#' style <- marquee::modify_style(
#'   marquee::classic_style(),
#'   "p",
#'   margin = marquee::trbl(0),
#'   align = "right"
#' )
#'
#' # Simpel brug (backward compatible)
#' height <- estimate_label_height_npc(label, style = style)
#' # Returns faktisk målt højde (typisk ~0.10-0.15 for 2-line label)
#'
#' # Detaljeret brug (ny API for fixed gaps)
#' height_details <- estimate_label_height_npc(label, style = style, return_details = TRUE)
#' # Returns list(npc = 0.12, inches = 0.5, panel_height_inches = 4.2)
estimate_label_height_npc <- function(
    text,
    style = NULL,
    panel_height_inches = NULL,
    fallback_npc = 0.13,
    use_cache = TRUE,
    return_details = FALSE) {
  tryCatch(
    {
      # Default style hvis ikke angivet
      # NOTE: marquee_grob accepterer kun 'style' parameter, ikke separate
      # size/lineheight/family. Disse skal specificeres gennem style-objektet.
      if (is.null(style)) {
        style <- marquee::modify_style(
          marquee::classic_style(),
          "p",
          margin = marquee::trbl(0),
          align = "right"
        )
      }

      # Generate cache key from text + style signature + panel height + safety margin
      # Key parameters affecting height: margin, align, lineheight, panel_height, safety_margin
      if (use_cache) {
        style_hash <- digest::digest(list(
          style$p$margin,
          style$p$align,
          style$p$lineheight
        ), algo = "xxhash32") # Fast hash algorithm

        # Hent height_safety_margin for cache key
        safety_margin <- if (exists("get_label_placement_config", mode = "function")) {
          cfg <- get_label_placement_config()
          value <- cfg[["height_safety_margin"]]
          if (is.null(value)) 1.05 else value
        } else if (exists("get_label_placement_param", mode = "function")) {
          get_label_placement_param("height_safety_margin")
        } else {
          1.05
        }

        # Include panel_height, return_details AND height_safety_margin in cache key
        # Different panel heights → different NPC values for same absolute height
        # Different return_details → different return formats (numeric vs list)
        # Different safety_margin → different final heights
        cache_key <- digest::digest(list(
          text = text,
          style = style_hash,
          panel_height = if (!is.null(panel_height_inches)) {
            round(panel_height_inches, 4) # Round to avoid float precision issues
          } else {
            "viewport" # Different cache entry for viewport-based measurement
          },
          return_details = return_details, # VIGTIG: Undgå cache collision mellem formats
          safety_margin = round(safety_margin, 4) # FIX: Cache invalidation ved config change
        ), algo = "xxhash32")

        # Check if cache is enabled (PHASE 0 DIAGNOSTIC)
        if (.grob_cache_config$enabled) {
          # Check cache
          cached_result <- .grob_height_cache[[cache_key]]
          if (!is.null(cached_result)) {
            # Cache hit - update statistics
            safe_update_cache_stat("hits", 1L, "grob", increment = TRUE)
            return(cached_result)
          }

          # Cache miss - update statistics
          safe_update_cache_stat("misses", 1L, "grob", increment = TRUE)

          # Auto-purge check before adding new entry
          auto_purge_grob_cache()
        }
      }

      # Opret marquee grob for at måle faktisk højde
      # NOTE: marquee_grob() bruger default size fra style
      # For at måle korrekt skal vi bruge samme setup som ved rendering

      # VIGTIGT: Sikr at der er en aktiv device for at undgå Rplots.pdf
      # Grob operationer kræver en graphics device, men vi vil ikke skabe filer
      device_was_open <- grDevices::dev.cur() != 1

      if (!device_was_open) {
        # Åbn en usynlig device uden fil output
        # Vi SKAL åbne device før nogen grid operationer for at undgå Rplots.pdf
        # Brug png med /dev/null på Unix eller NUL på Windows
        null_file <- if (.Platform$OS.type == "windows") "NUL" else "/dev/null"
        suppressMessages(
          grDevices::png(filename = null_file, width = 480, height = 480)
        )
      }

      g <- marquee::marquee_grob(
        text = text,
        x = 0.5,
        y = 0.5,
        style = style
      )

      # Mål højde i native units
      h_native <- grid::grobHeight(g)

      # Luk midlertidig device hvis vi åbnede en
      if (!device_was_open) {
        grDevices::dev.off()
      }

      # Konverter til NPC
      # Hvis panel_height kendt, brug den; ellers brug current viewport
      if (!is.null(panel_height_inches)) {
        h_inches <- grid::convertHeight(h_native, "inches", valueOnly = TRUE)
        h_npc <- h_inches / panel_height_inches
      } else {
        # Auto-detect fra current viewport
        h_npc <- grid::convertHeight(h_native, "npc", valueOnly = TRUE)
        # Beregn også inches for details-return
        h_inches <- grid::convertHeight(h_native, "inches", valueOnly = TRUE)
      }

      # Tilføj sikkerhedsmargin for at være konservativ
      # Dette sikrer at labels ikke overlapper selv med små afrundingsfejl
      # HENT FRA CONFIG for at gøre det konfigurerbart
      safety_margin <- if (exists("get_label_placement_config", mode = "function")) {
        cfg <- get_label_placement_config()
        value <- cfg[["height_safety_margin"]]
        if (is.null(value)) 1.05 else value
      } else if (exists("get_label_placement_param", mode = "function")) {
        get_label_placement_param("height_safety_margin")
      } else {
        1.05 # Fallback hvis config ikke tilgængelig
      }
      h_npc <- h_npc * safety_margin
      h_inches_with_margin <- h_inches * safety_margin

      # Sanity check: Verificer at målingen er rimelig
      # VIGTIGT: Fra 2025-01-05 - Tillad store labels (>50%) på små paneler
      # Dette er nødvendigt for facets og lave viewports
      if (!is.finite(h_npc) || h_npc <= 0) {
        # FATAL error - return fallback
        warning(
          "Grob-måling gav invalid værdi (", round(h_npc, 4), "), bruger fallback. ",
          "Dette kan skyldes manglende viewport eller ugyldigt marquee markup."
        )
        if (return_details) {
          return(list(
            npc = fallback_npc,
            inches = NA_real_,
            panel_height_inches = panel_height_inches
          ))
        }
        return(fallback_npc)
      }

      # Warn hvis label er meget stor relativt til panel (men tillad det)
      if (h_npc > 0.5) {
        warning(
          sprintf(
            "Label optager %.1f%% af panel højde (%.2f inches). ",
            h_npc * 100, panel_height_inches
          ),
          "Dette kan indikere et meget lille panel eller en fejlmåling."
        )
      }

      # Prepare return value based on return_details flag
      if (return_details) {
        result <- list(
          npc = as.numeric(h_npc),
          inches = as.numeric(h_inches_with_margin),
          panel_height_inches = panel_height_inches
        )
      } else {
        result <- as.numeric(h_npc)
      }

      # Store in cache for future reuse (only if cache is enabled)
      # VIGTIGT: Cache det faktiske result (list eller numeric) ikke bare h_npc
      if (use_cache && .grob_cache_config$enabled) {
        .grob_height_cache[[cache_key]] <- result
        # Store timestamp for TTL tracking
        timestamp_key <- paste0(".", cache_key, "_timestamp")
        .grob_height_cache[[timestamp_key]] <- Sys.time()
      }

      return(result)
    },
    error = function(e) {
      warning(
        "Grob-baseret højdemåling fejlede: ", e$message,
        " - bruger fallback: ", fallback_npc
      )
      if (return_details) {
        return(list(
          npc = fallback_npc,
          inches = NA_real_,
          panel_height_inches = panel_height_inches
        ))
      }
      return(fallback_npc)
    }
  )
}


# ==============================================================================
# LABEL PLACEMENT - HELPER FUNCTION
# ==============================================================================

#' Helper: propose single label placement
#'
#' Foreslår en position for én label ved en linje, med foretrukken side.
#' Flipper automatisk til modsatte side hvis foretrukken side er udenfor bounds.
#'
#' @param y_line_npc Linje position i NPC
#' @param pref_side Foretrukken side: "under" eller "over"
#' @param label_h Label højde i NPC
#' @param gap Min gap fra label edge til linje
#' @param pad_top Top padding
#' @param pad_bot Bottom padding
#'
#' @return List med:
#'   - `center`: NPC position for label center
#'   - `side`: Faktisk side ("under" eller "over")
propose_single_label <- function(y_line_npc, pref_side, label_h, gap, pad_top, pad_bot) {
  half <- label_h / 2
  low_bound <- pad_bot + half
  high_bound <- 1 - pad_top - half

  # Prøv foretrukket side først
  if (pref_side == "under") {
    y <- y_line_npc - gap - half
    if (y >= low_bound) {
      return(list(center = y, side = "under"))
    }
    # Flip til over - NU MED BOUNDS-AWARE CLAMPING
    y <- y_line_npc + gap + half
    return(list(center = clamp_to_bounds(y, low_bound, high_bound), side = "over"))
  } else {
    y <- y_line_npc + gap + half
    if (y <= high_bound) {
      return(list(center = y, side = "over"))
    }
    # Flip til under - NU MED BOUNDS-AWARE CLAMPING
    y <- y_line_npc - gap - half
    return(list(center = clamp_to_bounds(y, low_bound, high_bound), side = "under"))
  }
}


# ==============================================================================
# LABEL PLACEMENT - CORE ALGORITHM
# ==============================================================================

#' Placer to labels ved horisontale linjer med collision avoidance
#'
#' Core placement algoritme med multi-level collision avoidance:
#' - NIVEAU 1: Reducer label gap (50% → 30% → 15%)
#' - NIVEAU 2: Flip labels til modsatte side (3 strategier)
#' - NIVEAU 3: Shelf placement (sidste udvej)
#'
#' @param yA_npc Y-position for linje A i NPC (0-1)
#' @param yB_npc Y-position for linje B i NPC (0-1)
#' @param label_height_npc Label højde - enten:
#'   - Numerisk værdi i NPC (backward compatible)
#'   - List fra estimate_label_height_npc(..., return_details=TRUE) med $npc, $inches, $panel_height_inches
#' @param gap_line Min gap fra label edge til linje (default NULL = auto-beregn fra config)
#'   - Hvis label_height_npc er list: Beregnes som fast % af absolute højde (inches)
#'   - Hvis label_height_npc er numerisk: Beregnes som % af NPC (legacy)
#' @param gap_labels Min gap mellem labels (default NULL = auto-beregn fra config)
#' @param pad_top Top panel padding (default NULL = hent fra config)
#' @param pad_bot Bottom panel padding (default NULL = hent fra config)
#' @param priority Prioriteret label: "A" eller "B" (default "A")
#' @param pref_pos Foretrukne positioner: c("under"/"over", "under"/"over") (default c("under", "under"))
#' @param debug Returnér debug info? (default FALSE)
#'
#' @return List med:
#'   - `yA`: NPC position for label A center
#'   - `yB`: NPC position for label B center
#'   - `sideA`: "over" eller "under"
#'   - `sideB`: "over" eller "under"
#'   - `placement_quality`: "optimal" / "acceptable" / "suboptimal" / "degraded" / "failed"
#'   - `warnings`: Character vector med warnings
#'   - `debug_info`: (kun hvis debug=TRUE)
#'
#' @examples
#' # Basic usage (backward compatible - NPC-baseret gap)
#' result <- place_two_labels_npc(
#'   yA_npc = 0.4,
#'   yB_npc = 0.6,
#'   label_height_npc = 0.13
#' )
#'
#' # Ny API (fixed absolute gap baseret på label inches)
#' height_details <- estimate_label_height_npc(
#'   "{.8 **CL**}  \n{.24 **45%**}",
#'   return_details = TRUE
#' )
#' result <- place_two_labels_npc(
#'   yA_npc = 0.4,
#'   yB_npc = 0.6,
#'   label_height_npc = height_details # List med npc/inches/panel_height
#' )
#' # Gap vil nu være fast % af label's faktiske højde
#'
#' # Coincident lines (target = CL)
#' result <- place_two_labels_npc(
#'   yA_npc = 0.5,
#'   yB_npc = 0.5, # Samme værdi
#'   label_height_npc = 0.13,
#'   pref_pos = c("under", "under")
#' )
#' # Result: sideA = "under", sideB = "over"
place_two_labels_npc <- function(
    yA_npc,
    yB_npc,
    # label_height_npc = 0.035,
    label_height_npc = 0.114,
    gap_line = NULL, # NU: Auto-beregnes fra config
    gap_labels = NULL, # NU: Auto-beregnes fra config
    pad_top = NULL, # NU: Hentes fra config
    pad_bot = NULL, # NU: Hentes fra config
    priority = c("A", "B")[1],
    pref_pos = c("under", "under"),
    debug = FALSE) {
  # ============================================================================
  # INPUT VALIDATION & PARSING
  # ============================================================================

  # Parse label_height_npc - kan være enten numerisk eller list
  label_height_is_list <- is.list(label_height_npc)

  if (label_height_is_list) {
    # Ny API: List med details
    if (!all(c("npc", "inches", "panel_height_inches") %in% names(label_height_npc))) {
      stop("label_height_npc list skal indeholde 'npc', 'inches', og 'panel_height_inches'")
    }

    label_height_npc_value <- label_height_npc$npc
    label_height_inches <- label_height_npc$inches
    panel_height_inches <- label_height_npc$panel_height_inches

    # Validér at panel_height er tilgængelig for absolute gap beregning
    if (is.null(panel_height_inches) || is.na(panel_height_inches)) {
      warning("panel_height_inches ikke tilgængelig - falder tilbage til NPC-baseret gap")
      label_height_is_list <- FALSE
      label_height_inches <- NA_real_
    }
  } else {
    # Legacy API: Enkelt numerisk værdi
    label_height_npc_value <- label_height_npc
    label_height_inches <- NA_real_
    panel_height_inches <- NULL
  }

  # Helper function for NPC parameter validation
  validate_npc_param <- function(value, name, allow_na = TRUE) {
    if (is.null(value)) {
      return(invisible(NULL))
    }

    if (!is.numeric(value)) {
      stop(sprintf("%s skal være numerisk, modtog: %s", name, class(value)[1]))
    }

    if (length(value) != 1) {
      stop(sprintf("%s skal være en enkelt værdi, modtog: %d værdier", name, length(value)))
    }

    if (!allow_na && is.na(value)) {
      stop(sprintf("%s må ikke være NA", name))
    }

    if (!is.na(value) && !is.finite(value)) {
      stop(sprintf("%s skal være finite (ikke Inf/-Inf), modtog: %s", name, value))
    }

    invisible(NULL)
  }

  # Validér alle NPC inputs
  validate_npc_param(yA_npc, "yA_npc", allow_na = TRUE)
  validate_npc_param(yB_npc, "yB_npc", allow_na = TRUE)
  validate_npc_param(label_height_npc_value, "label_height_npc", allow_na = FALSE)
  validate_npc_param(gap_line, "gap_line", allow_na = FALSE)
  validate_npc_param(gap_labels, "gap_labels", allow_na = FALSE)
  validate_npc_param(pad_top, "pad_top", allow_na = FALSE)
  validate_npc_param(pad_bot, "pad_bot", allow_na = FALSE)

  # Bounds validation for label_height_npc
  if (!is.null(label_height_npc_value)) {
    if (label_height_npc_value <= 0) {
      stop("label_height_npc skal være positiv, modtog: ", label_height_npc_value)
    }
    if (label_height_npc_value > 0.5) {
      stop("label_height_npc må ikke overstige 0.5 (50% af panel), modtog: ", label_height_npc_value)
    }
  }

  # Bounds validation for padding
  if (!is.null(pad_top) && (pad_top < 0 || pad_top > 0.2)) {
    stop("pad_top skal være mellem 0 og 0.2, modtog: ", pad_top)
  }
  if (!is.null(pad_bot) && (pad_bot < 0 || pad_bot > 0.2)) {
    stop("pad_bot skal være mellem 0 og 0.2, modtog: ", pad_bot)
  }

  # Priority validation
  priority <- match.arg(priority, choices = c("A", "B"))

  # pref_pos validation
  if (!is.character(pref_pos) || length(pref_pos) == 0) {
    stop("pref_pos skal være en character vektor")
  }
  pref_pos <- rep_len(pref_pos, 2)
  if (!all(pref_pos %in% c("under", "over"))) {
    stop("pref_pos skal indeholde 'under' eller 'over', modtog: ", paste(pref_pos, collapse = ", "))
  }

  # debug validation
  if (!is.logical(debug) || length(debug) != 1) {
    stop("debug skal være en enkelt logical værdi")
  }

  # ============================================================================
  # CONFIGURATION LOADING
  # ============================================================================

  default_cfg <- list(
    relative_gap_line = 0.08,
    relative_gap_labels = 0.30,
    pad_top = 0.01,
    pad_bot = 0.01,
    tight_lines_threshold_factor = 0.5,
    coincident_threshold_factor = 0.1,
    gap_reduction_factors = c(0.5, 0.3, 0.15),
    shelf_center_threshold = 0.5
  )

  cfg <- default_cfg
  config_available <- FALSE

  # Source config hvis tilgængelig (standalone compatibility)
  if (exists("get_label_placement_config", mode = "function")) {
    config_available <- TRUE
    loaded_cfg <- get_label_placement_config()
  } else if (exists("get_label_placement_param", mode = "function")) {
    config_available <- TRUE
    loaded_cfg <- list(
      relative_gap_line = get_label_placement_param("relative_gap_line"),
      relative_gap_labels = get_label_placement_param("relative_gap_labels"),
      pad_top = get_label_placement_param("pad_top"),
      pad_bot = get_label_placement_param("pad_bot"),
      tight_lines_threshold_factor = get_label_placement_param("tight_lines_threshold_factor"),
      coincident_threshold_factor = get_label_placement_param("coincident_threshold_factor"),
      gap_reduction_factors = get_label_placement_param("gap_reduction_factors"),
      shelf_center_threshold = get_label_placement_param("shelf_center_threshold")
    )
  } else {
    loaded_cfg <- NULL
  }

  if (!is.null(loaded_cfg)) {
    for (name in names(default_cfg)) {
      value <- loaded_cfg[[name]]
      if (!is.null(value)) {
        cfg[[name]] <- value
      }
    }
  }

  # Beregn defaults fra config
  # VIGTIG FORBEDRING: Beregn gap baseret på absolute inches hvis tilgængelig
  if (is.null(gap_line)) {
    if (label_height_is_list && !is.na(label_height_inches)) {
      # Ny API: Beregn gap som fast % af absolute label højde
      gap_line_inches <- label_height_inches * cfg$relative_gap_line

      # FIX: Absolut minimum gap for at undgå labels der klistrer til linjer
      # Reduceret til 0.01 inches (~1 pixel @ 96dpi) for at tillade små gaps
      # når relative_gap_line er lille (fx 0.05 = 5%)
      min_gap_inches <- 0.01
      gap_line_inches <- max(gap_line_inches, min_gap_inches)

      gap_line <- gap_line_inches / panel_height_inches # Konverter til NPC
      if (debug) {
        message(sprintf(
          "[DEBUG] gap_line beregnet fra config (NY API): %.4f inches × %.2f = %.4f inches (min: %.2f) = %.4f NPC",
          label_height_inches, cfg$relative_gap_line, gap_line_inches, min_gap_inches, gap_line
        ))
      }
    } else {
      # Legacy API: Beregn gap som % af NPC
      gap_line <- label_height_npc_value * cfg$relative_gap_line
      if (debug) {
        message(sprintf(
          "[DEBUG] gap_line beregnet fra config (LEGACY API): %.4f NPC × %.2f = %.4f NPC",
          label_height_npc_value, cfg$relative_gap_line, gap_line
        ))
      }
    }
  } else {
    if (debug) {
      message(sprintf("[DEBUG] gap_line var eksplicit sat til: %.4f NPC (config IKKE brugt)", gap_line))
    }
  }

  if (is.null(gap_labels)) {
    if (label_height_is_list && !is.na(label_height_inches)) {
      # Ny API: Beregn gap som fast % af absolute label højde
      gap_labels_inches <- label_height_inches * cfg$relative_gap_labels
      gap_labels <- gap_labels_inches / panel_height_inches # Konverter til NPC
    } else {
      # Legacy API: Beregn gap som % af NPC
      gap_labels <- label_height_npc_value * cfg$relative_gap_labels
    }
  }

  if (is.null(pad_top)) {
    pad_top <- cfg$pad_top
  }

  if (is.null(pad_bot)) {
    pad_bot <- cfg$pad_bot
  }

  warnings <- character(0)
  placement_quality <- "optimal"

  # Håndter NA værdier
  if (is.na(yA_npc) && is.na(yB_npc)) {
    warnings <- c(warnings, "Begge linjer er NA - ingen labels placeret")
    return(list(
      yA = NA_real_,
      yB = NA_real_,
      sideA = NA_character_,
      sideB = NA_character_,
      warnings = warnings,
      placement_quality = "failed"
    ))
  }

  # Håndter out-of-bounds
  if (!is.na(yA_npc) && (yA_npc < 0 || yA_npc > 1)) {
    warnings <- c(warnings, paste0("Label A linje uden for panel (", round(yA_npc, 3), ")"))
    yA_npc <- NA_real_
  }
  if (!is.na(yB_npc) && (yB_npc < 0 || yB_npc > 1)) {
    warnings <- c(warnings, paste0("Label B linje uden for panel (", round(yB_npc, 3), ")"))
    yB_npc <- NA_real_
  }

  # Hvis kun én linje er valid
  if (is.na(yA_npc) && !is.na(yB_npc)) {
    yB <- propose_single_label(yB_npc, pref_pos[2], label_height_npc_value, gap_line, pad_top, pad_bot)
    return(list(
      yA = NA_real_,
      yB = yB$center,
      sideA = NA_character_,
      sideB = yB$side,
      warnings = c(warnings, "Kun label B placeret"),
      placement_quality = "degraded"
    ))
  }
  if (is.na(yB_npc) && !is.na(yA_npc)) {
    yA <- propose_single_label(yA_npc, pref_pos[1], label_height_npc_value, gap_line, pad_top, pad_bot)
    return(list(
      yA = yA$center,
      yB = NA_real_,
      sideA = yA$side,
      sideB = NA_character_,
      warnings = c(warnings, "Kun label A placeret"),
      placement_quality = "degraded"
    ))
  }

  # Begge linjer er valid - fuld placeringsalgoritme
  half <- label_height_npc_value / 2
  low_bound <- pad_bot + half
  high_bound <- 1 - pad_top - half

  pref_pos <- rep_len(pref_pos, 2)

  # Hvis linjer er meget tætte, flip strategy: en over, en under
  line_gap_npc <- abs(yA_npc - yB_npc)
  min_center_gap <- label_height_npc_value + gap_labels

  # Brug batch-loaded config
  tight_threshold_factor <- cfg$tight_lines_threshold_factor

  if (line_gap_npc < min_center_gap * tight_threshold_factor) {
    # Linjer er for tætte til begge at være på samme side
    warnings <- c(warnings, paste0("Linjer meget tætte (gap=", round(line_gap_npc, 3), ") - bruger over/under strategi"))

    # Placer den øverste linje's label OVER, den nederste UNDER
    if (yA_npc > yB_npc) {
      # A er højere
      pref_pos[1] <- "over" # A over
      pref_pos[2] <- "under" # B under
    } else {
      # B er højere
      pref_pos[1] <- "under" # A under
      pref_pos[2] <- "over" # B over
    }
  }

  # Initial proposals
  propA <- propose_single_label(yA_npc, pref_pos[1], label_height_npc_value, gap_line, pad_top, pad_bot)
  propB <- propose_single_label(yB_npc, pref_pos[2], label_height_npc_value, gap_line, pad_top, pad_bot)

  yA <- propA$center
  yB <- propB$center
  sideA <- propA$side
  sideB <- propB$side

  # Tjek for coincident lines (meget tætte)
  # Brug batch-loaded config
  coincident_threshold <- label_height_npc_value * cfg$coincident_threshold_factor

  if (abs(yA_npc - yB_npc) < coincident_threshold) {
    warnings <- c(warnings, "Sammenfaldende linjer - placerer labels over/under")

    # Placer den ene label over, den anden under samme linje
    # Prioriter CL (A) til foretrukken side
    if (pref_pos[1] == "under") {
      # CL under, Target over
      yA <- clamp01(yA_npc - gap_line - half)
      yB <- clamp01(yA_npc + gap_line + half)
      sideA <- "under"
      sideB <- "over"
    } else {
      # CL over, Target under
      yA <- clamp01(yA_npc + gap_line + half)
      yB <- clamp01(yA_npc - gap_line - half)
      sideA <- "over"
      sideB <- "under"
    }

    # Verificér at begge labels er inden for bounds
    if (yA < low_bound || yA > high_bound || yB < low_bound || yB > high_bound) {
      warnings <- c(warnings, "Label(s) uden for bounds - justerer til bounds")
      yA <- clamp01(yA)
      yB <- clamp01(yB)
      placement_quality <- "acceptable"
    }

    return(list(
      yA = yA,
      yB = yB,
      sideA = sideA,
      sideB = sideB,
      warnings = warnings,
      placement_quality = placement_quality
    ))
  }

  # Collision detection
  min_center_gap <- label_height_npc_value + gap_labels

  # OPTIMIZATION: Early exit hvis ingen kollision
  if (abs(yA - yB) >= min_center_gap) {
    # Ingen kollision - returnér optimal placering med det samme
    return(list(
      yA = yA,
      yB = yB,
      sideA = sideA,
      sideB = sideB,
      warnings = warnings,
      placement_quality = "optimal"
    ))
  }

  # Kollision detekteret - fortsæt med resolution logic
  if (abs(yA - yB) < min_center_gap) {
    # Kollision detekteret
    warnings <- c(warnings, "Label kollision detekteret - justerer placering")

    # Sortér efter linje-position (lower først)
    if (yA_npc < yB_npc) {
      lower_y <- yA
      upper_y <- yB
      lower_is_A <- TRUE
    } else {
      lower_y <- yB
      upper_y <- yA
      lower_is_A <- FALSE
    }

    # Prøv at skubbe upper opad
    new_upper <- lower_y + min_center_gap
    if (new_upper <= high_bound) {
      upper_y <- new_upper
    } else {
      # Prøv at skubbe lower nedad
      new_lower <- upper_y - min_center_gap
      if (new_lower >= low_bound) {
        lower_y <- new_lower
      } else {
        # Kan ikke opfylde begge constraints - brug shelf placement
        warnings <- c(warnings, "Umuligt at opfylde alle constraints - bruger shelf placement")
        placement_quality <- "suboptimal"

        # Prioriter den vigtigste label tættest på sin linje
        if (priority == "A") {
          if (lower_is_A) {
            lower_y <- max(low_bound, min(propA$center, high_bound))
            upper_y <- high_bound
          } else {
            lower_y <- low_bound
            upper_y <- min(high_bound, max(propA$center, low_bound))
          }
        } else {
          if (lower_is_A) {
            lower_y <- low_bound
            upper_y <- min(high_bound, max(propB$center, low_bound))
          } else {
            lower_y <- max(low_bound, min(propB$center, high_bound))
            upper_y <- high_bound
          }
        }
      }
    }

    # Map tilbage til A/B
    if (lower_is_A) {
      yA <- lower_y
      yB <- upper_y
    } else {
      yA <- upper_y
      yB <- lower_y
    }
  }

  # Final verification: line-gap enforcement
  # MEN: Prioriter collision avoidance over line-gap hvis konflikt
  verify_line_gap <- function(y_center, y_line, side, label_h) {
    half <- label_h / 2
    if (side == "under") {
      required_max <- y_line - gap_line - half
      if (y_center > required_max) {
        return(list(y = required_max, violated = TRUE))
      }
    } else {
      required_min <- y_line + gap_line + half
      if (y_center < required_min) {
        return(list(y = required_min, violated = TRUE))
      }
    }
    return(list(y = y_center, violated = FALSE))
  }

  verifyA <- verify_line_gap(yA, yA_npc, sideA, label_height_npc_value)
  verifyB <- verify_line_gap(yB, yB_npc, sideB, label_height_npc_value)

  # Tjek om line-gap enforcement vil skabe ny collision
  if (verifyA$violated || verifyB$violated) {
    proposed_yA <- if (verifyA$violated) verifyA$y else yA
    proposed_yB <- if (verifyB$violated) verifyB$y else yB

    # Vil dette skabe collision?
    if (abs(proposed_yA - proposed_yB) < min_center_gap) {
      warnings <- c(warnings, "Line-gap enforcement ville skabe collision - forsøger multi-level fallback")

      # === NIVEAU 1: Reducer gap_labels for at give mere plads ===
      reduced_gap_successful <- FALSE

      # Brug batch-loaded config
      reduction_factors <- cfg$gap_reduction_factors

      for (reduction_factor in reduction_factors) {
        reduced_min_gap <- label_height_npc_value + gap_labels * reduction_factor

        if (abs(proposed_yA - proposed_yB) >= reduced_min_gap) {
          # Success! Vi kan bruge line-gap enforcement med reduceret label-gap
          warnings <- c(warnings, paste0(
            "NIVEAU 1: Reduceret label gap til ",
            round(reduction_factor * 100), "% - line-gaps overholdt"
          ))
          yA <- clamp01(proposed_yA)
          yB <- clamp01(proposed_yB)
          reduced_gap_successful <- TRUE
          placement_quality <- "acceptable"
          break
        }
      }

      # === NIVEAU 2: Flip label til modsatte side ===
      if (!reduced_gap_successful) {
        warnings <- c(warnings, "NIVEAU 1 fejlede - forsøger NIVEAU 2: flip labels til modsatte side")

        # Prøv begge flip-strategier i prioritetsrækkefølge
        # Strategi 1: Flip A (CL) til modsatte side, hold B (Target) fast
        new_side_A <- if (sideA == "under") "over" else "under"
        propA_flipped <- propose_single_label(yA_npc, new_side_A, label_height_npc_value, gap_line, pad_top, pad_bot)
        verifyA_flipped <- verify_line_gap(propA_flipped$center, yA_npc, propA_flipped$side, label_height_npc_value)
        test_yA <- if (verifyA_flipped$violated) verifyA_flipped$y else propA_flipped$center

        # Check om flip A løser problemet
        if (abs(test_yA - proposed_yB) >= label_height_npc_value) { # Minimum: labels må ikke overlappe
          yA <- clamp01(test_yA)
          yB <- clamp01(proposed_yB)
          sideA <- propA_flipped$side
          warnings <- c(warnings, "NIVEAU 2a: Flippet label A til modsatte side - konflikt løst")
          placement_quality <- "acceptable"
          reduced_gap_successful <- TRUE
        } else {
          # Strategi 2: Hold A fast, flip B til modsatte side
          new_side_B <- if (sideB == "under") "over" else "under"
          propB_flipped <- propose_single_label(yB_npc, new_side_B, label_height_npc_value, gap_line, pad_top, pad_bot)
          verifyB_flipped <- verify_line_gap(propB_flipped$center, yB_npc, propB_flipped$side, label_height_npc_value)
          test_yB <- if (verifyB_flipped$violated) verifyB_flipped$y else propB_flipped$center

          if (abs(proposed_yA - test_yB) >= label_height_npc_value) {
            yA <- clamp01(proposed_yA)
            yB <- clamp01(test_yB)
            sideB <- propB_flipped$side
            warnings <- c(warnings, "NIVEAU 2b: Flippet label B til modsatte side - konflikt løst")
            placement_quality <- "acceptable"
            reduced_gap_successful <- TRUE
          } else {
            # Strategi 3: Flip BEGGE labels til modsatte side
            if (abs(test_yA - test_yB) >= label_height_npc_value) {
              yA <- clamp01(test_yA)
              yB <- clamp01(test_yB)
              sideA <- propA_flipped$side
              sideB <- propB_flipped$side
              warnings <- c(warnings, "NIVEAU 2c: Flippet BEGGE labels til modsatte side - konflikt løst")
              placement_quality <- "suboptimal"
              reduced_gap_successful <- TRUE
            }
          }
        }
      }

      # === NIVEAU 3: Shelf placement som sidste udvej ===
      if (!reduced_gap_successful) {
        warnings <- c(warnings, "NIVEAU 2 fejlede - bruger NIVEAU 3: shelf placement")

        # Brug batch-loaded config
        shelf_threshold <- cfg$shelf_center_threshold

        # Prioriter den vigtigste label tættest på sin linje
        if (priority == "A") {
          yA <- clamp01(proposed_yA)
          yB <- if (yA < shelf_threshold) high_bound else low_bound # Modsatte shelf
        } else {
          yB <- clamp01(proposed_yB)
          yA <- if (yB < shelf_threshold) high_bound else low_bound
        }
        placement_quality <- "degraded"
      }
    } else {
      # Sikkert at enforce line-gaps uden collision
      if (verifyA$violated) {
        warnings <- c(warnings, "Label A justeret for line-gap compliance")
        yA <- clamp01(verifyA$y)
      }
      if (verifyB$violated) {
        warnings <- c(warnings, "Label B justeret for line-gap compliance")
        yB <- clamp01(verifyB$y)
      }
    }
  }

  list(
    yA = yA,
    yB = yB,
    sideA = sideA,
    sideB = sideB,
    warnings = warnings,
    placement_quality = placement_quality,
    debug_info = if (debug) {
      list(
        yA_npc = yA_npc,
        yB_npc = yB_npc,
        propA = propA,
        propB = propB,
        bounds = c(low_bound, high_bound)
      )
    } else {
      NULL
    }
  )
}
