# dev/analyze_i18n_budget.R
#
# Standalone analyse af i18n YAML-tekstbudget for bfh_generate_analysis().
#
# Formaal: kvantificere hvor godt de tre tekst-arme (stability/target/action)
# udnytter deres tegnbudget under max_chars=375 (Typst-skabelonens designgraense),
# identificere "doede" varianter der aldrig vaelges, og simulere det sammensatte
# output paa tvaers af alle realistiske scenarier.
#
# Koerse:
#   Rscript dev/analyze_i18n_budget.R
#   Rscript dev/analyze_i18n_budget.R --lang en
#   Rscript dev/analyze_i18n_budget.R --max-chars 400
#
# Dependencies: yaml (kun). Ingen pakke-load_all() noedvendig -- algoritmen er
# reimplementeret saa scriptet kan koeres standalone.

suppressPackageStartupMessages({
  library(yaml)
})

# ----------------------------------------------------------------------------
# CLI args
# ----------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default) {
  i <- match(flag, args)
  if (is.na(i) || i == length(args)) default else args[i + 1L]
}
LANG <- get_arg("--lang", "da")
MAX_CHARS <- as.integer(get_arg("--max-chars", "375"))
YAML_PATH <- file.path("inst", "i18n", paste0(LANG, ".yaml"))

if (!file.exists(YAML_PATH)) {
  stop("YAML not found: ", YAML_PATH,
    "\nRun from BFHcharts root or pass --lang da/en.")
}

cat(sprintf("\n=== i18n budget analysis: %s (max_chars=%d) ===\n\n",
  YAML_PATH, MAX_CHARS))

yml <- yaml::read_yaml(YAML_PATH, fileEncoding = "UTF-8")
analysis <- yml$analysis
labels <- yml$labels

# ----------------------------------------------------------------------------
# Budget allocation (mirror af .allocate_text_budget i R/spc_analysis.R)
# ----------------------------------------------------------------------------
# Hold synkront med R/spc_analysis.R:.allocate_text_budget()
ALLOCATION_POLICY <- list(
  with_target = list(stability = 0.45, target = 0.20),  # action = 0.35 (rest)
  no_target   = list(stability = 0.55)                  # action = 0.45 (rest)
)

allocate_budget <- function(max_chars, has_target) {
  if (has_target) {
    s <- floor(max_chars * ALLOCATION_POLICY$with_target$stability)
    t <- floor(max_chars * ALLOCATION_POLICY$with_target$target)
    a <- max_chars - s - t
  } else {
    s <- floor(max_chars * ALLOCATION_POLICY$no_target$stability)
    t <- 0L
    a <- max_chars - s
  }
  list(stability = as.integer(s), target = as.integer(t), action = as.integer(a))
}

budget_with <- allocate_budget(MAX_CHARS, TRUE)
budget_no <- allocate_budget(MAX_CHARS, FALSE)

cat(sprintf("Budget med target:   stability=%d  target=%d  action=%d\n",
  budget_with$stability, budget_with$target, budget_with$action))
cat(sprintf("Budget uden target:  stability=%d  target=--  action=%d\n\n",
  budget_no$stability, budget_no$action))

# ----------------------------------------------------------------------------
# Placeholder substitution + pick_variant (mirror af R/utils_text_da.R)
# ----------------------------------------------------------------------------
substitute_placeholders <- function(text, data) {
  for (key in names(data)) {
    text <- gsub(paste0("\\{", key, "\\}"),
      as.character(data[[key]] %||% ""), text)
  }
  text
}
`%||%` <- function(a, b) if (is.null(a)) b else a

pick_variant <- function(variants, data, budget) {
  if (is.null(variants) || length(variants) == 0) {
    return(list(text = "", variant = NA_character_, fits = NA))
  }
  for (cand in c("detailed", "standard", "short")) {
    if (!is.null(variants[[cand]])) {
      text <- substitute_placeholders(variants[[cand]], data)
      if (nchar(text) <= budget) {
        return(list(text = text, variant = cand, fits = TRUE))
      }
    }
  }
  # Fallback: korteste tilgaengelige (overstiger budget)
  available <- intersect(c("short", "standard", "detailed"), names(variants))
  if (length(available) > 0) {
    text <- substitute_placeholders(variants[[available[1]]], data)
    return(list(text = text, variant = paste0(available[1], "*"), fits = FALSE))
  }
  list(text = "", variant = NA_character_, fits = NA)
}

# ----------------------------------------------------------------------------
# 1) RAW VARIANT LENGTHS — tabular oversigt + budget compliance
# ----------------------------------------------------------------------------
cat("== 1) Raa varianttegnlaengder per arm ==\n")
cat("   '!' markerer variant der overstiger relevant budget; '?' markerer at standard >= detailed (variant-monotoni broken)\n")
cat("   NB: raa nchar inkluderer {placeholder}-tokens. Reel rendret laengde efter substitution er typisk 10-40 tegn KORTERE.\n")
cat("   Den faktiske variant-valg-fordeling i sektion 3 reflekterer rendret laengde -- 'best m.tgt' i tabellen er konservativt upper bound.\n\n")

print_arm <- function(arm_name, arm_data, budget_with, budget_no) {
  cat(sprintf("--- %s (budget m. target=%d, u. target=%d) ---\n",
    toupper(arm_name), budget_with, budget_no))
  cat(sprintf("  %-24s %5s %5s %5s  %-12s %-12s\n",
    "key", "shrt", "std", "detl", "fits m.tgt", "fits u.tgt"))
  for (key in names(arm_data)) {
    variants <- arm_data[[key]]
    if (!is.list(variants)) next
    sl <- if (is.null(variants$short)) NA else nchar(variants$short)
    stl <- if (is.null(variants$standard)) NA else nchar(variants$standard)
    dl <- if (is.null(variants$detailed)) NA else nchar(variants$detailed)
    mono_ok <- is.na(sl) || is.na(stl) || is.na(dl) || (sl <= stl && stl <= dl)
    mono_flag <- if (mono_ok) " " else "?"

    fits_with <- function(len) {
      if (is.na(len)) "    -"
      else if (len <= budget_with) sprintf("%3d  OK", len)
      else sprintf("%3d  !!", len)
    }
    fits_no <- function(len) {
      if (is.na(len) || budget_no == 0L) "    -"
      else if (len <= budget_no) sprintf("%3d  OK", len)
      else sprintf("%3d  !!", len)
    }
    # Bedste (laengste der passer) for hver budget-kontekst:
    best_with <- if (!is.na(dl) && dl <= budget_with) "detl"
      else if (!is.na(stl) && stl <= budget_with) "std"
      else if (!is.na(sl) && sl <= budget_with) "shrt"
      else "OVER"
    best_no <- if (budget_no == 0L) "-"
      else if (!is.na(dl) && dl <= budget_no) "detl"
      else if (!is.na(stl) && stl <= budget_no) "std"
      else if (!is.na(sl) && sl <= budget_no) "shrt"
      else "OVER"

    cat(sprintf("  %-22s%s %5s %5s %5s  m=%-10s u=%-10s\n",
      key, mono_flag,
      ifelse(is.na(sl), "-", sl),
      ifelse(is.na(stl), "-", stl),
      ifelse(is.na(dl), "-", dl),
      best_with, best_no))
  }
  cat("\n")
}

print_arm("stability", analysis$stability, budget_with$stability, budget_no$stability)
print_arm("target", analysis$target, budget_with$target, budget_no$target)
print_arm("action", analysis$action, budget_with$action, budget_no$action)

