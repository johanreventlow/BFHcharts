# Installing Roboto Font for BFHcharts

BFHcharts uses **Roboto Medium** for optimal typography. Without it, the package falls back to system sans-serif fonts.

## Quick Install (Recommended)

### Option 1: Use systemfonts package (Easiest)

```r
# Install systemfonts if not already installed
install.packages("systemfonts")

# Register font from Google Fonts or local system
# BFHcharts will automatically use it via ragg device
```

### Option 2: Install Roboto system-wide

#### macOS:
```bash
# Download Roboto
curl -L "https://github.com/google/roboto/releases/download/v2.138/roboto-unhinted.zip" -o ~/Downloads/roboto.zip

# Extract
unzip ~/Downloads/roboto-unhinted.zip -d ~/Downloads/roboto

# Install (double-click each .ttf file in Roboto-Medium subfolder)
open ~/Downloads/roboto/Roboto-Medium.ttf
```

Or use Homebrew:
```bash
brew tap homebrew/cask-fonts
brew install font-roboto
```

#### Windows:
1. Download Roboto from [Google Fonts](https://fonts.google.com/specimen/Roboto)
2. Extract ZIP file
3. Right-click `Roboto-Medium.ttf` → Install

#### Linux (Ubuntu/Debian):
```bash
sudo apt-get update
sudo apt-get install fonts-roboto
```

### Option 3: Use Alternative Font

Modify theme to use system font:

```r
# Create custom color palette with different font
my_colors <- BFH_COLORS
attr(my_colors, "font_family") <- "Arial"  # or "Helvetica"

plot <- create_spc_chart(
  data = df,
  x = month,
  y = infections,
  chart_type = "i",
  y_axis_unit = "count",
  colors = my_colors
)
```

## Verify Installation

```r
# Check available fonts
systemfonts::system_fonts() |>
  dplyr::filter(grepl("Roboto", family, ignore.case = TRUE))

# Should show Roboto Medium if installed correctly
```

## Font Rendering in R

BFHcharts uses the `ragg` graphics device for high-quality rendering:

```r
# Save with ragg device (automatic font discovery)
ragg::agg_png("output.png", width = 10, height = 6, units = "in", res = 300)
print(plot)
dev.off()

# Or use ggsave with ragg
ggsave("output.png", plot, width = 10, height = 6, dpi = 300, device = ragg::agg_png)
```

## Fallback Behavior

If Roboto is not found:
- ✅ Package still works correctly
- ⚠️ Uses system sans-serif font instead
- ⚠️ Typography may differ slightly from designed appearance

**Bottom line:** Installing Roboto is optional but recommended for best visual results.
