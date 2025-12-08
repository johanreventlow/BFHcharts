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
  title: "Paper Title",
  analysis: none,
  details: none,
  author: none,
  date: datetime.today(),
  data_definition: lorem(75),
  runs_expected: 7,
  runs_actual: 8,
  crossings_expected: 15,
  crossings_actual: 10,
  outliers_expected: 0,
  outliers_actual: 0,
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
       //dy: 32.67mm,
       //dy: 37.33mm, 
       //dy: 66mm,
       dy: 170.4mm,
       //dy: 177mm,
       dx: 0mm)
       //dx: 4.67mm)
     )
  )

    grid(
      //rows: (51.33mm, 22.66mm, 1fr),
      rows: (59.4mm, 22.1mm, 1fr),
      //rows: (52.8mm, 26.4mm, 1fr),
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
                size: 13pt,
                //weight: "bold",
                hospital ) \
                #text(
                  font: ("Mari", "Roboto", "Arial", "Helvetica", "sans-serif"),
                  //weight: "bold",
                  size: 13pt,
                  rgb("fff"),
                  department
                )]        )
            ) +
          align(bottom,
            par(
              leading: 0.5em,
                text(rgb("fff"), 
                size: 38pt,
                title
                )
              )
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
      block(inset: (left: 26.4mm, top: 6.6mm, right: 6.6mm, bottom: 0mm),
      width: 100%,
      //fill: rgb("ccebfa"), //Blå baggrundsfarve - husk at fjerne
          block(inset: (0mm),
          text(fill: rgb("888888"),
               //weight: "light",
               size: 9pt,
               upper(details))) +
          
          text(
               chart
             ) 
             
        ),
      block(inset: (left: 0mm, top: 6.6mm, right: 6.6mm),
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
             [#label-cell[ANTAL KRYDS (MINIMUM)]],
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
           v(2mm)
         }
         // Data definition section - only show if provided
         #if data_definition != none {
           text(fill: rgb("888888"),
                    weight: "bold",
                    size: 9pt,
                    upper([Datadefinition]))
           linebreak()
           par(justify: true,
           text(fill: rgb("888888"),
                    size: 9pt,
                    data_definition)
                  )
         }

         // Footer content and production date - placed at bottom of this column
         #v(1fr)  // Push to bottom
         #align(right)[
           #text(fill: rgb("888888"), size: 6pt)[
             #if footer_content != none {
               upper(footer_content)
               linebreak()
             }
             #upper[PRODUCERET: #datetime.today().display("[day] [month repr:short] [year]")]
           ]
         ]
       ]



)

    )
  )
)

}