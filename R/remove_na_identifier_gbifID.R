remove_na_identifier_gbifID <- function(m.df) {
  identifierNA <- is.na(m.df$identifier)
  identifierNA_sum <- sum(identifierNA)
  if (identifierNA_sum > 0) {
    warning(
      "The 'indentifier' column contained NA. ",
      identifierNA_sum, " row(s) removed. ",
      "Consider pre-processing with the imgbif package."
    )

    m.df <- m.df[!identifierNA, ]
  }

  gbifIDNA <- is.na(m.df$gbifID)
  gbifIDNA_sum <- sum(gbifIDNA)
  if (gbifIDNA_sum > 0) {
    warning(
      "The 'gbifID' column contained NA. ",
      gbifIDNA_sum, " row(s) removed. ",
      "Consider pre-processing with the imgbif package."
    )

    m.df <- m.df[!gbifIDNA, ]
  }
  return(m.df)
}
