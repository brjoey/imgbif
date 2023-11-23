#' Remove gbifIDs with Specified Licenses from Multimedia Data Frame
#'
#' Filters out records from a multimedia data frame based on specified license types.
#' By default, records with "all rights reserved" and "unclear" licenses are removed.
#'
#' @param m.df A `data.frame` containing multimedia data.
#' @param license A `character vector` specifying the license types to be excluded from further processing.
#' Accepted values include 'all rights reserved', 'by-sa', 'by-nc', 'NA', and 'unclear'.
#'
#' @return A `data.frame` with records filtered according to the specified license criteria.
remove_license <- function(m.df = multimedia.df,
                           license = c("all rights reserved", "by-sa", "by-nc", "NA", "unclear")
                           ) {

  license <- match.arg(license)


  if (!"license" %in% names(m.df)) {
    stop("The data frame does not contain a 'license' column.")
  }
  nrow0 <- nrow(m.df)


  if ("NA" %in% license) {
    m.df <- m.df[!is.na(m.df$license), ]
  }


  if ("all rights reserved" %in% license) {
    index <- stringr::str_detect(
      m.df$license,
      "[:graph:]+ll rights reserved",
      negate = TRUE
    )
    m.df <- m.df[index, ]
  }


  if ("by-nc" %in% license) {
    index <- stringr::str_detect(m.df$license,
      "[:graph:]by-nc[:graph:]",
      negate = TRUE
    )
    m.df <- m.df[index, ]
  }


  if ("by-sa" %in% license) {
    index <- stringr::str_detect(m.df$license,
      "[:graph:]by-sa[:graph:]",
      negate = TRUE
    )
    m.df <- m.df[index, ]
  }


  if ("by-nd" %in% license) {
    index <- stringr::str_detect(m.df$license,
      "[:graph:]by-nd[:graph:]",
      negate = TRUE
    )
    m.df <- m.df[index, ]
  }


  if ("Usage Conditions Apply" %in% license) {
    index <- stringr::str_detect(m.df$license,
      "[:graph:]by-sa[:graph:]",
      negate = TRUE
    )
    m.df <- m.df[index, ]
  }


  if ("unclear" %in% license) {
    licenses_list <- c(
      "[:graph:]+all rights reserved",
      "[:graph:]by-nc[:graph:]",
      "[:graph:]by-sa[:graph:]",
      "[:graph:]by-nd[:graph:]",
      "[:graph:]zero[:graph:]",
      "http://creativecommons.org/licenses/by/[:digit:]*.0/",
      "http://creativecommons.org/publicdomain/zero/1.0/[:graph:]"
    )

    index <- stringr::str_detect(
      m.df$license,
      paste(licenses_list, collapse = "|")
    )

    m.df <- m.df[index, ]

    index <- stringr::str_detect(m.df$license, "Ok[:cntrl:]nd", negate = TRUE)

    m.df <- m.df[index, ]
  }



  nrowT <- nrow(m.df)

  message((nrow0 - nrowT), " occurrences removed according to the license filter.")


  return(m.df)
}
