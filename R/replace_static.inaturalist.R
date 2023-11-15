#' Replace Static iNaturalist URLs
#'
#' Replaces static iNaturalist URLs in the identifier column of a multimedia `data frame` with the correct URL format.
#'
#' @param m.df A `data.frame` containing the multimedia data.
#' @return A `data.frame` with the updated URLs in the identifier column.
replace_static.inaturalist <- function(m.df = multimedia) {
  if (!"identifier" %in% names(m.df)) {
    stop("The data frame does not contain an 'identifier' column.")
  }

  count <- sum(stringr::str_detect(
    m.df$identifier[!is.na(m.df$identifier)],
    "htt[:lower:]{1,2}://static.inaturalist.org/"
  ))


  m.df$identifier <- stringr::str_replace(
    m.df$identifier,
    "htt[:lower:]{1,2}://static.inaturalist.org/",
    "https://inaturalist-open-data.s3.amazonaws.com/"
  )

  message(count, " static inaturalis identifier(s) replaced.")

  return(m.df)
}
