# ============================================================================
# TESTS FOR FIGURE PDF EXPORT (add-figure-pdf-export)
#
# Spec: pdf-export + batch-pdf-export (full-width figure layout,
# bfh_export_figure_pdf(), bfh_stage_figure_page()). Tests der ikke kraever
# Quarto mocker Typst-compileren; render-gatede tests ligger i
# test-production-template-renders.R og test-export-batch-render.R.
# ============================================================================

# ---- 1. Forudsaetninger -----------------------------------------------------

test_that("PDF_IMAGE_WIDTH_FULL_MM udleder fuld kolonnebredde (297 - 26.4 - 6.6)", {
  expect_equal(BFHcharts:::PDF_IMAGE_WIDTH_FULL_MM, 297 - 26.4 - 6.6)
  expect_equal(BFHcharts:::PDF_IMAGE_WIDTH_FULL_MM, 264)
  # Haejde er uaendret: kun bredden aendres i fuld-bredde-tilstand
  expect_equal(BFHcharts:::PDF_IMAGE_HEIGHT_MM, 109)
})

test_that("bfh_merge_metadata() er uaendret og filtrerer spc_panel fra", {
  merged <- bfh_merge_metadata(list(spc_panel = FALSE), chart_title = "T")

  expect_setequal(
    names(merged),
    c(
      "hospital", "department", "title", "analysis", "details", "author",
      "date", "data_definition", "footer_content", "logo_path"
    )
  )
  expect_length(merged, 10L)
  expect_null(merged$spc_panel)
  expect_false("spc_panel" %in% names(merged))
})

# ---- 3. Parameter-builder ---------------------------------------------------

test_that("build_typst_page_params() emitterer spc_panel: false kun naar FALSE", {
  spc_stats <- list(runs_expected = 7, runs_actual = 5, is_run_chart = FALSE)
  base_md <- list(hospital = "H", title = "T")

  params_false <- BFHcharts:::build_typst_page_params(
    c(base_md, list(spc_panel = FALSE)), spc_stats
  )
  expect_match(params_false, "spc_panel: false", fixed = TRUE)

  # TRUE og NULL: ingen spc_panel-param, output byte-identisk med foer
  baseline <- BFHcharts:::build_typst_page_params(base_md, spc_stats)
  params_true <- BFHcharts:::build_typst_page_params(
    c(base_md, list(spc_panel = TRUE)), spc_stats
  )
  expect_false(grepl("spc_panel", baseline, fixed = TRUE))
  expect_identical(params_true, baseline)
})

test_that("build_typst_page_params() ignorerer ikke-logiske spc_panel-vaerdier", {
  for (bad in list("false", 0, NA, c(FALSE, FALSE))) {
    params <- BFHcharts:::build_typst_page_params(
      list(title = "T", spc_panel = bad), list()
    )
    expect_false(grepl("spc_panel", params, fixed = TRUE))
  }
})

# ---- helpers for bfh_export_figure_pdf() ------------------------------------

fixture_figure <- function() {
  ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point()
}

# Mock Quarto + Typst-compile. Captures the generated .typ document and the
# chart SVG root tag from the workspace before it is cleaned up.
local_figure_compile_mock <- function(env = parent.frame()) {
  captured <- new.env(parent = emptyenv())
  captured$calls <- 0L
  captured$typ <- NULL
  captured$svg_root <- NULL
  testthat::local_mocked_bindings(
    bfh_compile_typst = function(typst_file, output, ...) {
      captured$calls <- captured$calls + 1L
      captured$typ <- readLines(typst_file, warn = FALSE)
      svg <- list.files(
        dirname(typst_file),
        pattern = "^chart-.*\\.svg$", full.names = TRUE
      )
      captured$svg_root <- grep("<svg", readLines(svg[1], warn = FALSE),
        value = TRUE
      )[1]
      writeLines("%PDF-fake", output)
      invisible(output)
    },
    quarto_available = function(...) TRUE,
    .package = "BFHcharts",
    .env = env
  )
  captured
}

