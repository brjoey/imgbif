server.imgbif_app <- function(firstRow, nRow, labelBtn, multimedia, backupDir, classSize, labelId, label, backupInterval, multi_label, pbID, backup_cache, brush_image, slider, write_image, image_format) {
  server <- function(input, output, session) {
    currentRow <- shiny::reactiveValues(number = firstRow)

    current <- shiny::reactiveValues(image = 0)

    trigger <- shiny::reactiveValues(activateDownloadImages = 0)
    trigger$activateDownloadImages <- 1


    shiny::observeEvent(trigger$activateDownloadImages, {
      if (shiny::isolate(currentRow$number) == (nRow + 1)) {
        shiny::showNotification("You labeled the last image. \n
                                Closing the app now.",
          duration = 3,
          closeButton = FALSE,
          type = "error"
        )
        Sys.sleep(3)
        disableBServer(label2disable = labelBtn)
        backupDataServer(
          data = multimedia,
          backupPath = backupDir,
          backup_cache = backup_cache
        )
        shinyjs::js$closeWindow()
        shiny::stopApp()
      } else {
        shiny::withProgress(message = "Downloading image...", {
        image <- try2read(identifier = multimedia$identifier[shiny::isolate(currentRow$number)])

        while (is(image, "try-error")) {
          notification <- shiny::showNotification("Trying to read image from URL.\n
                                                Please wait...",
            closeButton = TRUE,
            type = "message"
          )

          multimedia$label[shiny::isolate(currentRow$number)] <<- "exclude"

          currentRow$number <- shiny::isolate(currentRow$number) + 1

          image <- try2read(identifier = multimedia$identifier[shiny::isolate(currentRow$number)])

          on.exit(shiny::removeNotification(notification), add = TRUE)
        }


        enableBServer(label2enable = labelBtn)

        setProgress(message = "Rendering plot...")
        output$ImagePlot <- shiny::renderPlot({
          magick::image_ggplot(image)
        })


        output$gbifID <- shiny::renderText({
          multimedia$gbifID[shiny::isolate(currentRow$number)]
        })


        try_created <- try({
          (format(as.Date(multimedia$created[shiny::isolate(currentRow$number)]), "%d. %b %Y"))
        })

        if (!is(try_created, "try-error")) {
          output$date <- shiny::renderText({
            try_created
          })

          assigned_label_txt <- try({
            multimedia$label[shiny::isolate(currentRow$number)]
          })

          if (!is(assigned_label_txt, "try-error")) {
            output$assigned_label <- shiny::renderText({
              assigned_label_txt
            })
          }

          if (!is(image, "try-error")) {
            current$image <- magick::image_ggplot(image)
          } else {
            current$image <- image
          }
        }
        })
      }
    })


    if (!multi_label) {
      actionButtonServer <- lapply(labelId, function(i) {
        shiny::observeEvent(input[[i]], {
          disableBServer(label2disable = labelBtn)

          index <- as.numeric(stringr::str_remove_all(i, "btn"))

          multimedia$label[shiny::isolate(currentRow$number)] <<- label[index]

          if (slider) {
            multimedia$scale[shiny::isolate(currentRow$number)] <<- input$slider
          }

          if (brush_image) {
            if (length(input$ImagePlot_brush) > 0) {
              multimedia[shiny::isolate(currentRow$number), "xmin"] <<- input$ImagePlot_brush$coords_css$xmin
              multimedia[shiny::isolate(currentRow$number), "ymin"] <<- input$ImagePlot_brush$coords_css$ymin
              multimedia[shiny::isolate(currentRow$number), "xmax"] <<- input$ImagePlot_brush$coords_css$xmax
              multimedia[shiny::isolate(currentRow$number), "ymax"] <<- input$ImagePlot_brush$coords_css$ymax
              session$resetBrush("ImagePlot_brush")
            }
          }

          if (write_image) {
            image_cache = shiny::isolate(current$image)
            if (!is(shiny::isolate(current$image), "try-error")) {
           server.write_image(
             multi_label = multi_label,
             image_cache = list(shiny::isolate(current$image)),
             image_format = image_format,
             currentRows = shiny::isolate(currentRow$number),
             imageSelection = 1,
             multimedia = multimedia,
             backupDir = backupDir
           )
           }
          }

          currentRow$number <- shiny::isolate(currentRow$number) + 1
          trigger$activateDownloadImages <- trigger$activateDownloadImages + 1
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

          multimedia$label[shiny::isolate(currentRow$number)] <<- input[["checkbox"]]

          if (slider) {
            multimedia$scale[shiny::isolate(currentRow$number)] <<- input$slider
          }

          if (brush_image) {
            if (length(input$ImagePlot_brush) > 0) {
              multimedia[shiny::isolate(currentRow$number), "xmin"] <<- input$ImagePlot_brush$coords_css$xmin
              multimedia[shiny::isolate(currentRow$number), "ymin"] <<- input$ImagePlot_brush$coords_css$ymin
              multimedia[shiny::isolate(currentRow$number), "xmax"] <<- input$ImagePlot_brush$coords_css$xmax
              multimedia[shiny::isolate(currentRow$number), "ymax"] <<- input$ImagePlot_brush$coords_css$ymax
              session$resetBrush("ImagePlot_brush")
            }
          }

          if (write_image) {
            if (!is(shiny::isolate(current$image), "try-error")) {
              server.write_image(
                multi_label = multi_label,
                image_cache = list(shiny::isolate(current$image)),
                image_format = image_format,
                currentRows = shiny::isolate(currentRow$number),
                imageSelection = 1,
                multimedia = multimedia,
                backupDir = backupDir
              )
            }
          }

          shiny::updateCheckboxGroupInput(
            inputId = "checkbox",
            selected =
              character(0)
          )

          currentRow$number <- shiny::isolate(currentRow$number) + 1

          trigger$activateDownloadImages <- trigger$activateDownloadImages + 1
        }
      })
    }


    shiny::observeEvent(input$exclude, {
      disableBServer(label2disable = labelBtn)
      multimedia$label[shiny::isolate(currentRow$number)] <<- "exclude"
      currentRow$number <- shiny::isolate(currentRow$number) + 1
      trigger$activateDownloadImages <- 1
    })


    shiny::observeEvent(input$prevImage, {
      if (shiny::isolate(currentRow$number) > 1) {
        currentRow$number <- shiny::isolate(currentRow$number) - 1
        if (!is(shiny::isolate(current$image), "try-error")) {
          disableBServer(label2disable = labelBtn)
          trigger$activateDownloadImages <- 1
        } else {
          shiny::showNotification("The last image cannot be read or displayed.",
            duration = 6,
            closeButton = TRUE,
            type = "error"
          )
        }
      } else {
        shiny::showNotification("'Back' not possible. You are looking at the first image.",
          duration = 6,
          closeButton = TRUE,
          type = "error"
        )
      }
    })


    shiny::observeEvent(input$nextImage, {
      if (multimedia$label[shiny::isolate(currentRow$number)] != "NA") {
        disableBServer(label2disable = labelBtn)
        currentRow$number <- shiny::isolate(currentRow$number) + 1
        trigger$activateDownloadImages <- 1
      }
    })


    shiny::observeEvent(input$currentTab, {
      if (input$currentTab == "Progress") {
        pb_values <- vector(mode = "integer", length = length(label))
        pb_values <- lapply(label, function(x) {
          sum(x == multimedia$label)
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


    shiny::observeEvent(input$backup, {
      disableBServer(label2disable = labelBtn)
      notification <- shiny::showNotification("Creating Backup",
        type = "message"
      )
      backupDataServer(
        data = multimedia,
        backupPath = backupDir,
        backup_cache = backup_cache
      )
      enableBServer(label2enable = labelBtn)
      on.exit(shiny::removeNotification(notification), add = TRUE)
    })


    shiny::observeEvent(input$close, {
      disableBServer(label2disable = labelBtn)
      shiny::showNotification("Closing app",
        type = "message"
      )
      backupDataServer(
        data = multimedia,
        backupPath = backupDir,
        backup_cache = backup_cache
      )
      shinyjs::js$closeWindow()
      shiny::stopApp()
    })


    shiny::observe({
      shiny::invalidateLater(backupInterval * 60 * 1000)
      notification <- shiny::showNotification("Creating Backup",
        type = "message"
      )

      backupDataServer(
        data = multimedia,
        backupPath = backupDir,
        backup_cache = backup_cache
      )
      on.exit(shiny::removeNotification(notification), add = TRUE)
    })


    shiny::onStop(
      function() {
        backupDataServer(
          data = multimedia,
          backupPath = backupDir,
          backup_cache = backup_cache
        )
      },
      session = session
    )
  }
  return(server)
}
