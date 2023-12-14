server.img_app <- function(labelBtn, classSize, labelId, label, multi_label, image_list, sourceDir, pbID) {
  server <- function(input, output, session) {
    currentRow <- shiny::reactiveValues(number = 1)
    nRow <- length(image_list)

    trigger <- shiny::reactiveValues(activate = 0)
    trigger$activate <- 1

    shiny::observe({
      trigger$activate
      if (currentRow$number == (nRow + 1)) {
        shiny::showNotification("You labeled the last image. \n
                                Closing the app now.",
          duration = 3,
          closeButton = FALSE,
          type = "error"
        )
        Sys.sleep(3)
        disableBServer(label2disable = labelBtn)
        shinyjs::js$closeWindow()
        shiny::stopApp()
      } else {
        image <- try({
          magick::image_read(file.path(image_list[[currentRow$number]]))
        })


        while (is(image, "try-error")) {
          warning("ERROR: ", basename(image_list[[currentRow$number]]), " could not be read.")
          notification <- shiny::showNotification("ERROR: Unable to read image. Trying next...",
            closeButton = TRUE,
            type = "message"
          )


          file.copy(
            from = image_list[[currentRow$number]],
            to = file.path(sourceDir, "exclude")
          )
          file.remove(image_list[[currentRow$number]])

          currentRow$number <- shiny::isolate(currentRow$number) + 1

          image <- try({
            magick::image_read(file.path(image_list[[currentRow$number]]))
          })

          on.exit(shiny::removeNotification(notification), add = TRUE)
        }

        enableBServer(label2enable = labelBtn)

        output$ImagePlot <- shiny::renderPlot({
          magick::image_ggplot(image)
        })

        gbifid <- try({
          stringr::str_extract_all(image_list[[currentRow$number]], "[[:digit:]]{10}")
        })


        if (!is(gbifid, "try-error")) {
          output$gbifID <- shiny::renderText({
            as.character(gbifid)
          })
        } else {
          output$gbifID <- shiny::renderText({
            "Unknown"
          })
        }
      }
    })


    if (!multi_label) {
      actionButtonServer <- lapply(labelId, function(i) {
        shiny::observeEvent(input[[i]], {
          disableBServer(label2disable = labelBtn)

          index <- as.numeric(stringr::str_remove_all(i, "btn"))
          file.copy(
            from = image_list[[currentRow$number]],
            to = file.path(sourceDir, label[index])
          )
          file.remove(image_list[[currentRow$number]])
          currentRow$number <- shiny::isolate(currentRow$number) + 1

          trigger$activate <- 1
        })
      })
    }


    if (multi_label) {
      checkboxServer <- shiny::observeEvent(input$submitBtn, {
        if (length(input[["checkbox"]]) == 0) {
          shiny::showNotification("Please select at least one label
                                \n and submit again.",
            duration = 6,
            closeButton = TRUE,
            type = "error"
          )
        } else {
          disableBServer(label2disable = labelBtn)

          index <- (label %in% input[["checkbox"]])
          lapply(label[index], function(l) {
            file.copy(
              from = image_list[[currentRow$number]],
              to = file.path(sourceDir, l)
            )
          })
          file.remove(image_list[[currentRow$number]])
          shiny::updateCheckboxGroupInput(
            inputId = "checkbox",
            selected =
              character(0)
          )

          currentRow$number <- shiny::isolate(currentRow$number) + 1

          trigger$activate <- 1
        }
      })
    }


    shiny::observeEvent(input$exclude, {
      disableBServer(label2disable = labelBtn)
      file.copy(
        from = image_list[[currentRow$number]],
        to = file.path(sourceDir, "exclude")
      )
      file.remove(image_list[[currentRow$number]])
      currentRow$number <- shiny::isolate(currentRow$number) + 1
      trigger$activate <- 1
    })


    shiny::observeEvent(input$currentTab, {
      if (input$currentTab == "Progress") {
        pb_values <- vector(mode = "integer", length = length(label))
        pb_values <- lapply(label, function(x) {
          length(list.files(path = file.path(sourceDir, x), pattern = "\\.jpg$|\\.png$|\\.jpeg$|\\.tiff$|\\.bmp$", full.names = FALSE))
        })

        lapply(seq_along(pbID), function(j) {
          shinyWidgets::updateProgressBar(
            id = pbID[j],
            session = session,
            value = pb_values[[j]],
            total = classSize
          )
        })
      }
    })


    shiny::observeEvent(input$close, {
      disableBServer(label2disable = labelBtn)
      shiny::showNotification("Closing app",
        type = "message"
      )
      shinyjs::js$closeWindow()
      shiny::stopApp()
    })
  }
  return(server)
}
