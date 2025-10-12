# qicharts2::qic() Parameter Analyse

Systematisk gennemgang af alle `qicharts2::qic()` parametre og deres håndtering i BFHcharts.

---

## 📊 Parameter Kategorisering

### KATEGORI 1: DATA INPUT (Håndteret ✅)

| Parameter | BFHcharts Status | Implementering | Visualisering | Notes |
|-----------|-----------------|----------------|---------------|-------|
| `x` | ✅ Fuldt håndteret | NSE via `substitute(x)` | Ja - x-akse | Dato/tid column |
| `y` | ✅ Fuldt håndteret | NSE via `substitute(y)` | Ja - y-akse | Målvariabel |
| `n` | ✅ Fuldt håndteret | NSE via `substitute(n)` | Ja - indirekte via ratio | Denominator for P/U charts |
| `data` | ✅ Fuldt håndteret | Direkte pass-through | Ja | Data frame |

**Konklusion:** Alle grundlæggende data input parametre er håndteret korrekt.

---

### KATEGORI 2: CHART BEREGNING (Håndteret ✅)

| Parameter | BFHcharts Status | Implementering | Visualisering | Notes |
|-----------|-----------------|----------------|---------------|-------|
| `chart` | ✅ Fuldt håndteret | Via `chart_type` parameter | Ja | Mapped til dansk terminologi |
| `agg.fun` | ❌ IKKE håndteret | - | Ja | mean/median/sum/sd for run/i charts |
| `method` | ❌ IKKE håndteret | - | Ja | anhoej/bestbox/cutbox runs analysis |
| `multiply` | ❌ IKKE håndteret | - | Ja | Multiply y-axis (e.g., 100 for %) |
| `freeze` | ✅ Fuldt håndteret | Pass-through | Ja | Freeze baseline position |
| `part` | ✅ Fuldt håndteret | Pass-through | Ja | Phase splits |
| `exclude` | ❌ IKKE håndteret | - | Ja | Exclude points from calculations |
| `target` | ✅ Fuldt håndteret | Via `target_value` | Ja | Target line |
| `cl` | ❌ IKKE håndteret | - | Ja | Override centre line |

**Konklusion:**
- Core funktionalitet håndteret (chart type, freeze, part, target)
- Missing: agg.fun, method, multiply, exclude, cl

---

### KATEGORI 3: FACETTING & LAYOUT (⚠️ KRITISK - IKKE HÅNDTERET)

| Parameter | BFHcharts Status | Implementering | Visualisering | Notes |
|-----------|-----------------|----------------|---------------|-------|
| `facets` | ❌ IKKE håndteret | - | **JA - KRITISK** | ggplot2 facetting formula |
| `nrow` | ❌ IKKE håndteret | - | Ja | Facet rows |
| `ncol` | ❌ IKKE håndteret | - | Ja | Facet columns |
| `scales` | ❌ IKKE håndteret | - | Ja | "fixed", "free_y", "free_x", "free" |
| `strip.horizontal` | ❌ IKKE håndteret | - | Ja | Horizontal facet strips |

**⚠️ KONKLUSION:**
**FACETTING er IKKE håndteret - dette er en STOR manglende feature!**
Facetting påvirker HELE visualiseringen:
- Multiple charts i grid layout
- Separate panels med forskellige data subsets
- Labels skal håndteres per facet
- Theme skal tilpasses strip elements

**IMPLIKATIONER:**
1. **Labels:** `add_spc_labels()` virker IKKE med facets (labels placeres kun på én panel)
2. **Theme:** Strip styling mangler i `theme_bfh_spc()`
3. **Config:** Ingen facet-aware label placement
4. **Testing:** Ingen facet tests

---

### KATEGORI 4: ANNOTATIONS & NOTES (Delvist håndteret ⚠️)

| Parameter | BFHcharts Status | Implementering | Visualisering | Notes |
|-----------|-----------------|----------------|---------------|-------|
| `notes` | ⚠️ Delvist | Via `comment_column` i config | Ja | Point annotations |
| `part.labels` | ❌ IKKE håndteret | - | Ja | Custom phase labels |

**Konklusion:**
- `notes` håndteres via `comment_column`, men ikke direkte som `notes` parameter
- `part.labels` mangler (custom tekster for phase splits)

---

### KATEGORI 5: TEKSTLABELS & TITLER (Delvist håndteret ⚠️)

| Parameter | BFHcharts Status | Implementering | Visualisering | Notes |
|-----------|-----------------|----------------|---------------|-------|
| `title` | ✅ Håndteret | Via `chart_title` | Ja | Plot title |
| `ylab` | ⚠️ Hårdkodet | Fixed "Værdi" in theme | Ja | Y-axis label |
| `xlab` | ⚠️ Hårdkodet | Fixed "" (blank) in theme | Ja | X-axis label |
| `subtitle` | ❌ IKKE håndteret | - | Ja | Subtitle |
| `caption` | ❌ IKKE håndteret | - | Ja | Caption |
| `show.labels` | ❌ IKKE håndteret | - | Ja | Show CL/UCL/LCL labels |