# ----------------------------------------------------------------------------
# 1b) MODIFIER-SAETNING (cycle 05 finding #2)
# ----------------------------------------------------------------------------
# Modifier-sentence-budget er separat pool: max(80L, floor(max_chars * 0.30)).
# Composeren samler op til 3 aktive modifiers (magnitude + direction +
# baseline_delta) til EN saetning -- se .compose_modifier_sentence().
MODIFIER_BUDGET <- max(80L, floor(MAX_CHARS * 0.30))
cat(sprintf("== 1b) Modifier-saetning (budget=%d, sep pool) ==\n",
  MODIFIER_BUDGET))
cat("   Clauses (lowercase, ingen trailing period) -- samles til saetning.\n\n")

print_modifier_arm <- function(arm_name, arm_data, budget) {
  cat(sprintf("--- modifier.%s ---\n", arm_name))
  cat(sprintf("  %-32s %5s %5s %5s  %s\n", "key.variant", "shrt", "std", "detl", "fits-budget"))
  for (key in names(arm_data)) {
    variants <- arm_data[[key]]
    if (!is.list(variants)) next
    # Handle nested structure (baseline_delta.lead/standalone)
    if (!any(c("short", "standard", "detailed") %in% names(variants))) {
      for (sub_key in names(variants)) {
        sub <- variants[[sub_key]]
        if (!is.list(sub)) next
        sl <- if (is.null(sub$short)) NA else nchar(sub$short)
        stl <- if (is.null(sub$standard)) NA else nchar(sub$standard)
        dl <- if (is.null(sub$detailed)) NA else nchar(sub$detailed)
        best <- if (!is.na(dl) && dl <= budget) "detl"
          else if (!is.na(stl) && stl <= budget) "std"
          else if (!is.na(sl) && sl <= budget) "shrt"
          else "OVER"
        cat(sprintf("  %-32s %5s %5s %5s  %s\n",
          sprintf("%s.%s", key, sub_key),
          ifelse(is.na(sl), "-", sl),
          ifelse(is.na(stl), "-", stl),
          ifelse(is.na(dl), "-", dl), best))
      }
      next
    }
    sl <- if (is.null(variants$short)) NA else nchar(variants$short)
    stl <- if (is.null(variants$standard)) NA else nchar(variants$standard)
    dl <- if (is.null(variants$detailed)) NA else nchar(variants$detailed)
    best <- if (!is.na(dl) && dl <= budget) "detl"
      else if (!is.na(stl) && stl <= budget) "std"
      else if (!is.na(sl) && sl <= budget) "shrt"
      else "OVER"
    cat(sprintf("  %-32s %5s %5s %5s  %s\n", key,
      ifelse(is.na(sl), "-", sl),
      ifelse(is.na(stl), "-", stl),
      ifelse(is.na(dl), "-", dl), best))
  }
  cat("\n")
}

if (!is.null(analysis$modifier)) {
  print_modifier_arm("magnitude", analysis$modifier$magnitude, MODIFIER_BUDGET)
  print_modifier_arm("direction", analysis$modifier$direction, MODIFIER_BUDGET)
  print_modifier_arm("baseline_delta", analysis$modifier$baseline_delta, MODIFIER_BUDGET)
  print_modifier_arm("compose", analysis$modifier$compose, MODIFIER_BUDGET)
}

# ----------------------------------------------------------------------------
# 1c) NOT_EVALUABLE per low_confidence_reason (cycle 05 finding #5)
# ----------------------------------------------------------------------------
cat("== 1c) base.not_evaluable per low_confidence_reason ==\n")
cat("   Overrider stability-arm fuldstaendigt naar confidence_tier=='low'.\n")
cat(sprintf("   Bruges med stability-budget (m.tgt=%d / u.tgt=%d).\n\n",
  budget_with$stability, budget_no$stability))

if (!is.null(analysis$base$not_evaluable)) {
  cat(sprintf("  %-20s %5s %5s %5s  %-12s %-12s\n",
    "reason.variant", "shrt", "std", "detl", "fits m.tgt", "fits u.tgt"))
  for (reason in names(analysis$base$not_evaluable)) {
    v <- analysis$base$not_evaluable[[reason]]
    if (!is.list(v)) next
    sl <- if (is.null(v$short)) NA else nchar(v$short)
    stl <- if (is.null(v$standard)) NA else nchar(v$standard)
    dl <- if (is.null(v$detailed)) NA else nchar(v$detailed)
    best_with <- if (!is.na(dl) && dl <= budget_with$stability) "detl"
      else if (!is.na(stl) && stl <= budget_with$stability) "std"
      else if (!is.na(sl) && sl <= budget_with$stability) "shrt"
      else "OVER"
    best_no <- if (!is.na(dl) && dl <= budget_no$stability) "detl"
      else if (!is.na(stl) && stl <= budget_no$stability) "std"
      else if (!is.na(sl) && sl <= budget_no$stability) "shrt"
      else "OVER"
    cat(sprintf("  %-20s %5s %5s %5s  m=%-10s u=%-10s\n", reason,
      ifelse(is.na(sl), "-", sl),
      ifelse(is.na(stl), "-", stl),
      ifelse(is.na(dl), "-", dl), best_with, best_no))
  }
  cat("\n")
}

# ----------------------------------------------------------------------------
# 1d) TAIL CAVEATS (cl_source + discrete_scale + variable_cl)
# ----------------------------------------------------------------------------
cat("== 1d) Tail-caveats (labels.caveats.*) ==\n")
cat("   Appendes som tail-clauses efter stability+target+action; tager fra ledig plads.\n\n")
caveat_keys <- c("cl_user_supplied", "cl_auto_mean", "variable_cl",
  "discrete_scale_mild", "discrete_scale_moderate")
for (k in caveat_keys) {
  v <- labels$caveats[[k]]
  if (is.null(v)) next
  cat(sprintf("  %-26s %3d tegn\n", k, nchar(v)))
}
cat("\n")


# ----------------------------------------------------------------------------
# Helper: compose modifier sentence (mirror af .compose_modifier_sentence)
# ----------------------------------------------------------------------------
compose_modifier_sentence <- function(magnitude, direction, has_baseline,
                                       pct_abs = 10L, baseline_value = "50,00",
                                       current_value = "55,00",
                                       budget = MODIFIER_BUDGET) {
  m <- analysis$modifier
  if (is.null(m)) return(list(text = "", variant = NA_character_, fits = NA))

  has_mag <- !is.null(magnitude) && magnitude %in% c("small", "medium", "large")
  has_dir <- !is.null(direction) && direction %in% c("favorable", "unfavorable")

  if (!has_baseline && !has_mag && !has_dir) {
    return(list(text = "", variant = NA_character_, fits = NA))
  }

  mag_clause <- if (has_mag) {
    pick_variant(m$magnitude[[magnitude]],
      data = list(pct_abs = pct_abs), budget = budget)$text
  } else ""
  dir_clause <- if (has_dir) {
    pick_variant(m$direction[[direction]], data = list(), budget = budget)$text
  } else ""

  baseline_data <- list(baseline_value = baseline_value,
                        current_value = current_value)

  if (has_baseline && (nzchar(mag_clause) || nzchar(dir_clause))) {
    lead <- pick_variant(m$baseline_delta$lead,
      data = baseline_data, budget = budget)$text
    tail <- paste(c(mag_clause, dir_clause)[nzchar(c(mag_clause, dir_clause))],
      collapse = " ")
    out <- paste0(lead, ", ", tail, ".")
    list(text = out, variant = "lead+tail",
         fits = nchar(out) <= budget)
  } else if (has_baseline) {
    r <- pick_variant(m$baseline_delta$standalone,
      data = baseline_data, budget = budget)
    list(text = r$text, variant = paste0("standalone.", r$variant),
         fits = r$fits)
  } else if (nzchar(mag_clause)) {
    clauses <- if (nzchar(dir_clause)) paste(mag_clause, dir_clause) else mag_clause
    r <- pick_variant(m$compose$mod_only,
      data = list(clauses = clauses), budget = budget)
    list(text = r$text,
         variant = sprintf("mod_only.%s+%s%s", magnitude,
           if (has_dir) "dir" else "", if (has_dir) paste0("(", direction, ")") else ""),
         fits = r$fits)
  } else if (nzchar(dir_clause)) {
    r <- pick_variant(m$compose$dir_only,
      data = list(clauses = dir_clause), budget = budget)
    list(text = r$text,
         variant = sprintf("dir_only.%s", direction),
         fits = r$fits)
  } else {
    list(text = "", variant = NA_character_, fits = NA)
  }
}

