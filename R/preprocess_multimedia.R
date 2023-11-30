#' Pre-Process GBIF Multimedia File
#'
#' @description
#' Pre-processes a GBIF multimedia file by filtering out records without a GBIF ID (occurrence ID) or image link, processing URLs to images in the iNaturalist database, and optionally removing images from Herbarium databases if the occurrence file contains information about the publisher. Users can also specify which image licenses to exclude from the dataset.
#'
#' @param multimedia A `data.frame` containing the multimedia data or the path to the multimedia file (with the extension "txt", "csv", or "feather").
#' @param occurrence A `data.frame` containing the occurrence data or the path to the occurrence file (with the extension "txt", "csv", or "feather").
#' @param herbarium.rm A `boolean` indicating whether to remove Herbarium database records (the default is `TRUE`). When set to `FALSE`, Herbarium data is retained.
#' @param license.rm A `character vector` specifying the license types to be excluded. Common licenses include 'all rights reserved', 'by-sa', 'by-nc', 'NA', and 'unclear'.
#'
#' @return A `data.frame` containing the pre-processed multimedia data.
#' @export
#' @examples
#' \dontrun{
#' # Using default parameters with a file path
#' preprocess_multimedia(multimedia = "path/to/multimedia.txt", occurrence = "path/to/occurrence.txt")
#'
#' # Using default parameters with data.frame
#' preprocess_multimedia(multimedia = multimedia_df, occurrence = occurrence_df)
#'
#' # Custom parameters, retaining Herbarium data and excluding additional licenses
#' preprocess_multimedia(
#'   multimedia = multimedia_df, occurrence = occurrence_df,
#'   herbarium.rm = FALSE, license.rm = c("all rights reserved", "by-nc", "by-nd")
#' )
#' }
preprocess_multimedia <- function(multimedia,
                                  occurrence,
                                  herbarium.rm = TRUE,
                                  license.rm = c("all rights reserved", "by-sa", "by-nc", "NA", "unclear")
                                  ) {
  if (missing(multimedia)) {
    stop("Multimedia data frame or path to multimedia.txt file is required")
  } else {
    if (!is(multimedia, "tbl_df") && !is(multimedia, "data.frame")) {
      extension <- tools::file_ext(multimedia)
      if (extension == "txt") {
        multimedia <- try({
          read.csv2(multimedia, sep = "\t", na.strings = "", quote = "")
        })
      }
      if (extension == "csv") {
        multimedia <- try({
          read.csv2(multimedia, sep = "\t", na.strings = "", quote = "")
        })
      }
      if (extension == "feather") {
        multimedia <- try({
          feather::read_feather(multimedia)
        })
      }
      if (is(multimedia, "try-error")) {
        stop("Could not find provided path (multimedia):", multimedia)
      }
    }
  }


  if (missing(occurrence)) {
    stop("Occurrence data frame or path to occurrence file is required")
  } else {
    if (!is(occurrence, "tbl_df") && !is(occurrence, "data.frame")) {
      extension <- tools::file_ext(occurrence)
      if (extension == "txt") {
        occurrence <- try({
          read.csv2(occurrence, sep = "\t", na.strings = "", quote = "")
        })
      }
      if (extension == "csv") {
        occurrence <- try({
          read.csv2(occurrence, sep = "\t", na.strings = "", quote = "")
        })
      }
      if (extension == "feather") {
        occurrence <- try({
          feather::read_feather(occurrence)
        })
      }
      if (is(occurrence, "try-error")) {
        stop("Could not find provided path (occurrence):", occurrence)
      }
    }
  }

  multimedia <- remove_herbarium(
    m.df = multimedia,
    o.df = occurrence
  )


  multimedia <- remove_format(m.df = multimedia)


  index <- is.na(multimedia$identifier)
  multimedia <- multimedia[!index, ]
  message(sum(index), " occurrences removed due to missing identifier.")
  index2 <- is.na(multimedia$gbifID)
  multimedia <- multimedia[!index2, ]
  message(sum(index2), " occurrences removed due to missing gbifID")


  multimedia <- remove_license(
    m.df = multimedia,
    license = license.rm
  )


  multimedia <- replace_static.inaturalist(m.df = multimedia)


  return(multimedia)
}