# svglite skriver dimensioner i pt: konverter til mm (25.4 / 72).
svg_size_mm <- function(svg_root) {
  grab <- function(attr) {
    as.numeric(sub(
      paste0(".*", attr, "='([0-9.]+)pt'.*"), "\\1", svg_root
    )) * 25.4 / 72
  }
  c(width = grab("width"), height = grab("height"))
}

# ---- 5.1 Input-validering ---------------------------------------------------

test_that("bfh_export_figure_pdf() afviser ikke-ggplot med klassificeret fejl", {
  out <- withr::local_tempfile(fileext = ".pdf")
  for (bad in list(data.frame(), NULL, "plot", list(), 1)) {
    expect_error(
      bfh_export_figure_pdf(bad, out, metadata = list(title = "x")),
      "plot",
      class = "bfhcharts_export_error"
    )
  }
  expect_false(file.exists(out))
})

test_that("bfh_export_figure_pdf() afviser sammensatte (patchwork) plots", {
  # patchwork arver ggplot; konstruér klassen manuelt saa testen ikke
  # kraever patchwork som afhaengighed
  composite <- fixture_figure()
  class(composite) <- c("patchwork", class(composite))
  out <- withr::local_tempfile(fileext = ".pdf")

  expect_error(
    bfh_export_figure_pdf(composite, out, metadata = list(title = "x")),
    "composite plots are not supported",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_export_figure_pdf(composite, out, metadata = list(title = "x")),
    "plot",
    class = "bfhcharts_export_error"
  )
  expect_false(file.exists(out))
})

test_that("bfh_export_figure_pdf() kraever gyldig metadata$title", {
  mock <- local_figure_compile_mock()
  out <- withr::local_tempfile(fileext = ".pdf")
  p <- fixture_figure()

  bad_metadata <- list(
    list(), # mangler
    list(title = ""),
    list(title = "   "),
    list(title = NA_character_),
    list(title = c("a", "b")),
    list(title = 42),
    list(title = NULL)
  )
  for (md in bad_metadata) {
    expect_error(
      bfh_export_figure_pdf(p, out, metadata = md),
      "title",
      class = "bfhcharts_export_error"
    )
  }
  # Ingen Typst-compile er startet og ingen fil skrevet
  expect_identical(mock$calls, 0L)
  expect_false(file.exists(out))
})

test_that("bfh_export_figure_pdf() kraever metadata som liste", {
  local_figure_compile_mock()
  expect_error(
    bfh_export_figure_pdf(fixture_figure(), tempfile(fileext = ".pdf"),
      metadata = "titel"
    ),
    "metadata must be a list",
    class = "bfhcharts_export_error"
  )
})

test_that("bfh_export_figure_pdf() afviser template_path uden restrict_template = FALSE", {
  local_figure_compile_mock()
  tpl <- withr::local_tempfile(fileext = ".typ")
  writeLines("// tom", tpl)

  figure_msg <- tryCatch(
    bfh_export_figure_pdf(fixture_figure(), tempfile(fileext = ".pdf"),
      metadata = list(title = "x"), template_path = tpl
    ),
    error = function(e) conditionMessage(e)
  )
  spc_msg <- tryCatch(
    bfh_export_pdf(fixture_test_chart(), tempfile(fileext = ".pdf"),
      template_path = tpl
    ),
    error = function(e) conditionMessage(e)
  )
  expect_match(figure_msg, "template_path is not allowed", fixed = TRUE)
  expect_identical(figure_msg, spc_msg)

  expect_error(
    bfh_export_figure_pdf(fixture_figure(), tempfile(fileext = ".pdf"),
      metadata = list(title = "x"), restrict_template = NA
    ),
    "restrict_template",
    class = "bfhcharts_export_error"
  )
})