# ----------------------------------------------------------------------------
# 2) SCENARIE-SIMULERING
# ----------------------------------------------------------------------------
# Definer alle relevante scenarier som tuples:
#   (stability_key, has_target, target_direction, target_pos, outliers_n)
# hvor target_pos er "at"/"over"/"under" (kun naar has_target=TRUE).
# Action key udledes via samme regler som .select_action_key().

stability_keys <- c("no_variation", "majority_at_centerline", "no_signals",
                    "runs_only", "crossings_only", "outliers_only",
                    "runs_crossings", "runs_outliers", "crossings_outliers",
                    "all_signals")
# Stable keys: no_signals + no_variation. majority_at_centerline kan teknisk
# bestaa eller udvise signaler men i simulator-grid'et flagger vi den som
# stable (diskret maaleskala -> typisk ingen tilfaeldige run/crossing-signaler).
is_stable_from_key <- function(k) {
  k %in% c("no_signals", "no_variation", "majority_at_centerline")
}
# all_signals indeholder semantisk outliers selvom keyword ikke matcher.
has_outliers_from_key <- function(k) {
  k %in% c("outliers_only", "runs_outliers", "crossings_outliers", "all_signals")
}

# Target-state matrix.
#   - vn_*  : value-neutral (target_direction = NULL)
#   - dir_* : direction-aware (target_direction = "lower" / "higher")
#   - near  : CL paa forkert side af direction-target men inden for tolerance.
#             Kraever direction-aware path (target_direction != NULL); fanges
#             af near_target/stable_near_target/unstable_near_target-templates.
target_states <- list(
  no_target            = list(has_target = FALSE, direction = NULL,    pos = NA,      near = FALSE),
  vn_at_target         = list(has_target = TRUE,  direction = NULL,    pos = "at",    near = FALSE),
  vn_over_target       = list(has_target = TRUE,  direction = NULL,    pos = "over",  near = FALSE),
  vn_under_target      = list(has_target = TRUE,  direction = NULL,    pos = "under", near = FALSE),
  dir_goal_met         = list(has_target = TRUE,  direction = "lower", pos = "under", near = FALSE),  # CL under lower-target = goal met
  dir_goal_not_met     = list(has_target = TRUE,  direction = "lower", pos = "over",  near = FALSE),  # CL over lower-target = ikke met
  dir_near_lower       = list(has_target = TRUE,  direction = "lower", pos = "over",  near = TRUE),   # CL lige over lower-target (tolerance-naer)
  dir_near_higher      = list(has_target = TRUE,  direction = "higher",pos = "under", near = TRUE)    # CL lige under higher-target (tolerance-naer)
)

# Realistiske placeholder-vaerdier (typisk og worst case).
# `pos` styrer level_direction/level_vs_target -- skal matche scenariets target_meta$pos.
# Slaar op i `labels` saa scriptet virker for baade da og en.
make_placeholders <- function(outliers_n, scale = "typical", pos = "over") {
  is_long <- scale == "worst"
  out_word <- if (outliers_n == 1L) labels$outliers$singular else labels$outliers$plural
  pos_key <- if (is.na(pos) || is.null(pos)) "over" else pos
  level_direction <- labels$level_direction[[pos_key]] %||% ""
  level_vs_target <- labels$level_vs_target[[pos_key]] %||% ""
  list(
    runs_actual        = if (is_long) 12L else 9L,
    runs_expected      = 7L,
    crossings_actual   = if (is_long) 2L else 4L,
    crossings_expected = if (is_long) 8L else 6L,
    outliers_actual    = outliers_n,
    outliers_word      = out_word,
    effective_window   = 6L,
    centerline         = if (is_long) "85,5%" else "85%",
    target             = if (is_long) "≥ 99,5%" else "≥ 90%",
    level_direction    = level_direction,
    level_vs_target    = level_vs_target
  )
}

select_action_key <- function(is_stable, has_target, direction, target_pos,
                              near = FALSE) {
  if (has_target && !is.null(direction)) {
    if (isTRUE(near)) {
      return(if (is_stable) "stable_near_target" else "unstable_near_target")
    }
    # Direction-aware goal_met: CL paa "rigtig" side af target.
    #   lower-target  -> goal_met naar CL <= target (pos == "under" eller "at")
    #   higher-target -> goal_met naar CL >= target (pos == "over"  eller "at")
    goal_met <- (direction == "lower"  && target_pos %in% c("under", "at")) ||
                (direction == "higher" && target_pos %in% c("over",  "at"))
    if (is_stable && goal_met) "stable_goal_met"
    else if (is_stable && !goal_met) "stable_goal_not_met"
    else if (!is_stable && goal_met) "unstable_goal_met"
    else "unstable_goal_not_met"
  } else if (has_target) {
    at_target <- target_pos == "at"
    if (is_stable && at_target) "stable_at_target"
    else if (is_stable && !at_target) "stable_not_at_target"
    else if (!is_stable && at_target) "unstable_at_target"
    else "unstable_not_at_target"
  } else {
    if (is_stable) "stable_no_target" else "unstable_no_target"
  }
}

target_key_from_state <- function(state) {
  if (!state$has_target) return(NULL)
  if (isTRUE(state$near)) return("near_target")
  if (!is.null(state$direction)) {
    goal_met <- (state$direction == "lower"  && state$pos %in% c("under", "at")) ||
                (state$direction == "higher" && state$pos %in% c("over",  "at"))
    if (goal_met) "goal_met" else "goal_not_met"
  } else {
    paste0(state$pos, "_target")
  }
}

# Generer scenarier (kombineret med outliers_n=0/1/3 og scale=typical/worst)
scenarios <- list()
for (sk in stability_keys) {
  for (ts_name in names(target_states)) {
    ts <- target_states[[ts_name]]
    # outliers_n skal vaere konsistent med stability_key
    out_options <- if (has_outliers_from_key(sk)) c(1L, 3L) else 0L
    for (on in out_options) {
      for (sc in c("typical", "worst")) {
        scenarios[[length(scenarios) + 1L]] <- list(
          stability_key = sk,
          target_state  = ts_name,
          target_meta   = ts,
          outliers_n    = on,
          scale         = sc
        )
      }
    }
  }
}

cat(sprintf("== 2) Scenarie-simulering: %d kombinationer (10 stability x 8 target-states x 1-2 outlier-niveauer x 2 placeholder-skala) ==\n\n",
  length(scenarios)))

