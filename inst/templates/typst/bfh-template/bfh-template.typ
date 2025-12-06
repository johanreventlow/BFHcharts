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
  if it.x == 0 {
    set text(fill: rgb("888888"), size: 9pt, weight: "regular")
    pad(top: 2mm, bottom: 2mm, it)
  } else if it.y == 0 {
    set text(fill: rgb("888888"), size: 9pt, weight: "regular")
    set align(center)
    it
  } else {
    set align(center)
    set text(fill: rgb("888888"), 
    weight: "extrabold",
    size: 28pt)
    pad(2mm, it)
  }
}
 

  set page(
    "a4",
    flipped: true,
    margin: (4.67mm),
    fill: rgb("ffff00"),  // Gul baggrundsfarve for at visualisere margins
    foreground: (
       place(
         image("images/Hospital_Maerke_RGB_A1_str.png", 
         height: 14mm
       ), 
       //dy: 28mm,
       //dy: 32.67mm,
       //dy: 37.33mm, 
       dy: 46.7mm,
       dx: 4.6mm)
     )
  )

    grid(
      rows: (51.33mm, 25mm, auto, auto),
      columns: (4.67mm, auto),
        block(
          
          //fill: rgb("e5f2f8"),
          //fill: rgb("ccebfa"),
          //fill: rgb("4db9ef"),
          //fill: rgb("ffffff"),
          //fill: rgb("DCF1FC"),
          //fill: rgb("99D7F6"),
          //fill: rgb("007dbb"),
          height: 100%,
          width: 100%
        ),
  
        block(
          //fill: rgb("DCF1FC"),
          fill: rgb("007dbb"),
          inset: (left: 14mm, rest: 4.67mm),
          height: 100%,
          width: 100%,
          align(top,
            par(
              leading: 0.65em,
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
              leading: 0.4em,
                text(rgb("fff"), 
                size: 38pt,
                title
                )
              )
            ) 
        
      ),

  grid.cell(
  fill: rgb("ffffff"),
    colspan: 2,
        if analysis != none {
          block(inset: (left: 18.67mm, top: 4.67mm, rest: 0mm),
          text(
               size: 15pt,
          analysis)
          )
        }
      ),


grid.cell(
    fill: rgb("ffffff"),
    colspan: 2,
    grid(
      rows: (auto),
      columns: (auto, 62mm),
      block(inset: (left: 18.67mm, top: 4.67mm, right: 4.67mm, 
      bottom: 0mm),
      width: 100%,
      //fill: rgb("ccebfa"), //Blå baggrundsfarve - husk at fjerne
          block(inset: (0mm),
          text(fill: rgb("888888"),
               //weight: "light",
               size: 9pt,
               upper(details))) +
          
          text(
               size: 11pt,
               chart
             )
        ),
      block(inset: (left: 0mm, top: 4.67mm, right: 0mm),
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

           // Helper function for signal cell (grey background, white text)
           let signal-cell(content) = {
             box(
               fill: rgb("888888"),
               inset: 2mm,
               radius: 2pt,
               text(fill: white, weight: "extrabold", size: 28pt, content)
             )
           }

           // Helper function for normal cell
           let normal-cell(content) = {
             text(fill: rgb("888888"), weight: "extrabold", size: 28pt, content)
           }

           // Check for signal conditions
           let runs_signal = (runs_expected != none and runs_actual != none and runs_actual > runs_expected)
           let crossings_signal = (crossings_expected != none and crossings_actual != none and crossings_actual < crossings_expected)
           let outliers_signal = (outliers_actual != none and outliers_actual > 0)

           table(
             columns: (27mm, 18mm, 18mm),
             stroke: none,
             inset: (0mm),
             table.header(
               [],
               [FORVENTET],
               [FAKTISK],
             ),
             // Row 1: SERIELÆNGDE
             [SERIELÆNGDE (MAKSIMUM)],
             [#if runs_expected != none {str(runs_expected)} else {[-]}],
             [#if runs_actual != none {
               if runs_signal {
                 signal-cell(str(runs_actual))
               } else {
                 normal-cell(str(runs_actual))
               }
             } else {[-]}],
             // Row 2: ANTAL KRYDS
             [ANTAL KRYDS (MINIMUM)],
             [#if crossings_expected != none {str(crossings_expected)} else {[-]}],
             [#if crossings_actual != none {
               if crossings_signal {
                 signal-cell(str(crossings_actual))
               } else {
                 normal-cell(str(crossings_actual))
               }
             } else {[-]}],
             // Row 3: OBS. UDEN FOR KONTROLGRÆNSE (only for non-run charts)
             ..if not is_run_chart {(
               [OBS. UDEN FOR KONTROLGRÆNSE],
               [#if outliers_expected != none {str(outliers_expected)} else {[-]}],
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
           text(fill: rgb("888888"),
                    size: 9pt,
                    data_definition)
         }
       ]



)

    )
  ),

  // Footer content section - only show if provided
  grid.cell(
    fill: rgb("ffffff"),
    colspan: 2,
    if footer_content != none {
      block(inset: (left: 18.67mm, top: 4.67mm, right: 4.67mm, bottom: 4.67mm),
        text(
          fill: rgb("888888"),
          size: 9pt,
          footer_content
        )
      )
    }
  )
)

}
