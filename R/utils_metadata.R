#' Merge User Metadata with Defaults
#'
#' Merges user-provided metadata with package defaults for PDF generation.
#' This function is useful for downstream packages that need consistent
#' metadata handling without depending on BFHcharts internal functions.
#'
#' @param metadata Named list with user-provided metadata fields.
#'   Valid fields: hospital, department, title, analysis, details, author,
#'   date, data_definition, footer_content, logo_path. Other fields are ignored.
#' @param chart_title Character string with chart title. Used as default
#'   for metadata$title if not provided by user.
#'
#' @return Named list with merged metadata containing:
#' \describe{
#'   \item{hospital}{Hospital name (default: "Bispebjerg og Frederiksberg Hospital")}
#'   \item{department}{Department name (default: NULL)}
#'   \item{title}{Chart title (from chart_title or metadata)}
#'   \item{analysis}{Analysis description (default: NULL)}
#'   \item{details}{Additional details (default: NULL)}
#'   \item{author}{Author name (default: NULL)}
#'   \item{date}{Report date (default: Sys.Date())}
#'   \item{data_definition}{Data definition (default: NULL)}
#'   \item{footer_content}{Footer content below chart (default: NULL)}
#'   \item{logo_path}{Path to hospital logo image (default: NULL).
#'     When NULL, the Typst template renders without a foreground logo.
#'     Companion packages (BFHchartsAssets) populate this via inject_assets
#'     callback or auto-detection in `compose_typst_document()`.}
#' }
#'
#' User-provided values override defaults. Fields not in the default list
#' are silently ignored.
#'
#' @export
#' @examples
#' \dontrun{
#' # Basic usage
#' metadata <- list(
#'   department = "Kvalitetsafdeling",
#'   analysis = "Signifikant fald observeret"
#' )
#' merged <- bfh_merge_metadata(metadata, chart_title = "Infektioner")
#'
#' # merged$hospital = "Bispebjerg og Frederiksberg Hospital" (default)
#' # merged$department = "Kvalitetsafdeling" (user override)
#' # merged$title = "Infektioner" (from chart_title)
#' }
#'
#' @family utility-functions
#' @seealso [bfh_export_pdf()] for PDF export functionality
bfh_merge_metadata <- function(metadata, chart_title) {
  if (!is.null(metadata) && (!is.list(metadata) || is.data.frame(metadata))) {
    stop("metadata must be a list or NULL", call. = FALSE)
  }

  defaults <- list(
    hospital = "Bispebjerg og Frederiksberg Hospital",
    department = NULL,
    title = chart_title,
    analysis = NULL,
    details = NULL,
    author = NULL,
    date = Sys.Date(),
    data_definition = NULL,
    footer_content = NULL,
    logo_path = NULL
  )

  if (is.null(metadata)) {
    return(defaults)
  }

  # intersect sikrer ukendte felter i metadata ikke laekker igennem
  utils::modifyList(defaults, metadata[intersect(names(metadata), names(defaults))])
}