# Simuler hvert scenarie og opsaml resultater
results <- lapply(scenarios, function(sc) {
  ph <- make_placeholders(sc$outliers_n, sc$scale,
    pos = sc$target_meta$pos %||% "over")
  has_target <- sc$target_meta$has_target
  budget <- allocate_budget(MAX_CHARS, has_target)
  is_stable <- is_stable_from_key(sc$stability_key)

  # Stability arm
  if (sc$stability_key == "no_variation") {
    stab <- pick_variant(analysis$stability$no_variation,
      data = list(centerline = ph$centerline),
      budget = budget$stability)
  } else {
    stab <- pick_variant(analysis$stability[[sc$stability_key]],
      data = ph,
      budget = budget$stability)
  }

  # Target arm
  tgt_key <- target_key_from_state(sc$target_meta)
  if (is.null(tgt_key)) {
    tgt <- list(text = "", variant = NA, fits = NA)
  } else {
    tgt <- pick_variant(analysis$target[[tgt_key]],
      data = c(ph, list(target = ph$target)),
      budget = budget$target)
  }

  # Action arm
  act_key <- select_action_key(is_stable, has_target,
    sc$target_meta$direction, sc$target_meta$pos,
    near = isTRUE(sc$target_meta$near))
  act <- pick_variant(analysis$action[[act_key]],
    data = ph,
    budget = budget$action)

  # Saml
  parts <- c(stab$text, tgt$text, act$text)
  parts <- parts[nchar(parts) > 0]
  combined <- paste(parts, collapse = " ")
  combined_len <- nchar(combined)

  data.frame(
    stability_key = sc$stability_key,
    target_state  = sc$target_state,
    outliers_n    = sc$outliers_n,
    scale         = sc$scale,
    stab_variant  = stab$variant,
    stab_len      = nchar(stab$text),
    tgt_key       = tgt_key %||% "",
    tgt_variant   = tgt$variant %||% NA,
    tgt_len       = nchar(tgt$text),
    act_key       = act_key,
    act_variant   = act$variant,
    act_len       = nchar(act$text),
    combined_len  = combined_len,
    over_max      = combined_len > MAX_CHARS,
    headroom      = MAX_CHARS - combined_len,
    stringsAsFactors = FALSE
  )
})
res <- do.call(rbind, results)

# ----------------------------------------------------------------------------
# 2b) MODIFIER-SAETNING + TAIL-CAVEATS + LOW-CONFIDENCE (cycle 05 extensions)
# ----------------------------------------------------------------------------
# Modifier-sentence har separat budget-pool. Vi simulerer alle
# (magnitude x direction x phase_context)-kombinationer for at maale
# fits-rate + variant-fordeling.
cat("== 2b) Modifier-saetning, tail-caveats, low-confidence ==\n\n")

# 2b.1 Modifier-kombinationer
mod_scenarios <- list()
for (mag in list(NULL, "small", "medium", "large")) {
  for (dir in list(NULL, "favorable", "unfavorable")) {
    for (has_b in c(FALSE, TRUE)) {
      mag_lbl <- if (is.null(mag)) "none" else mag
      dir_lbl <- if (is.null(dir)) "none" else dir
      mod_scenarios[[length(mod_scenarios) + 1L]] <- list(
        magnitude = mag, direction = dir, has_baseline = has_b,
        label = sprintf("mag=%s,dir=%s,baseline=%s", mag_lbl, dir_lbl, has_b)
      )
    }
  }
}

mod_results <- lapply(mod_scenarios, function(sc) {
  out <- compose_modifier_sentence(sc$magnitude, sc$direction, sc$has_baseline)
  data.frame(
    label = sc$label,
    has_active = !is.na(out$variant),
    variant = out$variant %||% NA_character_,
    text_len = nchar(out$text),
    fits = out$fits %||% NA,
    stringsAsFactors = FALSE
  )
})
mod_df <- do.call(rbind, mod_results)
active_mod <- mod_df[mod_df$has_active, ]

cat(sprintf("Modifier-sentence (budget=%d): %d aktive ud af %d kombinationer\n",
  MODIFIER_BUDGET, nrow(active_mod), nrow(mod_df)))
if (nrow(active_mod) > 0) {
  cat(sprintf("  text_len: min=%d  median=%d  mean=%d  max=%d  budget=%d\n",
    min(active_mod$text_len), as.integer(median(active_mod$text_len)),
    as.integer(mean(active_mod$text_len)), max(active_mod$text_len),
    MODIFIER_BUDGET))
  cat(sprintf("  over budget: %d (%.1f%%)\n",
    sum(!active_mod$fits, na.rm = TRUE),
    100 * mean(!active_mod$fits, na.rm = TRUE)))
  cat(sprintf("  variant-distribution: %s\n",
    paste(sprintf("%s=%d", names(table(active_mod$variant)),
      as.integer(table(active_mod$variant))), collapse = "  ")))
}
cat("\n")

# 2b.2 Low-confidence (not_evaluable) -- override stability completely
cat("Low-confidence (not_evaluable) override-cases:\n")
cat(sprintf("  Tager stability-budget (%d m.tgt / %d u.tgt); skipper target+action+modifier.\n",
  budget_with$stability, budget_no$stability))
lc_results <- list()
for (reason in c("few_obs", "no_centerline", "no_spread")) {
  for (has_tgt in c(FALSE, TRUE)) {
    bdg <- if (has_tgt) budget_with$stability else budget_no$stability
    templates <- analysis$base$not_evaluable[[reason]]
    if (is.null(templates)) next
    # Realistic n_points per reason (few_obs => low n; others => n=15+)
    n_pts <- if (reason == "few_obs") 8L else 15L
    r <- pick_variant(templates, data = list(n_points = n_pts), budget = bdg)
    lc_results[[length(lc_results) + 1L]] <- data.frame(
      reason = reason, has_target = has_tgt, n_points = n_pts,
      variant = r$variant, text_len = nchar(r$text),
      fits = r$fits, stringsAsFactors = FALSE
    )
  }
}
lc_df <- do.call(rbind, lc_results)
cat(sprintf("  %-15s %-7s %5s %-10s %5s %s\n",
  "reason", "tgt?", "n", "variant", "len", "fits"))
for (i in seq_len(nrow(lc_df))) {
  r <- lc_df[i, ]
  cat(sprintf("  %-15s %-7s %5d %-10s %5d %s\n",
    r$reason, ifelse(r$has_target, "yes", "no"),
    r$n_points, r$variant, r$text_len,
    ifelse(isTRUE(r$fits), "OK", "OVER")))
}
cat("\n")

# 2b.3 Tail-caveats: tæl additiv mod stability+target+action+modifier
cat("Tail-caveats: individual + worst-case kombineret additivt-tilskud\n")
caveat_lens <- sapply(c("cl_user_supplied", "cl_auto_mean", "variable_cl",
  "discrete_scale_mild", "discrete_scale_moderate"),
  function(k) nchar(labels$caveats[[k]] %||% ""))
caveat_lens <- caveat_lens[caveat_lens > 0]
# Realistic max-simultaneous: cl_source + discrete_scale + variable_cl = 3 stk
# (cl_user_supplied OR cl_auto_mean, og discrete_scale_mild OR _moderate)
worst_combo <- nchar(labels$caveats$cl_user_supplied %||% "") +
  nchar(labels$caveats$discrete_scale_moderate %||% "") +
  nchar(labels$caveats$variable_cl %||% "") +
  2L  # 2 space-separators
cat(sprintf("  Per caveat: %s\n",
  paste(sprintf("%s=%d", names(caveat_lens), as.integer(caveat_lens)),
    collapse = "  ")))
cat(sprintf("  Worst-case 3 caveats samlet: %d tegn (additiv mod stab+tgt+act+mod)\n\n",
  worst_combo))