test_that("bfh_export_figure_pdf() validerer output-sti som bfh_export_pdf()", {
  local_figure_compile_mock()
  expect_error(
    bfh_export_figure_pdf(fixture_figure(), "../../evil.pdf",
      metadata = list(title = "x")
    ),
    class = "bfhcharts_export_error"
  )
})

test_that("bfh_export_figure_pdf() advarer ikke om title som ukendt felt", {
  local_figure_compile_mock()
  out <- withr::local_tempfile(fileext = ".pdf")
  expect_no_warning(
    bfh_export_figure_pdf(fixture_figure(), out,
      metadata = list(title = "Ventetid", department = "Kirurgi")
    )
  )
})

test_that("bfh_export_figure_pdf() ignorerer bruger-leveret spc_panel", {
  mock <- local_figure_compile_mock()
  out <- withr::local_tempfile(fileext = ".pdf")
  # spc_panel er ikke kalder-styret: advarsel om ukendt felt, og flaget
  # er stadig FALSE i dokumentet
  expect_warning(
    bfh_export_figure_pdf(fixture_figure(), out,
      metadata = list(title = "x", spc_panel = TRUE)
    ),
    "spc_panel"
  )
  expect_true(any(grepl("spc_panel: false", mock$typ, fixed = TRUE)))
})

# ---- 5.2 Dokument-indhold ---------------------------------------------------

test_that("figur-eksport sender spc_panel: false og ingen SPC-parametre", {
  mock <- local_figure_compile_mock()
  out <- withr::local_tempfile(fileext = ".pdf")

  bfh_export_figure_pdf(
    fixture_figure(), out,
    metadata = list(
      title = "Ventetid faldt",
      department = "Kirurgi",
      analysis = "Analysetekst",
      details = "Periode 2025",
      footer_content = "Kilde: test"
    )
  )

  expect_identical(mock$calls, 1L)
  typ <- paste(mock$typ, collapse = "\n")
  expect_match(typ, "spc_panel: false", fixed = TRUE)
  expect_false(grepl("runs_|crossings_|outliers_|is_run_chart|cl_", typ))
  expect_match(typ, "Ventetid faldt", fixed = TRUE)
  expect_match(typ, "Analysetekst", fixed = TRUE)
  expect_match(typ, "Periode 2025", fixed = TRUE)
  expect_match(typ, "Kilde: test", fixed = TRUE)
  expect_true(file.exists(out))
})

test_that("figur-eksport renderer SVG i fuld bredde (264 x 109 mm)", {
  mock <- local_figure_compile_mock()
  out <- withr::local_tempfile(fileext = ".pdf")

  bfh_export_figure_pdf(fixture_figure(), out, metadata = list(title = "x"))

  size <- svg_size_mm(mock$svg_root)
  expect_equal(unname(size["width"]), 264, tolerance = 0.1 / 264)
  expect_equal(unname(size["height"]), 109, tolerance = 0.1 / 109)
})

test_that("SPC-eksport er uaendret: 191.4 x 109 mm og ingen spc_panel", {
  mock <- local_figure_compile_mock()
  out <- withr::local_tempfile(fileext = ".pdf")

  bfh_export_pdf(fixture_test_chart(), out)

  size <- svg_size_mm(mock$svg_root)
  expect_equal(unname(size["width"]), 191.4, tolerance = 0.1 / 191.4)
  expect_false(any(grepl("spc_panel", mock$typ, fixed = TRUE)))
})

# ---- 5.3 Plot-forberedelse --------------------------------------------------

test_that("prepare_figure_plot() stripper titel/undertitel og saetter 0 mm margin", {
  p <- fixture_figure() +
    ggplot2::labs(title = "A", subtitle = "B", caption = "Kilde")
  prepared <- BFHcharts:::prepare_figure_plot(p)

  expect_null(prepared$labels$title)
  expect_null(prepared$labels$subtitle)
  # Caption er ikke titel/undertitel og roeres ikke
  expect_identical(prepared$labels$caption, "Kilde")
  expect_equal(as.numeric(prepared$theme$plot.margin), rep(0, 4))
  expect_true(all(grid::unitType(prepared$theme$plot.margin) == "mm"))
})

