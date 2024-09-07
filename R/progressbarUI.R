progressbarUI <- function(label, pbId, classSize) {
  pb <- lapply(pbId, function(id) {
    shinyWidgets::progressBar(id,
      value = 0,
      total = classSize,
      title = "",
      display_pct = FALSE
    )
  })

  title <- vector(mode = "list", length = length(label))

  lapply(seq_along(title), function(i) {
    title[[i]] <- htmltools::tags$b(label[i])
  })

  pbtitle <- vector("list", length(pb) + length(title))

  pbtitle[seq(1, length(pbtitle), 2)] <- title

  pbtitle[seq(2, length(pbtitle), 2)] <- pb

  return(pbtitle)
}
