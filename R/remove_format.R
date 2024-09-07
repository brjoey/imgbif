#' Remove Records with JSON Application Format
#'
#' Filters out records from the multimedia data frame that have a format indicating a JSON application.
#'
#' @param m.df A `data.frame` containing the multimedia data.
#' @return A `data.frame` without records where the format is a JSON application.
remove_format <- function(m.df) {
  index <- stringr::str_detect(m.df$format,
    "application",
    negate = TRUE
  )


  m.df <- m.df[index, ]


  message(paste0(sum(!index), " occurences (format: application) removed."))
  m.df
}