test_that("prepare_figure_plot() fjerner blanke aksetitler, bevarer udfyldte", {
  p <- fixture_figure() + ggplot2::labs(x = "", y = "Ventetid")
  prepared <- BFHcharts:::prepare_figure_plot(p)

  expect_s3_class(prepared$theme$axis.title.x.bottom, "element_blank")
  expect_null(prepared$theme$axis.title.y.left)
})

test_that("prepare_figure_plot() fjerner aksetitel saettet til NULL eller whitespace", {
  p_null <- fixture_figure() + ggplot2::labs(x = NULL, y = "   ")
  prepared <- BFHcharts:::prepare_figure_plot(p_null)

  expect_s3_class(prepared$theme$axis.title.x.bottom, "element_blank")
  expect_s3_class(prepared$theme$axis.title.y.left, "element_blank")
})

test_that("prepare_figure_plot() bevarer aksetitler udledt af aes() uden labs()", {
  # Regression: i ggplot2 >= 4.0 er plot$labels$x NULL naar titlen udledes af
  # aes(); blank-tjek skal derfor bruge de oploeste labels.
  p <- fixture_figure()
  prepared <- BFHcharts:::prepare_figure_plot(p)

  expect_null(prepared$theme$axis.title.x.bottom)
  expect_null(prepared$theme$axis.title.y.left)
})

test_that("prepare_figure_plot() bevarer kalderens tema", {
  p <- fixture_figure() +
    ggplot2::theme_minimal() +
    ggplot2::theme(panel.grid = ggplot2::element_line(colour = "red"))
  prepared <- BFHcharts:::prepare_figure_plot(p)

  keep <- setdiff(names(p$theme), "plot.margin")
  expect_identical(prepared$theme[keep], p$theme[keep])
  expect_identical(
    setdiff(names(prepared$theme), names(p$theme)),
    character(0)
  )
})

# ---- 5.4 batch_session ------------------------------------------------------

test_that("figur-eksport genbruger batch_session uden at kopiere template igen", {
  local_figure_compile_mock()
  staged <- list()
  testthat::local_mocked_bindings(
    .stage_packaged_template_dir = function(output_dir, skip_copy = FALSE) {
      staged[[length(staged) + 1L]] <<- list(dir = output_dir, skip = skip_copy)
      invisible(NULL)
    },
    .package = "BFHcharts"
  )
  session <- bfh_create_export_session()
  withr::defer(close(session))

  out <- withr::local_tempfile(fileext = ".pdf")
  bfh_export_figure_pdf(fixture_figure(), out,
    metadata = list(title = "x"), batch_session = session
  )

  expect_length(staged, 1L)
  expect_true(staged[[1]]$skip)
  expect_identical(
    normalizePath(staged[[1]]$dir), normalizePath(session$tmpdir)
  )
  # Session-tmpdir overlever eksporten; per-eksport filer er ryddet op
  expect_true(dir.exists(session$tmpdir))
  expect_length(
    list.files(session$tmpdir, pattern = "^(chart|document)-"), 0L
  )
})

# ---- 5.8 Datadefinition -----------------------------------------------------

test_that("ikke-tom data_definition udloeser klassificeret advarsel men eksporterer", {
  local_figure_compile_mock()
  out <- withr::local_tempfile(fileext = ".pdf")

  expect_warning(
    bfh_export_figure_pdf(fixture_figure(), out,
      metadata = list(title = "x", data_definition = "Antal patienter")
    ),
    class = "bfhcharts_warning"
  )
  expect_true(file.exists(out))
})

test_that("ingen data_definition-advarsel naar feltet er NULL eller tomt", {
  local_figure_compile_mock()
  for (dd in list(NULL, "", "  ")) {
    out <- withr::local_tempfile(fileext = ".pdf")
    md <- list(title = "x")
    md["data_definition"] <- list(dd)
    expect_no_warning(bfh_export_figure_pdf(fixture_figure(), out, metadata = md))
  }
})

