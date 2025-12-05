#' Export BFH QIC Chart to PNG
#'
#' Exports an SPC chart created by \code{bfh_qic()} to a PNG file with
#' configurable dimensions and resolution. Designed for pipe-compatible
#' workflows.
#'
#' @param x A \code{bfh_qic_result} object from \code{bfh_qic()}
#' @param output Character string specifying the output file path (e.g., "chart.png")
#' @param width_mm Numeric. Width of the output image in millimeters (default: 200mm)
#' @param height_mm Numeric. Height of the output image in millimeters (default: 120mm)
#' @param dpi Numeric. Dots per inch resolution for the PNG (default: 300)
#'
#' @return The input object \code{x} invisibly, enabling pipe chaining
#'
#' @details
#' **Dimension Handling:**
#' - Dimensions are specified in millimeters (Danish/European standard)
#' - Internally converted to inches for ggplot2::ggsave()
#' - Default 200mm × 120mm ≈ 7.87" × 4.72" (common presentation size)
#'
#' **Resolution (DPI):**
#' - 300 DPI (default): High quality for print and presentations
#' - 150 DPI: Medium quality, smaller file size
#' - 96 DPI: Screen resolution, minimal file size
#'
#' **Title Handling:**
#' - The chart title (if present) is rendered in the PNG image
#' - This differs from PDF export which strips the title for Typst template
#'
#' **Plot Optimization:**
#' - Plot already has 5mm margins from bfh_qic() via apply_spc_theme()
#' - Blank axis titles are automatically removed when plot is created
#' - User-defined axis titles are preserved
#' - No additional processing needed at export time
#'
#' **Pipe Compatibility:**
#' - Returns input object invisibly for chaining
#' - Example: \code{bfh_qic(...) |> bfh_export_png("chart.png")}
#'
#' @export
#' @seealso
#'   - [bfh_qic()] to create SPC charts
#'   - [bfh_export_pdf()] to export as PDF with Typst templates
#' @examples
#' \dontrun{
#' library(BFHcharts)
#'
#' # Create sample data
#' data <- data.frame(
#'   month = seq(as.Date("2024-01-01"), by = "month", length.out = 24),
#'   infections = rpois(24, lambda = 15)
#' )
#'
#' # Create and export chart in one pipeline
#' bfh_qic(
#'   data = data,
#'   x = month,
#'   y = infections,
#'   chart_type = "i",
#'   y_axis_unit = "count",
#'   chart_title = "Monthly Infections"
#' ) |>
#'   bfh_export_png("monthly_infections.png", width_mm = 250, height_mm = 150, dpi = 300)
#'
#' # Explicit dimensions for specific use cases
#' result <- bfh_qic(data, month, infections, chart_type = "i")
#'
#' # A4 width (210mm) for reports
#' bfh_export_png(result, "report_chart.png", width_mm = 210, height_mm = 140)
#'
#' # PowerPoint slide (widescreen 16:9)
#' bfh_export_png(result, "slide_chart.png", width_mm = 254, height_mm = 143)
#'
#' # Web display (lower DPI for smaller file size)
#' bfh_export_png(result, "web_chart.png", width_mm = 200, height_mm = 120, dpi = 96)
#' }
bfh_export_png <- function(x,
                           output,
                           width_mm = 200,
                           height_mm = 120,
                           dpi = 300) {
  # Input validation: Check object class
  if (!inherits(x, "bfh_qic_result")) {
    stop(
      "x must be a bfh_qic_result object from bfh_qic().\n",
      "  Got class: ", paste(class(x), collapse = ", "),
      call. = FALSE
    )
  }

  # Validate output path
  if (!is.character(output) || length(output) != 1 || nchar(output) == 0) {
    stop("output must be a non-empty character string specifying the file path",
      call. = FALSE
    )
  }

  # Validate dimensions
  if (!is.numeric(width_mm) || length(width_mm) != 1 || width_mm <= 0) {
    stop("width_mm must be a positive number", call. = FALSE)
  }

  if (!is.numeric(height_mm) || length(height_mm) != 1 || height_mm <= 0) {
    stop("height_mm must be a positive number", call. = FALSE)
  }

  if (width_mm > 2000 || height_mm > 2000) {
    warning(
      "Very large dimensions detected (width: ", width_mm, "mm, height: ", height_mm, "mm).\n",
      "  This may result in very large file sizes or memory issues.",
      call. = FALSE
    )
  }

  # Validate DPI
  if (!is.numeric(dpi) || length(dpi) != 1 || dpi <= 0) {
    stop("dpi must be a positive number", call. = FALSE)
  }

  if (dpi < 72 || dpi > 600) {
    warning(
      "Unusual DPI value: ", dpi, "\n",
      "  Common values: 96 (screen), 150 (medium), 300 (print)",
      call. = FALSE
    )
  }

  # Convert millimeters to inches for ggplot2::ggsave()
  # 1 inch = 25.4 mm
  width_inches <- width_mm / 25.4
  height_inches <- height_mm / 25.4

  # Extract plot from bfh_qic_result object
  # Note: Plot already has 5mm margins and blank axis titles removed
  # via apply_spc_theme() in bfh_qic()
  plot <- x$plot

  # Create output directory if it doesn't exist
  output_dir <- dirname(output)
  if (!dir.exists(output_dir) && output_dir != ".") {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Export using ggplot2::ggsave()
  ggplot2::ggsave(
    filename = output,
    plot = plot,
    width = width_inches,
    height = height_inches,
    dpi = dpi,
    units = "in",
    device = "png"
  )

  # Return input object invisibly for pipe chaining
  invisible(x)
}
