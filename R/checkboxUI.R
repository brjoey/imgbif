checkboxUI <- function(labelCbxUI,
                       conditionCbxUI) {
  if (conditionCbxUI) {
    htmltools::tagList(
      shiny::checkboxGroupInput("checkbox",
        label = "Select the appropriate labels:",
        choices = labelCbxUI
      ),
      #      htmltools::hr(),
      shiny::actionButton("submitBtn",
        label = "Submit",
        width = 100
      )
    )
  }
}
