// BFH SPC Diagram Template
// Generates A4 landscape PDF with hospital branding, SPC chart, and metadata
//
// Parameters:
//   hospital: Hospital name (default: "Bispebjerg og Frederiksberg Hospital")
//   department: Department/unit name (optional)
//   title: Chart title (required via content parameter)
//   analysis: Analysis text with findings and recommendations (optional)
//   details: Period info, averages, current level (optional)
//   author: Author name (optional)
//   date: Report date (default: today)
//   data_definition: Data definition text explaining indicator (optional)
//   runs_expected: Expected serielængde value for SPC table (optional)
//   runs_actual: Actual serielængde value for SPC table (optional)
//   crossings_expected: Expected antal kryds value for SPC table (optional)
//   crossings_actual: Actual antal kryds value for SPC table (optional)
//   outliers_expected: Expected obs. uden for kontrolgrænse value (optional)
//   outliers_actual: Actual obs. uden for kontrolgrænse value (optional)
//   is_run_chart: Boolean indicating if this is a run chart (hides outlier row)
//   cl_user_supplied: Boolean. When true, render a caveat note below the SPC
//                     table indicating that the centerline was set manually
//                     and Anhøj signals were computed against it (not the
//                     data-estimated process mean). Default false.
//   cl_auto_mean: Boolean. When true, render a caveat note indicating that
//                 the run-chart centerline was auto-switched from median to
//                 mean because >=50% of last-phase observations sat exactly
//                 on the median. Mutually exclusive with cl_user_supplied.
//                 Default false.
//   cl_caveat_text: Pre-translated caveat text rendered when either
//                   cl_user_supplied or cl_auto_mean is true. Resolved
//                   server-side via inst/i18n/{da,en}.yaml ->
//                   labels.caveats.{cl_user_supplied|cl_auto_mean}.
//   footer_content: Additional content to display below the chart (optional)
//   logo_path: Path to hospital logo image (optional). When none (default), no
//              foreground logo is rendered -- PDF compiles successfully without
//              proprietary branding assets. Companion packages (BFHchartsAssets)
//              populate this via inject_assets callback or auto-detection.
//   spc_panel: Boolean (default true). When false, the chart row renders as one
//              full-width column (details line, chart, footer) and the SPC
//              statistics column (heading, table, caveat, data definition) is
//              omitted. Used by bfh_export_figure_pdf() / bfh_stage_figure_page()
//              for non-SPC figures. data_definition is accepted but not
//              rendered in this mode.
//   figure_panel: Dictionary (default none). Only used when spc_panel is false:
//              adds a right column (72.6 mm, same width as the SPC column) next
//              to the figure. Keys, all optional:
//                kpis: array of (label:, value:, color:) - large key figures
//                kpi_title: heading above the key figures
//                legend: array of (label:, color:, group:, key:, thickness:) -
//                        colour legend; a group heading is shown each time
//                        group changes. key: "line" draws a short line of the
//                        given thickness instead of a filled square.
//                legend_title: heading above the legend (default "Tegnforklaring")
//                definition_height: height of the data definition block
//                        (default 39.6mm)
//                placement: "side" (default) or "bottom". "bottom" keeps the
//                        chart full width and puts key figures (side by side),
//                        legend and data definition in a row below it
//                        (bottom-panel-height + 3.3 mm gap; the R side renders
//                        the chart correspondingly lower).
//              data_definition IS rendered in the figure panel.
//   Figure pages (spc_panel: false) without analysis drop the analysis row, so
//   the figure takes over its 26.4 mm. The R side renders the chart SVG
//   correspondingly taller (PDF_IMAGE_HEIGHT_FIGURE_MM).
//   chart: Chart content (image or other content) (required via content parameter)
//
#let bfh-diagram(
  hospital: "Bispebjerg og Frederiksberg Hospital",
  department: none,
  title: [Skriv en kort titel, eller tilføj en konklusion,\ *der tydeligt opsummerer hvad grafen fortæller*],
  analysis: none,
  details: none,
  author: none,
  date: datetime.today(),
  data_definition: none,
  runs_expected: none,
  runs_actual: none,
  crossings_expected: none,
  crossings_actual: none,
  outliers_expected: none,
  outliers_actual: none,
  is_run_chart: false,
  cl_user_supplied: false,
  cl_auto_mean: false,
  cl_caveat_text: none,
  footer_content: none,
  logo_path: none,
  spc_panel: true,
  figure_panel: none,
  chart
) = {
  set text(font: ("Mari", "Roboto", "Arial", "Helvetica", "sans-serif"),
           lang: "da",
         )


show table.cell: it => {
  // Header row (y == 0): small grey text, centered
  if it.y == 0 {
    set text(fill: rgb("888888"), size: 9pt, weight: "regular")
    set align(center)
    it
  } else {
    // Data rows: let the box helper functions handle styling
    it
  }
}
 

  set page(
    "a4",
    flipped: true,
    margin: (bottom: 6.6mm, rest: 0mm),
    //fill: rgb("ffff00"),  // Gul baggrundsfarve for at visualisere margins
    // Foreground logo: rendered only when logo_path is supplied. When none
    // (the default for installs without companion-injected assets), the
    // foreground slot stays empty and the PDF compiles without errors.
    // Header bar + title block use fixed offsets independent of this slot,
    // so layout is preserved either way (see ADR-001 + change
    // openspec/changes/add-conditional-template-image/design.md D3).
    foreground: if logo_path != none {
       place(
         image(logo_path,
         height: 19.8mm
       ),
       dy: 39.6mm,
       dx: 0mm)
     } else { none }
  )

  // Figure pages without analysis text: the analysis row is dropped and the
  // chart row starts right below the header (with a 6.6 mm gap instead of 2 mm).
  let drop-analysis = not spc_panel and analysis == none

  // Data definition - cascade-rendering:
  //   1) Forsøg 9pt -> 8.5pt -> 8pt med tæt leading + hyphenation
  //   2) Vælg største font hvor indholdet passer i target-height
  //   3) Hvis selv 8pt overflower, render ved 8pt + clip + ellipsis
  // Newlines i input splittes til separate paragraffer.
  // Bruges af både SPC-kolonnen (52.8mm) og figur-panelet.
  // sizes: skriftstoerrelser der proeves i raekkefoelge (bundpanelet tillader
  // ned til 7pt, fordi raekken er lav).
  let definition-block(target-height, sizes: (9pt, 8.5pt, 8pt)) = {
    text(fill: rgb("888888"),
             weight: "bold",
             size: 9pt,
             upper([Datadefinition]))
    linebreak()
    set text(hyphenate: true)
    let paragraphs = data_definition
      .split("\n")
      .map(p => p.trim())
      .filter(p => p != "")
    let render-at(size) = {
      for (i, p) in paragraphs.enumerate() {
        if i > 0 { parbreak() }
        par(justify: true, leading: 0.55em,
          text(fill: rgb("888888"), size: size, p))
      }
    }
    let candidate-sizes = sizes
    layout(size => context {
      let fits(sz) = measure(
        block(width: size.width, render-at(sz))
      ).height <= target-height
      let chosen = candidate-sizes.find(fits)
      let final-size = if chosen != none { chosen } else { candidate-sizes.last() }
      let overflows = chosen == none
      block(
        height: target-height,
        width: 100%,
        clip: true,
        {
          render-at(final-size)
          if overflows {
            place(bottom + left,
              block(width: 100%, fill: white,
                text(fill: rgb("888888"), size: final-size, "...")))
          }
        }
      )
    })
  }

  let panel-heading(t) = text(fill: rgb("888888"), weight: "bold", size: 9pt, upper(t))

  // Datadefinition i naturlig hoejde (ingen fast boks), til sidepanelet naar
  // definitionen staar oeverst (figure_panel.definition_first).
  let definition-natural = {
    text(fill: rgb("888888"), weight: "bold", size: 9pt, upper([Datadefinition]))
    linebreak()
    set text(hyphenate: true)
    let paragraphs = data_definition.split("\n").map(p => p.trim()).filter(p => p != "")
    for (i, p) in paragraphs.enumerate() {
      if i > 0 { parbreak() }
      par(justify: true, leading: 0.55em, text(fill: rgb("888888"), size: 9pt, p))
    }
  }
  // Legend key: filled square, or a short line of the series' thickness
  let legend-key(item) = {
    let key = item.at("key", default: "box")
    if key == "line" {
      box(width: 6mm, height: 3.3mm,
        align(horizon, line(length: 6mm,
          stroke: (paint: rgb(item.color), thickness: item.at("thickness", default: 1.5pt)))))
    } else if key == "arrow_up" or key == "arrow_down" {
      // Lodret pil som i flowet: tyk stamme og lukket hoved
      let c = rgb(item.color)
      box(width: 3.3mm, height: 4.4mm, {
        let op = key == "arrow_up"
        place(dx: 1.15mm, dy: if op { 1.5mm } else { 0mm }, rect(width: 1mm, height: 2.9mm, fill: c))
        place(if op { polygon(fill: c, (0mm, 1.6mm), (1.65mm, 0mm), (3.3mm, 1.6mm)) }
              else { polygon(fill: c, (0mm, 2.8mm), (1.65mm, 4.4mm), (3.3mm, 2.8mm)) })
      })
    } else {
      let outline = item.at("outline", default: none)
      box(width: 3.3mm, height: 3.3mm, fill: rgb(item.color),
        stroke: if outline != none { 0.6pt + rgb(outline) } else { none })
    }
  }

  // Bottom panel (figure_panel.placement = "bottom"): key figures, legend
  // and data definition in one row below the full-width chart.
  //   kpi_columns: KPIs i et gitter med saa mange kolonner, fyldt kolonnevis
  //                (fx 2 -> 2x2 som i det gamle flow). Standard: alle i en raekke.
  //   kpi_size:    tallenes stoerrelse (standard 26pt).
  //   kpi_labels:  false skjuler navnet under tallet (tegnforklaringen
  //                forklarer farverne).
  //   legend_rows: raekker i tegnforklaringen, fyldt kolonnevis. Standard:
  //                en kolonne op til 3 punkter, ellers to kolonner.
  //   legend_label_width: tegnforklaringens tekster ombrydes ved denne bredde.
  // KPI-gitter og tegnforklaring har samme hoejde; raekkerne fordeles jaevnt.
  let bottom-panel-height = 31.5mm
  let bottom-panel = if (not spc_panel and figure_panel != none and
      figure_panel.at("placement", default: "side") == "bottom") {
    let kpis = figure_panel.at("kpis", default: none)
    let legend = figure_panel.at("legend", default: none)
    let body-height = bottom-panel-height - 6mm
    // Kolonnevis fyldning: element i (0-baseret) i kolonne floor(i / rows)
    let column-major(items, rows) = {
      let ncol = calc.ceil(items.len() / rows)
      let cells = ()
      for r in range(rows) {
        for c in range(ncol) {
          let i = c * rows + r
          cells.push(if i < items.len() { items.at(i) } else { [] })
        }
      }
      (ncol, cells)
    }
    let cols = ()
    let cells = ()
    if kpis != none and kpis.len() > 0 {
      let kpi-size = figure_panel.at("kpi_size", default: 26pt)
      let kpi-cols = figure_panel.at("kpi_columns", default: kpis.len())
      let kpi-rows = calc.ceil(kpis.len() / kpi-cols)
      let kpi-labels = figure_panel.at("kpi_labels", default: true)
      let kpi-cell(k) = {
        let tal = text(fill: rgb(k.at("color", default: "888888")),
                       weight: "extrabold", size: kpi-size, str(k.value))
        if not kpi-labels { align(horizon, tal) } else {
          block(width: calc.max(34mm, kpi-size * 3.6), stack(dir: ttb, spacing: 1.4mm, tal,
            text(fill: rgb("666666"), size: 7.5pt, k.label)))
        }
      }
      let (ncol, kcells) = column-major(kpis.map(kpi-cell), kpi-rows)
      cols.push(auto)
      cells.push({
        let kpi-title = figure_panel.at("kpi_title", default: none)
        block(below: 2mm, panel-heading(if kpi-title != none { kpi-title } else { "" }))
        block(height: body-height, grid(
          columns: ncol,
          rows: if kpi-rows > 1 { (1fr,) * kpi-rows } else { auto },
          column-gutter: 6mm,
          ..kcells))
      })
    }
    if legend != none and legend.len() > 0 {
      let rows = figure_panel.at("legend_rows",
        default: if legend.len() > 3 { calc.ceil(legend.len() / 2) } else { legend.len() })
      let label-width = figure_panel.at("legend_label_width", default: none)
      let item-cell(item) = grid(
        columns: (auto, auto),
        column-gutter: 2mm,
        align: (horizon, horizon),
        legend-key(item),
        {
          let t = text(fill: rgb("666666"), size: 8pt, item.label)
          // Maksimal bredde: korte tekster beholder deres egen bredde
          if label-width == none { t } else {
            context if measure(t).width > label-width { block(width: label-width, t) } else { t }
          }
        })
      let (ncol, lcells) = column-major(legend.map(item-cell), rows)
      cols.push(auto)
      cells.push({
        block(below: 2mm,
          panel-heading(figure_panel.at("legend_title", default: "Tegnforklaring")))
        block(height: body-height, grid(
          columns: ncol,
          rows: (1fr,) * rows,
          column-gutter: 5mm,
          align: horizon,
          ..lcells))
      })
    }
    if data_definition != none {
      cols.push(1fr)
      cells.push(definition-block(bottom-panel-height - 5mm,
        sizes: (9pt, 8.5pt, 8pt, 7.5pt, 7pt)))
    }
    block(above: 3.3mm, height: bottom-panel-height, width: 100%,
      grid(columns: cols, column-gutter: 8mm, ..cells))
  } else { none }

  // Left column of the chart row: details line, chart and footer. Hoisted so the
  // same content object is used in both layouts (spc_panel true/false).
  let chart-column = block(inset: (left: 26.4mm, top: if drop-analysis { 6.6mm } else { 2mm }, right: 6.6mm, bottom: 0mm),
      width: 100%,
      //fill: rgb("ccebfa"), //Blå baggrundsfarve - husk at fjerne
          block(inset: (0mm),
          text(fill: rgb("888888"),
               //weight: "light",
               size: 9pt,
               upper(details))) +

          text(
               chart
             ) +

          // Figure bottom panel (none unless figure_panel.placement = "bottom")
          (if bottom-panel != none { bottom-panel } else { [] }) +

          // Production date and footer content below chart
          v(1fr) +
          grid(
            columns: (1fr, 1fr),
            align: bottom,
            align(left, text(fill: rgb("888888"), size: 6pt, [
              PRODUCERET: #datetime.today().display("[day] [month repr:short] [year]")
              #if author != none { [ · #author] }
            ])),
            align(right, if footer_content != none { text(fill: rgb("888888"), size: 6pt, upper(footer_content)) })
          )

        )


  // Right column in figure mode (spc_panel: false + figure_panel): key
  // figures, colour legend and data definition. Same inset and width as the
  // SPC column, so figure pages line up with SPC pages in batch reports.
  let figure-column = if (figure_panel != none and
      figure_panel.at("placement", default: "side") != "bottom") {
    let kpis = figure_panel.at("kpis", default: none)
    let legend = figure_panel.at("legend", default: none)
    // definition_first: datadefinitionen oeverst i naturlig hoejde, derefter
    // noegletal og tegnforklaring
    let definition-first = figure_panel.at("definition_first", default: false)
    block(inset: (left: 0mm, top: if drop-analysis { 6.6mm } else { 2mm }, right: 6.6mm),
      width: 100%, {
        if definition-first and data_definition != none {
          block(below: 0mm, definition-natural)
          v(4mm)
        }
        if kpis != none and kpis.len() > 0 {
          let kpi-title = figure_panel.at("kpi_title", default: none)
          if kpi-title != none { block(below: 2mm, panel-heading(kpi-title)) }
          grid(
            columns: (auto, 1fr),
            column-gutter: 3.3mm,
            row-gutter: 1.5mm,
            align: (right + horizon, left + horizon),
            ..kpis.map(k => (
              text(fill: rgb(k.at("color", default: "888888")),
                   weight: "extrabold", size: 28pt, str(k.value)),
              text(fill: rgb("888888"), size: 9pt, upper(k.label)),
            )).flatten()
          )
          v(4mm)
        }
        if legend != none and legend.len() > 0 {
          // legend_title: "" udelader overskriften
          let legend-title = figure_panel.at("legend_title", default: "Tegnforklaring")
          if legend-title != "" { block(below: 1.5mm, panel-heading(legend-title)) }
          let forrige = none
          for item in legend {
            let gruppe = item.at("group", default: none)
            if gruppe != none and gruppe != forrige {
              block(above: 2mm, below: 1mm,
                text(fill: rgb("888888"), weight: "bold", size: 8pt, gruppe))
              forrige = gruppe
            }
            block(above: 0.8mm, below: 0.8mm,
              grid(
                columns: (if item.at("key", default: "box") == "line" { 6mm } else { 3.3mm }, 1fr),
                column-gutter: 2mm,
                align: (horizon, horizon),
                legend-key(item),
                text(fill: rgb("666666"), size: 8pt, item.label),
              ))
          }
          v(4mm)
        }
        if not definition-first and data_definition != none {
          definition-block(figure_panel.at("definition_height", default: 39.6mm))
        }
      })
  } else { none }

  let analysis-cell = grid.cell(
  fill: rgb("ffffff"),
        if analysis != none {
          block(inset: (left: 26.4mm, top: 6.6mm, right: 6.6mm, bottom: 0mm),
          par(
            //leading: .6em,
          text(
               size: 15pt,
               //font: ("Mari Book", "Roboto", "Arial", "Helvetica", "sans-serif"),
          analysis)
          )
        )
        }
      )

    grid(
      //rows: (51.33mm, 22.66mm, 1fr),
      //rows: (59.4mm, 22.1mm, 1fr),
      rows: if drop-analysis { (52.8mm, 1fr) } else { (52.8mm, 26.4mm, 1fr) },
        block(
          //fill: rgb("DCF1FC"),
          fill: rgb("007dbb"),
          inset: (left: 26.4mm, rest: 6.6mm),
          height: 100%,
          width: 100%,
          align(top,
            par(
              //leading: 0.65em,
              [#text(
                rgb("fff"),
                font: ("Mari", "Roboto", "Arial", "Helvetica", "sans-serif"),
                weight: "bold",
                size: 13pt,
                hospital ) \
                #text(
                  font: ("Mari", "Roboto", "Arial", "Helvetica", "sans-serif"),
                  weight: "bold",
                  size: 13pt,
                  rgb("fff"),
                  department
                )]        )
            ) +
          align(bottom,
            context {
              // Auto-skalér titel-font så hver linje passer på én linje
              // Titlen har typisk 2 linjer (datasæt + indikator) adskilt af linebreak
              // Strategi: mål en reference med præcis 2 linjer ved samme font-størrelse
              // og sammenlign med titlens faktiske højde
              let title-area-width = 264mm  // A4 landscape (297mm) minus venstre/højre insets (33mm i alt)
              let max-size = 38pt
              let min-size = 24pt
              let step = 2pt
              let leading = 0.15em
              // 1.05 giver 5% tolerance for Typst-målestøj (sub-pixel afrunding)
              let height-tolerance = 1.05

              // Brug find() i stedet for while-løkke med mutablevariabel —
              // while+mutation er upålidelig inde i context{}-blokke i Typst
              let n-steps = int((max-size - min-size) / step)
              let sizes = range(0, n-steps + 1).map(i => max-size - i * step)
              let fits = sizes.find(s => {
                let actual = measure(block(width: title-area-width, par(leading: leading, {
                  set text(size: s)
                  title
                })))
                // Reference: 2 linjer hvor første er fed (matcher titelstruktur:
                // linje 1 = #strong[register-navn], linje 2 = indikator-navn)
                let ref = measure(block(width: title-area-width, par(leading: leading, {
                  set text(size: s)
                  [#strong[X]\ X]
                })))
                actual.height <= ref.height * height-tolerance
              })
              let final-size = if fits == none { min-size } else { fits }

              par(leading: leading, {
                set text(rgb("fff"), size: final-size)
                title
              })
            }
          ) 
        
      ),

  ..if drop-analysis { () } else { (analysis-cell,) },


grid.cell(
    fill: rgb("ffffff"),
    if spc_panel {
    grid(
      rows: (auto),
      columns: (auto, 72.6mm),
      chart-column,
      block(inset: (left: 0mm, top: 2mm, right: 6.6mm),
      //fill: rgb("ccebfa"),
      width: 100%,
      //height: 100%, */
       [
         #text(fill: rgb("888888"),
                 weight: "bold",
                 size: 9pt,
                 upper([Statistisk Proceskontrol (SPC)]))

         // SPC Statistics Table - only show if at least one statistic is provided
         #if (runs_expected != none or runs_actual != none or
            crossings_expected != none or crossings_actual != none or
            outliers_expected != none or outliers_actual != none) {

           // Fixed cell dimensions for consistent alignment
           let cell-width = 13.2mm
           let cell-height = 9.9mm
           let cell-inset = 0mm
           let label-width = 33mm

           // Helper function for signal cell (grey background, white text)
           let signal-cell(content) = {
             box(
               fill: rgb("888888"),
               width: cell-width,
               height: cell-height,
               inset: cell-inset,
               radius: 0pt,
               align(center + horizon, text(fill: white, weight: "extrabold", size: 28pt, content))
             )
           }

           // Helper function for normal cell (same dimensions, no background)
           let normal-cell(content) = {
             box(
               width: cell-width,
               height: cell-height,
               inset: cell-inset,
               align(center + horizon, text(fill: rgb("888888"), weight: "extrabold", size: 28pt, content))
             )
           }

           // Helper function for label cell (first column, left-aligned)
           let label-cell(content) = {
             box(
               width: label-width,
               height: cell-height,
               inset: cell-inset,
               align(left + horizon, text(fill: rgb("888888"), size: 9pt, weight: "regular", content))
             )
           }

           // Check for signal conditions
           let runs_signal = (runs_expected != none and runs_actual != none and runs_actual > runs_expected)
           let crossings_signal = (crossings_expected != none and crossings_actual != none and crossings_actual < crossings_expected)
           let outliers_signal = (outliers_actual != none and outliers_actual > 0)

           table(
             columns: (33mm, 13.2mm, 13.2mm),
             column-gutter: 3.3mm,
             stroke: 0mm,
             inset: (0mm),
             table.header(
               [],
               pad(bottom: 1mm, align(center)[FORVENTET]),
               pad(bottom: 1mm, align(center)[FAKTISK]),
             ),
             // Row 1: SERIELÆNGDE
             [#label-cell[SERIELÆNGDE (MAKSIMUM)]],
             [#if runs_expected != none {normal-cell(str(runs_expected))} else {[-]}],
             [#if runs_actual != none {
               if runs_signal {
                 signal-cell(str(runs_actual))
               } else {
                 normal-cell(str(runs_actual))
               }
             } else {[-]}],
             // Row 2: ANTAL KRYDS
             [#label-cell[ANTAL KRYDS \ (MINIMUM)]],
             [#if crossings_expected != none {normal-cell(str(crossings_expected))} else {[-]}],
             [#if crossings_actual != none {
               if crossings_signal {
                 signal-cell(str(crossings_actual))
               } else {
                 normal-cell(str(crossings_actual))
               }
             } else {[-]}],
             // Row 3: OBS. UDEN FOR KONTROLGRÆNSE (only for non-run charts)
             ..if not is_run_chart {(
               [#label-cell[OBS. UDEN FOR KONTROLGRÆNSE]],
               [#if outliers_expected != none {normal-cell(str(outliers_expected))} else {[-]}],
               [#if outliers_actual != none {
                 if outliers_signal {
                   signal-cell(str(outliers_actual))
                 } else {
                   normal-cell(str(outliers_actual))
                 }
               } else {[-]}],
             )},
           )
         }
         // Centerline-caveat (italic, grey, smaller font). Rendered when
         // bfh_qic() either received a non-NULL cl argument
         // (cl_user_supplied=true) OR auto-switched a run-chart's
         // centerline from median to mean (cl_auto_mean=true). Flags are
         // mutually exclusive. See ADR-003 (warning-blind clinical readers).
         #if cl_user_supplied or cl_auto_mean {
           block(width: 100%, inset: (top: 2mm),
             text(fill: rgb("888888"), size: 9pt, style: "italic",
               if cl_caveat_text != none {
                 cl_caveat_text
               } else if cl_auto_mean {
                 "Niveaulinje skiftet til gennemsnit"
               } else {
                 "Centerlinje fastsat manuelt"
               }
             )
           )
         }
         // Data definition - cascade-rendering:
         //   1) Forsøg 9pt -> 8.5pt -> 8pt med tæt leading + hyphenation
         //   2) Vælg største font hvor indholdet passer i 52.8mm
         //   3) Hvis selv 8pt overflower, render ved 8pt + clip + ellipsis
         // Newlines i input splittes til separate paragraffer.
         #if data_definition != none {
           definition-block(52.8mm)
         }
       ]



)

    )
    } else if figure-column != none {
      // Figure mode with side panel: figure + key figures/legend/definition
      grid(
        rows: (auto),
        columns: (auto, 72.6mm),
        chart-column,
        figure-column
      )
    } else {
      // Full-width figure mode: no SPC column, chart fills the row
      chart-column
    }
  )
)

}