# ============================================================================
# bfh_stage_figure_page() (batch-pdf-export)
# ============================================================================

local_figure_cache <- function(env = parent.frame()) {
  withr::local_tempdir(.local_envir = env)
}

read_bundle <- function(cache, id) {
  readRDS(file.path(cache, id, "page.rds"))
}

# Run bfh_export_batch_pdf() with the Typst compiler mocked out; returns the
# captured .typ documents.
capture_batch_docs <- function(expr_fn, env = parent.frame()) {
  captured <- new.env(parent = emptyenv())
  captured$docs <- list()
  testthat::local_mocked_bindings(
    bfh_compile_typst = function(typst_file, output, ...) {
      captured$docs[[length(captured$docs) + 1L]] <- readLines(typst_file)
      writeLines("%PDF-fake", output)
      invisible(output)
    },
    quarto_available = function(...) TRUE,
    .package = "BFHcharts",
    .env = env
  )
  expr_fn()
  captured$docs
}

# ---- 6.1 Input-validering + staging-semantik --------------------------------

test_that("bfh_stage_figure_page() afviser ugyldigt plot og skriver intet", {
  cache <- local_figure_cache()
  composite <- fixture_figure()
  class(composite) <- c("patchwork", class(composite))

  for (bad in list(data.frame(), NULL, "plot", composite)) {
    expect_error(
      bfh_stage_figure_page(bad, cache, metadata = list(title = "x")),
      "plot",
      class = "bfhcharts_export_error"
    )
  }
  expect_length(list.files(cache, all.files = TRUE, no.. = TRUE), 0L)
})

test_that("bfh_stage_figure_page() afviser manglende eller ugyldig title", {
  cache <- local_figure_cache()
  p <- fixture_figure()

  for (md in list(
    list(), list(title = ""), list(title = "  "), list(title = NA_character_),
    list(title = c("a", "b")), list(title = 1)
  )) {
    expect_error(
      bfh_stage_figure_page(p, cache, metadata = md),
      "title",
      class = "bfhcharts_export_error"
    )
  }
  expect_length(list.files(cache, all.files = TRUE, no.. = TRUE), 0L)
})

test_that("bfh_stage_figure_page() afviser ugyldige argumenter som bfh_stage_pdf_page()", {
  cache <- local_figure_cache()
  p <- fixture_figure()
  md <- list(title = "x")

  expect_error(
    bfh_stage_figure_page(p, file.path(tempdir(), "does-not-exist-xyz"),
      metadata = md
    ),
    "cache_dir",
    class = "bfhcharts_export_error"
  )
  for (bad_id in c("../evil", "a/b", "a\\b", "a;b", ".hidden", "", "a b")) {
    expect_error(
      bfh_stage_figure_page(p, cache, id = bad_id, metadata = md),
      class = "bfhcharts_export_error"
    )
  }
  expect_error(
    bfh_stage_figure_page(p, cache, metadata = "not-a-list"),
    "metadata",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_stage_figure_page(p, cache, metadata = md, dpi = -1),
    "dpi",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_stage_figure_page(p, cache, metadata = md, template = "1bad; import"),
    "template",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_stage_figure_page(p, cache, metadata = md, overwrite = NA),
    "overwrite",
    class = "bfhcharts_export_error"
  )
  expect_error(
    bfh_stage_figure_page(p, cache, metadata = md, order = "first"),
    "order",
    class = "bfhcharts_export_error"
  )
  expect_length(list.files(cache, all.files = TRUE, no.. = TRUE), 0L)
})

