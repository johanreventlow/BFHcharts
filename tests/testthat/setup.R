# ============================================================================
# Test Setup — determinism og miljø-kontrol
# ============================================================================
#
# Kører automatisk før alle tests. Sikrer at tests er reproducerbare på tværs
# af platforme (macOS dev / Ubuntu CI / Windows CI) ved at pin'e:
#   - Locale til C.UTF-8 (undgår dansk vs. engelsk comma separator, månedsnavne)
#   - Timezone til Europe/Copenhagen (undgår dato-skifter omkring midnat)
#   - RNGkind til Mersenne-Twister (undgår R 3.6 → 4.0 sample-kind-skift)
#   - OutDec til "." (konsistent decimal separator ved print)
#
# Reference: openspec/changes/strengthen-test-infrastructure (task 6.1, Fase 2)
# Spec: test-infrastructure, "Test fixtures SHALL be centralized and deterministic"

# Locale: UTF-8 for dansk tegn-håndtering. Fall-back-kæde for platform-forskelle.
# macOS: en_US.UTF-8, Ubuntu: C.UTF-8, Windows: en_US.utf8 / Danish_Denmark.1252
.set_utf8_locale <- function() {
  candidates <- c("C.UTF-8", "en_US.UTF-8", "en_US.utf8", "C")
  for (loc in candidates) {
    res <- tryCatch(
      suppressWarnings(Sys.setlocale("LC_ALL", loc)),
      error = function(e) ""
    )
    if (nzchar(res)) return(invisible(res))
  }
  invisible(NULL)
}
.set_utf8_locale()

# Timezone: alle dato-aware tests skal have samme tidsbånd
Sys.setenv(TZ = "Europe/Copenhagen")

# RNGkind: eksplicit pinning så set.seed() giver samme sekvenser på tværs
# af R-versioner. Default ændrede sig mellem R 3.6 og R 4.0.
suppressWarnings(
  RNGkind(kind = "Mersenne-Twister",
          normal.kind = "Inversion",
          sample.kind = "Rejection")
)

# Decimal separator: "." for konsistens (nogle tests kontrollerer print-output)
options(OutDec = ".")

# Collation: "C" sikrer stabil sort-rækkefølge på tværs af miljøer
Sys.setlocale("LC_COLLATE", "C")
