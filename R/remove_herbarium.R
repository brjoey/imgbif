#' Remove Herbarium Databases from Multimedia Data Frame
#'
#' Removes entries from a multimedia data frame that correspond to Herbarium database records in an occurrence data frame based on the publisher's information.
#'
#' @param m.df A `data.frame` containing the multimedia data.
#' @param o.df A `data.frame` containing the occurrence data.
#' @return A `data.frame` where Herbarium database entries have been removed from the multimedia file.
#' @note This function assumes that the `publisher` column in `o.df` contains Herbarium information. This is not always the case.
remove_herbarium <- function(m.df = multimedia,
                             o.df = occurrence) {
  if (!"publisher" %in% names(o.df)) {
    warning("The occurrence data frame does not contain a 'publisher' column.")
    return(m.df)
  }

  if (all(is.na(o.df$publisher))) {
    warning("The 'publisher' column contains only NA values. No Herbarium publishers removed.")
    return(m.df)
  }

  if (!all(is.na(o.df$publisher)) && anyNA(o.df$publisher)) {
    warning("The 'publisher' column contains NA values which will be ignored.")
  }


  herbarium_indices <- (o.df$publisher %in% gbif_herbarium_title)
  if (sum(herbarium_indices) > 0) {
    remove_herbarium_gbifid_o.df <- o.df[herbarium_indices, "gbifID"]
    nrow1 <- nrow(m.df)
    m.df <- m.df[!(m.df$gbifID %in% remove_herbarium_gbifid_o.df), ]
    nrow2 <- nrow1 - nrow(m.df)
    message(sum(nrow2), " Herbarium occurrences removed.")
  }

  return(m.df)
}
