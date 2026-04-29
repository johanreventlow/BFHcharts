## 1. Implementation

- [x] 1.1 In `bfh_generate_analysis()` (`R/spc_analysis.R`), at the entry of the AI-branch (after `requireNamespace("BFHllm")` succeeds), emit a `message()` naming:
  - "BFHcharts AI: invoking BFHllm::bfhllm_spc_suggestion()"
  - the field names transmitted (extracted from spc_result + llm_context)
  - `use_rag` value
- [x] 1.2 Wrap the message in a check for `options("BFHcharts.suppress_ai_audit_message")` to allow opt-out
- [x] 1.3 Use a stable message format (named tag like `[BFHcharts/AI]`) for log-grep-ability

## 2. Tests

- [x] 2.1 Test: `bfh_generate_analysis(result, use_ai = TRUE)` emits message with expected tag
- [x] 2.2 Test: message lists the field names actually passed
- [x] 2.3 Test: `options(BFHcharts.suppress_ai_audit_message = TRUE)` suppresses the message
- [x] 2.4 Test: `use_ai = FALSE` (default) emits no AI-branch message

## 3. Documentation

- [x] 3.1 Update `bfh_generate_analysis()` Roxygen `@section AI audit signal` documenting the message format and opt-out
- [x] 3.2 Update `vignettes/safe-exports.Rmd` mentioning the audit signal as a defense-in-depth feature
- [x] 3.3 NEWS entry under `## Sikkerhed` or `## Forbedringer`

## 4. Release

- [x] 4.1 PATCH bump (additive)
- [x] 4.2 `devtools::test()` clean
- [x] 4.3 `devtools::check()` clean
