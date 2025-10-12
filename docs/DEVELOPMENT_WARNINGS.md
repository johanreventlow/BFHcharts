# Development Warnings Guide

This document explains common warnings you may encounter during BFHcharts development and how to handle them.

## 1. Font Warning (Optional)

```
Warning: Font 'Roboto Medium' not found. Falling back to sans.
```

**Cause:** Roboto font not installed on your system.

**Impact:**
- ✅ Package works correctly
- ⚠️ Uses system sans-serif instead
- ⚠️ Typography differs from designed appearance

**Solutions:**
1. **Install Roboto** (recommended): See `docs/INSTALLING_FONTS.md`
2. **Ignore warning**: Package is fully functional with fallback font
3. **Suppress warning**: Not recommended - font installation is better

**When to worry:** Never - this is purely cosmetic.

---

## 2. Locked Binding Warnings (Development Only)

```
Warning: cannot change value of locked binding for '.grob_cache_stats'
Warning: cannot change value of locked binding for '.panel_cache_stats'
```

**Cause:** Using `devtools::load_all()` creates locked package-level variables.

**Impact:**
- ⚠️ Cache statistics cannot be updated
- ✅ Label placement still works correctly
- ✅ Measurements fall back gracefully
- ⚠️ Only happens with `devtools::load_all()`

**Solutions:**

### Option 1: Ignore (Recommended for development)
These warnings are **harmless** during development. The label placement system has fallback mechanisms that work perfectly fine without cache updates.

```r
# Just continue working normally
devtools::load_all()
plot <- create_spc_chart(...)  # Works fine despite warnings
```

### Option 2: Install package properly
Install the package to eliminate locked bindings:

```r
# Install to library (no locked bindings)
devtools::install()
library(BFHcharts)

# Now no warnings
plot <- create_spc_chart(...)
```

### Option 3: Suppress warnings (Not recommended)
```r
suppressWarnings({
  plot <- create_spc_chart(...)
})
```

**When to worry:** Never - this is expected behavior with `devtools::load_all()`.

---

## 3. Panel Height Warning

```
Warning: panel_height_inches ikke tilgængelig - falder tilbage til NPC-baseret gap
```

**Cause:** No graphics device open when labels are calculated.

**Impact:**
- ⚠️ Falls back to NPC-only calculations (less precise)
- ✅ Labels still render correctly
- ✅ Collision avoidance still works

**Solutions:**

### Option 1: Specify viewport dimensions (Recommended)
```r
plot <- create_spc_chart(
  data = df,
  x = month,
  y = infections,
  chart_type = "i",
  y_axis_unit = "count",
  width = 10,   # Enables precise panel measurement
  height = 6
)
```

### Option 2: Open graphics device before plotting
```r
png("output.png", width = 10, height = 6, units = "in", res = 300)
plot <- create_spc_chart(...)
print(plot)
dev.off()
```

### Option 3: Accept NPC fallback
The fallback mechanism is robust and produces good results even without panel height measurements. For most use cases, this is acceptable.

**When to worry:** Only if you need pixel-perfect label placement (e.g., for print production).

---

## Summary: Which Warnings to Fix?

| Warning | Severity | Fix Priority | Solution |
|---------|----------|--------------|----------|
| Roboto font | Low | Optional | Install font |
| Locked binding | None | Ignore | Use `devtools::install()` for production |
| Panel height | Low | Optional | Add `width`/`height` parameters |

**Best Practice for Development:**
```r
# Just work normally with devtools::load_all()
devtools::load_all()

# Specify dimensions for optimal results
plot <- create_spc_chart(
  data = df,
  x = month,
  y = infections,
  chart_type = "i",
  y_axis_unit = "count",
  width = 10,
  height = 6
)

# Ignore warnings - they're harmless
ggsave("output.png", plot, width = 10, height = 6, dpi = 300)
```

**Best Practice for Production:**
```r
# Install package properly
devtools::install()
library(BFHcharts)

# Install Roboto font (see docs/INSTALLING_FONTS.md)

# Create plots (no warnings)
plot <- create_spc_chart(
  data = df,
  x = month,
  y = infections,
  width = 10,
  height = 6
)
```

---

## Debugging: Enable Verbose Mode

For detailed diagnostics during development:

```r
plot <- create_spc_chart(
  data = df,
  x = month,
  y = infections,
  width = 10,
  height = 6
)

# Add labels with verbose mode
plot <- add_spc_labels(
  plot = plot,
  qic_data = qic_data,
  y_axis_unit = "count",
  verbose = TRUE,      # Show placement diagnostics
  debug_mode = FALSE   # Add visual debug annotations if needed
)
```

This will print detailed information about:
- Viewport dimensions
- Device detection
- Label height calculations
- Collision avoidance strategy
- Placement quality

---

## TL;DR

**During development with `devtools::load_all()`:**
- ✅ All warnings are harmless
- ✅ Package works correctly
- ✅ Just ignore them and continue

**For production:**
- Install package properly: `devtools::install()`
- Install Roboto font (optional)
- Always specify `width` and `height` parameters
