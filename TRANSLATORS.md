# Adding a New Language to BFHcharts

BFHcharts loads user-facing strings from YAML files in `inst/i18n/`.
The files are keyed by language code (`da`, `en`, …).

## Steps

### 1. Copy the Danish template

```bash
cp inst/i18n/da.yaml inst/i18n/<lang>.yaml
```

Replace `<lang>` with the BCP-47 language code, e.g. `nb` (Norwegian
Bokmål), `sv` (Swedish), `de` (German).

### 2. Translate all values

Open `inst/i18n/<lang>.yaml` and translate every **value** on the right
side of the colon. **Never change the keys** (left side).

```yaml
# da.yaml                        # <lang>.yaml
labels:
  interval:
    monthly: "måned"    →        monthly: "mois"   # French example
    weekly:  "uge"      →        weekly:  "semaine"
```

The full key structure is documented inline in `inst/i18n/da.yaml`.

### 3. Test the translation

```r
devtools::load_all()

# Check all keys load without warning
BFHcharts:::load_translations("<lang>")

# Spot-check a few values
BFHcharts:::i18n_lookup("labels.interval.monthly", "<lang>")
BFHcharts:::i18n_lookup("labels.chart.current_level", "<lang>")

# Full round-trip
result <- bfh_qic(
  data.frame(x = 1:12, y = rpois(12, 5)),
  x = x, y = y, chart_type = "run",
  language = "<lang>"
)
bfh_generate_details(result, language = "<lang>")
bfh_generate_analysis(result, language = "<lang>")
```

### 4. Add key-parity test

Open `tests/testthat/test-i18n.R` and extend the parity test to include
the new language:

```r
test_that("key parity: <lang> matches da", {
  da <- BFHcharts:::load_translations("da")
  tgt <- BFHcharts:::load_translations("<lang>")
  expect_equal(sort(leaf_paths(tgt)), sort(leaf_paths(da)))
})
```

### 5. Document in NEWS.md and README.md

Add an entry under `## Nye features` in `NEWS.md` and update the
"Supported Languages" table in `README.md`.

## Fallback Behaviour

If a key is missing in the target file, `i18n_lookup()` automatically
falls back to Danish (`"da"`) and emits a warning. This means a
partial translation is functional — missing keys degrade gracefully.

## Key Reference

All keys are defined in `inst/i18n/da.yaml`. The top-level sections are:

| Section | Contents |
|---------|----------|
| `analysis.stability.*` | Stability descriptions (no signals, runs, etc.) |
| `analysis.target.*` | At-target / over / under target texts |
| `analysis.action.*` | Combined action recommendations |
| `analysis.padding.*` | Padding text for short analyses |
| `labels.interval.*` | Time interval names (day, week, month, …) |
| `labels.outliers.*` | Singular/plural forms for outlier counts |
| `labels.details.*` | Detail line labels (period, avg, latest, level) |
| `labels.chart.*` | Chart overlay labels (baseline, current level, goal) |
| `labels.misc.*` | Miscellaneous (unknown value placeholder) |