# 2b.4 Full-stack worst-case forecast
cat("Full-stack worst-case forecast (alle 4 layers active):\n")
stab_worst <- max(res$stab_len)
tgt_worst <- max(res$tgt_len)
act_worst <- max(res$act_len)
mod_worst <- if (nrow(active_mod) > 0) max(active_mod$text_len) else 0L
total_worst <- stab_worst + tgt_worst + act_worst + mod_worst + worst_combo + 4L
cat(sprintf("  stability: %d  +  target: %d  +  action: %d  +  modifier: %d  +  caveats: %d  +  separators: 4\n",
  stab_worst, tgt_worst, act_worst, mod_worst, worst_combo))
cat(sprintf("  = %d tegn  vs max_chars=%d  (headroom=%+d)\n",
  total_worst, MAX_CHARS, MAX_CHARS - total_worst))
if (total_worst > MAX_CHARS) {
  cat(sprintf("  ADVARSEL: worst-case overskrider max_chars med %d tegn.\n",
    total_worst - MAX_CHARS))
  cat("  ensure_within_max() vil trimme i bunden ved aktuelle scenarios.\n")
}
cat("\n")


# ----------------------------------------------------------------------------
# 3) AGGREGEREDE STATISTIKKER
# ----------------------------------------------------------------------------
cat("== 3) Aggregerede statistikker paa tvaers af alle scenarier ==\n")
cat("-- Sammensat tekstlaengde (alle scenarier) --\n")
cat(sprintf("  min  =%4d\n", min(res$combined_len)))
cat(sprintf("  median=%4d\n", as.integer(median(res$combined_len))))
cat(sprintf("  mean =%4d\n", as.integer(mean(res$combined_len))))
cat(sprintf("  max  =%4d  (limit=%d)\n", max(res$combined_len), MAX_CHARS))
cat(sprintf("  over %d: %d af %d scenarier (%.1f%%)\n",
  MAX_CHARS, sum(res$over_max), nrow(res),
  100 * mean(res$over_max)))
cat(sprintf("  under 200 (suspekt kort): %d af %d (%.1f%%)\n\n",
  sum(res$combined_len < 200), nrow(res),
  100 * mean(res$combined_len < 200)))

# Headroom distribution (positiv = ledig plads, negativ = overskridelse)
cat("-- Headroom-fordeling (max_chars - faktisk laengde) --\n")
hr <- res$headroom
cat(sprintf("  min =%4d  | p25=%4d | median=%4d | p75=%4d | max=%4d\n",
  min(hr), as.integer(quantile(hr, 0.25)),
  as.integer(median(hr)),
  as.integer(quantile(hr, 0.75)), max(hr)))
cat("  Negativ = teksten skulle trimmes af ensure_within_max()\n\n")

# Per-arm: variant-valg-distribution
variant_dist <- function(col) {
  tab <- table(res[[col]])
  paste(sprintf("%s=%d", names(tab), as.integer(tab)), collapse = "  ")
}
cat("-- Variant-valg per arm (paa tvaers af alle scenarier) --\n")
cat(sprintf("  stability:  %s\n", variant_dist("stab_variant")))
cat(sprintf("  target:     %s\n", variant_dist("tgt_variant")))
cat(sprintf("  action:     %s\n", variant_dist("act_variant")))
cat("  (* suffix = variant valgt selv om den OVERSTIGER budget; fallback)\n\n")

# ----------------------------------------------------------------------------
# PER-STRENG ANALYSE -- bruges denne tekst, og hvor sandsynligt?
# ----------------------------------------------------------------------------
# For hver (arm, key, variant) beregnes:
#   raw_len     = nchar(template) inkl. {placeholder}-tokens
#   demanded    = antal scenarier hvor denne key var aktiv (uanset variant)
#   selected    = antal scenarier hvor netop denne variant blev valgt
#   pick_rate   = selected/demanded -- "naar denne key kommer i spil, hvor
#                 ofte vinder netop denne variant?"
#   status      = en af:
#                   primary    = valgt i >50% af denne keys scenarier
#                   common     = 20-50%
#                   rare       = 1-19%
#                   dead       = aldrig valgt (omskriv eller slet)
#                   overflow   = valgt MEN sprenger budget (kortere variant
#                                kraevet)
#                   monotoni   = standard >= detailed (variant-laengde-brud)
#
# Demanded-tal afhaenger af den simulerede scenarie-fordeling (alle vaegtet
# lige) -- ej reel klinisk frekvens. Bruges som handlings-vejledning, ej
# eksakt prognose.

