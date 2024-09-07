#' Create ActionButtons for UI
#'
#' @import purrr
#'
#' @param labelAbtnUI Character. Label for the ActionButtons
#' @param conditionAbtnUI Condition for the ActionButton building
#'
actionbuttonUI <- function(labelAbtnUI, conditionAbtnUI) {
  if (!conditionAbtnUI) {
    labelId <- paste0("btn", 1:length(labelAbtnUI))

    actionbtns <- purrr::map2(labelId, labelAbtnUI, function(id, lbl) {
      shiny::actionButton((id), label = lbl, width = 100)
    })

    # if (length(actionbtns) == 1) {
    #   return(actionbtns)
    # } else {
    #   space <- vector(mode = "list", length = (length(labelAbtnUI) - 1))
    #
    #   lapply(seq_along(space), function(i) {
    #     space[[i]] <- htmltools::tags$div(style = "margin-bottom: 10px;")
    #   })
    #
    #   actionbtns10px <- vector("list", length(actionbtns) + length(space))
    #
    #   actionbtns10px[seq(1, length(actionbtns10px), 2)] <- actionbtns
    #
    #   actionbtns10px[seq(2, (length(actionbtns10px) - 1), 2)] <- space
    #
    #   return(actionbtns10px)
    # }
  }
}
