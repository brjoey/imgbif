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
#' @export
#' @examples
#' \dontrun{
#' imgbif_app(
#'   multimedia = "path/to/multimedia.txt",
#'   classSize = 100,
#'   label = c("flowering", "fruiting"),
#'   multi_label = FALSE,
#'   backupDir = "path/to/backup",
#'   backupInterval = 1
#' )
#' }
imgbif_app <- function(multimedia,
                      classSize = 100,
                      label,
                      multi_label = FALSE,
                      backupDir,
                      backupInterval = 1) {
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


  if (dir.exists(file.path(backupDir))) {
    testWriteBackup <- try({
      feather::write_feather(multimedia, file.path(backupDir, "multimedia.feather"))
    })
    if (is(testWriteBackup, "try-error")) {
      stop("Could not write to provided backupDir.")
    }
  }


  if (!("label" %in% colnames(multimedia))) {
    multimedia$label <- "NA"
  }

  firstRow <- which(multimedia$label == "NA")[1]



  if (!is.numeric(classSize) || length(classSize) != 1) {
    stop("classSize must be a single numeric value.")
  }

  jscode <- "shinyjs.closeWindow = function() { window.close(); }"


  pbID <- paste0("pb", seq_along(label))


  if (!is.numeric(backupInterval) || backupInterval <= 0) {
    stop("backupInterval must be a positive numeric value.")
  }


  labelId <- paste0("btn", seq_along(label))

  # if (firstRow == 1) {
  #   pb_values <- vector(mode = "list", length = length(label))
  #   pb_values <- lapply(seq_along(pb_values), function(i) {pb_values[[i]] <- 0})
  # } else {
  #   pb_values <- vector(mode = "integer", length = length(label))
  #   pb_values <- lapply(label, function(x) {sum(x == multimedia$label)})
  # }


  static_labelBtn <- c("exclude", "backup", "lastImage", "nextImage")
  if (!multi_label) {
    labelBtn <- c(labelId, static_labelBtn)
  } else {
    labelBtn <- c("submitBtn", static_labelBtn)
  }


  nRow <- nrow(multimedia)


  identifier_label <- as.list(multimedia$label)

  image_cache <- vector(mode = "list", length = 1)


  ui <- ui(
    label = label, multi_label = multi_label, jscode = jscode,
    pbID = pbID, classSize = classSize
  )
  server <- server(
    firstRow = firstRow, nRow = nRow, labelBtn = labelBtn,
    multimedia = multimedia, identifier_label = identifier_label,
    backupDir = backupDir, classSize = classSize,
    labelId = labelId, label = label,
    backupInterval = backupInterval, pb_values = pb_values,
    multi_label = multi_label, pbID = pbID, image_cache = image_cache
  )
  shiny::shinyApp(ui = ui, server = server)
}