build_variant_table <- function(arm_name, arm_data, variant_col, key_col) {
  rows <- list()
  for (key in names(arm_data)) {
    variants <- arm_data[[key]]
    if (!is.list(variants)) next

    # Demanded = scenarier hvor denne key var det aktive valg paa armen
    demanded <- if (arm_name == "stability") {
      sum(res$stability_key == key, na.rm = TRUE)
    } else if (arm_name == "target") {
      sum(res$tgt_key == key, na.rm = TRUE)
    } else {
      sum(res$act_key == key, na.rm = TRUE)
    }

    # Monotoni-tjek for hele key (varianter skal vaere kortere -> laengere)
    sl <- if (is.null(variants$short)) NA_integer_ else nchar(variants$short)
    stl <- if (is.null(variants$standard)) NA_integer_ else nchar(variants$standard)
    dl <- if (is.null(variants$detailed)) NA_integer_ else nchar(variants$detailed)
    mono_ok <- (is.na(sl) || is.na(stl) || sl <= stl) &&
               (is.na(stl) || is.na(dl) || stl <= dl)

    for (v in c("short", "standard", "detailed")) {
      tmpl <- variants[[v]]
      if (is.null(tmpl)) next
      raw_len <- nchar(tmpl)

      # Selected = scenarier hvor netop denne (key, variant) blev valgt
      # Star-suffix ('detailed*') markerer overflow-fallback i pick_variant().
      var_match <- if (arm_name == "stability") {
        res$stab_variant == v | res$stab_variant == paste0(v, "*")
      } else if (arm_name == "target") {
        res$tgt_variant == v | res$tgt_variant == paste0(v, "*")
      } else {
        res$act_variant == v | res$act_variant == paste0(v, "*")
      }
      var_match[is.na(var_match)] <- FALSE
      key_match <- if (arm_name == "stability") res$stability_key == key
                   else if (arm_name == "target") res$tgt_key == key
                   else res$act_key == key

      n_selected <- sum(var_match & key_match, na.rm = TRUE)

      # Overflow: blev variant valgt med * suffix?
      overflow_match <- if (arm_name == "stability") {
        res$stab_variant == paste0(v, "*")
      } else if (arm_name == "target") {
        res$tgt_variant == paste0(v, "*")
      } else {
        res$act_variant == paste0(v, "*")
      }
      overflow_match[is.na(overflow_match)] <- FALSE
      n_overflow <- sum(overflow_match & key_match, na.rm = TRUE)

      pick_rate <- if (demanded > 0) n_selected / demanded else 0

      status <- if (n_selected == 0) "dead"
                else if (n_overflow > 0 && n_overflow == n_selected) "overflow"
                else if (n_overflow > 0) "partial-overflow"
                else if (!mono_ok) "monotoni-brud"
                else if (pick_rate > 0.5) "primary"
                else if (pick_rate >= 0.20) "common"
                else "rare"

      rows[[length(rows) + 1L]] <- data.frame(
        arm = arm_name, key = key, variant = v,
        raw_len = raw_len, demanded = demanded,
        selected = n_selected, overflow = n_overflow,
        pick_rate = pick_rate, status = status,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

variant_tbl <- rbind(
  build_variant_table("stability", analysis$stability),
  build_variant_table("target", analysis$target),
  build_variant_table("action", analysis$action)
)

print_variant_table <- function(arm_name) {
  sub <- variant_tbl[variant_tbl$arm == arm_name, ]
  cat(sprintf("\n--- %s arm ---\n", toupper(arm_name)))
  cat(sprintf("  %-26s %-8s %5s %5s %5s %5s %6s  %s\n",
    "key.variant", "raw_len", "dem", "sel", "ovr", "rate", " ", "status"))
  cat(sprintf("  %s\n", strrep("-", 85)))
  # Grupper efter key, indrykk varianter
  current_key <- ""
  for (i in seq_len(nrow(sub))) {
    r <- sub[i, ]
    label <- if (r$key != current_key) {
      current_key <- r$key
      sprintf("%s.%s", r$key, r$variant)
    } else {
      sprintf("  .%s", r$variant)
    }
    rate_str <- if (r$demanded > 0) sprintf("%4.0f%%", r$pick_rate * 100) else "  --"
    cat(sprintf("  %-26s %5d    %5d %5d %5d  %s    %s\n",
      label, r$raw_len, r$demanded, r$selected, r$overflow,
      rate_str, r$status))
  }
}

cat("== 4) Per-streng analyse: hvor sandsynligt er denne tekst i brug? ==\n")
cat("   raw_len = template-tegn (med {placeholder}-tokens)\n")
cat("   dem(anded) = scenarier hvor denne key var aktiv\n")
cat("   sel(ected) = scenarier hvor netop denne variant vandt\n")
cat("   ovr(flow)  = variant valgt selv om den OVERSTIGER budget (fallback)\n")
cat("   rate       = sel/dem inden for denne key (likelihood-proxy)\n")
print_variant_table("stability")
print_variant_table("target")
print_variant_table("action")

cat(sprintf("\n   Total varianter: %d (heraf %d dead, %d med overflow, %d monotoni-brud)\n",
  nrow(variant_tbl),
  sum(variant_tbl$status == "dead"),
  sum(variant_tbl$overflow > 0),
  sum(variant_tbl$status == "monotoni-brud")))
cat("\n")

# Top 10 laengste scenarier
cat("-- 10 laengste sammensatte tekster --\n")
ord <- order(res$combined_len, decreasing = TRUE)[1:10]
for (i in ord) {
  cat(sprintf("  %4d tegn | %s + %s + %s [%s/%s, n_out=%d, %s]\n",
    res$combined_len[i],
    res$stab_variant[i], res$tgt_variant[i], res$act_variant[i],
    res$stability_key[i], res$target_state[i],
    res$outliers_n[i], res$scale[i]))
}
cat("\n")

# Top 10 korteste scenarier
cat("-- 10 korteste sammensatte tekster --\n")
ord <- order(res$combined_len, decreasing = FALSE)[1:10]
for (i in ord) {
  cat(sprintf("  %4d tegn | %s + %s + %s [%s/%s, n_out=%d, %s]\n",
    res$combined_len[i],
    res$stab_variant[i], res$tgt_variant[i], res$act_variant[i],
    res$stability_key[i], res$target_state[i],
    res$outliers_n[i], res$scale[i]))
}
cat("\n")

# Eksempler paa worst-case overflow
overflow <- res[res$over_max, ]
if (nrow(overflow) > 0) {
  cat(sprintf("-- ADVARSEL: %d scenarier overskrider max_chars=%d FOER trim --\n",
    nrow(overflow), MAX_CHARS))
  for (i in seq_len(min(5, nrow(overflow)))) {
    cat(sprintf("  +%d over | %s/%s\n",
      overflow$combined_len[i] - MAX_CHARS,
      overflow$stability_key[i], overflow$target_state[i]))
  }
  cat("\n")
}

# Ledig plads per arm (gennemsnit)
cat("-- Gennemsnitlig ledig plads per arm (budget - faktisk variantlaengde) --\n")
m_stab_with <- mean(budget_with$stability - res$stab_len[res$target_state != "no_target"])
m_stab_no <- mean(budget_no$stability - res$stab_len[res$target_state == "no_target"])
m_tgt <- mean(budget_with$target - res$tgt_len[res$target_state != "no_target"])
m_act_with <- mean(budget_with$action - res$act_len[res$target_state != "no_target"])
m_act_no <- mean(budget_no$action - res$act_len[res$target_state == "no_target"])
cat(sprintf("  stability (m. target):  %.1f tegn ledig\n", m_stab_with))
cat(sprintf("  stability (u. target):  %.1f tegn ledig\n", m_stab_no))
cat(sprintf("  target:                 %.1f tegn ledig\n", m_tgt))
cat(sprintf("  action (m. target):     %.1f tegn ledig\n", m_act_with))
cat(sprintf("  action (u. target):     %.1f tegn ledig\n", m_act_no))
cat("  Hoeje vaerdier indikerer at budget-allokeringen kan strammes.\n\n")

# ----------------------------------------------------------------------------
# 5) EKSEMPLER PAA SAMMENSATTE TEKSTER (én pr stability-key + dir_goal_not_met)
# ----------------------------------------------------------------------------
cat("== 5) Eksempler paa sammensatte tekster (m. target=dir_goal_not_met, typical placeholders) ==\n\n")
example_rows <- which(res$target_state == "dir_goal_not_met" & res$scale == "typical" &
                      (res$outliers_n == 0 | res$outliers_n == 1))
example_rows <- example_rows[!duplicated(res$stability_key[example_rows])]
for (i in example_rows) {
  cat(sprintf("[%s] %d tegn (headroom=%d)\n",
    res$stability_key[i], res$combined_len[i], res$headroom[i]))
  # Genoptag fuldteksten -- dir_goal_not_met svarer til pos="over"
  ph <- make_placeholders(res$outliers_n[i], "typical", pos = "over")
  has_target <- TRUE
  budget <- allocate_budget(MAX_CHARS, has_target)
  if (res$stability_key[i] == "no_variation") {
    stab <- pick_variant(analysis$stability$no_variation,
      data = list(centerline = ph$centerline), budget = budget$stability)
  } else {
    stab <- pick_variant(analysis$stability[[res$stability_key[i]]],
      data = ph, budget = budget$stability)
  }
  tgt <- pick_variant(analysis$target[[res$tgt_key[i]]],
    data = c(ph, list(target = ph$target)), budget = budget$target)
  act <- pick_variant(analysis$action[[res$act_key[i]]],
    data = ph, budget = budget$action)
  parts <- c(stab$text, tgt$text, act$text)
  cat("  ", paste(parts[nchar(parts) > 0], collapse = " "), "\n\n", sep = "")
}

# ----------------------------------------------------------------------------
# 6) BUDGET-RATIO GRID SEARCH
# ----------------------------------------------------------------------------
# Soeg over plausible ratio-splits og find dem der maksimerer brugen af
# 'detailed' varianter (mest informativ tekst) uden at sprenge max_chars.
# Tiebreaker: minimer brug af 'short' (mindst informativ).
#
# Bemark: kun MED-target-ratio er parameteriseret her. UDEN-target-ratio
# holdes konstant via ALLOCATION_POLICY$no_target.
cat("== 6) Budget-ratio grid search ==\n")
cat(sprintf("Soeger over stability%% x target%% (action%% = resten); max_chars=%d\n",
  MAX_CHARS))
cat(sprintf("Maal: maksimer #detailed-valg paa tvaers af alle %d scenarier.\n\n",
  length(scenarios)))

# Genbrug af pick/allocate-logik med custom ratio
simulate_with_ratio <- function(stab_ratio, target_ratio) {
  if (stab_ratio + target_ratio >= 0.95) return(NULL)
  alloc <- function(max_chars, has_target) {
    if (has_target) {
      s <- floor(max_chars * stab_ratio)
      t <- floor(max_chars * target_ratio)
      list(stability = as.integer(s), target = as.integer(t),
           action = as.integer(max_chars - s - t))
    } else {
      # Uden-target-ratio holdes konstant (matcher ALLOCATION_POLICY$no_target).
      # Kun MED-target-ratio er parameteriseret af grid search.
      s <- floor(max_chars * ALLOCATION_POLICY$no_target$stability)
      list(stability = as.integer(s), target = 0L,
           action = as.integer(max_chars - s))
    }
  }

  sims <- lapply(scenarios, function(sc) {
    ph <- make_placeholders(sc$outliers_n, sc$scale,
      pos = sc$target_meta$pos %||% "over")
    has_target <- sc$target_meta$has_target
    budget <- alloc(MAX_CHARS, has_target)
    is_stable <- is_stable_from_key(sc$stability_key)

    if (sc$stability_key == "no_variation") {
      stab <- pick_variant(analysis$stability$no_variation,
        data = list(centerline = ph$centerline), budget = budget$stability)
    } else {
      stab <- pick_variant(analysis$stability[[sc$stability_key]],
        data = ph, budget = budget$stability)
    }
    tgt_key <- target_key_from_state(sc$target_meta)
    tgt <- if (is.null(tgt_key)) list(text = "", variant = NA_character_)
           else pick_variant(analysis$target[[tgt_key]],
             data = c(ph, list(target = ph$target)), budget = budget$target)
    act_key <- select_action_key(is_stable, has_target,
      sc$target_meta$direction, sc$target_meta$pos)
    act <- pick_variant(analysis$action[[act_key]], data = ph, budget = budget$action)

    parts <- c(stab$text, tgt$text, act$text)
    parts <- parts[nchar(parts) > 0]
    combined_len <- nchar(paste(parts, collapse = " "))
    list(stab_v = stab$variant, tgt_v = tgt$variant, act_v = act$variant,
         combined_len = combined_len)
  })

  all_variants <- c(
    vapply(sims, function(s) s$stab_v %||% NA_character_, character(1)),
    vapply(sims, function(s) s$tgt_v %||% NA_character_, character(1)),
    vapply(sims, function(s) s$act_v %||% NA_character_, character(1))
  )
  combined_lens <- vapply(sims, function(s) s$combined_len, integer(1))
  list(
    n_detailed = sum(all_variants == "detailed", na.rm = TRUE),
    n_standard = sum(all_variants == "standard", na.rm = TRUE),
    n_short = sum(all_variants == "short", na.rm = TRUE),
    n_overflow = sum(grepl("\\*$", all_variants), na.rm = TRUE),
    n_over_max = sum(combined_lens > MAX_CHARS),
    mean_headroom = mean(MAX_CHARS - combined_lens),
    max_len = max(combined_lens)
  )
}

# Grid: stability 40-60%, target 10-25%, step 5%
stab_grid <- seq(0.40, 0.60, by = 0.05)
target_grid <- seq(0.10, 0.25, by = 0.05)
grid_rows <- list()
for (sr in stab_grid) {
  for (tr in target_grid) {
    m <- simulate_with_ratio(sr, tr)
    if (is.null(m)) next
    grid_rows[[length(grid_rows) + 1L]] <- data.frame(
      stab_pct = sr * 100, target_pct = tr * 100,
      action_pct = round((1 - sr - tr) * 100),
      n_detailed = m$n_detailed, n_standard = m$n_standard, n_short = m$n_short,
      n_overflow = m$n_overflow, n_over_max = m$n_over_max,
      max_len = m$max_len, mean_headroom = round(m$mean_headroom, 1),
      stringsAsFactors = FALSE
    )
  }
}
grid_df <- do.call(rbind, grid_rows)
# Sorter: SAFETY FIRST -- minimer overflow, derefter maksimer detailed,
# tiebreak: minimer short. Et ratio der overskrider max_chars rangerer aldrig
# over et der ikke gor, uanset hvor mange detailed-valg det giver.
grid_df <- grid_df[order(grid_df$n_over_max, grid_df$n_overflow,
                         -grid_df$n_detailed, grid_df$n_short), ]

# Identificer nuvaerende ratio dynamisk fra ALLOCATION_POLICY
CURRENT_STAB_PCT <- ALLOCATION_POLICY$with_target$stability * 100
CURRENT_TGT_PCT <- ALLOCATION_POLICY$with_target$target * 100
CURRENT_ACT_PCT <- round((1 - ALLOCATION_POLICY$with_target$stability -
                            ALLOCATION_POLICY$with_target$target) * 100)
is_current_row <- function(r) {
  abs(r$stab_pct - CURRENT_STAB_PCT) < 0.5 &&
    abs(r$target_pct - CURRENT_TGT_PCT) < 0.5
}

cat("Top 12 ratio-splits (sorteret: ingen overflow > flest detailed > faerrest short):\n")
cat(sprintf("%-6s %-6s %-6s | %-9s %-7s %-7s %-9s %-10s %-7s %s\n",
  "stab%", "tgt%", "act%",
  "detail", "std", "short", "overflow", "over_max", "max_len", "mean_hr"))
cat(strrep("-", 95), "\n", sep = "")
for (i in seq_len(min(12L, nrow(grid_df)))) {
  r <- grid_df[i, ]
  marker <- if (is_current_row(r)) " <- nuv." else ""
  cat(sprintf("%-6.0f %-6.0f %-6.0f | %-9d %-7d %-7d %-9d %-10d %-7d %-6.1f%s\n",
    r$stab_pct, r$target_pct, r$action_pct,
    r$n_detailed, r$n_standard, r$n_short, r$n_overflow,
    r$n_over_max, r$max_len, r$mean_headroom, marker))
}

current <- grid_df[vapply(seq_len(nrow(grid_df)),
                          function(i) is_current_row(grid_df[i, ]),
                          logical(1)), ]
if (nrow(current) > 0) {
  current_rank <- which(vapply(seq_len(nrow(grid_df)),
                               function(i) is_current_row(grid_df[i, ]),
                               logical(1)))[1]
  cat(sprintf("\nNuvaerende ratio (%.0f/%.0f/%.0f) er nr. %d af %d testede splits.\n",
    CURRENT_STAB_PCT, CURRENT_TGT_PCT, CURRENT_ACT_PCT,
    current_rank, nrow(grid_df)))
  best <- grid_df[1, ]
  if (best$n_detailed > current$n_detailed) {
    cat(sprintf("Bedste split (%.0f/%.0f/%.0f) ville give %+d detailed, %+d short.\n",
      best$stab_pct, best$target_pct, best$action_pct,
      best$n_detailed - current$n_detailed,
      best$n_short - current$n_short))
  } else {
    cat("Nuvaerende setup er allerede paa det optimale niveau af detailed-valg.\n")
  }
}

cat("\nKolonneforklaring:\n")
cat("  detail/std/short  = antal scenarier hvor variant blev valgt (alle 3 arme samlet)\n")
cat("  overflow          = pick_variant maatte falde tilbage til en variant der overstiger budget\n")
cat("  over_max          = sammensat tekst overstiger max_chars (kraever trim)\n")
cat("  max_len           = laengste sammensatte tekst (foer evt. trim)\n")
cat("  mean_hr           = gennemsnitlig headroom (max_chars - combined_len)\n\n")

# ----------------------------------------------------------------------------
# 7) ACTION ITEMS -- konkret prioriteret liste
# ----------------------------------------------------------------------------
# Genererer en kort, prioriteret to-do-liste ud fra variant_tbl + scenario-res.
# Hver bullet har: prioritet (P1/P2/P3), handling (omskriv/slet/kort ned),
# placering (arm.key.variant), og begrundelse.

cat("== 7) Action items: prioriteret liste ==\n\n")

action_items <- list()
add_item <- function(prio, action, location, detail) {
  action_items[[length(action_items) + 1L]] <<- list(
    prio = prio, action = action, location = location, detail = detail
  )
}

# P1: Overflow -- variant valgt selv om den overstiger budget (alvorligt:
# truncate-risk eller misvisende output). Alle skal omskrives kortere.
overflow_rows <- variant_tbl[variant_tbl$overflow > 0, ]
if (nrow(overflow_rows) > 0) {
  for (i in seq_len(nrow(overflow_rows))) {
    r <- overflow_rows[i, ]
    arm_budget <- if (r$arm == "stability") budget_with$stability
                  else if (r$arm == "target") budget_with$target
                  else budget_with$action
    overshoot <- r$raw_len - arm_budget
    add_item("P1",
      "KORT NED",
      sprintf("%s.%s.%s", r$arm, r$key, r$variant),
      sprintf("%d tegn, %d over %s-budget (%d). Sprenger %d af %d valg.",
        r$raw_len, overshoot, r$arm, arm_budget, r$overflow, r$selected))
  }
}

# P2: Monotoni-brud -- standard >= detailed eller short >= standard. Bryder
# pick_variant's antagelse om at variant-rangen short<standard<detailed.
mono_seen <- character()
for (arm_name in c("stability", "target", "action")) {
  arm_data <- analysis[[arm_name]]
  for (key in names(arm_data)) {
    variants <- arm_data[[key]]
    if (!is.list(variants)) next
    sl <- if (is.null(variants$short)) NA_integer_ else nchar(variants$short)
    stl <- if (is.null(variants$standard)) NA_integer_ else nchar(variants$standard)
    dl <- if (is.null(variants$detailed)) NA_integer_ else nchar(variants$detailed)
    if (!is.na(stl) && !is.na(dl) && stl >= dl) {
      add_item("P2", "OMSKRIV detailed",
        sprintf("%s.%s.detailed", arm_name, key),
        sprintf("detailed (%d tegn) er ikke laengere end standard (%d).",
          dl, stl))
    }
    if (!is.na(sl) && !is.na(stl) && sl >= stl) {
      add_item("P2", "OMSKRIV short eller standard",
        sprintf("%s.%s.short/standard", arm_name, key),
        sprintf("short (%d tegn) er ikke kortere end standard (%d).",
          sl, stl))
    }
  }
}

# P3: Dead variants -- aldrig valgt. Enten redundante eller for lange/korte.
dead_rows <- variant_tbl[variant_tbl$status == "dead", ]
if (nrow(dead_rows) > 0) {
  for (i in seq_len(nrow(dead_rows))) {
    r <- dead_rows[i, ]
    arm_budget <- if (r$arm == "stability") budget_with$stability
                  else if (r$arm == "target") budget_with$target
                  else budget_with$action
    reason <- if (r$demanded == 0) {
      "key blev aldrig aktiveret i nogen scenarie (review om scenarier dakker)"
    } else if (r$variant == "detailed" && r$raw_len > arm_budget) {
      sprintf("detailed (%d tegn) passer aldrig i budget (%d) -- altid downgrade",
        r$raw_len, arm_budget)
    } else if (r$variant == "short") {
      sprintf("short (%d tegn) bliver aldrig valgt -- standard fitter altid",
        r$raw_len)
    } else {
      "ingen scenarie udloeser dette valg (review pick-rates for sibling-varianter)"
    }
    add_item("P3", "REVIEW / EVT. SLET",
      sprintf("%s.%s.%s", r$arm, r$key, r$variant),
      reason)
  }
}

# Print sorteret efter prioritet
if (length(action_items) == 0) {
  cat("  Ingen action items -- alle varianter ser handlingsrigtige ud!\n\n")
} else {
  # Sorter P1 -> P2 -> P3
  prios <- vapply(action_items, function(x) x$prio, character(1))
  ord <- order(prios)
  current_prio <- ""
  for (idx in ord) {
    it <- action_items[[idx]]
    if (it$prio != current_prio) {
      current_prio <- it$prio
      header <- switch(it$prio,
        "P1" = "P1: Overflow (variant for lang, bliver alligevel valgt)",
        "P2" = "P2: Variant-monotoni brudt (forstyrrer pick_variant-logik)",
        "P3" = "P3: Dead variants (aldrig valgt -- omskriv eller slet)")
      cat(sprintf("\n%s\n", header))
      cat(sprintf("%s\n", strrep("-", nchar(header))))
    }
    cat(sprintf("  [%s] %s\n      %s\n",
      it$action, it$location, it$detail))
  }
  cat(sprintf("\nTotal: %d action items (P1=%d, P2=%d, P3=%d)\n\n",
    length(action_items),
    sum(prios == "P1"), sum(prios == "P2"), sum(prios == "P3")))
}

# Top kandidater: hvor er der mest 'tom plads' i action-armen?
# Hvis en variant er primary/common men render-rendet er langt under budget,
# kunne den evt. udvides med mere indhold.
cat("Forslag: varianter med plads til mere indhold\n")
cat("  (primary/common-status, raw_len < 60% af arm-budget)\n")
expansion_candidates <- character()
for (i in seq_len(nrow(variant_tbl))) {
  r <- variant_tbl[i, ]
  if (!r$status %in% c("primary", "common")) next
  arm_budget <- if (r$arm == "stability") budget_with$stability
                else if (r$arm == "target") budget_with$target
                else budget_with$action
  if (r$raw_len < 0.6 * arm_budget && r$variant == "detailed") {
    expansion_candidates <- c(expansion_candidates,
      sprintf("  [UDVID?] %s.%s.%s (%d/%d tegn, pick_rate=%.0f%%)",
        r$arm, r$key, r$variant, r$raw_len, arm_budget, r$pick_rate * 100))
  }
}
if (length(expansion_candidates) == 0) {
  cat("  Ingen oplagte kandidater -- detailed-varianter udnytter budget rimeligt.\n\n")
} else {
  cat(paste(expansion_candidates, collapse = "\n"), "\n\n", sep = "")
}

# ----------------------------------------------------------------------------
# 8) FULD CSV-EKSPORT
# ----------------------------------------------------------------------------
csv_path <- file.path("dev", sprintf("i18n_budget_scenarios_%s.csv", LANG))
write.csv(res, csv_path, row.names = FALSE)
cat(sprintf("Fuldt scenarie-resultatset eksporteret til: %s\n", csv_path))
cat(sprintf("  (%d raekker, %d kolonner)\n", nrow(res), ncol(res)))

# Per-variant tabel CSV
variant_csv <- file.path("dev", sprintf("i18n_variant_usage_%s.csv", LANG))
write.csv(variant_tbl, variant_csv, row.names = FALSE)
cat(sprintf("Per-variant usage-tabel eksporteret til: %s\n", variant_csv))
cat(sprintf("  (%d raekker -- kan sorteres/filtreres i Excel for prioritering)\n\n",
  nrow(variant_tbl)))

cat("=== Faerdig ===\n")