test_that("bfh_stage_figure_page() returnerer usynligt og folger id/order-sekvensen", {
  cache <- local_figure_cache()
  p <- fixture_figure()
  md <- list(title = "x")

  expect_invisible(bfh_stage_figure_page(p, cache, id = "inv", metadata = md))
  s1 <- bfh_stage_figure_page(p, cache, metadata = md)
  s2 <- bfh_stage_figure_page(p, cache, metadata = md)

  expect_s3_class(s1, "bfh_staged_page")
  expect_identical(s1$id, "page-0001")
  expect_identical(s2$id, "page-0002")
  expect_gt(s2$order, s1$order)
})

test_that("bfh_stage_figure_page() overwrite = FALSE fejler; TRUE erstatter atomisk", {
  cache <- local_figure_cache()
  p <- fixture_figure()

  bfh_stage_figure_page(p, cache, id = "dup", metadata = list(title = "Foer"))
  expect_error(
    bfh_stage_figure_page(p, cache,
      id = "dup", metadata = list(title = "x"), overwrite = FALSE
    ),
    "already exists",
    class = "bfhcharts_export_error"
  )

  bfh_stage_figure_page(p, cache, id = "dup", metadata = list(title = "Efter"))
  expect_identical(read_bundle(cache, "dup")$metadata$title, "Efter")
  expect_length(
    list.files(cache, pattern = "^\\.(staging|replaced)-", all.files = TRUE), 0L
  )
})

test_that("afbrudt figur-staging efterlader ingen synlig bundle", {
  cache <- local_figure_cache()
  testthat::local_mocked_bindings(
    export_chart_svg = function(...) stop("simulated render failure"),
    .package = "BFHcharts"
  )
  expect_error(
    bfh_stage_figure_page(fixture_figure(), cache,
      id = "boom", metadata = list(title = "x")
    )
  )
  expect_false(dir.exists(file.path(cache, "boom")))
  expect_length(list.files(cache, pattern = "^\\.staging-", all.files = TRUE), 0L)
})

# ---- 6.2 Bundle-indhold ------------------------------------------------------

test_that("figur-bundle har SPC-bundlens format med spc_panel = FALSE og tom stats", {
  cache <- local_figure_cache()
  bfh_stage_figure_page(fixture_figure(), cache,
    id = "fig-1",
    metadata = list(title = "Ventetid", department = "Kirurgi")
  )

  bundle <- read_bundle(cache, "fig-1")
  expect_identical(bundle$format_version, BFHcharts:::BATCH_CACHE_FORMAT_VERSION)
  expect_identical(bundle$id, "fig-1")
  expect_identical(bundle$template, "bfh-diagram")
  expect_identical(bundle$metadata$title, "Ventetid")
  expect_identical(bundle$metadata$department, "Kirurgi")
  expect_identical(bundle$metadata$spc_panel, FALSE)
  expect_true(is.list(bundle$spc_stats))
  expect_true(all(vapply(bundle$spc_stats, is.null, logical(1))))

  expect_true(file.exists(file.path(cache, "fig-1", "chart.svg")))
  root <- grep("<svg", readLines(file.path(cache, "fig-1", "chart.svg"),
    warn = FALSE
  ), value = TRUE)[1]
  size <- svg_size_mm(root)
  expect_equal(unname(size["width"]), 264, tolerance = 0.1 / 264)
  expect_equal(unname(size["height"]), 109, tolerance = 0.1 / 109)
  # Ingen PDF produceres ved staging
  expect_length(list.files(cache, pattern = "\\.pdf$", recursive = TRUE), 0L)
})

test_that("bruger-leveret spc_panel i metadata ignoreres ved staging", {
  cache <- local_figure_cache()
  bfh_stage_figure_page(fixture_figure(), cache,
    id = "fig-1", metadata = list(title = "x", spc_panel = TRUE)
  )
  expect_identical(read_bundle(cache, "fig-1")$metadata$spc_panel, FALSE)
})

test_that("SPC-bundles baerer stadig ingen spc_panel-vaerdi", {
  cache <- local_figure_cache()
  bfh_stage_pdf_page(fixture_test_chart(), cache, id = "spc-1")
  expect_false("spc_panel" %in% names(read_bundle(cache, "spc-1")$metadata))
})

