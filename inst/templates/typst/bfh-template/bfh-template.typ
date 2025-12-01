/*#let bfh-short(
  author : none,
  date : datetime.today(),
  doc
) = {
  set text(font: "Arial", 
           lang: "da")
  

  set par(justify: true)
  set text(hyphenate: false)
  set heading(numbering: "1.")
  show heading.where(level: 1): it => [
    #set text(24pt)
    #(it.body)
      ]
  show heading.where(level: 2): it => [
    #counter(heading).display() #(it.body)

      ]
    
  set page(
    "a4",
    margin: (top: 42mm, left: 25mm),
    header-ascent: 0.71cm,
    header: [
      #place(left, image("Logo_Bispebjerg_og Frederiksberg_RGB.png", height: 15mm), dy: 12mm)
      #place(right + bottom)[
        #author\
        #if type(date) == datetime [
          #date.display("[day]/[month]/[year]")
        ] else [
          #date
        ]
      ]
    ],
    footer: [
      #place(
        right,
        dy: -0.6cm,
        dx: 1.9cm,
        //image("footer.png")
      )
      #place(
        right,
        dx: 1.55cm,
        dy: 0.58cm,
        text(fill: white, weight: "bold", counter(page).display())
      )
    ]
  )

  doc
}



#let bfh-diagram(
  author : none,
  date : datetime.today(),
  doc
) = {
  set text(font: "Mari", 
           lang: "da",
           //fill: rgb("fdfdfd")
         )
  
  set page(
    "a4",
    flipped: true,
    margin: (5mm),
    header: [
      #place(left, 
      image("images/Logo_Bispebjerg_og Frederiksberg_RGB.png", 
      //image("Logo_Bispebjerg_png.png", 
      height: 14mm,
    ), dy: 18.67mm, dx: 4.67mm)
    ]
  )

    grid(
    rows: (23.33mm, 50mm, auto),
    columns: 100%,
    //gutter: 1em,
    block(
      height: 100%,
      width: 100%
    ),

    block(
      fill: rgb("007dbb"),
      inset: (left: 3.3mm, rest: 5mm),
      //lorem(100),
      height: 100%,
      width: 100%,
      text(rgb("ffffff"), 
      font: "Mari",
      size: 55pt
    )[
  Medicinsikkert Hospital \
  Medicin scannet ved dispensering
]
      ),
    /*block(
      inset: 14pt
    )[
      //#set par(leading: 3mm)
      //#lorem(500)
]*/
    grid(
      columns: (3fr, 1fr),
      gutter: 14pt,

    block(
      fill: rgb("e4e5ea"),
      height: auto,
      width: 100%,
      inset: (left: 4mm, rest: 5mm)
      
    )[
      #lorem(300)
    ],

        block(
      fill: rgb("e4e5ea"),
      height: 300pt,
      width: 100%,
      inset: 14pt
    )[
      #lorem(50)
    ],
    )
    
  )

  //doc
}
*/

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
//   chart: Chart content (image or other content) (required via content parameter)
//
#let bfh-diagram2(
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
  chart
) = {
  set text(font: "Mari",
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
      rows: (51.33mm, auto),
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
                font: "Arial",
                size: 13pt,
                //weight: "bold", 
                hospital ) \
                #text(
                  font: "Arial",
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
    colspan: 2,
    grid(
      rows: (auto),
      columns: (auto, 62mm),
      block(inset: (left: 18.67mm, top: 4.67mm, right: 4.67mm, 
      bottom: 0mm),
      width: 100%,
      //fill: rgb("ccebfa"),
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
           table(
             columns: (27mm, 18mm, 18mm),
             stroke: none,
             inset: (0mm),
             table.header(
               [],
               [FORVENTET],
               [FAKTISK],
             ),
             [SERIELÆNGDE (MAKSIMUM)],
             [#if runs_expected != none {str(runs_expected)} else {[-]}],
             [#if runs_actual != none {str(runs_actual)} else {[-]}],
             [ANTAL KRYDS (MINIMUM)],
             [#if crossings_expected != none {str(crossings_expected)} else {[-]}],
             [#if crossings_actual != none {str(crossings_actual)} else {[-]}],
             [OBS. UDEN FOR KONTROLGRÆNSE],
             [#if outliers_expected != none {str(outliers_expected)} else {[-]}],
             [#if outliers_actual != none {str(outliers_actual)} else {[-]}],
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
  )
)
      
}

   /*grid(
      rows: (51.33mm, auto),
      columns: (4.67mm, auto),*/