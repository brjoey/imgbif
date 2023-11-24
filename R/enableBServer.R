enableBServer <- function(label2enable) {
  btns <- lapply(label2enable, function(id) {
    shinyjs::enable(id)
  })
}