**Konklusion:**
- Title håndteret
- ylab/xlab er hårdkodet - ingen user control
- subtitle/caption mangler
- `show.labels` mangler (qic's native labels, ikke vores marquee labels)

---

### KATEGORI 6: VISUAL STYLING (Delvist håndteret ⚠️)

| Parameter | BFHcharts Status | Implementering | Visualisering | Notes |
|-----------|-----------------|----------------|---------------|-------|
| `decimals` | ⚠️ Hårdkodet | Fixed 1 decimal via theme | Ja | Label decimals |
| `point.size` | ⚠️ Hårdkodet | Fixed 3 in geom_point | Ja | Point size |
| `show.95` | ❌ IKKE håndteret | - | Ja | Show 95% limits (±3σ) |
| `show.grid` | ⚠️ Hårdkodet | Fixed FALSE in theme | Ja | Show grid |
| `flip` | ❌ IKKE håndteret | - | Ja | Rotate 90° |

**Konklusion:**
- Styling er hårdkodet i theme
- Ingen user control over decimals, point.size, grid
- `show.95` mangler (3-sigma vs 2-sigma limits)
- `flip` mangler (coord_flip for horizontal charts)

---

### KATEGORI 7: AXIS FORMATTING (Delvist håndteret ⚠️)

| Parameter | BFHcharts Status | Implementering | Visualisering | Notes |
|-----------|-----------------|----------------|---------------|-------|
| `x.period` | ❌ IKKE håndteret | - | Ja | Aggregate by week/month/etc |
| `x.format` | ❌ IKKE håndteret | - | Ja | Date format (strftime) |
| `x.angle` | ⚠️ Hårdkodet | Fixed 0° in theme | Ja | X-axis label angle |
| `x.pad` | ⚠️ Hårdkodet | Fixed expansion in theme | Ja | X-axis expansion |
| `y.expand` | ⚠️ Hårdkodet | Fixed expansion in theme | Ja | Y-axis expansion |
| `y.neg` | ⚠️ Hårdkodet | Fixed TRUE | Ja | Allow negative y-axis |
| `y.percent` | ⚠️ Delvist | Via `y_axis_unit = "percent"` | Ja | Format as % |
| `y.percent.accuracy` | ❌ IKKE håndteret | - | Ja | Decimal precision for % |

**Konklusion:**
- X-axis formatting mangler (period aggregation, date format, angle)
- Y-axis expansion hårdkodet
- Percent formatting håndteret via `y_axis_unit`, men mangler precision control

---

### KATEGORI 8: OUTPUT CONTROL (Håndteret ✅)

| Parameter | BFHcharts Status | Implementering | Visualisering | Notes |
|-----------|-----------------|----------------|---------------|-------|
| `return.data` | ✅ Håndteret | Fixed TRUE | N/A | Always return qic_data |
| `print.summary` | ✅ Implicit | Vi printer aldrig summary | N/A | Not needed |

**Konklusion:** Output control er korrekt håndteret.

---

## 🚨 KRITISKE MANGLER

### 1. **FACETTING** (Højeste prioritet)

**Problem:**
- `facets` parameter er IKKE håndteret
- Multi-panel plots fungerer IKKE
- Labels placeres kun på første facet
- Strip styling mangler

**Impact:**
- **KAN IKKE** lave grouped/comparative charts (fx per afdeling, per hospital)
- **STOR** manglende feature for klinisk brug

**Løsning:**
```r
# Ønsket API:
plot <- create_spc_chart(
  data = data,
  x = month,
  y = infections,
  facets = ~ hospital,  # MANGLER
  chart_type = "i",
  y_axis_unit = "count"
)
```

**Nødvendige ændringer:**
1. Add `facets` parameter to `create_spc_chart()`
2. Pass through to `qic()`
3. Update `add_spc_labels()` to handle faceted plots (loop per panel)
4. Update `theme_bfh_spc()` to style strips
5. Add `nrow`, `ncol`, `scales` parameters

---

### 2. **AGGREGATION FUNCTION** (`agg.fun`)

**Problem:**
- Kun mean aggregation understøttes
- `agg.fun = "median"` mangler for robusthed mod outliers

**Impact:**
- **Median** ofte bedre for kliniske data (outlier-robust)
- **Sum** nødvendig for visse metrics
- **SD** nødvendig for variability charts

**Løsning:**
```r
plot <- create_spc_chart(
  data = data,
  x = month,
  y = infections,
  agg_fun = "median",  # MANGLER
  chart_type = "run",
  y_axis_unit = "count"
)
```

---

### 3. **AXIS LABELS** (`ylab`, `xlab`)

**Problem:**
- Y-axis label er hårdkodet til "Værdi"
- X-axis label er blank
- Ingen user control

**Impact:**
- **Forvirring** hvis y-axis skal være "Antal infektioner", "Procent", etc.
- **Manglende kontekst** på x-axis (år, kvartal, etc.)

**Løsning:**
```r
plot <- create_spc_chart(
  data = data,
  x = month,
  y = infections,
  chart_type = "i",
  y_axis_unit = "count",
  ylab = "Antal infektioner",  # MANGLER
  xlab = "Måned"                # MANGLER
)
```

---

### 4. **EXCLUDE POINTS** (`exclude`)

**Problem:**
- Kan ikke ekskludere outliers fra baseline beregning
- Vigtig for kliniske data med known anomalies

**Impact:**
- **Baseline pollution** hvis outliers ikke kan ekskluderes
- **Forkerte control limits**

**Løsning:**
```r
plot <- create_spc_chart(
  data = data,
  x = month,
  y = infections,
  chart_type = "i",
  y_axis_unit = "count",
  exclude = c(5, 12, 18)  # MANGLER - exclude specific points
)
```

---

### 5. **95% LIMITS** (`show.95`)

**Problem:**
- Kun 2-sigma limits vises
- Nogle brugere ønsker 3-sigma limits (±3σ = 99.7%)

**Impact:**
- **Mindre stringent** special cause detection
- **Compliance** issue hvis 3-sigma er standard

---

## 📋 KOMPLET PARAMETER MATRIX

| Parameter | Håndteret | Visualisering | Prioritet | Notes |
|-----------|-----------|---------------|-----------|-------|
| **DATA INPUT** ||||
| `x` | ✅ | Ja | - | OK |
| `y` | ✅ | Ja | - | OK |
| `n` | ✅ | Ja | - | OK |
| `data` | ✅ | Ja | - | OK |
| **CHART BEREGNING** ||||
| `chart` | ✅ | Ja | - | OK |
| `agg.fun` | ❌ | Ja | 🔴 HIGH | median/sum/sd support |
| `method` | ❌ | Ja | 🟡 LOW | bestbox/cutbox (EXPERIMENTAL) |
| `multiply` | ❌ | Ja | 🟡 MEDIUM | Scale y-axis (e.g., ×100 for %) |
| `freeze` | ✅ | Ja | - | OK |
| `part` | ✅ | Ja | - | OK |
| `exclude` | ❌ | Ja | 🔴 HIGH | Exclude outliers from baseline |
| `target` | ✅ | Ja | - | OK |
| `cl` | ❌ | Ja | 🟡 LOW | Override centre line (rare) |
| **FACETTING** ||||
| `facets` | ❌ | **JA** | 🔴 **CRITICAL** | Multi-panel plots |
| `nrow` | ❌ | Ja | 🔴 HIGH | Facet layout |
| `ncol` | ❌ | Ja | 🔴 HIGH | Facet layout |
| `scales` | ❌ | Ja | 🔴 HIGH | Independent axes per facet |
| `strip.horizontal` | ❌ | Ja | 🟡 LOW | Strip orientation |
| **ANNOTATIONS** ||||
| `notes` | ⚠️ | Ja | 🟡 MEDIUM | Via `comment_column` (ikke direkte) |
| `part.labels` | ❌ | Ja | 🟡 LOW | Custom phase labels |
| **TEKSTLABELS** ||||
| `title` | ✅ | Ja | - | OK |
| `ylab` | ⚠️ | Ja | 🔴 HIGH | Hårdkodet "Værdi" |
| `xlab` | ⚠️ | Ja | 🔴 HIGH | Hårdkodet blank |
| `subtitle` | ❌ | Ja | 🟡 MEDIUM | Missing |
| `caption` | ❌ | Ja | 🟡 LOW | Missing |
| `show.labels` | ❌ | Ja | 🟡 LOW | qic native labels (ikke vores) |
| **VISUAL STYLING** ||||
| `decimals` | ⚠️ | Ja | 🟡 MEDIUM | Hårdkodet til 1 |
| `point.size` | ⚠️ | Ja | 🟡 LOW | Hårdkodet til 3 |
| `show.95` | ❌ | Ja | 🟡 MEDIUM | 3-sigma limits |
| `show.grid` | ⚠️ | Ja | 🟢 LOW | Hårdkodet FALSE (OK) |
| `flip` | ❌ | Ja | 🟡 LOW | Horizontal charts |
| **AXIS FORMATTING** ||||
| `x.period` | ❌ | Ja | 🟡 MEDIUM | Aggregate by week/month |
| `x.format` | ❌ | Ja | 🟡 MEDIUM | Date format |
| `x.angle` | ⚠️ | Ja | 🟡 LOW | Hårdkodet 0° |
| `x.pad` | ⚠️ | Ja | 🟢 LOW | OK |
| `y.expand` | ⚠️ | Ja | 🟢 LOW | OK |
| `y.neg` | ⚠️ | Ja | 🟢 LOW | OK |
| `y.percent` | ⚠️ | Ja | - | Via `y_axis_unit` (OK) |
| `y.percent.accuracy` | ❌ | Ja | 🟡 LOW | Precision control |
| **OUTPUT** ||||
| `return.data` | ✅ | N/A | - | OK |
| `print.summary` | ✅ | N/A | - | OK |

---

## 🎯 PRIORITERET ACTION PLAN

### 🔴 CRITICAL (Blokerer major use cases)

1. **FACETTING** (`facets`, `nrow`, `ncol`, `scales`)
   - **Impact:** Cannot create grouped/comparative charts
   - **Effort:** HIGH (label placement per facet, strip styling)
   - **Use case:** Per-hospital, per-department comparisons

2. **AXIS LABELS** (`ylab`, `xlab`)
   - **Impact:** Poor user experience, unclear context
   - **Effort:** LOW (simple pass-through)
   - **Use case:** All charts

3. **EXCLUDE POINTS** (`exclude`)
   - **Impact:** Cannot handle known anomalies properly
   - **Effort:** LOW (pass-through to qic)
   - **Use case:** Baseline calculation with outliers

### 🟡 HIGH (Manglende flexibility)

4. **AGG.FUN** (`agg.fun`)
   - **Impact:** Limited aggregation strategies
   - **Effort:** LOW (pass-through)
   - **Use case:** Robust median, variability charts

5. **MULTIPLY** (`multiply`)
   - **Impact:** Manual scaling required
   - **Effort:** LOW (pass-through)
   - **Use case:** Convert proportions to percentages

6. **SUBTITLE/CAPTION** (`subtitle`, `caption`)
   - **Impact:** Limited plot annotation
   - **Effort:** LOW (pass-through)
   - **Use case:** Metadata, sources

### 🟢 MEDIUM (Nice-to-have)

7. **SHOW.95** (`show.95`)
   - **Impact:** Limited control over sigma limits
   - **Effort:** LOW (pass-through)
   - **Use case:** 3-sigma compliance

8. **X.FORMAT** (`x.format`, `x.period`)
   - **Impact:** Limited date formatting
   - **Effort:** LOW (pass-through)
   - **Use case:** Custom date displays

9. **DECIMALS/POINT.SIZE** (user control)
   - **Impact:** Limited styling control
   - **Effort:** MEDIUM (config system)
   - **Use case:** Fine-tuning appearance

---

## 📝 RECOMMENDATIONS

### Immediate Actions:

1. **Add facetting support** - This is the biggest gap
2. **Expose ylab/xlab parameters** - Quick win for UX
3. **Add exclude parameter** - Critical for data quality

### Short-term:

4. **Add agg.fun, multiply, subtitle, caption** - Common needs
5. **Update documentation** - Document all unsupported params

### Long-term:

6. **Comprehensive config system** - Allow override of all styling
7. **Facet-aware label placement** - Smart labels per panel
8. **Advanced axis formatting** - Period aggregation, custom formats

---

## 🔍 TESTING GAPS

Based on this analysis, we need tests for:

1. ✅ **Covered:** Basic chart types, target values, phase splits
2. ❌ **Missing:** Facetting (complete gap)
3. ❌ **Missing:** Aggregation functions (median, sum, sd)
4. ❌ **Missing:** Exclude points
5. ❌ **Missing:** Custom axis labels
6. ❌ **Missing:** Subtitle/caption
7. ❌ **Missing:** 95% limits
8. ❌ **Missing:** Multiply scaling

---

## KONKLUSION

**BFHcharts håndterer:**
- ✅ Core data input (x, y, n, data)
- ✅ Basic chart types (run, i, p, c, u, etc.)
- ✅ Phase management (part, freeze)
- ✅ Target values
- ✅ Responsive typography (width/height)
- ✅ Automatic label placement

**BFHcharts mangler:**
- 🔴 **KRITISK:** Facetting (multi-panel plots)
- 🔴 **HIGH:** Axis labels (ylab, xlab)
- 🔴 **HIGH:** Exclude points
- 🟡 **MEDIUM:** Aggregation functions (median, sum, sd)
- 🟡 **MEDIUM:** Multiply scaling
- 🟡 **MEDIUM:** Subtitle/caption
- 🟡 **LOW:** User styling control (decimals, point.size, etc.)

**Next Steps:**
1. Prioritize facetting implementation
2. Add axis label parameters
3. Add exclude parameter
4. Update tests to cover gaps
