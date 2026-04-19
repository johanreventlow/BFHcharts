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
//   footer_content: Additional content to display below the chart (optional)
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
  footer_content: none,
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
    foreground: (
       place(
         image("images/Hospital_Maerke_RGB_A1_str.png",
         height: 19.8mm
       ),
       //dy: 46.2mm,
       dy: 39.6mm,
       //dy: 59.43mm, 
       //dy: 66mm,
       //dy: 170.4mm,
       //dy: 177mm,
       dx: 0mm)
       //dx: 4.67mm)
     )
  )

    grid(
      //rows: (51.33mm, 22.66mm, 1fr),
      //rows: (59.4mm, 22.1mm, 1fr),
      rows: (52.8mm, 26.4mm, 1fr),
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

  grid.cell(
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
      ),


grid.cell(
    fill: rgb("ffffff"),
    grid(
      rows: (auto),
      columns: (auto, 72.6mm),
      block(inset: (left: 26.4mm, top: 2mm, right: 6.6mm, bottom: 0mm),
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

          // Production date and footer content below chart
          v(1fr) +
          grid(
            columns: (1fr, 1fr),
            align: bottom,
            align(left, text(fill: rgb("888888"), size: 6pt, upper[PRODUCERET: #datetime.today().display("[day] [month repr:short] [year]")])),
            align(right, if footer_content != none { text(fill: rgb("888888"), size: 6pt, upper(footer_content)) })
          )

        ),
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
         // Data definition - clip til max højde, "..." ved overflow
         #if data_definition != none {
           text(fill: rgb("888888"),
                    weight: "bold",
                    size: 9pt,
                    upper([Datadefinition]))
           linebreak()
           block(
             height: 52.8mm,
             width: 100%,
             clip: true,
             {
               par(justify: true,
                 text(fill: rgb("888888"), size: 9pt, data_definition)
               )
               place(bottom + left,
                 block(width: 100%, fill: white,
                   text(fill: rgb("888888"), size: 9pt, "..."))
               )
             }
           )
         }
       ]



)

    )
  )
)

}
