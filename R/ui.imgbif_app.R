ui.imgbif_app <- function(label, multi_label, pbID, classSize, brush_image, slider, sliderRange) {
  ui <- shiny::navbarPage(
    title = "Classification App",
    id = "currentTab",
    shiny::tabPanel(
      title = "Label",
      value = "Label",
      shiny::sidebarLayout(
        shiny::sidebarPanel(
          width = 3,
          shiny::fluidRow(
            width = 3,
            shiny::column(
              width = 6,
              htmltools::tags$b("gbifID"),
              shiny::textOutput("gbifID")
            ),
            shiny::column(
              width = 6,
              htmltools::tags$b("Date"),
              shiny::textOutput("date")
            )
          ),
          htmltools::hr(),
          shiny::tags$head(
            shiny::tags$style(htmltools::HTML("
             .button-container .btn {
                display: block;
                width: 100%;s
                margin-bottom: 10px;
            }
        "))
          ), shiny::div(
            class = "button-container",
            actionbuttonUI(
              labelAbtnUI = label,
              conditionAbtnUI = multi_label
            )
          ),
          checkboxUI(
            labelCbxUI = label,
            conditionCbxUI = multi_label
          ),
        htmltools::hr(),
          if (slider) {
            shiny::sliderInput(
              inputId = "slider", label = "Scale",
              min = min(sliderRange), max = max(sliderRange),
              value = sliderRange[!(sliderRange == min(sliderRange) | sliderRange == max(sliderRange))]
            )
          },
          htmltools::hr(),
          shiny::actionButton(
            inputId = "exclude",
            label = "Exclude",
            width = 100
          ),
          htmltools::hr(),
          shiny::fluidRow(
            width = 3,
            shiny::column(
              width = 6,
              shinyjs::extendShinyjs(
                text = "shinyjs.closeWindow = function() { window.close(); }",
                functions = c("closeWindow")
              ),
              shiny::actionButton(
                inputId = "close",
                label = "Close App",
                width = 100
              )
            ),
            shiny::column(
              width = 6,
              shiny::actionButton(
                inputId = "backup",
                label = "Backup",
                width = 100
              )
            )
          ),
          htmltools::hr(),
          shiny::fluidRow(
            width = 3,
            shiny::column(
              width = 6,
              shiny::actionButton(
                inputId = "prevImage",
                label = "Back",
                width = 100
              )
            ),
            shiny::column(
              width = 6,
              shiny::actionButton(
                inputId = "nextImage",
                label = "Next",
                width = 100
              )
            )
          ),
          htmltools::hr(),
          htmltools::tags$b("Assigned Label"),
          shiny::textOutput("assigned_label")
        ),
        shiny::mainPanel(
          width = 9,
          htmltools::br(),
          shiny::plotOutput(
            outputId = "ImagePlot",
            brush = if (brush_image) shiny::brushOpts(id = paste0("ImagePlot", "_brush"), stroke = "#BB29BB", fill = "#C5B4E3") else NULL
          )
        ),
        position = "left",
        fluid = TRUE
      )
    ),
    shiny::tabPanel(
      title = "Progress",
      value = "Progress",
      shiny::sidebarLayout(
        shiny::sidebarPanel(
          htmltools::tags$b("Number of images per class:"),
          htmltools::tags$div(style = "margin-bottom: 15px;"),
          progressbarUI(
            label = label,
            pbId = pbID,
            classSize = classSize
          )
        ),
        shiny::mainPanel()
      )
    )
  )
  return(ui)
}
