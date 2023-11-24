disableBServer <- function(label2disable) {
  btns <- lapply(label2disable, function(id) {
    shinyjs::disable(id)
  })
}
