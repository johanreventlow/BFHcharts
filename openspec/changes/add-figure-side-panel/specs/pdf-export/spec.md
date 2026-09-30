## ADDED Requirements

### Requirement: Figure pages SHALL support a side panel

The `bfh-diagram` template SHALL accept a dictionary parameter `figure_panel`
(default `none`). When `spc_panel` is `false` and `figure_panel` is given, the
chart row SHALL render the chart column plus a 72.6 mm right column containing,
in order and each only when present: key figures (`kpis`), a colour legend
(`legend`, with a group heading each time `group` changes) and the data
definition. `bfh_figure_panel()` SHALL build and validate the panel, and
`bfh_export_figure_pdf()` / `bfh_stage_figure_page()` SHALL accept it as
`panel`.

#### Scenario: Panel with legend and definition

- **GIVEN** `bfh_export_figure_pdf(plot, out, metadata = list(title = "T", data_definition = "D"), panel = bfh_figure_panel(legend = ...))`
- **WHEN** it is exported
- **THEN** the chart SVG SHALL be 191.4 mm wide
- **AND** the Typst document SHALL pass `figure_panel` with the legend entries
- **AND** no data-definition warning SHALL be raised

#### Scenario: SPC pages ignore the panel

- **GIVEN** metadata without `spc_panel: false`
- **THEN** `figure_panel` SHALL NOT be emitted and the page SHALL render as before

#### Scenario: Caller metadata cannot inject a panel

- **GIVEN** `metadata$figure_panel` supplied by the caller
- **THEN** it SHALL NOT reach the template; only the `panel` argument does

## MODIFIED Requirements

### Requirement: Typst template SHALL support a full-width figure layout

The `bfh-diagram` Typst template SHALL accept a boolean parameter `spc_panel`
(default `true`). When `false`, the chart row SHALL render without the SPC
statistics column (a full-width column, or chart column plus figure side
panel). When `spc_panel` is `false` and `analysis` is `none`, the analysis row
SHALL be omitted, the chart row SHALL start 6.6 mm below the header, and the R
side SHALL render the chart 130.8 mm high. With analysis, figure pages keep the
26.4 mm analysis row and a 109 mm chart.

#### Scenario: Default mode is unchanged

- **GIVEN** a Typst document that does not pass `spc_panel`
- **WHEN** it is compiled
- **THEN** the page SHALL render exactly as before this change

#### Scenario: Figure page without analysis uses the analysis row

- **GIVEN** `bfh_export_figure_pdf()` without `metadata$analysis`
- **THEN** the chart SVG SHALL be 130.8 mm high
- **AND** the template SHALL render only the header row and the chart row
