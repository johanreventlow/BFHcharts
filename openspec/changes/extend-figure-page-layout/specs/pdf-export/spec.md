## ADDED Requirements

### Requirement: Figure bottom panel
Figure pages SHALL support a panel below a full-width figure when
`bfh_figure_panel(placement = "bottom")` is used. The panel row shows key
figures side by side, the legend and the data definition. The chart is
rendered `PDF_FIGURE_BOTTOM_PANEL_MM` lower than without the panel.

#### Scenario: Bottom panel
- **WHEN** a figure is exported with `panel = bfh_figure_panel(kpis = k, placement = "bottom")`
- **THEN** the chart SVG is 264 mm wide and 96 mm high (no analysis text)
- **AND** the Typst parameters contain `placement: "bottom"`

#### Scenario: Line keys
- **WHEN** a legend row has `key = "line"` and `linewidth = 1`
- **THEN** the template draws a short line of `1 * .pt * 0.75` pt instead of a square

### Requirement: Bottom panel layout options
`bfh_figure_panel()` SHALL accept `kpi_columns`, `kpi_size_pt`, `kpi_labels`,
`legend_rows` and `legend_label_width_mm` for the bottom panel. Key figures
and legend fill column by column and share the same height. Legend keys MAY
be `"arrow_up"`/`"arrow_down"`, and a `"box"` key MAY have an `outline`
colour. Defaults SHALL NOT be sent to the template, so existing pages are
unchanged.

#### Scenario: Flow panel
- **WHEN** a panel has four key figures with `kpi_columns = 2` and a legend with `legend_rows = 3`
- **THEN** the Typst parameters contain `kpi_columns: 2` and `legend_rows: 3`
- **AND** the template places the key figures in a 2 x 2 grid and the legend in 2 columns of 3 rows

#### Scenario: Band with outline
- **WHEN** a legend row has `key = "box"` and `outline = "#99d8f6"`
- **THEN** the template draws the square with a thin `#99d8f6` border

### Requirement: Figure date axis
The package SHALL export `bfh_apply_date_axis()`, which gives a ggplot with
a date x-axis the same two-level axis as SPC charts (ISO week numbers above
the axis, month/year below).

#### Scenario: Weekly figure
- **WHEN** `bfh_apply_date_axis(p, x)` is called with 30 weekly POSIXct dates
- **THEN** the plot has a datetime x-scale and one week-number text layer whose first label is "UGE\n<nn>"
