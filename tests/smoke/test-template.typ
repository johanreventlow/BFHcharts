// CI-only smoke test template for BFHcharts
//
// Formål:
//   Validerer at BFHcharts → Typst pipeline (R → SVG → .typ → PDF) fungerer
//   end-to-end på CI-kørere uden proprietære fonts (Mari, Arial).
//   Bruger kun DejaVu Sans (universal open font tilgængelig via apt-get på Ubuntu).
//
// VIGTIGT: Denne template er IKKE production-template.
//   - Ingen hospital-logo (images/ kopieres ikke ved custom template_path)
//   - Ingen Mari-fonts
//   - Bruger kun set text(font: "DejaVu Sans") — fallback til sans-serif
//   - Visuel korrekthed verificeres IKKE her (håndteres af vdiffr + lokal review)
//
// Parameternavne matcher PRÆCIS bfh-template.typ (bfh-diagram funktion).
// build_typst_content() i R/utils_typst.R genererer kald til #show: bfh-diagram.with(...)
// Typst fejler ved ukendte named-params — alle params skal accepteres.
//
// Kilde: openspec/changes/enable-ci-safe-pdf-smoke-render (Strategi B)

#let bfh-diagram(
  hospital: "Bispebjerg og Frederiksberg Hospital",
  department: none,
  title: [SPC Diagram],
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
  set text(font: ("DejaVu Sans", "sans-serif"), lang: "da")

  set page(
    "a4",
    flipped: true,
    margin: (top: 10mm, bottom: 10mm, left: 15mm, right: 15mm),
  )

  // Header: hospital + department
  block(
    width: 100%,
    below: 4mm,
    {
      set text(size: 14pt, weight: "bold")
      hospital
      if department != none {
        linebreak()
        text(size: 11pt, weight: "regular", department)
      }
    }
  )

  // Title
  block(
    width: 100%,
    below: 4mm,
    {
      set text(size: 16pt, weight: "bold")
      title
    }
  )

  // Analysis text (if provided)
  if analysis != none {
    block(
      width: 100%,
      below: 4mm,
      text(size: 11pt, analysis)
    )
  }

  // Details (period, averages etc.)
  if details != none {
    block(
      width: 100%,
      below: 4mm,
      text(size: 9pt, fill: rgb("888888"), details)
    )
  }

  // Chart image (positional body parameter)
  block(
    width: 100%,
    below: 4mm,
    chart
  )

  // Minimal SPC stats summary (only if at least one value provided)
  if (runs_expected != none or runs_actual != none or
      crossings_expected != none or crossings_actual != none or
      outliers_expected != none or outliers_actual != none) {
    block(
      width: 100%,
      below: 2mm,
      {
        set text(size: 9pt, fill: rgb("888888"))
        [*SPC:* ]
        if runs_expected != none or runs_actual != none {
          [Serielængde: forventet=#if runs_expected != none {str(runs_expected)} else {[-]}, faktisk=#if runs_actual != none {str(runs_actual)} else {[-]} ]
        }
        if crossings_expected != none or crossings_actual != none {
          [Kryds: forventet=#if crossings_expected != none {str(crossings_expected)} else {[-]}, faktisk=#if crossings_actual != none {str(crossings_actual)} else {[-]} ]
        }
        if not is_run_chart and (outliers_expected != none or outliers_actual != none) {
          [Outliers: forventet=#if outliers_expected != none {str(outliers_expected)} else {[-]}, faktisk=#if outliers_actual != none {str(outliers_actual)} else {[-]}]
        }
      }
    )
  }

  // Footer
  block(
    width: 100%,
    {
      set text(size: 7pt, fill: rgb("aaaaaa"))
      [CI smoke render — ]
      date.display("[day].[month].[year]")
      if author != none { [ · #author] }
      if footer_content != none { [ · #footer_content] }
      [ · (test-template.typ — ikke production)]
    }
  )

  // Data definition (if provided)
  if data_definition != none {
    block(
      width: 100%,
      {
        set text(size: 8pt, fill: rgb("aaaaaa"))
        [*Datadefinition:* #data_definition]
      }
    )
  }
}
