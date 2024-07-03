server.imgbif_app_multi.image <- function(firstRow, nRow, labelBtn, multimedia, backupDir, classSize, labelId, label, backupInterval, multi_label, pbID, slider, brush_image, backup_cache, write_image, image_format) {
  server <- function(input, output, session) {
    uniqueIDs <- unique(multimedia[multimedia$label == "NA", "gbifID"])

    currentID <- shiny::reactiveValues(index = 1)

    current <- shiny::reactiveValues(Rows = 0)

    cache <- shiny::reactiveValues(imageSelection = vector(mode = "double"))

    trigger <- shiny::reactiveValues(activateDownloadImages = 0, activateRenderPlots = list(), activateImageSelection = 0)
    trigger$activateDownloadImages <- 1


    shiny::observeEvent(trigger$activateDownloadImages, {
      imgPlot_list <- list()
      current_indentifier_idx <- which(multimedia$gbifID == uniqueIDs[shiny::isolate(currentID$index)])

      current_indentifier_vec <- multimedia[current_indentifier_idx, "identifier"]
      current$Rows <- current_indentifier_idx

      shiny::withProgress(message = "Downloading image...", value = 0, {
        n <- length(current_indentifier_vec)
        for (i in seq_along(current_indentifier_vec)) {
          shiny::incProgress(1 / n, detail = paste0(i, "/", n))

          identifier <- current_indentifier_vec[i]

          image <- try2read(identifier = identifier)

          if (is(image, "try-error")) {
            index <- which(multimedia$identifier == identifier)
            multimedia[index, "label"] <<- "exclude"
          }

          if (!is(image, "try-error")) {
            magick2ggplot <- magick::image_ggplot(image)
            imgPlot_list[[i]] <- magick2ggplot
          }
        }
      })

      if (length(imgPlot_list) == 0) {
        currentID$index <- shiny::isolate(currentID$index) + 1

        trigger$activateDownloadImages <- trigger$activateDownloadImages + 1
      }


      if (length(imgPlot_list) > 0) {
        enableBServer(label2enable = labelBtn)

        output$gbifID <- shiny::renderText({
          multimedia$gbifID[current$Rows[1]]
        })

        try_created <- try({
          (format(as.Date(multimedia$created[current$Rows[1]]), "%d. %b %Y"))
        })

        if (!is(try_created, "try-error")) {
          output$date <- shiny::renderText({
            try_created
          })
        }

        output$DynamicImageSpace <- shiny::renderUI({
          outputPlot_list <- lapply(seq_along(imgPlot_list), function(i) {
            imgPlotName <- paste0("img", multimedia$gbifID[shiny::isolate(current$Rows[1])], "-", i)

            column(
              width = 6,
              shiny::tags$div(
                id = paste0(imgPlotName, "-border"),
                class = "white-border",
                shiny::tags$style(
                  ".white-border {
          border: 3px solid white;
        }
        .red-border {
          border: 3px solid red;
        }"
                ),
                shiny::plotOutput(
                  outputId = imgPlotName,
                  inline = FALSE,
                  brush = if (brush_image) shiny::brushOpts(id = paste0(imgPlotName, "_brush"), stroke = "#BB29BB", fill = "#C5B4E3") else NULL,
                  fill = FALSE,
                  click = paste0(imgPlotName, "_click"),
                  width = "100%",
                  height = "400px"
                )
              )
            )
          })


          do.call(shiny::tagList, outputPlot_list)
        })

        trigger$activateRenderPlots <- imgPlot_list
      }
    })

    shiny::observeEvent(trigger$activateRenderPlots,
      {
        shiny::withProgress(message = "Rendering plot for...", value = 0, {
          n <- length(shiny::isolate(trigger$activateRenderPlots))

          lapply(seq_along(shiny::isolate(trigger$activateRenderPlots)), function(i) {
            shiny::incProgress(1 / n, detail = paste0("Image ", i, "/", n))

            imgPlotName <- paste0("img", multimedia$gbifID[shiny::isolate(current$Rows[1])], "-", i)

            output[[imgPlotName]] <- shiny::renderPlot(
              expr = shiny::isolate(trigger$activateRenderPlots[[i]]),
            )
          })
        })
        trigger$activateImageSelection <- trigger$activateImageSelection + 1
      },
      ignoreInit = FALSE
    )

    shiny::observeEvent(trigger$activateImageSelection, {
      cache$imageSelection <- vector(mode = "double")
      lapply(seq_along(shiny::isolate(trigger$activateRenderPlots)), function(i) {
        imgPlotName <- paste0("img", multimedia$gbifID[shiny::isolate(current$Rows[1])], "-", i)
        shiny::observeEvent(input[[paste0(imgPlotName, "_click")]], {
          if (!any(shiny::isolate(cache$imageSelection == i))) {
            shinyjs::removeClass(paste0(imgPlotName, "-border"), "white-border")
            shinyjs::addClass(paste0(imgPlotName, "-border"), "red-border")
            shiny::isolate(cache$imageSelection[length(shiny::isolate(cache$imageSelection)) + 1] <- i)
          } else {
            shinyjs::removeClass(paste0(imgPlotName, "-border"), "red-border")
            shinyjs::addClass(paste0(imgPlotName, "-border"), "white-border")
            shiny::isolate(
              cache$imageSelection <- shiny::isolate(cache$imageSelection[!(shiny::isolate(cache$imageSelection == i))])
            )
          }
        })
      })
    })


    if (!multi_label) {
      actionButtonServer <- lapply(labelId, function(i) {
        shiny::observeEvent(input[[i]], {
          if ((length(shiny::isolate(cache$imageSelection)) == 0) && !(length(shiny::isolate(trigger$activateRenderPlots)) == 1)) {
            shiny::showNotification("Please select at least one image by clicking on it
                                \n and submit again.",
              duration = 6,
              closeButton = TRUE,
              type = "error"
            )
          } else {
            disableBServer(label2disable = labelBtn)

            index <- as.numeric(stringr::str_remove_all(i, "btn"))

            multimedia[current$Rows[shiny::isolate(cache$imageSelection)], "label"] <<- shiny::isolate(label[index])
            multimedia[current$Rows[shiny::isolate(-cache$imageSelection)], "label"] <<- "exclude"

            if (slider) {
              multimedia[current$Rows[shiny::isolate(cache$imageSelection)], "scale"] <<- input$slider
            }

            if (brush_image) {
              lapply(shiny::isolate(cache$imageSelection), function(i) {
                imgPlotName <- paste0("img", multimedia$gbifID[shiny::isolate(current$Rows[1])], "-", i, "_brush")
                if (length(input[[imgPlotName]]) > 0) {
                    multimedia[current$Rows[shiny::isolate(cache$imageSelection)], "xmin"] <<- input[[imgPlotName]]$coords_css$xmin
                    multimedia[current$Rows[shiny::isolate(cache$imageSelection)], "ymin"] <<- input[[imgPlotName]]$coords_css$ymin
                    multimedia[current$Rows[shiny::isolate(cache$imageSelection)], "xmax"] <<- input[[imgPlotName]]$coords_css$xmax
                    multimedia[current$Rows[shiny::isolate(cache$imageSelection)], "ymax"] <<- input[[imgPlotName]]$coords_css$ymax

                }
              })
            }

            if (write_image) {
              server.write_image(
                multi_label = multi_label,
                image_cache = shiny::isolate(trigger$activateRenderPlots),
                image_format = image_format,
                currentRows = shiny::isolate(current$Rows),
                imageSelection = shiny::isolate(cache$imageSelection),
                multimedia = multimedia,
                backupDir = backupDir,
                label = label[index]
              )
            }

            imgPlotName <- paste0("img", multimedia$gbifID[shiny::isolate(current$Rows[1])], "-", i)

            currentID$index <- shiny::isolate(currentID$index) + 1

            trigger$activateDownloadImages <- trigger$activateDownloadImages + 1
          }
        })
      })
    }


    if (multi_label) {
      checkboxServer <- shiny::observeEvent(input$submitBtn, {
        if (length(shiny::isolate(input[["checkbox"]])) == 0) {
          shiny::showNotification("Please select at least one label
                                \n and submit again.",
            duration = 6,
            closeButton = TRUE,
            type = "error"
          )
        }

        if ((length(shiny::isolate(cache$imageSelection)) == 0) && !(length(shiny::isolate(trigger$activateRenderPlots)) == 1)) {
          shiny::showNotification("Please select at least one image by clicking on it
                                \n and submit again.",
            duration = 6,
            closeButton = TRUE,
            type = "error"
          )
        }

        if ((length(shiny::isolate(cache$imageSelection)) > 0) && (length(shiny::isolate(input[["checkbox"]])) > 0)) {
          disableBServer(label2disable = labelBtn)

          multimedia[current$Rows[shiny::isolate(cache$imageSelection)], "label"] <<- shiny::isolate(input[["checkbox"]])
          multimedia[current$Rows[shiny::isolate(-cache$imageSelection)], "label"] <<- "exclude"

          if (slider) {
            multimedia[current$Rows[shiny::isolate(cache$imageSelection)], "scale"] <<- input$slider
          }

          if (brush_image) {
            lapply(shiny::isolate(cache$imageSelection), function(i) {
              imgPlotName <- paste0("img", multimedia$gbifID[shiny::isolate(current$Rows[1])], "-", i, "_brush")
              if (length(input[[imgPlotName]]) > 0) {
                  multimedia[current$Rows[shiny::isolate(cache$imageSelection)], "xmin"] <<- input[[imgPlotName]]$coords_css$xmin
                  multimedia[current$Rows[shiny::isolate(cache$imageSelection)], "ymin"] <<- input[[imgPlotName]]$coords_css$ymin
                  multimedia[current$Rows[shiny::isolate(cache$imageSelection)], "xmax"] <<- input[[imgPlotName]]$coords_css$xmax
                  multimedia[current$Rows[shiny::isolate(cache$imageSelection)], "ymax"] <<- input[[imgPlotName]]$coords_css$ymax
              }
            })
          }

          if (write_image) {
            server.write_image(
              multi_label = multi_label,
              image_cache = shiny::isolate(trigger$activateRenderPlots),
              image_format = image_format,
              currentRows = shiny::isolate(current$Rows),
              imageSelection = shiny::isolate(cache$imageSelection),
              multimedia = multimedia,
              backupDir = backupDir
            )
          }

          shiny::updateCheckboxGroupInput(
            inputId = "checkbox",
            selected =
              character(0)
          )
          currentID$index <- shiny::isolate(currentID$index) + 1

          trigger$activateDownloadImages <- trigger$activateDownloadImages + 1
        }
      })
    }

    shiny::observeEvent(input$exclude, {
      disableBServer(label2disable = labelBtn)
      multimedia[shiny::isolate(current$Rows), "label"] <<- "exclude"


      currentID$index <- shiny::isolate(currentID$index) + 1


      trigger$activateDownloadImages <- trigger$activateDownloadImages + 1
    })

    shiny::observeEvent(input$currentTab, {
      if (input$currentTab == "Progress") {
        pb_values <- vector(mode = "integer", length = length(label))
        pb_values <- lapply(label, function(x) {
          sum(x == multimedia[, "label"])
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
