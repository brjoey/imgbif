server <- function(firstRow, nRow, labelBtn, multimedia, identifier_label, backupDir, classSize, labelId, label, backupInterval, pb_values, multi_label, pbID, image_cache) {
  server <- function(input, output, session) {
    currentRow <- shiny::reactiveValues(number = firstRow)


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
        backupDataServer(
          data = multimedia,
          label_list = identifier_label,
          backupPath = backupDir
        )
        shinyjs::js$closeWindow()
        shiny::stopApp()
      } else {
        image <- try2read(identifier = multimedia$identifier[currentRow$number])


        while (is(image, "try-error")) {
          notification <- shiny::showNotification("Trying to read image from URL.\n
                                                Please wait...",
            closeButton = TRUE,
            type = "message"
          )

          identifier_label[[currentRow$number]] <<- "exclude"

          currentRow$number <- shiny::isolate(currentRow$number) + 1

          image <- try2read(identifier = multimedia$identifier[currentRow$number])

          on.exit(shiny::removeNotification(notification), add = TRUE)
        }


        enableBServer(label2enable = labelBtn)


        output$ImagePlot <- shiny::renderPlot({
          magick::image_ggplot(image)
        })


        output$gbifID <- shiny::renderText({
          multimedia$gbifID[currentRow$number]
        })


        try_created <- try({
          (format(as.Date(multimedia$created[currentRow$number]), "%d. %b %Y"))
        })

        if (!is(try_created, "try-error")) {
          output$date <- shiny::renderText({
            try_created
          })
         } #else {
        #   output$date <- shiny::renderText({
        #     "Unkown"
        #   })
        # }


        assigned_label_txt <- try({
          identifier_label[[currentRow$number]]
        })

        if (!is(assigned_label_txt, "try-error")) {
          output$assigned_label <- shiny::renderText({
            assigned_label_txt
          })
         } # else {
        #   output$assigned_label <- shiny::renderText({
        #     "Unknown"
        #   })
        # }


        image_cache[[1]] <<- image
      }
    })


    if (!multi_label) {
      actionButtonServer <- lapply(labelId, function(i) {
        shiny::observeEvent(input[[i]], {
          disableBServer(label2disable = labelBtn)

          index <- as.numeric(stringr::str_remove_all(i, "btn"))

          identifier_label[[currentRow$number]] <<- label[index]

          # lapply(seq_along(pbID), function(j) {
          #   shinyWidgets::updateProgressBar(
          #     id = pbID[j],
          #     session = session,
          #     value = (pb_values[[j]] + input[[labelId[j]]]),
          #     total = classSize
          #   )
          # })

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

          identifier_label[[currentRow$number]] <<- input[["checkbox"]]

          # lapply(seq_along(pb_values), function(i) {
          #   pb_values[[i]] <<- pb_values[[i]] + 1 * (label[[i]] %in% input[["checkbox"]])
          # })
          #
          # lapply(seq_along(pbID), function(j) {
          #   shinyWidgets::updateProgressBar(
          #     id = pbID[j],
          #     session = session,
          #     value = pb_values[[j]],
          #     total = classSize
          #   )
          # })

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
      identifier_label[[currentRow$number]] <<- "exclude"
      currentRow$number <- shiny::isolate(currentRow$number) + 1
      trigger$activate <- 1
    })


    shiny::observeEvent(input$prevImage, {
      if (currentRow$number > 1) {
        currentRow$number <- shiny::isolate(currentRow$number) - 1
        if (!is(image_cache[[1]], "try-error")) {
          disableBServer(label2disable = labelBtn)
          trigger$activate <- 1
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
      if (identifier_label[[currentRow$number]] != "NA") {
        disableBServer(label2disable = labelBtn)
        currentRow$number <- shiny::isolate(currentRow$number) + 1
        trigger$activate <- 1
      }
    })


    shiny::observeEvent(input$currentTab, {
      if (input$currentTab == "Progress") {
        pb_values <- vector(mode = "integer", length = length(label))
        pb_values <- lapply(label, function(x) {
          sum(x == identifier_label)
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
        label_list = identifier_label,
        backupPath = backupDir
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
        label_list = identifier_label,
        backupPath = backupDir
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
        label_list = identifier_label,
        backupPath = backupDir
      )
      on.exit(shiny::removeNotification(notification), add = TRUE)
    })


    shiny::onStop(
      function() {
        backupDataServer(
          data = multimedia,
          label_list = identifier_label,
          backupPath = backupDir
        )
      },
      session = session
    )
  }
  return(server)
}