# ---- 5.8 (stage) Datadefinition ----------------------------------------------

test_that("bfh_stage_figure_page() advarer om data_definition, men stager", {
  cache <- local_figure_cache()
  expect_warning(
    bfh_stage_figure_page(fixture_figure(), cache,
      id = "fig-1",
      metadata = list(title = "x", data_definition = "Antal patienter")
    ),
    class = "bfhcharts_warning"
  )
  expect_true(dir.exists(file.path(cache, "fig-1")))

  expect_no_warning(
    bfh_stage_figure_page(fixture_figure(), cache,
      id = "fig-2", metadata = list(title = "x")
    )
  )
})

# ---- 6.3 Blandet batch -------------------------------------------------------

test_that("blandet batch (SPC + figur) har kun spc_panel: false paa figur-siden", {
  cache <- local_figure_cache()
  bfh_stage_pdf_page(fixture_test_chart(), cache, id = "spc-1", order = 1)
  bfh_stage_figure_page(fixture_figure(), cache,
    id = "fig-1", order = 2, metadata = list(title = "Figurtitel")
  )
  out <- file.path(withr::local_tempdir(), "out.pdf")

  docs <- capture_batch_docs(function() {
    bfh_export_batch_pdf(cache, out, ids = c("spc-1", "fig-1"))
  })

  expect_length(docs, 1L)
  doc <- docs[[1]]
  # Eet template-import og to sidekald
  expect_length(grep("^#import ", doc), 1L)
  calls <- grep("^#bfh-diagram\\(", doc)
  expect_length(calls, 2L)
  # spc_panel forekommer praecis een gang og hoerer til det andet kald
  panel_line <- grep("spc_panel: false", doc, fixed = TRUE)
  expect_length(panel_line, 1L)
  expect_gt(panel_line, calls[[2]])
  expect_true(any(grepl("Figurtitel", doc, fixed = TRUE)))
  expect_true(file.exists(out))
})

test_that("figur-bundles behandles som sider ved manifest og pruning", {
  cache <- local_figure_cache()
  bfh_stage_figure_page(fixture_figure(), cache,
    id = "fig-1", metadata = list(title = "x")
  )
  out <- file.path(withr::local_tempdir(), "out.pdf")

  docs <- capture_batch_docs(function() {
    bfh_export_batch_pdf(cache, out, ids = "fig-1")
  })
  expect_length(docs, 1L)

  removed <- bfh_prune_page_cache(cache, keep = character(0))
  expect_identical(removed, "fig-1")

  expect_error(
    bfh_export_batch_pdf(cache, out, ids = "fig-1"),
    "fig-1",
    class = "bfhcharts_export_error"
  )
})

# ---- 6.6 Fejltekster i bfh_export_batch_pdf() ----------------------------------

test_that("batch-fejltekster naevner baade SPC- og figur-staging", {
  cache <- local_figure_cache()
  out <- file.path(withr::local_tempdir(), "out.pdf")

  empty_msg <- tryCatch(bfh_export_batch_pdf(cache, out),
    error = function(e) conditionMessage(e)
  )
  expect_match(empty_msg, "bfh_stage_pdf_page()", fixed = TRUE)
  expect_match(empty_msg, "bfh_stage_figure_page()", fixed = TRUE)

  bfh_stage_figure_page(fixture_figure(), cache,
    id = "fig-1", metadata = list(title = "x")
  )
  missing_msg <- tryCatch(bfh_export_batch_pdf(cache, out, ids = c("fig-1", "nope")),
    error = function(e) conditionMessage(e)
  )
  expect_match(missing_msg, "nope", fixed = TRUE)
  expect_match(missing_msg, "bfh_stage_pdf_page()", fixed = TRUE)
  expect_match(missing_msg, "bfh_stage_figure_page()", fixed = TRUE)
})
