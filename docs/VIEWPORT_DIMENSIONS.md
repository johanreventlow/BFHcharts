# Viewport Dimensions & Label Placement

## Overview

BFHcharts' advanced label placement system uses **viewport dimensions** to achieve pixel-perfect label sizing and collision avoidance. This document explains how the system works and how to use it optimally.

## How It Works

### The Label Placement Pipeline

```
create_spc_chart(width=10, height=6)
  ↓
add_spc_labels(viewport_width=10, viewport_height=6 inches)
  ↓
add_right_labels_marquee() opens temporary PDF device
  ↓
measure_panel_height_from_gtable() measures actual panel size
  ↓
estimate_label_heights_npc() calculates precise label heights
  ↓
place_two_labels_npc() applies collision avoidance
  ↓
Perfect label placement!
```

### Key Components

1. **Viewport Dimensions** (width/height in inches)
   - Provided by user or derived from graphics device
   - Enables opening temporary device with exact dimensions
   - Critical for accurate grob measurements

2. **Temporary PDF Device**
   - Opened automatically when viewport dimensions provided
   - Allows precise measurement of label heights
   - Closed after measurements complete

3. **Panel Height Measurement**
   - Extracts exact panel dimensions from gtable
   - Converts NPC (0-1) coordinates to inches
   - Enables inch-based collision gap calculations

4. **Responsive Label Sizing**
   - `base_size` parameter scales all typography
   - `label_size` auto-calculated: `base_size / 14 * 6`
   - Maintains proportions across different plot sizes

## Usage Patterns

### Pattern 1: Specify Dimensions (Recommended)

```r
# Best practice: match create_spc_chart dimensions with ggsave
plot <- create_spc_chart(
  data = df,
  x = month,
  y = infections,
  chart_type = "i",
  y_axis_unit = "count",
  width = 10,   # inches
  height = 6,   # inches
  target_value = 15,
  target_text = "<15"
)

# Save with same dimensions for perfect rendering
ggsave("output.png", plot, width = 10, height = 6, dpi = 300)
```

**Benefits:**
- ✅ Pixel-perfect label placement
- ✅ Consistent rendering across devices
- ✅ Optimal collision avoidance
- ✅ Predictable typography scaling

### Pattern 2: Use Active Graphics Device

```r
# Open device first
png("output.png", width = 10, height = 6, units = "in", res = 300)

# Create plot (will detect device dimensions)
plot <- create_spc_chart(
  data = df,
  x = month,
  y = infections,
  chart_type = "i",
  y_axis_unit = "count"
)

print(plot)
dev.off()
```

**Benefits:**
- ✅ Works with any graphics device (png, pdf, svg, etc.)
- ✅ Automatic dimension detection
- ⚠️ Device must be open before plot creation

### Pattern 3: Default Behavior (Fallback)

```r
# No dimensions specified
plot <- create_spc_chart(
  data = df,
  x = month,
  y = infections,
  chart_type = "i",
  y_axis_unit = "count"
)

# Labels will use NPC-based fallback
print(plot)
```

**Behavior:**
- ⚠️ Falls back to NPC-only calculations
- ⚠️ Less precise collision avoidance
- ⚠️ May produce warnings about missing panel_height
- ✅ Still functional, just less optimal

## Scaling Behavior

### Typography Scaling

```r
# Small plot with proportional typography
plot_small <- create_spc_chart(..., base_size = 10, width = 6, height = 4)

# Large plot with proportional typography
plot_large <- create_spc_chart(..., base_size = 18, width = 14, height = 8)
```

**Scaling relationships:**
- `base_size` = 14 (default) → label_size = 6
- `base_size` = 10 → label_size ≈ 4.3
- `base_size` = 18 → label_size ≈ 7.7

### DPI Considerations

```r
# Web display (96 DPI)
ggsave("web.png", plot, width = 10, height = 6, dpi = 96)

# Print quality (300 DPI)
ggsave("print.png", plot, width = 10, height = 6, dpi = 300)

# High-res presentation (600 DPI)
ggsave("presentation.png", plot, width = 10, height = 6, dpi = 600)
```

**Important:** DPI only affects pixel density, not label placement. Labels are sized in **inches**, so they remain consistent across DPI settings.

## Shiny Integration

In Shiny apps, viewport dimensions come from `session$clientData`:

```r
# In Shiny server function
output$spc_plot <- renderPlot({
  create_spc_chart(
    data = data(),
    x = month,
    y = infections,
    chart_type = "i",
    y_axis_unit = "count",
    width = session$clientData$output_spc_plot_width / 96,   # pixels → inches
    height = session$clientData$output_spc_plot_height / 96
  )
})
```

**Note:** BFHcharts API expects **inches**, not pixels. Convert using `pixels / 96` (web standard DPI).

## Troubleshooting

### Warning: "panel_height_inches ikke tilgængelig"

**Cause:** No viewport dimensions provided and no graphics device open.

**Solutions:**
1. Add `width` and `height` parameters to `create_spc_chart()`
2. Open graphics device before creating plot
3. Accept NPC-based fallback (functional but less precise)

### Warning: "cannot change value of locked binding"

**Cause:** Using `devtools::load_all()` creates locked package-level variables.

**Impact:** Non-critical - caching system falls back gracefully.

**Solutions:**
1. Ignore warning (labels still work correctly)
2. Install package properly: `devtools::install()` instead of `load_all()`

### Labels Too Large or Too Small

**Solutions:**
1. Adjust `base_size` parameter (default: 14)
2. Ensure `width`/`height` match actual output dimensions
3. Check DPI is appropriate for medium (96 web, 300 print)

## Performance Considerations

**With viewport dimensions:**
- Opens temporary PDF device (~10ms)
- Precise grob measurements (~5ms per label)
- Total overhead: ~20ms

**Without viewport dimensions:**
- Falls back to estimated measurements
- Faster (~5ms) but less accurate
- May require manual label adjustment

**Recommendation:** Always provide dimensions for production plots.

## Advanced: Custom Label Placement

For fine-grained control, use `add_spc_labels()` directly:

```r
plot <- bfh_spc_plot(qic_data, plot_config, viewport)

plot_with_labels <- add_spc_labels(
  plot = plot,
  qic_data = qic_data,
  y_axis_unit = "count",
  label_size = 8,           # Custom size
  viewport_width = 12,      # Custom dimensions
  viewport_height = 7,
  target_text = "<15",
  verbose = TRUE,           # Show placement diagnostics
  debug_mode = FALSE        # Add visual debug annotations
)
```

## Summary

**Best Practice Checklist:**
- ✅ Always specify `width` and `height` for production plots
- ✅ Match dimensions between `create_spc_chart()` and `ggsave()`
- ✅ Use `base_size` to scale typography proportionally
- ✅ Test at target DPI before final export
- ✅ Ignore locked binding warnings when using `devtools::load_all()`

**Result:** Pixel-perfect SPC charts with intelligent label placement! 📊
