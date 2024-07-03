#' Setup Classification App to Label Images from GBIF Multimedia File
#'
#' Sets up and launches a Shiny application to manually classify images from a GBIF multimedia file.
#'
#' @param multimedia A `data.frame` or the path to the GBIF multimedia file (with the extension "txt", "csv", or "feather").
#' @param classSize A `numeric` value with the desired number of images per class (label) for tracking purposes.
#' @param label A `character` `vector` that contains the label for each class.
#' @param multi_label A `Boolean` value that indicates if multiple label (TRUE) can be assigned to one image or not (FALSE).
#'   The app launches with check boxes if "multi_label = TRUE" and with action buttons if "multi_label = FALSE".
#' @param backupDir A `character` string that specifies the path to the directory for storing backups and the final file.
#' @param backupInterval A `numeric` value that indicates the interval for automatic backups of the multimedia file (in minutes).
#' @param image_format A character vector specifying the image format such as 'png' or 'jpeg'. 'png' by default.
#' @param write_image A logical value indicating whether the selected images should be written to disk into the backup directory. Default is FALSE.
#' @param multi_image A logical value indicating whether the multi-image app that displays all images of a gbifID at once should be selected, or the single-image app. Default is FALSE.
#' @param brush_image A logical value. If TRUE, the user can draw a rectangle on the image and store the edges of the frame. Default is FALSE.
#' @param slider A logical value indicating whether a slider should be displayed in the respective app. Default is FALSE.
#' @param sliderRange A numeric vector containing the minimum, default value, and maximum value of the slider.
#' @return A `shiny` app for image classification is launched, and a modified `data.frame` is written into "backupDir".
#' @note The modified `data.frame` is written using the `feather` package. The assigned labels are stored in a new "label" column as character vectors.
#' @import shiny
#' @import shinyjs
#' @import htmltools
#' @import magick
#' @import feather
#' @import shinyWidgets
#' @import stringr
#' @import tools
#' @import ggplot2 ggsave
#' @export
imgbif_app.dev <- function(multimedia,
                           classSize = 100,
                           label,
                           multi_label = FALSE,
                           backupDir,
                           backupInterval = 1,
                           image_format = "png",
                           write_image = FALSE,
                           multi_image = TRUE,
                           brush_image = FALSE,
                           slider = FALSE,
                           sliderRange = NULL # min = 0, max = 100, value = 50)
) {
  if (missing(multimedia)) {
    stop("Multimedia data frame or path to multimedia.txt file is required")
  } else {
    if (!is(multimedia, "tbl_df") && !is(multimedia, "data.frame")) {
      extension <- tools::file_ext(multimedia)
      if (extension == "txt") {
        multimedia <- try({
          read.csv2(multimedia, sep = "\t", na.strings = "", quote = "")
        })
      }
      if (extension == "csv") {
        multimedia <- try({
          read.csv2(multimedia, sep = "\t", na.strings = "", quote = "")
        })
      }
      if (extension == "feather") {
        multimedia <- try({
          feather::read_feather(multimedia)
        })
      }
      if (is(multimedia, "try-error")) {
        stop("Could not find provided path (multimedia):", multimedia)
      }
    }
  }

  multimedia <- remove_na_identifier_gbifID(m.df = multimedia)

  if (missing(label)) {
    stop("label character vector is required.")
  }



  if (!dir.exists(file.path(backupDir))) {
    stop("Could not find the provided backupDir.")
  }

  backup_cache <- vector(mode = "character", length = 3)

  if (dir.exists(file.path(backupDir))) {
    testWriteBackup <- try({
      backupDataServer(
        data = multimedia,
        backupPath = backupDir,
        backup_cache = backup_cache
      )
    })
  }


  if (!("label" %in% colnames(multimedia))) {
    multimedia$label <- "NA"
  }

  if (slider && !("scale" %in% colnames(multimedia))) {
    multimedia$scale <- "NA"
  }

  if (slider) {
    if (length(sliderRange) != 3) {
      stop("Provide a min, max and default value (int) for scaleRange.")
    }
    lapply(seq_along(sliderRange), \(x) {
      if (!is.integer(x)) {
        stop("sliderRange contains at least one non integer element´.")
      }
    })
  }

  if (brush_image) {
    multimedia$xmin <- "NA"
    multimedia$ymin <- "NA"
    multimedia$xmax <- "NA"
    multimedia$ymax <- "NA"
  }



  firstRow <- which(multimedia$label == "NA")[1]



  if (!is.numeric(classSize) || length(classSize) != 1) {
    stop("classSize must be a single numeric value.")
  }


  pbID <- paste0("pb", seq_along(label))


  if (!is.numeric(backupInterval) || backupInterval <= 0) {
    stop("backupInterval must be a positive numeric value.")
  }


  labelId <- paste0("btn", seq_along(label))

  static_labelBtn <- c("exclude", "backup", "lastImage", "nextImage")
  if (!multi_label) {
    labelBtn <- c(labelId, static_labelBtn)
  } else {
    labelBtn <- c("submitBtn", static_labelBtn)
  }


  nRow <- nrow(multimedia)

  if (write_image) {
    if (!dir.exists(file.path(backupDir, "GBIF_multimedia_file_images"))) {
      dir.create(file.path(backupDir, "GBIF_multimedia_file_images"))
    }
    if (!multi_label) {
      for (folder in label) {
        if (!dir.exists(file.path(backupDir, "GBIF_multimedia_file_images", folder))) {
          dir.create(file.path(backupDir, "GBIF_multimedia_file_images", folder))
        }
      }
    }
  }

  if (multi_image) {
    server <- server.imgbif_app_multi.image(
      firstRow = firstRow,
      nRow = nRow,
      labelBtn = labelBtn,
      multimedia = multimedia,
      backupDir = backupDir,
      classSize = classSize,
      labelId = labelId,
      label = label,
      backupInterval = backupInterval,
      multi_label = multi_label,
      pbID = pbID,
      backup_cache = backup_cache,
      brush_image = brush_image,
      slider = slider,
      write_image = write_image,
      image_format = image_format
    )

    ui <- ui.imgbif_app_multi.image(
      label = label,
      multi_label = multi_label,
      pbID = pbID,
      classSize = classSize,
      slider = slider,
      sliderRange = sliderRange
    )
  }

  if (!multi_image) {
    server <- server.imgbif_app(
      firstRow = firstRow,
      nRow = nRow,
      labelBtn = labelBtn,
      multimedia = multimedia,
      backupDir = backupDir,
      classSize = classSize,
      labelId = labelId,
      label = label,
      backupInterval = backupInterval,
      multi_label = multi_label,
      pbID = pbID,
      backup_cache = backup_cache,
      brush_image = brush_image,
      slider = slider,
      write_image = write_image,
      image_format = image_format
    )

    ui <- ui.imgbif_app(
      label = label,
      multi_label = multi_label,
      pbID = pbID,
      classSize = classSize,
      brush_image = brush_image,
      slider = slider,
      sliderRange = sliderRange
    )
  }

  shiny::shinyApp(ui = ui, server = server)
}
